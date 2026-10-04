import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../repositories/bundled_vocabulary_repository.dart';
import 'flashcard_seed.dart';
import 'vocabulary_content.dart';

const vocabularyCurriculumMarker = 'bundled_hsk_curriculum_v1';
const vocabularyExampleCorrectionsMarker = 'bundled_hsk_examples_v2';
const vocabularyLessonSize = 20;

/// Classify only the first exact bundled deck in backups lacking provenance.
/// Later copies with the same title remain learner-created lessons.
Future<void> identifyVocabularyCurriculumLessons(DatabaseExecutor db) async {
  final document =
      jsonDecode(
            await rootBundle.loadString('assets/data/vocabulary_lessons.json'),
          )
          as Map<String, dynamic>;
  final vocabulary = await const BundledVocabularyRepository().load();
  final byId = {for (final word in vocabulary) word['id']: word};
  for (final definition
      in (document['lessons'] as List).cast<Map<String, dynamic>>()) {
    final rows = await db.query(
      'lessons',
      columns: ['id'],
      where:
          'lesson_title = ? AND hsk_level = ? AND is_sentence_practice = 0 AND guide_json IS NULL',
      whereArgs: [definition['title'], definition['hskLevel']],
      orderBy: 'id ASC',
    );
    final expected = [
      for (final entry in definition['entries'] as List)
        _wordKey(
          byId[entry['vocabularyId']]!['simplified'] as String,
          byId[entry['vocabularyId']]!['pinyin'] as String,
        ),
    ];
    for (final row in rows) {
      final members = await db.rawQuery(
        '''
        SELECT cards.chinese, cards.pinyin FROM lesson_cards
        INNER JOIN cards ON cards.id = lesson_cards.card_id
        WHERE lesson_cards.lesson_id = ? ORDER BY lesson_cards.position ASC
      ''',
        [row['id']],
      );
      final cards = members.isNotEmpty
          ? members
          : await db.query(
              'cards',
              columns: ['chinese', 'pinyin'],
              where: 'lesson_id = ?',
              whereArgs: [row['id']],
              orderBy: 'id ASC',
            );
      if (cards.length != expected.length ||
          cards.indexed.any(
            (entry) =>
                _wordKey(
                  entry.$2['chinese'] as String,
                  entry.$2['pinyin'] as String,
                ) !=
                expected[entry.$1],
          )) {
        continue;
      }
      await db.update(
        'lessons',
        {'is_user_generated': 0},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      break;
    }
  }
}

String _wordKey(String chinese, String pinyin) =>
    '$chinese\u0000${pinyin.toLowerCase().replaceAll(RegExp(r"[\s']"), '')}';

