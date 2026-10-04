import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/database/flashcard_seed.dart';
import 'package:mylanguageapp/database/vocabulary_lesson_content.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/models/learner_profile.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/backup_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:mylanguageapp/services/review_scheduler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const lessons = SqliteLessonRepository();
  const progress = SqliteProgressRepository();
  late Directory directory;
  setUp(() async {
    await LocalDatabase.close();
    directory = await Directory.systemTemp.createTemp('vocabulary_curriculum_');
    LocalDatabase.useDatabasePathForTesting('${directory.path}/test.db');
    await LocalDatabase.initialize();
    await const SqliteLearnerRepository().save(
      const LearnerProfile(name: 'Mei', hskLevel: 3, dailyWordTarget: 20),
    );
  });
  tearDown(() async {
    await LocalDatabase.close();
    LocalDatabase.useDatabasePathForTesting(inMemoryDatabasePath);
    await directory.delete(recursive: true);
  });

  test(
    '251 twenty-word lessons cover every entry with source-backed examples',
    () async {
      final vocabulary =
          (jsonDecode(
                    File('assets/data/hsk_vocabulary.json').readAsStringSync(),
                  )
                  as List)
              .cast<Map<String, dynamic>>();
      final expected = {
        for (final word in vocabulary)
          '${word['simplified']}|${word['pinyin']}',
      };
      final topics = (await lessons.topics())
          .where((topic) => !topic.isSentencePractice)
          .toList();
      expect(topics, hasLength(251));
      final covered = <String>{};
      var exampleCount = 0;
      for (final topic in topics) {
        final lesson = (await lessons.findById(topic.id))!;
        expect(lesson.cards, hasLength(20));
        expect(lesson.cards.map((card) => card.id).toSet(), hasLength(20));
        for (final card in lesson.cards) {
          covered.add('${card.chinese}|${card.pinyin}');
          expect(card.quizOptions.toSet(), hasLength(4));
          expect(card.quizOptions, contains(card.englishMeaning));
          exampleCount++;
          expect(card.exampleChinese, contains(card.chinese));
          expect(card.examplePinyin, isNotEmpty);
          expect(card.exampleEnglish, isNotEmpty);
          expect(card.exampleSource, anyOf('Tatoeba', 'Original'));
          if (card.exampleSource == 'Tatoeba') {
            expect(int.tryParse(card.exampleSourceId), greaterThan(0));
            expect(int.tryParse(card.exampleTranslationId), greaterThan(0));
          } else {
            expect(card.exampleSourceId, isEmpty);
            expect(card.exampleTranslationId, isEmpty);
          }
        }
      }
      expect(covered, expected);
      expect(exampleCount, 5020);
      final db = await LocalDatabase.ensureInitialized();
      expect(await db.query('lesson_cards'), hasLength(5020));
      expect(
        await db.query('cards', where: "part_of_speech <> 'sentence'"),
        hasLength(4991),
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'learned counts track shared cards, legacy ownership, and current mastery',
    () async {
      final topics = await lessons.topics();
      final vocabularyTopics = topics.where(
        (topic) => !topic.isSentencePractice,
      );
      final initial = await progress.lessonLearningProgress();
      for (final topic in vocabularyTopics) {
        expect(initial[topic.id]!.totalCards, 20);
        expect(initial[topic.id]!.learnedCards, 0);
      }
      final db = await LocalDatabase.ensureInitialized();
      final shared =
          (await db.rawQuery('''
        SELECT card_id FROM lesson_cards GROUP BY card_id
        HAVING COUNT(*) > 1 LIMIT 1
      ''')).single['card_id']
              as int;
      final memberships = await db.query(
        'lesson_cards',
        where: 'card_id = ?',
        whereArgs: [shared],
      );
      final now = DateTime.utc(2026, 10, 2);
      Future<void> saveReview(bool wasCorrect) => progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: shared,
          reviewedAt: now,
          rating: ReviewRating.good,
          wasCorrect: wasCorrect,
        ),
        progress: CardProgress(
          cardId: shared,
          dueAt: now.add(const Duration(days: 1)),
        ),
      );
      for (var index = 0; index < 5; index++) {
        await saveReview(index < 4);
      }
      var counts = await progress.lessonLearningProgress();
      for (final member in memberships) {
        expect(counts[member['lesson_id']]!.learnedCards, 1);
        expect(counts[member['lesson_id']]!.totalCards, 20);
      }
      await saveReview(false);
      counts = await progress.lessonLearningProgress();
      for (final member in memberships) {
        expect(counts[member['lesson_id']]!.learnedCards, 0);
      }
      expect(counts.values.every((count) => count.learnedCards == 0), isTrue);

      final bundled = (await lessons.findById(vocabularyTopics.first.id))!;
      await lessons.saveGenerated(bundled);
      final custom = (await lessons.topics()).firstWhere(
        (topic) => topic.isUserGenerated,
      );
      final legacy = (await lessons.findById(custom.id))!;
      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: legacy.cards.first.id,
          reviewedAt: now,
          rating: ReviewRating.good,
          wasCorrect: true,
        ),
        progress: CardProgress(
          cardId: legacy.cards.first.id,
          dueAt: now,
          timesSeen: 1,
          mastery: 1,
        ),
      );
      counts = await progress.lessonLearningProgress();
      expect(counts[custom.id]!.totalCards, 20);
      expect(counts[custom.id]!.learnedCards, 1);
      expect(counts[bundled.summary.id]!.learnedCards, 0);
    },
  );

  test(
    'version 16 upgrade reuses learned cards and preserves legacy sessions and custom lessons',
    () async {
      final db = await LocalDatabase.ensureInitialized();
      await db.execute(
        'DELETE FROM lessons WHERE id IN (SELECT lesson_id FROM lesson_cards)',
      );
      await db.delete(
        'content_migrations',
        where: 'key = ?',
        whereArgs: [vocabularyCurriculumMarker],
      );
      final definition = flashcardLessons.first;
      final legacyId = await db.insert('lessons', {
        'lesson_title': definition['lesson_title'],
        'theme': definition['theme'],
        'hsk_level': definition['hsk_level'],
        'is_user_generated': 0,
      });
      final oldCardIds = <int>[];
      for (final card
          in (definition['cards'] as List).cast<Map<String, dynamic>>()) {
        oldCardIds.add(
          await db.insert('cards', {
            ...card,
            'quiz_options': jsonEncode(card['quiz_options']),
            'hsk_level': definition['hsk_level'],
            'lesson_id': legacyId,
          }),
        );
      }
      final legacy = (await lessons.findById(legacyId))!;
      // 谢谢 is in the HSK dataset; the historical greeting 你好 is not.
      final reviewedCardId = legacy.cards
          .firstWhere((c) => c.chinese == '谢谢')
          .id;
      await lessons.saveGenerated(legacy);
      final custom = (await lessons.topics()).firstWhere(
        (topic) => topic.isUserGenerated,
      );
      final customCards = (await lessons.findById(
        custom.id,
      ))!.cards.map((card) => card.id).toList();
      final session = await progress.startSession(legacyId);
      final now = DateTime.utc(2026, 10, 2);
      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: reviewedCardId,
          sessionId: session.id,
          reviewedAt: now,
          rating: ReviewRating.good,
          wasCorrect: true,
        ),
        progress: scheduleCardReview(
          cardId: reviewedCardId,
          rating: ReviewRating.good,
          reviewedAt: now,
        ),
      );
      await progress.updateSession(
        LessonSession(
          id: session.id,
          lessonId: legacyId,
          startedAt: session.startedAt,
          currentCardIndex: 1,
          cardsReviewed: 1,
          correctAnswers: 1,
        ),
      );
      await const SqliteDailyReviewSessionRepository().create(
        date: now,
        queuedCardIds: oldCardIds.take(2).toList(),
      );
      final savedProgress = await db.query('card_progress');
      final savedReviews = await db.query('review_history');
      final savedQueue = await db.query('daily_review_sessions');
      await db.execute('DROP TABLE lesson_cards');
      await db.execute('ALTER TABLE lessons DROP COLUMN is_archived');
      await db.setVersion(16);
      await LocalDatabase.close();
      final upgraded = await LocalDatabase.ensureInitialized();
      expect(await upgraded.getVersion(), 17);
      expect(await upgraded.query('card_progress'), savedProgress);
      expect(await upgraded.query('review_history'), savedReviews);
      expect(await upgraded.query('daily_review_sessions'), savedQueue);
      expect(
        (await progress.activeSessionForLesson(legacyId))!.currentCardIndex,
        1,
      );
      expect(
        (await lessons.findById(legacyId))!.cards.map((card) => card.id),
        oldCardIds,
      );
      expect(
        (await lessons.findById(custom.id))!.cards.map((card) => card.id),
        customCards,
      );
      expect(
        (await lessons.topics()).any((topic) => topic.id == legacyId),
        isFalse,
      );
      expect(
        (await lessons.topics()).any((topic) => topic.id == custom.id),
        isTrue,
      );
      final members = await upgraded.query(
        'lesson_cards',
        where: 'card_id = ?',
        whereArgs: [reviewedCardId],
      );
      expect(members, isNotEmpty);
      final fresh = (await lessons.findById(
        members.first['lesson_id'] as int,
      ))!;
      expect(fresh.cards.any((card) => card.id == reviewedCardId), isTrue);
      expect(await progress.progressForCard(reviewedCardId), isNotNull);
      expect(await upgraded.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      final cards = await upgraded.query('cards');
      final mappings = await upgraded.query('lesson_cards');
      await LocalDatabase.close();
      final reopened = await LocalDatabase.ensureInitialized();
      expect(await reopened.query('cards'), cards);
      expect(await reopened.query('lesson_cards'), mappings);
    },
  );

  test(
    'example corrections preserve card IDs, history, sessions and custom copies',
    () async {
      final db = await LocalDatabase.ensureInitialized();
      final targets = await db.query(
        'cards',
        where: 'chinese IN (?, ?)',
        whereArgs: ['最', '一会儿'],
        orderBy: 'id',
      );
      expect(targets, hasLength(2));
      for (final card in targets) {
        await db.update(
          'cards',
          {
            'example_sentence_chinese': 'Old example',
            'example_sentence_pinyin': 'Old pinyin',
            'example_sentence_english': 'Old translation',
            'example_source_id': '1',
            'example_translation_id': '2',
          },
          where: 'id = ?',
          whereArgs: [card['id']],
        );
      }
      final member = (await db.query(
        'lesson_cards',
        where: 'card_id = ?',
        whereArgs: [targets.first['id']],
      )).first;
      final topic = (await lessons.findById(member['lesson_id'] as int))!;
      await lessons.saveGenerated(topic);
      final session = await progress.startSession(topic.summary.id);
      final now = DateTime.utc(2026, 10, 4);
      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: targets.first['id'] as int,
          sessionId: session.id,
          reviewedAt: now,
          rating: ReviewRating.good,
          wasCorrect: true,
        ),
        progress: scheduleCardReview(
          cardId: targets.first['id'] as int,
          rating: ReviewRating.good,
          reviewedAt: now,
        ),
      );
      await progress.updateSession(
        LessonSession(
          id: session.id,
          lessonId: topic.summary.id,
          startedAt: session.startedAt,
          currentCardIndex: 1,
          cardsReviewed: 1,
          correctAnswers: 1,
        ),
      );
      final correctedCards = {for (final card in targets) card['id']: card};
      final expectedCards = [
        for (final card in await db.query('cards', orderBy: 'id'))
          correctedCards[card['id']] ?? card,
      ];
      final preserved = {
        for (final table in [
          'lessons',
          'lesson_cards',
          'card_progress',
          'review_history',
          'lesson_sessions',
        ])
          table: await db.query(table, orderBy: 'rowid'),
      };
      await db.delete(
        'content_migrations',
        where: 'key = ?',
        whereArgs: [vocabularyExampleCorrectionsMarker],
      );
      // Keep the original curriculum marker: an installed app must receive
      // corrections without reinstalling the curriculum.
      for (var reopen = 0; reopen < 2; reopen++) {
        await LocalDatabase.close();
        final upgraded = await LocalDatabase.ensureInitialized();
        expect(await upgraded.query('cards', orderBy: 'id'), expectedCards);
        for (final entry in preserved.entries) {
          expect(
            await upgraded.query(entry.key, orderBy: 'rowid'),
            entry.value,
            reason: '${entry.key} must survive the content update',
          );
        }
        expect(
          await upgraded.query(
            'content_migrations',
            where: 'key = ?',
            whereArgs: [vocabularyExampleCorrectionsMarker],
          ),
          hasLength(1),
        );
        expect(await upgraded.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      }
    },
  );

  test('example corrections roll back and can be retried', () async {
    final db = await LocalDatabase.ensureInitialized();
    final currentCards = await db.query('cards', orderBy: 'id');
    await db.update(
      'cards',
      {'example_sentence_chinese': 'Old example'},
      where: 'chinese IN (?, ?)',
      whereArgs: ['最', '一会儿'],
    );
    await db.delete(
      'content_migrations',
      where: 'key = ?',
      whereArgs: [vocabularyExampleCorrectionsMarker],
    );
    final oldCards = await db.query('cards', orderBy: 'id');
    await db.execute(
      "CREATE TRIGGER fail_example_marker BEFORE INSERT ON content_migrations "
      "WHEN NEW.key = '$vocabularyExampleCorrectionsMarker' "
      "BEGIN SELECT RAISE(ABORT, 'Simulated failure'); END",
    );
    await expectLater(
      db.transaction(installVocabularyCurriculum),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.query('cards', orderBy: 'id'), oldCards);
    expect(
      await db.query(
        'content_migrations',
        where: 'key = ?',
        whereArgs: [vocabularyExampleCorrectionsMarker],
      ),
      isEmpty,
    );
    await db.execute('DROP TRIGGER fail_example_marker');
    await db.transaction(installVocabularyCurriculum);
    expect(await db.query('cards', orderBy: 'id'), currentCards);
  });

  test(
    'restoring old examples corrects them even after the update was applied',
    () async {
      const backups = SqliteBackupRepository();
      final db = await LocalDatabase.ensureInitialized();
      final currentCards = await db.query('cards', orderBy: 'id');
      await db.update(
        'cards',
        {'example_sentence_chinese': 'Old example'},
        where: 'chinese IN (?, ?)',
        whereArgs: ['最', '一会儿'],
      );
      final oldBackup = await backups.exportBackup();
      await backups.restoreBackup(oldBackup);
      expect(await db.query('cards', orderBy: 'id'), currentCards);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'curriculum refresh is repeatable and rolls back failed membership writes',
    () async {
      final db = await LocalDatabase.ensureInitialized();
      final cards = await db.query('cards', orderBy: 'id');
      final mappings = await db.query(
        'lesson_cards',
        orderBy: 'lesson_id, position',
      );
      await db.delete(
        'content_migrations',
        where: 'key = ?',
        whereArgs: [vocabularyCurriculumMarker],
      );
      await db.transaction(installVocabularyCurriculum);
      expect(await db.query('cards', orderBy: 'id'), cards);
      expect(
        await db.query('lesson_cards', orderBy: 'lesson_id, position'),
        mappings,
      );
      await db.delete(
        'content_migrations',
        where: 'key = ?',
        whereArgs: [vocabularyCurriculumMarker],
      );
      await db.execute(
        "CREATE TRIGGER fail_membership BEFORE INSERT ON lesson_cards "
        "BEGIN SELECT RAISE(ABORT, 'Simulated failure'); END",
      );
      await expectLater(
        db.transaction(installVocabularyCurriculum),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('cards', orderBy: 'id'), cards);
      expect(
        await db.query('lesson_cards', orderBy: 'lesson_id, position'),
        mappings,
      );
      expect(
        await db.query(
          'content_migrations',
          where: 'key = ?',
          whereArgs: [vocabularyCurriculumMarker],
        ),
        isEmpty,
      );
    },
  );

  test(
    'backups retain shared memberships and older backups acquire the curriculum',
    () async {
      const backups = SqliteBackupRepository();
      final bytes = await backups.exportBackup();
      final db = await LocalDatabase.ensureInitialized();
      final mappings = await db.query(
        'lesson_cards',
        orderBy: 'lesson_id, position',
      );
      await backups.restoreBackup(bytes);
      expect(
        await db.query('lesson_cards', orderBy: 'lesson_id, position'),
        mappings,
      );
      final old = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      old['databaseSchemaVersion'] = 16;
      (old['data'] as Map).remove('lesson_cards');
      await backups.restoreBackup(
        Uint8List.fromList(utf8.encode(jsonEncode(old))),
      );
      expect(await db.query('lesson_cards'), hasLength(5020));
      expect(
        (await lessons.topics()).where((topic) => !topic.isSentencePractice),
        hasLength(251),
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
}
