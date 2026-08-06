import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/database/migrations.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/models/learner_profile.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/models/lesson.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const learners = SqliteLearnerRepository();
  const lessons = SqliteLessonRepository();
  const settings = SqliteSettingsRepository();
  const progress = SqliteProgressRepository();
  late Directory testDirectory;

  setUpAll(() async {
    testDirectory = await Directory.systemTemp.createTemp('hanzipath_db_test_');
    LocalDatabase.useDatabasePathForTesting(
      '${testDirectory.path}/local_app.db',
    );
  });

  tearDownAll(() async {
    await LocalDatabase.close();
    LocalDatabase.useDatabasePathForTesting(null);
    await testDirectory.delete(recursive: true);
  });

  test('database initializes and starts empty', () async {
    await LocalDatabase.resetForTesting();
    final db = await LocalDatabase.ensureInitialized();

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='app_data'",
    );

    expect(tables, hasLength(1));

    final rows = await db.query('app_data');
    expect(rows, isEmpty);
  });

  test(
    'version 1 database migrates to latest version without data loss',
    () async {
      await LocalDatabase.resetForTesting();
      final path = await LocalDatabase.databasePath();
      final legacyDb = await openDatabase(
        path,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
          CREATE TABLE app_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT NOT NULL UNIQUE,
            value TEXT
          )
        ''');
          await db.execute('''
          CREATE TABLE lessons (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lesson_title TEXT NOT NULL,
            theme TEXT NOT NULL,
            hsk_level INTEGER NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE cards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lesson_id INTEGER NOT NULL,
            chinese TEXT NOT NULL,
            pinyin TEXT NOT NULL,
            english_meaning TEXT NOT NULL,
            part_of_speech TEXT NOT NULL,
            hsk_level INTEGER NOT NULL,
            example_sentence_chinese TEXT NOT NULL,
            example_sentence_pinyin TEXT NOT NULL,
            example_sentence_english TEXT NOT NULL,
            quiz_options TEXT NOT NULL,
            correct_answer TEXT NOT NULL
          )
        ''');
          await db.insert('app_data', {
            'key': 'legacy_marker',
            'value': 'preserve me',
          });
          await db.insert('app_data', {
            'key': 'learner_profile',
            'value': jsonEncode({
              'name': 'Legacy learner',
              'hskLevel': 2,
              'dailyWordTarget': 15,
            }),
          });
          await db.insert('lessons', {
            'lesson_title': 'Legacy lesson',
            'theme': 'Legacy',
            'hsk_level': 1,
          });
        },
      );
      await legacyDb.close();

      final upgraded = await LocalDatabase.ensureInitialized();
      final version = await upgraded.getVersion();
      final marker = await upgraded.query(
        'app_data',
        where: 'key = ?',
        whereArgs: ['legacy_marker'],
      );
      final indexes = await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index'",
      );

      expect(version, 4);
      expect(marker.single['value'], 'preserve me');
      expect(
        indexes.map((row) => row['name']),
        containsAll(['idx_lessons_theme_hsk', 'idx_cards_lesson_id']),
      );
      final migratedProfile = await learners.load();
      expect(migratedProfile?.name, 'Legacy learner');
      expect(migratedProfile?.hskLevel, 2);
      expect(migratedProfile?.dailyWordTarget, 15);
    },
  );

  test('learner profile is persisted in its typed repository', () async {
    await learners.save(
      const LearnerProfile(name: 'Mei', hskLevel: 3, dailyWordTarget: 20),
    );

    final profile = await learners.load();
    expect(profile?.name, 'Mei');
    expect(profile?.hskLevel, 3);
    expect(profile?.dailyWordTarget, 20);

    await learners.clear();
    expect(await learners.load(), isNull);
  });

  test('generated lessons are saved and offered as previous topics', () async {
    await LocalDatabase.resetForTesting();
    await LocalDatabase.ensureInitialized();

    await lessons.saveGenerated(
      const Lesson(
        summary: LessonSummary(
          id: 0,
          title: 'Ordering breakfast · HSK 1',
          theme: 'Ordering breakfast',
          hskLevel: 1,
        ),
        cards: [
          Flashcard(
            chinese: '吃',
            pinyin: 'chī',
            englishMeaning: 'to eat',
            partOfSpeech: 'verb',
            exampleChinese: '我吃早饭。',
            examplePinyin: 'Wǒ chī zǎofàn.',
            exampleEnglish: 'I eat breakfast.',
          ),
        ],
      ),
    );

    final topics = await lessons.topics();
    expect(topics.first.title, 'Ordering breakfast · HSK 1');
    expect(topics.first.theme, 'Ordering breakfast');

    final db = await LocalDatabase.ensureInitialized();
    final cards = await db.query(
      'cards',
      where: 'lesson_id = ?',
      whereArgs: [topics.first.id],
    );
    expect(cards, hasLength(1));
    expect(cards.single['chinese'], '吃');
    expect(cards.single['example_sentence_english'], 'I eat breakfast.');

    final cached = await lessons.findGenerated(
      theme: 'ordering BREAKFAST',
      hskLevel: 1,
    );
    expect(cached, isNotNull);
    expect(cached!.summary.title, 'Ordering breakfast · HSK 1');
    expect(cached.cards, hasLength(1));
    expect(cached.cards.single.chinese, '吃');
  });

  test('settings, sessions, reviews, and card progress persist', () async {
    await LocalDatabase.resetForTesting();
    await LocalDatabase.ensureInitialized();
    await learners.save(
      const LearnerProfile(name: 'Mei', hskLevel: 3, dailyWordTarget: 20),
    );
    await settings.save(
      const LearnerSettings(
        showPinyin: false,
        soundEnabled: false,
        reminderEnabled: true,
        reminderHour: 9,
      ),
    );

    final storedSettings = await settings.load();
    expect(storedSettings.showPinyin, isFalse);
    expect(storedSettings.soundEnabled, isFalse);
    expect(storedSettings.reminderEnabled, isTrue);
    expect(storedSettings.reminderHour, 9);

    final lessonSummary = (await lessons.topics()).first;
    final lesson = await lessons.findGenerated(
      theme: lessonSummary.theme,
      hskLevel: lessonSummary.hskLevel,
    );
    final cardId = lesson!.cards.first.id;
    final session = await progress.startSession(lessonSummary.id);
    final completedAt = DateTime.utc(2026, 7, 27, 10);
    await progress.updateSession(
      LessonSession(
        id: session.id,
        lessonId: session.lessonId,
        startedAt: session.startedAt,
        completedAt: completedAt,
        currentCardIndex: 1,
        cardsReviewed: 1,
        correctAnswers: 1,
      ),
    );

    expect(await progress.activeSessionForLesson(lessonSummary.id), isNull);

    final reviewedAt = DateTime.utc(2026, 7, 27, 9);
    final dueAt = DateTime.utc(2026, 7, 30, 9);
    await progress.recordReview(
      review: ReviewRecord(
        id: 0,
        cardId: cardId,
        sessionId: session.id,
        reviewedAt: reviewedAt,
        rating: ReviewRating.good,
        wasCorrect: true,
        responseTimeMs: 1200,
      ),
      progress: CardProgress(
        cardId: cardId,
        repetitions: 1,
        intervalDays: 3,
        easeFactor: 2.6,
        dueAt: dueAt,
        lastReviewedAt: reviewedAt,
      ),
    );

    final history = await progress.reviewHistory(cardId: cardId);
    final cardProgress = await progress.progressForCard(cardId);
    expect(history, hasLength(1));
    expect(history.single.rating, ReviewRating.good);
    expect(history.single.responseTimeMs, 1200);
    expect(cardProgress?.repetitions, 1);
    expect(cardProgress?.timesSeen, 1);
    expect(cardProgress?.correctAnswers, 1);
    expect(cardProgress?.incorrectAnswers, 0);
    expect(cardProgress?.mastery, 1);
    expect(cardProgress?.lastReview, reviewedAt);
    expect(cardProgress?.nextReview, dueAt);
    expect(cardProgress?.reviewInterval, 3);
    expect(cardProgress?.intervalDays, 3);
    expect(cardProgress?.dueAt, dueAt);
    expect(await progress.dueCards(dueAt), hasLength(1));
  });

  test('daily queue prioritizes due, weak, then new cards', () async {
    await LocalDatabase.resetForTesting();
    final db = await LocalDatabase.ensureInitialized();
    await learners.save(
      const LearnerProfile(name: 'Mei', hskLevel: 2, dailyWordTarget: 3),
    );
    final cardRows = await db.query('cards', columns: ['id'], limit: 3);
    final dueCardId = cardRows[0]['id'] as int;
    final weakCardId = cardRows[1]['id'] as int;
    final newCardId = cardRows[2]['id'] as int;
    final today = DateTime.utc(2026, 8, 6);

    await progress.recordReview(
      review: ReviewRecord(
        id: 0,
        cardId: dueCardId,
        reviewedAt: today.subtract(const Duration(days: 3)),
        rating: ReviewRating.good,
        wasCorrect: true,
      ),
      progress: CardProgress(
        cardId: dueCardId,
        dueAt: today.subtract(const Duration(days: 1)),
        lastReviewedAt: today.subtract(const Duration(days: 3)),
      ),
    );
    await progress.recordReview(
      review: ReviewRecord(
        id: 0,
        cardId: weakCardId,
        reviewedAt: today.subtract(const Duration(days: 1)),
        rating: ReviewRating.again,
        wasCorrect: false,
      ),
      progress: CardProgress(
        cardId: weakCardId,
        dueAt: today.add(const Duration(days: 5)),
        lastReviewedAt: today.subtract(const Duration(days: 1)),
      ),
    );

    final queue = await progress.dailyQueue(forDay: today, limit: 3);

    expect(queue.map((item) => item.card.id), [
      dueCardId,
      weakCardId,
      newCardId,
    ]);
    expect(queue.map((item) => item.reason), [
      DailyQueueReason.due,
      DailyQueueReason.weak,
      DailyQueueReason.newWord,
    ]);
  });

  test('incorrect Vocab Rush words persist into the daily queue', () async {
    await LocalDatabase.resetForTesting();
    await LocalDatabase.ensureInitialized();
    await learners.save(
      const LearnerProfile(name: 'Mei', hskLevel: 1, dailyWordTarget: 200),
    );
    const rushCard = Flashcard(
      chinese: '错题',
      pinyin: 'cuò tí',
      englishMeaning: 'incorrect question',
      partOfSpeech: 'noun',
    );
    final stored = await lessons.findOrCreateVocabularyCard(
      card: rushCard,
      hskLevel: 1,
    );
    final duplicate = await lessons.findOrCreateVocabularyCard(
      card: rushCard,
      hskLevel: 1,
    );
    final now = DateTime.utc(2026, 8, 6, 10);
    await progress.recordReview(
      review: ReviewRecord(
        id: 0,
        cardId: stored.id,
        reviewedAt: now,
        rating: ReviewRating.again,
        wasCorrect: false,
      ),
      progress: CardProgress(
        cardId: stored.id,
        lapses: 1,
        intervalDays: 1,
        easeFactor: 2.3,
        dueAt: now.add(const Duration(days: 1)),
        lastReviewedAt: now,
      ),
    );

    final queue = await progress.dailyQueue(
      forDay: now,
      limit: 200,
      maxHskLevel: 1,
    );
    final queued = queue.singleWhere((item) => item.card.id == stored.id);

    expect(duplicate.id, stored.id);
    expect(queued.card.chinese, '错题');
    expect(queued.reason, DailyQueueReason.weak);
    expect(queued.progress?.incorrectAnswers, 1);
  });

  test('all milestone tables, progress columns, and indexes exist', () async {
    await LocalDatabase.resetForTesting();
    final db = await LocalDatabase.ensureInitialized();

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(
      tables.map((row) => row['name']),
      containsAll([
        'learner_profiles',
        'learner_settings',
        'lesson_sessions',
        'review_history',
        'card_progress',
      ]),
    );

    final progressColumns = await db.rawQuery(
      'PRAGMA table_info(card_progress)',
    );
    expect(
      progressColumns.map((row) => row['name']),
      containsAll([
        'times_seen',
        'correct_answers',
        'incorrect_answers',
        'mastery',
        'interval_days',
        'due_at',
        'last_reviewed_at',
      ]),
    );

    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    expect(
      indexes.map((row) => row['name']),
      containsAll([
        'idx_sessions_learner_started',
        'idx_reviews_card_date',
        'idx_progress_due',
      ]),
    );
  });

  test(
    'reopening the database preserves the complete learning state',
    () async {
      await LocalDatabase.resetForTesting();
      await LocalDatabase.ensureInitialized();
      await learners.save(
        const LearnerProfile(
          name: 'Restart Mei',
          hskLevel: 4,
          dailyWordTarget: 30,
        ),
      );
      await settings.save(
        const LearnerSettings(
          showPinyin: false,
          soundEnabled: false,
          reminderEnabled: true,
          reminderHour: 7,
        ),
      );
      final summary = (await lessons.topics()).first;
      final lesson = await lessons.findGenerated(
        theme: summary.theme,
        hskLevel: summary.hskLevel,
      );
      final cardId = lesson!.cards.first.id;
      final session = await progress.startSession(summary.id);
      final savedSession = LessonSession(
        id: session.id,
        lessonId: session.lessonId,
        startedAt: session.startedAt,
        currentCardIndex: 2,
        cardsReviewed: 1,
        correctAnswers: 1,
      );
      await progress.updateSession(savedSession);
      final reviewedAt = DateTime.utc(2026, 7, 28, 8);
      final nextReview = DateTime.utc(2026, 8, 1, 8);
      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: cardId,
          sessionId: session.id,
          reviewedAt: reviewedAt,
          rating: ReviewRating.easy,
          wasCorrect: true,
        ),
        progress: CardProgress(
          cardId: cardId,
          repetitions: 1,
          reviewInterval: 4,
          nextReview: nextReview,
          lastReview: reviewedAt,
        ),
      );

      await LocalDatabase.close();

      final restoredProfile = await learners.load();
      final restoredSettings = await settings.load();
      final restoredSession = await progress.activeSessionForLesson(summary.id);
      final restoredProgress = await progress.progressForCard(cardId);
      final restoredHistory = await progress.reviewHistory(cardId: cardId);

      expect(restoredProfile?.name, 'Restart Mei');
      expect(restoredProfile?.hskLevel, 4);
      expect(restoredProfile?.dailyWordTarget, 30);
      expect(restoredSettings.showPinyin, isFalse);
      expect(restoredSettings.soundEnabled, isFalse);
      expect(restoredSettings.reminderEnabled, isTrue);
      expect(restoredSettings.reminderHour, 7);
      expect(restoredSession?.currentCardIndex, 2);
      expect(restoredSession?.cardsReviewed, 1);
      expect(restoredSession?.correctAnswers, 1);
      expect(restoredProgress?.timesSeen, 1);
      expect(restoredProgress?.mastery, 1);
      expect(restoredProgress?.nextReview, nextReview);
      expect(restoredHistory.single.rating, ReviewRating.easy);
    },
  );

  test(
    'repeated reviews derive totals and mastery from review history',
    () async {
      await LocalDatabase.resetForTesting();
      await LocalDatabase.ensureInitialized();
      await learners.save(
        const LearnerProfile(name: 'Mei', hskLevel: 1, dailyWordTarget: 10),
      );
      final summary = (await lessons.topics()).first;
      final lesson = await lessons.findGenerated(
        theme: summary.theme,
        hskLevel: summary.hskLevel,
      );
      final cardId = lesson!.cards.first.id;
      final firstReview = DateTime.utc(2026, 7, 28, 9);
      final secondReview = DateTime.utc(2026, 7, 29, 9);

      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: cardId,
          reviewedAt: firstReview,
          rating: ReviewRating.good,
          wasCorrect: true,
        ),
        progress: CardProgress(
          cardId: cardId,
          repetitions: 1,
          reviewInterval: 1,
          nextReview: secondReview,
          lastReview: firstReview,
        ),
      );
      final finalDue = DateTime.utc(2026, 7, 30, 9);
      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: cardId,
          reviewedAt: secondReview,
          rating: ReviewRating.again,
          wasCorrect: false,
        ),
        progress: CardProgress(
          cardId: cardId,
          repetitions: 0,
          lapses: 1,
          reviewInterval: 1,
          nextReview: finalDue,
          lastReview: secondReview,
        ),
      );

      final stored = await progress.progressForCard(cardId);
      final history = await progress.reviewHistory(cardId: cardId);
      expect(stored?.timesSeen, 2);
      expect(stored?.correctAnswers, 1);
      expect(stored?.incorrectAnswers, 1);
      expect(stored?.mastery, .5);
      expect(stored?.lapses, 1);
      expect(stored?.lastReview, secondReview);
      expect(history.map((review) => review.rating), [
        ReviewRating.again,
        ReviewRating.good,
      ]);
      expect(
        await progress.reviewHistory(cardId: cardId, limit: 1),
        hasLength(1),
      );
      expect(
        (await progress.reviewHistory(cardId: cardId, limit: 1)).single.rating,
        ReviewRating.again,
      );
      expect(
        (await progress.dueCards(
          finalDue.subtract(const Duration(seconds: 1)),
        )).where((card) => card.cardId == cardId),
        isEmpty,
      );
      expect(
        (await progress.dueCards(finalDue)).map((card) => card.cardId),
        contains(cardId),
      );
    },
  );

  test(
    'a mismatched review and progress pair is rejected atomically',
    () async {
      await LocalDatabase.resetForTesting();
      await LocalDatabase.ensureInitialized();
      await learners.save(
        const LearnerProfile(name: 'Mei', hskLevel: 1, dailyWordTarget: 10),
      );
      final summary = (await lessons.topics()).first;
      final lesson = await lessons.findGenerated(
        theme: summary.theme,
        hskLevel: summary.hskLevel,
      );
      final firstCard = lesson!.cards.first.id;
      final secondCard = lesson.cards[1].id;

      await expectLater(
        progress.recordReview(
          review: ReviewRecord(
            id: 0,
            cardId: firstCard,
            reviewedAt: DateTime.utc(2026, 7, 28),
            rating: ReviewRating.good,
            wasCorrect: true,
          ),
          progress: CardProgress(
            cardId: secondCard,
            nextReview: DateTime.utc(2026, 7, 29),
          ),
        ),
        throwsArgumentError,
      );
      expect(await progress.reviewHistory(cardId: firstCard), isEmpty);
      expect(await progress.progressForCard(secondCard), isNull);
    },
  );

  test(
    'version 4 migration backfills progress summaries from history',
    () async {
      await LocalDatabase.resetForTesting();
      final path = await LocalDatabase.databasePath();
      final versionThree = await openDatabase(
        path,
        version: 3,
        onCreate: (db, _) async {
          await _createVersionOneSchema(db);
          await migrateDatabase(db, fromVersion: 1, toVersion: 3);
        },
      );
      final now = DateTime.utc(2026, 7, 28);
      await versionThree.insert('learner_profiles', {
        'id': 1,
        'name': 'Migrating learner',
        'hsk_level': 2,
        'daily_word_target': 15,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      final lessonId = await versionThree.insert('lessons', {
        'lesson_title': 'Migration lesson',
        'theme': 'Migration',
        'hsk_level': 1,
      });
      final cardId = await versionThree.insert('cards', {
        'lesson_id': lessonId,
        'chinese': '学',
        'pinyin': 'xué',
        'english_meaning': 'study',
        'part_of_speech': 'verb',
        'hsk_level': 1,
        'example_sentence_chinese': '',
        'example_sentence_pinyin': '',
        'example_sentence_english': '',
        'quiz_options': '[]',
        'correct_answer': 'study',
      });
      for (final wasCorrect in [1, 1, 0]) {
        await versionThree.insert('review_history', {
          'learner_id': 1,
          'card_id': cardId,
          'reviewed_at': now.toIso8601String(),
          'rating': wasCorrect == 1
              ? ReviewRating.good.index
              : ReviewRating.again.index,
          'was_correct': wasCorrect,
        });
      }
      await versionThree.insert('card_progress', {
        'learner_id': 1,
        'card_id': cardId,
        'repetitions': 0,
        'lapses': 1,
        'interval_days': 1,
        'ease_factor': 2.3,
        'due_at': now.add(const Duration(days: 1)).toIso8601String(),
        'last_reviewed_at': now.toIso8601String(),
      });
      await versionThree.close();

      final upgraded = await LocalDatabase.ensureInitialized();
      expect(await upgraded.getVersion(), 4);
      final restored = await progress.progressForCard(cardId);
      expect(restored?.timesSeen, 3);
      expect(restored?.correctAnswers, 2);
      expect(restored?.incorrectAnswers, 1);
      expect(restored?.mastery, closeTo(2 / 3, .000001));
    },
  );
}

Future<void> _createVersionOneSchema(Database db) async {
  await db.execute('''
    CREATE TABLE app_data (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      key TEXT NOT NULL UNIQUE,
      value TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE lessons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lesson_title TEXT NOT NULL,
      theme TEXT NOT NULL,
      hsk_level INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE cards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lesson_id INTEGER NOT NULL,
      chinese TEXT NOT NULL,
      pinyin TEXT NOT NULL,
      english_meaning TEXT NOT NULL,
      part_of_speech TEXT NOT NULL,
      hsk_level INTEGER NOT NULL,
      example_sentence_chinese TEXT NOT NULL,
      example_sentence_pinyin TEXT NOT NULL,
      example_sentence_english TEXT NOT NULL,
      quiz_options TEXT NOT NULL,
      correct_answer TEXT NOT NULL
    )
  ''');
}