/// Runs in the caller's transaction. Memberships let the new decks share
/// existing cards without moving cards out of unfinished historical lessons.
Future<void> installVocabularyCurriculum(DatabaseExecutor db) async {
  if ((await db.query(
    'content_migrations',
    where: 'key = ?',
    whereArgs: [vocabularyCurriculumMarker],
  )).isNotEmpty) {
    await _correctVocabularyExamples(db);
    return;
  }
  final document =
      jsonDecode(
            await rootBundle.loadString('assets/data/vocabulary_lessons.json'),
          )
          as Map<String, dynamic>;
  final vocabulary = await const BundledVocabularyRepository().load();
  final byId = {for (final word in vocabulary) word['id'] as String: word};
  final definitions = (document['lessons'] as List)
      .cast<Map<String, dynamic>>();
  final covered = <String>{};
  final titles = <String>{};
  for (final lesson in definitions) {
    final level = lesson['hskLevel'];
    final entries = (lesson['entries'] as List).cast<Map<String, dynamic>>();
    if (level is! int ||
        level < 1 ||
        level > 6 ||
        lesson['title'] is! String ||
        !titles.add(lesson['title'] as String) ||
        entries.length != vocabularyLessonSize ||
        entries.map((entry) => entry['vocabularyId']).toSet().length !=
            vocabularyLessonSize) {
      throw const FormatException('Invalid bundled vocabulary lesson.');
    }
    for (final entry in entries) {
      final word = byId[entry['vocabularyId']];
      if (word == null || word['hskLevel'] != level) {
        throw const FormatException('Invalid lesson vocabulary.');
      }
      covered.add(word['id'] as String);
      final example = entry['example'];
      if (example == null) {
        throw const FormatException('Missing lesson example.');
      }
      if (example is! Map<String, dynamic> ||
          !const ['Tatoeba', 'Original'].contains(example['source']) ||
          ['chinese', 'pinyin', 'english'].any(
            (field) =>
                example[field] is! String ||
                (example[field] as String).trim().isEmpty,
          ) ||
          !(example['chinese'] as String).contains(
            word['simplified'] as String,
          ) ||
          (example['source'] == 'Tatoeba' &&
              (int.tryParse(example['chineseId'] as String? ?? '') == null ||
                  int.tryParse(example['englishId'] as String? ?? '') ==
                      null))) {
        throw const FormatException('Invalid lesson example.');
      }
    }
  }
  if (covered.length != byId.length) {
    throw const FormatException(
      'Bundled lessons must cover every vocabulary entry.',
    );
  }

  final existing = await db.rawQuery('''
    SELECT cards.*, COALESCE(card_progress.times_seen, 0) AS saved_times_seen
    FROM cards INNER JOIN lessons ON lessons.id = cards.lesson_id
    LEFT JOIN card_progress ON card_progress.card_id = cards.id AND card_progress.learner_id = 1
    WHERE lessons.is_user_generated = 0 AND lessons.is_sentence_practice = 0
    ORDER BY saved_times_seen DESC, cards.id ASC
  ''');
  final cardIds = <String, int>{};
  for (final card in existing) {
    cardIds.putIfAbsent(
      _wordKey(card['chinese'] as String, card['pinyin'] as String),
      () => card['id'] as int,
    );
  }
  final installedLessons = await db.query(
    'lessons',
    columns: ['id', 'lesson_title'],
    where: 'is_user_generated = 0 AND is_sentence_practice = 0',
    orderBy: 'id ASC',
  );
  final lessonIds = <String, int>{};
  for (final row in installedLessons) {
    lessonIds.putIfAbsent(
      row['lesson_title'] as String,
      () => row['id'] as int,
    );
  }
  Future<int> nextId(String table) async =>
      ((await db.rawQuery(
            'SELECT MAX(COALESCE(MAX(id), 0), '
            "COALESCE((SELECT seq FROM sqlite_sequence WHERE name = ?), 0)) AS last_id FROM $table",
            [table],
          )).single['last_id']
          as int) +
      1;
  var nextLessonId = await nextId('lessons');
  var nextCardId = await nextId('cards');
  final updatedCards = <int>{};
  final batch = db.batch();
  for (final definition in definitions) {
    final title = definition['title'] as String;
    final previousId = lessonIds[title];
    final lessonId = previousId ?? nextLessonId++;
    if (previousId == null) {
      batch.insert('lessons', {
        'id': lessonId,
        'lesson_title': title,
        'theme': 'HSK ${definition['hskLevel']} vocabulary',
        'hsk_level': definition['hskLevel'],
        'is_listed': 1,
        'is_user_generated': 0,
      });
    } else {
      batch.update(
        'lessons',
        {'is_listed': 1},
        where: 'id = ?',
        whereArgs: [lessonId],
      );
      batch.delete(
        'lesson_cards',
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
      );
    }
    final entries = (definition['entries'] as List)
        .cast<Map<String, dynamic>>();
    final meanings = {
      for (final entry in entries)
        vocabularyStudyMeaning(byId[entry['vocabularyId']]!),
    };
    for (final (position, entry) in entries.indexed) {
      final word = byId[entry['vocabularyId']]!;
      final meaning = vocabularyStudyMeaning(word);
      final key = _wordKey(
        word['simplified'] as String,
        word['pinyin'] as String,
      );
      final example = entry['example'] as Map<String, dynamic>?;
      final values = <String, Object?>{
        'chinese': word['simplified'],
        'pinyin': word['pinyin'],
        'english_meaning': meaning,
        'part_of_speech': (word['partOfSpeech'] as List).join(', '),
        'hsk_level': word['hskLevel'],
        'example_sentence_chinese': example?['chinese'] ?? '',
        'example_sentence_pinyin': example?['pinyin'] ?? '',
        'example_sentence_english': example?['english'] ?? '',
        'example_source': example?['source'] ?? '',
        'example_source_id': example?['chineseId'] ?? '',
        'example_translation_id': example?['englishId'] ?? '',
        'quiz_options': jsonEncode([
          meaning,
          ...meanings.where((value) => value != meaning).take(3),
        ]),
        'correct_answer': meaning,
      };
      var cardId = cardIds[key];
      if (cardId == null) {
        cardId = nextCardId++;
        batch.insert('cards', {...values, 'id': cardId, 'lesson_id': lessonId});
        updatedCards.add(cardId);
        cardIds[key] = cardId;
      } else if (updatedCards.add(cardId)) {
        batch.update('cards', values, where: 'id = ?', whereArgs: [cardId]);
      }
      batch.insert('lesson_cards', {
        'lesson_id': lessonId,
        'card_id': cardId,
        'position': position,
      });
    }
  }
  // Keep historical cards/sessions for reviews and resumption, but replace the
  // default library. Never archive learner-created lessons sharing a title.
  for (final lesson in flashcardLessons) {
    batch.update(
      'lessons',
      {'is_listed': 0, 'is_archived': 1},
      where:
          'lesson_title = ? AND is_user_generated = 0 AND is_sentence_practice = 0',
      whereArgs: [lesson['lesson_title']],
    );
  }
  batch.insert('content_migrations', {
    'key': vocabularyCurriculumMarker,
    'applied_at': DateTime.now().toUtc().toIso8601String(),
  });
  await batch.commit(noResult: true);
  await _correctVocabularyExamples(db);
}

