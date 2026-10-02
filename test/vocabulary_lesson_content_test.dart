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
