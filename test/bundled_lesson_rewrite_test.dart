import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/database/bundled_lesson_content.dart';
import 'package:mylanguageapp/database/flashcard_seed.dart';
import 'package:mylanguageapp/database/migrations.dart';
import 'package:mylanguageapp/database/vocabulary_lesson_content.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/models/learner_profile.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/models/lesson.dart';
import 'package:mylanguageapp/repositories/backup_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:mylanguageapp/services/review_scheduler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const lessons = SqliteLessonRepository();
const progress = SqliteProgressRepository();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    await LocalDatabase.close();
    directory = await Directory.systemTemp.createTemp('lesson_rewrite_');
    LocalDatabase.useDatabasePathForTesting('${directory.path}/test.db');
    await LocalDatabase.ensureInitialized();
    await const SqliteLearnerRepository().save(
      const LearnerProfile(name: 'Mei', hskLevel: 3, dailyWordTarget: 10),
    );
  });
  tearDown(() async {
    await LocalDatabase.close();
    LocalDatabase.useDatabasePathForTesting(inMemoryDatabasePath);
    await directory.delete(recursive: true);
  });

  test(
    'historical seed definitions retain complete original examples and real quiz choices',
    () async {
      expect(flashcardLessons, hasLength(30));
      var count = 0;
      for (final lesson in flashcardLessons) {
        final cards = (lesson['cards'] as List).cast<Map<String, dynamic>>();
        final meanings = cards.map((c) => c['english_meaning']).toSet();
        for (final card in cards) {
          count++;
          expect(card['example_sentence_chinese'], contains(card['chinese']));
          expect(
            card['example_sentence_pinyin'],
            matches(RegExp('[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]')),
          );
          expect(card['example_sentence_english'], isNot(contains('I to ')));
          final options = card['quiz_options'] as List;
          expect(options.toSet(), hasLength(4));
          expect(options, contains(card['correct_answer']));
          expect(options.every(meanings.contains), isTrue);
        }
      }
      expect(count, 360);
      expect((await lessons.topics()).every((s) => !s.isUserGenerated), isTrue);
    },
  );

  test(
    'version 15 content upgrade preserves IDs, reviews, progress, and same-title generated lessons',
    () async {
      final db = await LocalDatabase.ensureInitialized();
      // Recreate an actual pre-curriculum installation, with the old decks.
      await db.execute(
        'DELETE FROM lessons WHERE id IN (SELECT lesson_id FROM lesson_cards)',
      );
      await db.delete(
        'content_migrations',
        where: 'key = ?',
        whereArgs: [vocabularyCurriculumMarker],
      );
      for (final definition in flashcardLessons) {
        final id = await db.insert('lessons', {
          'lesson_title': definition['lesson_title'],
          'theme': definition['theme'],
          'hsk_level': definition['hsk_level'],
          'is_user_generated': 0,
        });
        for (final card
            in (definition['cards'] as List).cast<Map<String, dynamic>>()) {
          await db.insert('cards', {
            ...card,
            'quiz_options': jsonEncode(card['quiz_options']),
            'hsk_level': definition['hsk_level'],
            'lesson_id': id,
          });
        }
      }
      final originalTopics = await lessons.topics();
      final vocabulary = (await lessons.findById(
        originalTopics.firstWhere((t) => !t.isSentencePractice).id,
      ))!;
      final sentence = (await lessons.findById(
        originalTopics.firstWhere((t) => t.isSentencePractice).id,
      ))!;
      // Even an exact copy with the same title remains generated after upgrade.
      await lessons.saveGenerated(vocabulary);
      final generated = (await lessons.topics()).firstWhere(
        (t) => t.isUserGenerated,
      );
      final generatedCards = (await lessons.findById(generated.id))!.cards;
      final session = await progress.startSession(sentence.summary.id);
      final now = DateTime.utc(2026, 9, 29);
      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: sentence.cards.first.id,
          sessionId: session.id,
          reviewedAt: now,
          rating: ReviewRating.good,
          wasCorrect: true,
        ),
        progress: scheduleCardReview(
          cardId: sentence.cards.first.id,
          rating: ReviewRating.good,
          reviewedAt: now,
        ),
      );
      await progress.updateSession(
        LessonSession(
          id: session.id,
          lessonId: sentence.summary.id,
          startedAt: session.startedAt,
          currentCardIndex: 1,
          cardsReviewed: 1,
          correctAnswers: 1,
        ),
      );
      final savedProgress = await db.query('card_progress');
      await db.update(
        'cards',
        {
          'example_sentence_chinese': '旧例句。',
          'example_sentence_pinyin': '',
          'example_source': 'Tatoeba',
          'example_source_id': '123',
          'example_translation_id': '456',
        },
        where: 'lesson_id = ?',
        whereArgs: [vocabulary.summary.id],
      );
      await db.update(
        'cards',
        {'chinese': '旧句子。'},
        where: 'id = ?',
        whereArgs: [sentence.cards.first.id],
      );
      await db.delete(
        'content_migrations',
        where: 'key = ?',
        whereArgs: [bundledLessonRewriteMarker],
      );
      await db.execute('DROP TABLE lesson_cards');
      await db.execute('ALTER TABLE lessons DROP COLUMN is_archived');
      await db.execute('ALTER TABLE lessons DROP COLUMN is_user_generated');
      await db.setVersion(15);
      await LocalDatabase.close();
      final upgraded = await LocalDatabase.ensureInitialized();
      expect(await upgraded.getVersion(), databaseSchemaVersion);
      expect(await upgraded.query('card_progress'), savedProgress);
      expect(
        await progress.reviewHistory(cardId: sentence.cards.first.id),
        hasLength(1),
      );
      expect(
        (await progress.activeSessionForLesson(
          sentence.summary.id,
        ))!.currentCardIndex,
        1,
      );
      expect(
        (await lessons.findById(vocabulary.summary.id))!.cards.map((c) => c.id),
        vocabulary.cards.map((c) => c.id),
      );
      expect(
        (await lessons.findById(
          vocabulary.summary.id,
        ))!.cards.first.exampleChinese,
        contains(vocabulary.cards.first.chinese),
      );
      expect(
        (await lessons.findById(
          vocabulary.summary.id,
        ))!.cards.firstWhere((card) => card.chinese == '谢谢').exampleSource,
        'Tatoeba',
      );
      expect(
        (await lessons.findById(sentence.summary.id))!.cards.first.chinese,
        sentence.cards.first.chinese,
      );
      expect(
        (await lessons.findById(generated.id))!.summary.isUserGenerated,
        isTrue,
      );
      expect(
        (await lessons.findById(generated.id))!.cards.map((c) => c.id),
        generatedCards.map((c) => c.id),
      );
      final snapshot = await upgraded.query('cards');
      await LocalDatabase.close();
      final reopened = await LocalDatabase.ensureInitialized();
      expect(await reopened.query('cards'), snapshot);
      expect(await lessons.topics(), hasLength(262));
    },
  );

  test(
    'delete generated lesson cascades progress and repairs queues, without changing other lessons',
    () async {
      final bundled = (await lessons.findById(
        (await lessons.topics()).first.id,
      ))!;
      await lessons.saveGenerated(bundled);
      final generated = (await lessons.topics()).firstWhere(
        (s) => s.isUserGenerated,
      );
      final cards = (await lessons.findById(generated.id))!.cards;
      final session = await progress.startSession(generated.id);
      final now = DateTime.utc(2026, 9, 29);
      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: cards.first.id,
          sessionId: session.id,
          reviewedAt: now,
          rating: ReviewRating.again,
          wasCorrect: false,
        ),
        progress: scheduleCardReview(
          cardId: cards.first.id,
          rating: ReviewRating.again,
          reviewedAt: now,
        ),
      );
      final db = await LocalDatabase.ensureInitialized();
      final queues = [
        [cards[0].id, bundled.cards[0].id, cards[1].id, bundled.cards[1].id],
        [cards[0].id, cards[1].id],
        [bundled.cards[0].id, cards[0].id],
      ];
      for (var i = 0; i < queues.length; i++) {
        await db.insert('daily_review_sessions', {
          'learner_id': 1,
          'session_date': '2026-09-${27 + i}',
          'queued_card_ids': jsonEncode(queues[i]),
          'current_position': i == 0 ? 2 : 1,
        });
      }
      // Warm read caches before deletion.
      await lessons.topics();
      await lessons.findById(generated.id);
      await lessons.deleteGenerated(generated.id);
      expect(await lessons.findById(generated.id), isNull);
      expect(
        (await lessons.topics()).any((s) => s.id == generated.id),
        isFalse,
      );
      expect(
        (await lessons.findById(bundled.summary.id))!.cards.map((c) => c.id),
        bundled.cards.map((c) => c.id),
      );
      expect(
        await db.query(
          'cards',
          where: 'lesson_id = ?',
          whereArgs: [generated.id],
        ),
        isEmpty,
      );
      expect(await progress.reviewHistory(cardId: cards.first.id), isEmpty);
      expect(await db.query('card_progress'), isEmpty);
      expect(await db.query('lesson_sessions'), isEmpty);
      final rows = await db.query('daily_review_sessions', orderBy: 'id');
      expect(jsonDecode(rows[0]['queued_card_ids'] as String), [
        bundled.cards[0].id,
        bundled.cards[1].id,
      ]);
      expect(rows[0]['current_position'], 1);
      expect(rows[0]['completed_at'], isNull);
      expect(jsonDecode(rows[1]['queued_card_ids'] as String), isEmpty);
      expect(rows[1]['current_position'], 0);
      expect(rows[1]['completed_at'], isNotNull);
      expect(rows[2]['current_position'], 1);
      expect(rows[2]['completed_at'], isNotNull);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await LocalDatabase.close();
      expect((await lessons.topics()).where((s) => s.isUserGenerated), isEmpty);
      expect(await lessons.topics(), hasLength(261));
    },
  );

  test(
    'failed deletion rolls back queue cleanup and retains the lesson',
    () async {
      final bundled = (await lessons.findById(
        (await lessons.topics()).first.id,
      ))!;
      await lessons.saveGenerated(bundled);
      final generated = (await lessons.topics()).firstWhere(
        (s) => s.isUserGenerated,
      );
      final card = (await lessons.findById(generated.id))!.cards.first;
      final db = await LocalDatabase.ensureInitialized();
      await db.insert('daily_review_sessions', {
        'learner_id': 1,
        'session_date': '2026-09-29',
        'queued_card_ids': jsonEncode([card.id]),
        'current_position': 0,
      });
      final queues = await db.query('daily_review_sessions');
      await db.execute(
        "CREATE TRIGGER fail_lesson_delete BEFORE DELETE ON lessons "
        "BEGIN SELECT RAISE(ABORT, 'Simulated storage failure'); END",
      );
      await expectLater(
        lessons.deleteGenerated(generated.id),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('daily_review_sessions'), queues);
      expect(await lessons.findById(generated.id), isNotNull);
      expect(
        await db.query('cards', where: 'id = ?', whereArgs: [card.id]),
        hasLength(1),
      );
      await db.execute('DROP TRIGGER fail_lesson_delete');
      await lessons.deleteGenerated(generated.id);
      expect(await lessons.findById(generated.id), isNull);
    },
  );

  test('bundled lessons and hidden vocabulary cards are protected', () async {
    for (final summary in await lessons.topics()) {
      await expectLater(lessons.deleteGenerated(summary.id), throwsStateError);
    }
    await lessons.findOrCreateVocabularyCard(
      card: const Flashcard(
        chinese: '测试词',
        pinyin: 'cèshìcí',
        englishMeaning: 'test word',
      ),
      hskLevel: 1,
    );
    final db = await LocalDatabase.ensureInitialized();
    final hidden = (await db.query('lessons', where: 'is_listed = 0')).single;
    await expectLater(
      lessons.deleteGenerated(hidden['id'] as int),
      throwsStateError,
    );
    await expectLater(lessons.deleteGenerated(-1), throwsStateError);
    expect(await lessons.topics(), hasLength(261));
  });

  test(
    'backup round trips provenance and upgrades older backups immediately',
    () async {
      const backups = SqliteBackupRepository();
      final bundled = (await lessons.findById(
        (await lessons.topics()).first.id,
      ))!;
      await lessons.saveGenerated(bundled);
      final generated = (await lessons.topics()).firstWhere(
        (s) => s.isUserGenerated,
      );
      final bytes = await backups.exportBackup();
      await backups.restoreBackup(bytes);
      expect(
        (await lessons.findById(generated.id))!.summary.isUserGenerated,
        isTrue,
      );
      final document = jsonDecode(utf8.decode(bytes));
      for (final row in document['data']['lessons']) {
        row.remove('is_user_generated');
      }
      for (final row in document['data']['cards']) {
        if (row['lesson_id'] == bundled.summary.id) {
          row['example_sentence_pinyin'] = '';
        }
      }
      document['databaseSchemaVersion'] = 15;
      await backups.restoreBackup(
        Uint8List.fromList(utf8.encode(jsonEncode(document))),
      );
      expect(
        (await lessons.findById(bundled.summary.id))!.summary.isUserGenerated,
        isFalse,
      );
      expect(
        (await lessons.findById(bundled.summary.id))!.cards.first.examplePinyin,
        isNotEmpty,
      );
      expect(
        (await lessons.findById(generated.id))!.summary.isUserGenerated,
        isTrue,
      );
      await lessons.deleteGenerated(generated.id);
      expect(await lessons.topics(), hasLength(261));
    },
  );
}
