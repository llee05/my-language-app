import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/database/migrations.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/models/learner_profile.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/models/lesson.dart';
import 'package:mylanguageapp/repositories/daily_review_session_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const learners = SqliteLearnerRepository();
  const lessons = SqliteLessonRepository();
  const settings = SqliteSettingsRepository();
  const progress = SqliteProgressRepository();
  const DailyReviewSessionRepository dailyReviews =
      SqliteDailyReviewSessionRepository();
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
          await db.insert('lessons', {
            'lesson_title': 'Vocab Rush · HSK 1',
            'theme': 'Vocab Rush',
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

      expect(version, databaseSchemaVersion);
      expect(marker.single['value'], 'preserve me');
      expect(
        indexes.map((row) => row['name']),
        containsAll([
          'idx_lessons_theme_hsk',
          'idx_cards_lesson_id',
          'idx_daily_review_sessions_date',
          'idx_lessons_listed',
          'idx_reviews_submission_key',
        ]),
      );
      final migratedRushRows = await upgraded.query(
        'lessons',
        where: 'lesson_title = ?',
        whereArgs: ['Vocab Rush · HSK 1'],
      );
      expect(migratedRushRows, hasLength(1));
      expect(migratedRushRows.single['is_listed'], 0);
      expect(
        (await lessons.topics()).map((lesson) => lesson.title),
        isNot(contains('Vocab Rush · HSK 1')),
      );
      final migratedProfile = await learners.load();
      expect(migratedProfile?.name, 'Legacy learner');
      expect(migratedProfile?.hskLevel, 2);
      expect(migratedProfile?.dailyWordTarget, 15);
      final migratedSettings = await settings.load();
      expect(migratedSettings.pronunciationEngine, PronunciationEngine.kokoro);
      expect(migratedSettings.kokoroVoiceIds, isEmpty);
    },
  );

  test('version 8 settings migrate to Kokoro without data loss', () async {
    await LocalDatabase.resetForTesting();
    final path = await LocalDatabase.databasePath();
    final versionEight = await openDatabase(
      path,
      version: 8,
      onCreate: (db, _) async {
        await _createVersionOneSchema(db);
        await migrateDatabase(db, fromVersion: 1, toVersion: 8);
      },
    );
    final now = DateTime.utc(2026, 8, 25).toIso8601String();
    await versionEight.insert('learner_profiles', {
      'id': 1,
      'name': 'Existing learner',
      'hsk_level': 2,
      'daily_word_target': 15,
      'created_at': now,
      'updated_at': now,
    });
    await versionEight.insert('learner_settings', {
      'learner_id': 1,
      'show_pinyin': 0,
      'sound_enabled': 1,
      'reminder_enabled': 1,
      'reminder_hour': 8,
    });
    await versionEight.close();

    final upgraded = await LocalDatabase.ensureInitialized();
    expect(await upgraded.getVersion(), databaseSchemaVersion);
    final restored = await settings.load();
    expect(restored.showPinyin, isFalse);
    expect(restored.soundEnabled, isTrue);
    expect(restored.reminderEnabled, isTrue);
    expect(restored.reminderHour, 8);
    expect(restored.pronunciationEngine, PronunciationEngine.kokoro);
    expect(restored.kokoroVoiceIds, isEmpty);
  });

  test('version 9 voice choice migrates to a one-voice Kokoro pool', () async {
    await LocalDatabase.resetForTesting();
    final path = await LocalDatabase.databasePath();
    final versionNine = await openDatabase(
      path,
      version: 9,
      onCreate: (db, _) async {
        await _createVersionOneSchema(db);
        await migrateDatabase(db, fromVersion: 1, toVersion: 9);
      },
    );
    final now = DateTime.utc(2026, 8, 25).toIso8601String();
    await versionNine.insert('learner_profiles', {
      'id': 1,
      'name': 'Existing Kokoro learner',
      'hsk_level': 2,
      'daily_word_target': 15,
      'created_at': now,
      'updated_at': now,
    });
    await versionNine.insert('learner_settings', {
      'learner_id': 1,
      'show_pinyin': 1,
      'sound_enabled': 1,
      'reminder_enabled': 0,
      'reminder_hour': 18,
      'pronunciation_engine': 'kokoro',
      'pronunciation_voice_id': 'zm_041',
    });
    await versionNine.close();

    final upgraded = await LocalDatabase.ensureInitialized();
    expect(await upgraded.getVersion(), databaseSchemaVersion);
    final restored = await settings.load();
    expect(restored.pronunciationEngine, PronunciationEngine.kokoro);
    expect(restored.kokoroVoiceIds, ['zm_041']);
  });

  test('learner profile is persisted in its typed repository', () async {
    await learners.save(
      const LearnerProfile(name: 'Mei', hskLevel: 3, dailyWordTarget: 20),
    );

    final profile = await learners.load();
    expect(profile?.name, 'Mei');
    expect(profile?.hskLevel, 3);
    expect(profile?.dailyWordTarget, 20);

    await learners.resetOnboarding();
    expect(await learners.load(), isNull);
  });

  test('onboarding reset preserves the complete learning state', () async {
    await LocalDatabase.resetForTesting();
    await LocalDatabase.ensureInitialized();
    await learners.save(
      const LearnerProfile(
        name: 'Original Mei',
        hskLevel: 2,
        dailyWordTarget: 15,
      ),
    );
    await settings.save(
      const LearnerSettings(
        showPinyin: false,
        soundEnabled: false,
        reminderEnabled: true,
        reminderHour: 7,
        pronunciationEngine: PronunciationEngine.kokoro,
        kokoroVoiceIds: ['zf_017'],
      ),
    );
    await lessons.saveGenerated(
      const Lesson(
        summary: LessonSummary(
          id: 0,
          title: 'Preserved topic · HSK 2',
          theme: 'Preserved topic',
          hskLevel: 2,
        ),
        cards: [
          Flashcard(
            chinese: '保留',
            pinyin: 'bǎoliú',
            englishMeaning: 'preserve',
          ),
        ],
      ),
    );
    final generated = await lessons.findGenerated(
      theme: 'Preserved topic',
      hskLevel: 2,
    );
    final lessonId = generated!.summary.id;
    final cardId = generated.cards.single.id;
    final session = await progress.startSession(lessonId);
    final reviewedAt = DateTime.utc(2026, 8, 18, 9);
    await progress.recordReview(
      review: ReviewRecord(
        id: 0,
        cardId: cardId,
        sessionId: session.id,
        reviewedAt: reviewedAt,
        rating: ReviewRating.good,
        wasCorrect: true,
      ),
      progress: CardProgress(
        cardId: cardId,
        repetitions: 1,
        intervalDays: 3,
        dueAt: reviewedAt.add(const Duration(days: 3)),
        lastReviewedAt: reviewedAt,
      ),
    );
    await dailyReviews.create(
      date: DateTime(2026, 8, 18),
      queuedCardIds: [cardId],
    );

    var db = await LocalDatabase.ensureInitialized();
    final originalProfile = (await db.query('learner_profiles')).single;
    final originalSettings = await db.query('learner_settings');
    final originalSessions = await db.query('lesson_sessions');
    final originalHistory = await db.query('review_history');
    final originalProgress = await db.query('card_progress');
    final originalDailySessions = await db.query('daily_review_sessions');
    final originalGeneratedLesson = await db.query(
      'lessons',
      where: 'id = ?',
      whereArgs: [lessonId],
    );
    final originalGeneratedCards = await db.query(
      'cards',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
    );

    await learners.resetOnboarding();
    await learners.resetOnboarding();
    expect(await learners.load(), isNull);

    await LocalDatabase.close();
    expect(await learners.load(), isNull);
    db = await LocalDatabase.ensureInitialized();
    expect(
      await db.query(
        'app_data',
        where: 'key = ?',
        whereArgs: ['onboarding_required'],
      ),
      hasLength(1),
    );
    expect((await db.query('learner_profiles')).single, originalProfile);
    expect(await db.query('learner_settings'), originalSettings);
    expect(await db.query('lesson_sessions'), originalSessions);
    expect(await db.query('review_history'), originalHistory);
    expect(await db.query('card_progress'), originalProgress);
    expect(await db.query('daily_review_sessions'), originalDailySessions);
    expect(
      await db.query('lessons', where: 'id = ?', whereArgs: [lessonId]),
      originalGeneratedLesson,
    );
    expect(
      await db.query('cards', where: 'lesson_id = ?', whereArgs: [lessonId]),
      originalGeneratedCards,
    );
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);

    await learners.save(
      const LearnerProfile(
        name: 'Re-onboarded Mei',
        hskLevel: 4,
        dailyWordTarget: 30,
      ),
    );

    final restoredProfile = await learners.load();
    final restoredSettings = await settings.load();
    final updatedProfile = (await db.query('learner_profiles')).single;
    expect(restoredProfile?.name, 'Re-onboarded Mei');
    expect(restoredProfile?.hskLevel, 4);
    expect(restoredProfile?.dailyWordTarget, 30);
    expect(updatedProfile['id'], originalProfile['id']);
    expect(updatedProfile['created_at'], originalProfile['created_at']);
    expect(restoredSettings.showPinyin, isFalse);
    expect(restoredSettings.soundEnabled, isFalse);
    expect(restoredSettings.reminderEnabled, isTrue);
    expect(restoredSettings.reminderHour, 7);
    expect(await db.query('lesson_sessions'), originalSessions);
    expect(await db.query('review_history'), originalHistory);
    expect(await db.query('card_progress'), originalProgress);
    expect(await db.query('daily_review_sessions'), originalDailySessions);
    expect(
      await db.query(
        'app_data',
        where: 'key = ?',
        whereArgs: ['onboarding_required'],
      ),
      isEmpty,
    );
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('failed setup save keeps the onboarding reset atomic', () async {
    await LocalDatabase.resetForTesting();
    final db = await LocalDatabase.ensureInitialized();
    await learners.save(
      const LearnerProfile(
        name: 'Original Mei',
        hskLevel: 2,
        dailyWordTarget: 15,
      ),
    );
    final originalProfile = (await db.query('learner_profiles')).single;
    await learners.resetOnboarding();

    await expectLater(
      learners.save(
        const LearnerProfile(
          name: 'Invalid Mei',
          hskLevel: 7,
          dailyWordTarget: 15,
        ),
      ),
      throwsA(isA<DatabaseException>()),
    );

    expect(await learners.load(), isNull);
    expect((await db.query('learner_profiles')).single, originalProfile);
    expect(
      await db.query(
        'app_data',
        where: 'key = ?',
        whereArgs: ['onboarding_required'],
      ),
      hasLength(1),
    );
  });

  test('generated lessons are saved and offered as previous topics', () async {
    await LocalDatabase.resetForTesting();
    final db = await LocalDatabase.ensureInitialized();

    const generated = Lesson(
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
    );
    await Future.wait([
      lessons.saveGenerated(generated),
      lessons.saveGenerated(generated),
    ]);

    final topics = await lessons.topics();
    expect(
      topics.where(
        (topic) =>
            topic.theme.toLowerCase() == 'ordering breakfast' &&
            topic.hskLevel == 1,
      ),
      hasLength(1),
    );
    expect(topics.first.title, 'Ordering breakfast · HSK 1');
    expect(topics.first.theme, 'Ordering breakfast');

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
        pronunciationEngine: PronunciationEngine.kokoro,
        kokoroVoiceIds: ['zf_021', 'zm_041'],
      ),
    );

    final storedSettings = await settings.load();
    expect(storedSettings.showPinyin, isFalse);
    expect(storedSettings.soundEnabled, isFalse);
    expect(storedSettings.reminderEnabled, isTrue);
    expect(storedSettings.reminderHour, 9);
    expect(storedSettings.pronunciationEngine, PronunciationEngine.kokoro);
    expect(storedSettings.kokoroVoiceIds, ['zf_021', 'zm_041']);

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
    final vocabularyProgress = await progress.vocabularyProgress();
    final vocabularyCard = vocabularyProgress.singleWhere(
      (item) => item.progress.cardId == cardId,
    );
    expect(vocabularyCard.chinese, lesson.cards.first.chinese);
    expect(vocabularyCard.progress.mastery, 1);
  });

  test(
    'starting the same lesson concurrently reuses its active session',
    () async {
      await LocalDatabase.resetForTesting();
      await LocalDatabase.ensureInitialized();
      await learners.save(
        const LearnerProfile(name: 'Mei', hskLevel: 1, dailyWordTarget: 10),
      );
      final lessonId = (await lessons.topics()).first.id;

      final sessions = await Future.wait([
        progress.startSession(lessonId),
        progress.startSession(lessonId),
      ]);

      expect(sessions[0].id, sessions[1].id);
      final db = await LocalDatabase.ensureInitialized();
      final activeRows = await db.query(
        'lesson_sessions',
        where: 'learner_id = ? AND lesson_id = ? AND completed_at IS NULL',
        whereArgs: [1, lessonId],
      );
      expect(activeRows, hasLength(1));
    },
  );

  test('lesson position saves cannot roll back answer progress', () async {
    await LocalDatabase.resetForTesting();
    await LocalDatabase.ensureInitialized();
    await learners.save(
      const LearnerProfile(name: 'Mei', hskLevel: 1, dailyWordTarget: 10),
    );
    final lessonId = (await lessons.topics()).first.id;
    final session = await progress.startSession(lessonId);
    await progress.updateSession(
      LessonSession(
        id: session.id,
        lessonId: lessonId,
        startedAt: session.startedAt,
        currentCardIndex: 1,
        cardsReviewed: 1,
        correctAnswers: 1,
      ),
    );

    await progress.updateSessionPosition(
      sessionId: session.id,
      currentCardIndex: 0,
      expectedCardsReviewed: 0,
    );
    final beforeValidNavigation = await progress.activeSessionForLesson(
      lessonId,
    );
    expect(beforeValidNavigation?.currentCardIndex, 1);
    await progress.updateSessionPosition(
      sessionId: session.id,
      currentCardIndex: 0,
      expectedCardsReviewed: 1,
    );
    await progress.updateSession(session);
    final active = await progress.activeSessionForLesson(lessonId);
    expect(active?.currentCardIndex, 0);
    expect(active?.cardsReviewed, 1);
    expect(active?.correctAnswers, 1);

    final completedAt = DateTime.utc(2026, 8, 8, 10);
    await progress.updateSession(
      LessonSession(
        id: session.id,
        lessonId: lessonId,
        startedAt: session.startedAt,
        completedAt: completedAt,
        currentCardIndex: 2,
        cardsReviewed: 2,
        correctAnswers: 2,
      ),
    );
    await progress.updateSessionPosition(
      sessionId: session.id,
      currentCardIndex: 0,
      expectedCardsReviewed: 2,
    );
    final db = await LocalDatabase.ensureInitialized();
    final stored = (await db.query(
      'lesson_sessions',
      where: 'id = ?',
      whereArgs: [session.id],
    )).single;
    expect(stored['completed_at'], completedAt.toIso8601String());
    expect(stored['current_card_index'], 2);
    expect(stored['cards_reviewed'], 2);
  });

  test('stale lesson reconciliation cannot overwrite newer progress', () async {
    await LocalDatabase.resetForTesting();
    await LocalDatabase.ensureInitialized();
    await learners.save(
      const LearnerProfile(name: 'Mei', hskLevel: 1, dailyWordTarget: 10),
    );
    final lessonId = (await lessons.topics()).first.id;
    final session = await progress.startSession(lessonId);
    final advanced = LessonSession(
      id: session.id,
      lessonId: lessonId,
      startedAt: session.startedAt,
      currentCardIndex: 1,
      cardsReviewed: 1,
      correctAnswers: 1,
    );
    await progress.updateSession(advanced);

    await progress.updateSession(
      session,
      reconcileFromHistory: true,
      expectedCardsReviewed: 0,
      expectedCorrectAnswers: 0,
    );
    await progress.updateSession(
      LessonSession(
        id: session.id,
        lessonId: lessonId,
        startedAt: session.startedAt,
        currentCardIndex: 0,
        cardsReviewed: 1,
      ),
    );
    var stored = await progress.activeSessionForLesson(lessonId);
    expect(stored?.cardsReviewed, 1);
    expect(stored?.correctAnswers, 1);

    await progress.updateSession(
      LessonSession(
        id: session.id,
        lessonId: lessonId,
        startedAt: session.startedAt,
        currentCardIndex: 1,
        cardsReviewed: 1,
      ),
      reconcileFromHistory: true,
      expectedCardsReviewed: 1,
      expectedCorrectAnswers: 1,
    );
    stored = await progress.activeSessionForLesson(lessonId);
    expect(stored?.cardsReviewed, 1);
    expect(stored?.correctAnswers, 0);
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

  test(
    'daily review session restores its queue and position until midnight',
    () async {
      await LocalDatabase.resetForTesting();
      await LocalDatabase.ensureInitialized();
      await learners.save(
        const LearnerProfile(name: 'Mei', hskLevel: 2, dailyWordTarget: 3),
      );
      final day = DateTime(2026, 8, 6, 9);
      final originalQueue = await progress.dailyQueue(forDay: day, limit: 3);
      final original = await dailyReviews.load(day);

      expect(original, isNotNull);
      expect(
        original!.queuedCardIds,
        originalQueue.map((item) => item.card.id),
      );
      await dailyReviews.update(
        DailyReviewSession(
          id: original.id,
          date: original.date,
          queuedCardIds: original.queuedCardIds,
          currentPosition: 2,
        ),
      );
      await dailyReviews.update(
        DailyReviewSession(
          id: original.id,
          date: original.date,
          queuedCardIds: original.queuedCardIds,
          currentPosition: 1,
        ),
      );

      await LocalDatabase.close();
      final restoredQueue = await progress.dailyQueue(
        forDay: DateTime(2026, 8, 6, 20),
        limit: 1,
      );
      final restored = await dailyReviews.load(day);

      expect(
        restoredQueue.map((item) => item.card.id),
        original.queuedCardIds.skip(2),
      );
      expect(restored?.currentPosition, 2);
      expect(await dailyReviews.load(DateTime(2026, 8, 7)), isNull);

      final completedAt = DateTime.utc(2026, 8, 6, 21);
      await dailyReviews.complete(
        sessionId: restored!.id,
        completedAt: completedAt,
        expectedCardCount: original.queuedCardIds.length,
      );
      final completed = await dailyReviews.load(day);
      expect(completed?.currentPosition, original.queuedCardIds.length);
      expect(completed?.completedAt, completedAt);
      await dailyReviews.update(
        DailyReviewSession(
          id: original.id,
          date: original.date,
          queuedCardIds: original.queuedCardIds,
          currentPosition: 0,
        ),
      );
      final stillCompleted = await dailyReviews.load(day);
      expect(stillCompleted?.currentPosition, original.queuedCardIds.length);
      expect(stillCompleted?.completedAt, completedAt);

      await dailyReviews.enqueueCard(
        date: day,
        cardId: original.queuedCardIds.first,
      );
      await dailyReviews.complete(
        sessionId: original.id,
        completedAt: completedAt.add(const Duration(minutes: 1)),
        expectedCardCount: original.queuedCardIds.length,
      );
      final restoredWeakCard = await progress.dailyQueue(forDay: day, limit: 3);
      final reopened = await dailyReviews.load(day);
      expect(restoredWeakCard.map((item) => item.card.id), [
        original.queuedCardIds.first,
      ]);
      expect(reopened?.isComplete, isFalse);
      expect(reopened?.currentPosition, original.queuedCardIds.length);
      expect(reopened?.queuedCardIds.length, original.queuedCardIds.length + 1);

      await dailyReviews.complete(
        sessionId: original.id,
        completedAt: completedAt.add(const Duration(minutes: 2)),
        expectedCardCount: reopened!.queuedCardIds.length,
      );
      await dailyReviews.enqueueCard(
        date: day,
        cardId: original.queuedCardIds.first,
      );
      final reopenedAgain = await dailyReviews.load(day);
      expect(reopenedAgain?.currentPosition, original.queuedCardIds.length + 1);
      expect(
        reopenedAgain?.queuedCardIds.length,
        original.queuedCardIds.length + 2,
      );
    },
  );

  test(
    'daily review repository creates once and rolls over at midnight',
    () async {
      await LocalDatabase.resetForTesting();
      await LocalDatabase.ensureInitialized();
      await learners.save(
        const LearnerProfile(name: 'Mei', hskLevel: 1, dailyWordTarget: 2),
      );
      final cards = await progress.dailyQueue(
        forDay: DateTime(2026, 8, 6, 8),
        limit: 2,
      );
      final ids = cards.map((item) => item.card.id).toList();

      final morning = await dailyReviews.load(DateTime(2026, 8, 6, 8));
      final restored = await dailyReviews.create(
        date: DateTime(2026, 8, 6, 23, 59),
        queuedCardIds: ids.reversed.toList(),
      );
      final nextDay = await dailyReviews.create(
        date: DateTime(2026, 8, 7),
        queuedCardIds: ids.reversed.toList(),
      );

      expect(restored.id, morning?.id);
      expect(restored.queuedCardIds, ids);
      expect(nextDay.id, isNot(restored.id));
      expect(nextDay.date, DateTime(2026, 8, 7));
      expect(nextDay.queuedCardIds, ids.reversed);
    },
  );

  test('incorrect Vocab Rush words persist into the daily queue', () async {
    await LocalDatabase.resetForTesting();
    final db = await LocalDatabase.ensureInitialized();
    await learners.save(
      const LearnerProfile(name: 'Mei', hskLevel: 1, dailyWordTarget: 200),
    );
    const rushCard = Flashcard(
      chinese: '错题',
      pinyin: 'cuò tí',
      englishMeaning: 'incorrect question',
      partOfSpeech: 'noun',
    );
    final topicsBefore = await lessons.topics();
    final stored = await lessons.findOrCreateVocabularyCard(
      card: rushCard,
      hskLevel: 1,
    );
    final duplicate = await lessons.findOrCreateVocabularyCard(
      card: rushCard,
      hskLevel: 1,
    );
    final visibleTopics = await lessons.topics();
    final hiddenCollections = await db.query(
      'lessons',
      where: 'is_listed = ?',
      whereArgs: [0],
    );
    final hiddenId = hiddenCollections.single['id'] as int;
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
    expect(
      visibleTopics.map((lesson) => lesson.id),
      topicsBefore.map((lesson) => lesson.id),
    );
    expect(
      visibleTopics.map((lesson) => lesson.title),
      isNot(contains('Vocab Rush · HSK 1')),
    );
    expect(await lessons.findById(hiddenId), isNull);
    expect(
      await lessons.findGenerated(theme: 'Vocab Rush', hskLevel: 1),
      isNull,
    );
    await expectLater(progress.startSession(hiddenId), throwsStateError);

    final realSession = await progress.startSession(topicsBefore.first.id);
    await db.insert('lesson_sessions', {
      'learner_id': 1,
      'lesson_id': hiddenId,
      'started_at': DateTime.utc(2100).toIso8601String(),
    });
    expect(await progress.activeSessionForLesson(hiddenId), isNull);
    expect((await progress.latestActiveSession())?.id, realSession.id);
    expect(queued.card.chinese, '错题');
    expect(queued.reason, DailyQueueReason.weak);
    expect(queued.progress?.incorrectAnswers, 1);
  });

  test('Vocab Rush storage cannot alter a listed lesson', () async {
    await LocalDatabase.resetForTesting();
    final db = await LocalDatabase.ensureInitialized();
    await lessons.saveGenerated(
      const Lesson(
        summary: LessonSummary(
          id: 0,
          title: 'Vocab Rush strategies · HSK 1',
          theme: 'Vocab Rush',
          hskLevel: 1,
        ),
        cards: [
          Flashcard(chinese: '快', pinyin: 'kuài', englishMeaning: 'fast'),
        ],
      ),
    );
    final topicsBefore = await lessons.topics();

    await lessons.findOrCreateVocabularyCard(
      card: const Flashcard(
        chinese: '快',
        pinyin: 'kuài',
        englishMeaning: 'soon',
      ),
      hskLevel: 1,
    );

    final topicsAfter = await lessons.topics();
    final listedLesson = await lessons.findGenerated(
      theme: 'Vocab Rush',
      hskLevel: 1,
    );
    final hiddenCollections = await db.query(
      'lessons',
      where: 'is_listed = ?',
      whereArgs: [0],
    );
    expect(
      topicsAfter.map((lesson) => lesson.id),
      topicsBefore.map((lesson) => lesson.id),
    );
    expect(listedLesson?.summary.title, 'Vocab Rush strategies · HSK 1');
    expect(listedLesson?.cards.map((card) => card.chinese), ['快']);
    expect(hiddenCollections, hasLength(1));
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
    final settingsColumns = await db.rawQuery(
      'PRAGMA table_info(learner_settings)',
    );

    final cardColumns = await db.rawQuery('PRAGMA table_info(cards)');
    final lessonColumns = await db.rawQuery('PRAGMA table_info(lessons)');
    final reviewColumns = await db.rawQuery(
      'PRAGMA table_info(review_history)',
    );
    expect(lessonColumns.map((row) => row['name']), contains('is_listed'));
    expect(reviewColumns.map((row) => row['name']), contains('submission_key'));
    expect(
      settingsColumns.map((row) => row['name']),
      containsAll([
        'pronunciation_engine',
        'pronunciation_voice_id',
        'kokoro_voice_ids',
      ]),
    );
    expect(
      cardColumns.map((row) => row['name']),
      containsAll([
        'example_source',
        'example_source_id',
        'example_translation_id',
      ]),
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
        'idx_lessons_listed',
        'idx_reviews_submission_key',
      ]),
    );
  });

  test(
    'vocabulary content repair preserves card identity and learning history',
    () async {
      await LocalDatabase.resetForTesting();
      final db = await LocalDatabase.ensureInitialized();
      await learners.save(
        const LearnerProfile(
          name: 'Migration learner',
          hskLevel: 2,
          dailyWordTarget: 10,
        ),
      );
      final lessonId = await db.insert('lessons', {
        'lesson_title': 'Numbers · HSK 1',
        'theme': 'Numbers',
        'hsk_level': 1,
        'is_listed': 1,
      });
      final cardId = await db.insert('cards', {
        'lesson_id': lessonId,
        'chinese': '三',
        'pinyin': 'Sān',
        'english_meaning': 'surname San',
        'part_of_speech': 'm, t',
        'hsk_level': 1,
        'example_sentence_chinese': '三先生来了。',
        'example_sentence_pinyin': 'Sān xiānsheng lái le.',
        'example_sentence_english': 'Mr San has arrived.',
        'example_source': 'Generated',
        'example_source_id': 'old-source',
        'example_translation_id': 'old-translation',
        'quiz_options': jsonEncode(['surname San', 'two', 'four', 'five']),
        'correct_answer': 'surname San',
      });
      final sameReadingCardId = await db.insert('cards', {
        'lesson_id': lessonId,
        'chinese': '本',
        'pinyin': 'běn',
        'english_meaning': 'root',
        'part_of_speech': 'm, r',
        'hsk_level': 1,
        'example_sentence_chinese': '这是植物的根本。',
        'example_sentence_pinyin': 'Zhè shì zhíwù de gēnběn.',
        'example_sentence_english': 'This is the root of the plant.',
        'quiz_options': jsonEncode(['root', 'book', 'pen', 'paper']),
        'correct_answer': 'root',
      });
      final reviewedAt = DateTime.utc(2026, 8, 20, 9);
      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: cardId,
          submissionKey: 'content-repair-review',
          reviewedAt: reviewedAt,
          rating: ReviewRating.good,
          wasCorrect: true,
        ),
        progress: CardProgress(
          cardId: cardId,
          repetitions: 1,
          reviewInterval: 2,
          nextReview: reviewedAt.add(const Duration(days: 2)),
          lastReview: reviewedAt,
        ),
      );
      final queueDate = DateTime(2026, 8, 20);
      await dailyReviews.create(date: queueDate, queuedCardIds: [cardId]);
      await db.delete(
        'content_migrations',
        where: 'key = ?',
        whereArgs: ['hsk_vocabulary_content_v2'],
      );

      await LocalDatabase.close();
      final migrated = await LocalDatabase.ensureInitialized();
      final card = (await migrated.query(
        'cards',
        where: 'id = ?',
        whereArgs: [cardId],
      )).single;

      expect(card['pinyin'], 'sān');
      expect(card['english_meaning'], 'three');
      expect(card['correct_answer'], 'three');
      expect(jsonDecode(card['quiz_options'] as String), [
        'three',
        'two',
        'four',
        'five',
      ]);
      expect(card['example_sentence_chinese'], isEmpty);
      expect(card['example_sentence_pinyin'], isEmpty);
      expect(card['example_sentence_english'], isEmpty);
      expect(card['example_source'], isEmpty);
      expect(card['example_source_id'], isEmpty);
      expect(card['example_translation_id'], isEmpty);
      final sameReadingCard = (await migrated.query(
        'cards',
        where: 'id = ?',
        whereArgs: [sameReadingCardId],
      )).single;
      expect(sameReadingCard['pinyin'], 'běn');
      expect(sameReadingCard['english_meaning'], 'measure word for books');
      expect(sameReadingCard['example_sentence_chinese'], isEmpty);
      expect(sameReadingCard['example_sentence_pinyin'], isEmpty);
      expect(sameReadingCard['example_sentence_english'], isEmpty);
      expect(await progress.reviewHistory(cardId: cardId), hasLength(1));
      expect((await progress.progressForCard(cardId))?.timesSeen, 1);
      expect((await dailyReviews.load(queueDate))?.queuedCardIds, [cardId]);
      expect(
        await migrated.query(
          'content_migrations',
          where: 'key = ?',
          whereArgs: ['hsk_vocabulary_content_v2'],
        ),
        hasLength(1),
      );

      await LocalDatabase.close();
      final reopened = await LocalDatabase.ensureInitialized();
      final reopenedCard = (await reopened.query(
        'cards',
        where: 'id = ?',
        whereArgs: [cardId],
      )).single;
      expect(reopenedCard['pinyin'], 'sān');
      expect(reopenedCard['english_meaning'], 'three');
      expect(await progress.reviewHistory(cardId: cardId), hasLength(1));
    },
  );

  test('bundled cards use packaged Tatoeba examples', () async {
    await LocalDatabase.resetForTesting();
    final db = await LocalDatabase.ensureInitialized();
    final rows = await db.rawQuery(
      '''
      SELECT cards.*
      FROM cards
      INNER JOIN lessons ON lessons.id = cards.lesson_id
      WHERE cards.chinese = ? AND lessons.lesson_title = ?
      LIMIT 1
    ''',
      ['胡萝卜', 'Vegetables HSK3 Flashcards'],
    );

    expect(rows, hasLength(1));
    expect(rows.single['example_sentence_chinese'], '除了胡萝卜，他没有什么是不吃的。');
    expect(
      rows.single['example_sentence_english'],
      "Except for carrots, there is nothing he won't eat.",
    );
    expect(rows.single['example_sentence_pinyin'], isEmpty);
    expect(rows.single['example_source'], 'Tatoeba');
    expect(rows.single['example_source_id'], '333939');
    expect(rows.single['example_translation_id'], '35862');
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
          pronunciationEngine: PronunciationEngine.kokoro,
          kokoroVoiceIds: ['zm_041', 'zf_021'],
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
      expect(restoredSettings.pronunciationEngine, PronunciationEngine.kokoro);
      expect(restoredSettings.kokoroVoiceIds, ['zm_041', 'zf_021']);
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

  test('a review submission key is persisted exactly once', () async {
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
    final session = await progress.startSession(summary.id);
    final reviewedAt = DateTime.utc(2026, 8, 8, 9);
    final firstDue = DateTime.utc(2026, 8, 9, 9);
    final submissionKey = 'lesson:${session.id}:card:$cardId';

    Future<void> submit(DateTime dueAt) => progress.recordReview(
      review: ReviewRecord(
        id: 0,
        cardId: cardId,
        sessionId: session.id,
        submissionKey: submissionKey,
        reviewedAt: reviewedAt,
        rating: ReviewRating.good,
        wasCorrect: true,
      ),
      progress: CardProgress(
        cardId: cardId,
        repetitions: 1,
        reviewInterval: 1,
        nextReview: dueAt,
        lastReview: reviewedAt,
      ),
    );

    await Future.wait([submit(firstDue), submit(firstDue)]);
    await submit(DateTime.utc(2030));

    final history = await progress.reviewHistory(cardId: cardId);
    final stored = await progress.progressForCard(cardId);
    expect(history, hasLength(1));
    expect(history.single.submissionKey, submissionKey);
    expect(stored?.timesSeen, 1);
    expect(stored?.correctAnswers, 1);
    expect(stored?.nextReview, firstDue);

    await progress.recordReview(
      review: ReviewRecord(
        id: 0,
        cardId: cardId,
        submissionKey: 'daily:submission:two',
        reviewedAt: reviewedAt.add(const Duration(days: 1)),
        rating: ReviewRating.again,
        wasCorrect: false,
      ),
      progress: CardProgress(
        cardId: cardId,
        lapses: 1,
        reviewInterval: 1,
        nextReview: firstDue.add(const Duration(days: 1)),
        lastReview: reviewedAt.add(const Duration(days: 1)),
      ),
    );
    expect(await progress.reviewHistory(cardId: cardId), hasLength(2));
    expect((await progress.progressForCard(cardId))?.timesSeen, 2);
  });

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
      final sessionId = await versionThree.insert('lesson_sessions', {
        'learner_id': 1,
        'lesson_id': lessonId,
        'started_at': now.toIso8601String(),
      });
      final answers = [1, 1, 0];
      for (var index = 0; index < answers.length; index++) {
        final wasCorrect = answers[index];
        await versionThree.insert('review_history', {
          'learner_id': 1,
          'card_id': cardId,
          'session_id': index < 2 ? sessionId : null,
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
      expect(await upgraded.getVersion(), databaseSchemaVersion);
      final restored = await progress.progressForCard(cardId);
      expect(restored?.timesSeen, 3);
      expect(restored?.correctAnswers, 2);
      expect(restored?.incorrectAnswers, 1);
      expect(restored?.mastery, closeTo(2 / 3, .000001));
      final migratedReviews = await upgraded.query(
        'review_history',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      expect(migratedReviews, hasLength(2));
      expect(
        migratedReviews.where((row) => row['submission_key'] != null),
        hasLength(1),
      );
      expect(
        migratedReviews.singleWhere(
          (row) => row['submission_key'] != null,
        )['submission_key'],
        'lesson:$sessionId:card:$cardId',
      );
      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: cardId,
          sessionId: sessionId,
          reviewedAt: now.add(const Duration(minutes: 1)),
          rating: ReviewRating.easy,
          wasCorrect: true,
        ),
        progress: CardProgress(
          cardId: cardId,
          nextReview: now.add(const Duration(days: 2)),
        ),
      );
      expect(await progress.reviewHistory(cardId: cardId), hasLength(3));
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
