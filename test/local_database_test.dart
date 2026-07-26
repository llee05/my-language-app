import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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

  test('version 1 database migrates to version 3 without data loss', () async {
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

    expect(version, 3);
    expect(marker.single['value'], 'preserve me');
    expect(
      indexes.map((row) => row['name']),
      containsAll(['idx_lessons_theme_hsk', 'idx_cards_lesson_id']),
    );
    final migratedProfile = await learners.load();
    expect(migratedProfile?.name, 'Legacy learner');
    expect(migratedProfile?.hskLevel, 2);
    expect(migratedProfile?.dailyWordTarget, 15);
  });

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
    expect(cardProgress?.intervalDays, 3);
    expect(cardProgress?.dueAt, dueAt);
    expect(await progress.dueCards(dueAt), hasLength(1));
  });
}