/// Update examples in place, without rebuilding memberships or choosing new
/// shared cards based on the learner's current progress. The caller owns the
/// transaction, including the completion marker.
Future<void> _correctVocabularyExamples(DatabaseExecutor db) async {
  if ((await db.query(
    'content_migrations',
    where: 'key = ?',
    whereArgs: [vocabularyExampleCorrectionsMarker],
  )).isNotEmpty) {
    return;
  }
  const correctedIds = {'hsk-old-2-最', 'hsk-old-3-一会儿'};
  final document =
      jsonDecode(
            await rootBundle.loadString('assets/data/vocabulary_lessons.json'),
          )
          as Map<String, dynamic>;
  final vocabulary = await const BundledVocabularyRepository().load();
  final byId = {for (final word in vocabulary) word['id']: word};
  for (final definition
      in (document['lessons'] as List).cast<Map<String, dynamic>>()) {
    for (final entry
        in (definition['entries'] as List).cast<Map<String, dynamic>>()) {
      if (!correctedIds.contains(entry['vocabularyId'])) continue;
      final word = byId[entry['vocabularyId']]!;
      final example = entry['example'] as Map<String, dynamic>;
      final cards = await db.rawQuery(
        '''
        SELECT DISTINCT cards.id, cards.chinese, cards.pinyin
        FROM cards
        INNER JOIN lessons owner ON owner.id = cards.lesson_id
        INNER JOIN lesson_cards ON lesson_cards.card_id = cards.id
        INNER JOIN lessons deck ON deck.id = lesson_cards.lesson_id
        WHERE owner.is_user_generated = 0 AND owner.is_sentence_practice = 0
          AND deck.is_user_generated = 0 AND deck.is_sentence_practice = 0
          AND deck.lesson_title = ? AND cards.chinese = ?
        ''',
        [definition['title'], word['simplified']],
      );
      for (final card in cards) {
        if (_wordKey(card['chinese'] as String, card['pinyin'] as String) !=
            _wordKey(word['simplified'] as String, word['pinyin'] as String)) {
          continue;
        }
        await db.update(
          'cards',
          {
            'example_sentence_chinese': example['chinese'],
            'example_sentence_pinyin': example['pinyin'],
            'example_sentence_english': example['english'],
            'example_source': example['source'],
            'example_source_id': example['chineseId'],
            'example_translation_id': example['englishId'],
          },
          where: 'id = ?',
          whereArgs: [card['id']],
        );
      }
    }
  }
  await db.insert('content_migrations', {
    'key': vocabularyExampleCorrectionsMarker,
    'applied_at': DateTime.now().toUtc().toIso8601String(),
  });
}
