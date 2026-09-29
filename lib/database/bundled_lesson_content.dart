import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'flashcard_seed.dart';

const bundledLessonRewriteMarker = 'bundled_lessons_rewrite_v1';

Future<List<Map<String, dynamic>>> _sentenceDecks() async =>
    (jsonDecode(
              await rootBundle.loadString('assets/data/sentence_practice.json'),
            )
            as List)
        .cast<Map<String, dynamic>>();

/// Older versions did not record origin. Claim only the earliest matching
/// bundled deck, never every lesson sharing its title. Vocabulary decks must
/// also have the original word sequence, so custom same-title decks survive.
Future<void> identifyLegacyBundledLessons(DatabaseExecutor db) async {
  final definitions = <Map<String, dynamic>>[
    ...flashcardLessons,
    for (final deck in await _sentenceDecks())
      {
        'lesson_title': 'Sentence practice · ${deck['topic']}',
        'theme': deck['topic'],
        'hsk_level': 3,
        'sentence': true,
      },
  ];
  for (final definition in definitions) {
    final sentence = definition['sentence'] == true;
    final rows = await db.query(
      'lessons',
      columns: ['id'],
      where:
          'lesson_title = ? AND theme = ? AND hsk_level = ? '
          'AND is_sentence_practice = ? AND is_listed = 1 AND guide_json IS NULL',
      whereArgs: [
        definition['lesson_title'],
        definition['theme'],
        definition['hsk_level'],
        sentence ? 1 : 0,
      ],
      orderBy: 'id ASC',
    );
    for (final row in rows) {
      final cards = await db.query(
        'cards',
        columns: ['chinese'],
        where: 'lesson_id = ?',
        whereArgs: [row['id']],
        orderBy: 'id ASC',
      );
      final words = sentence
          ? null
          : (definition['cards'] as List).map((c) => c['chinese']).toList();
      if (sentence
          ? cards.length != 10
          : cards.length != words!.length ||
                cards.indexed.any(
                  (entry) => entry.$2['chinese'] != words[entry.$1],
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
  await db.update('lessons', {'is_user_generated': 0}, where: 'is_listed = 0');
}

/// Runs in the caller's transaction. Updates content in place, leaving IDs,
/// card order, review events, scheduling, and lesson sessions untouched.
Future<void> refreshBundledLessonContent(DatabaseExecutor db) async {
  if ((await db.query(
    'content_migrations',
    where: 'key = ?',
    whereArgs: [bundledLessonRewriteMarker],
  )).isNotEmpty) {
    return;
  }
  for (final lesson in flashcardLessons) {
    final rows = await db.query(
      'lessons',
      columns: ['id'],
      where:
          'lesson_title = ? AND is_user_generated = 0 AND is_sentence_practice = 0',
      whereArgs: [lesson['lesson_title']],
    );
    for (final row in rows) {
      for (final card
          in (lesson['cards'] as List).cast<Map<String, dynamic>>()) {
        await db.update(
          'cards',
          {
            'pinyin': card['pinyin'],
            'english_meaning': card['english_meaning'],
            'part_of_speech': card['part_of_speech'],
            'example_sentence_chinese': card['example_sentence_chinese'],
            'example_sentence_pinyin': card['example_sentence_pinyin'],
            'example_sentence_english': card['example_sentence_english'],
            'quiz_options': jsonEncode(card['quiz_options']),
            'correct_answer': card['correct_answer'],
            // These are original examples, not the previously imported corpus pairs.
            'example_source': '',
            'example_source_id': '',
            'example_translation_id': '',
          },
          where: 'lesson_id = ? AND chinese = ?',
          whereArgs: [row['id'], card['chinese']],
        );
      }
    }
  }
  for (final deck in await _sentenceDecks()) {
    final rows = await db.query(
      'lessons',
      columns: ['id'],
      where:
          'lesson_title = ? AND is_user_generated = 0 AND is_sentence_practice = 1',
      whereArgs: ['Sentence practice · ${deck['topic']}'],
    );
    for (final row in rows) {
      final cards = await db.query(
        'cards',
        columns: ['id'],
        where: 'lesson_id = ?',
        whereArgs: [row['id']],
        orderBy: 'id ASC',
      );
      final sentences = deck['sentences'] as List;
      if (cards.length != sentences.length) {
        throw StateError('Unexpected bundled sentence deck size.');
      }
      for (var i = 0; i < cards.length; i++) {
        final sentence = sentences[i] as Map<String, dynamic>;
        await db.update(
          'cards',
          {
            'chinese': sentence['chinese'],
            'pinyin': sentence['pinyin'],
            'english_meaning': sentence['english'],
            'correct_answer': sentence['english'],
          },
          where: 'id = ?',
          whereArgs: [cards[i]['id']],
        );
      }
    }
  }
  await db.insert('content_migrations', {
    'key': bundledLessonRewriteMarker,
    'applied_at': DateTime.now().toUtc().toIso8601String(),
  });
}
