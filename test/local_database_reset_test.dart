import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/database/flashcard_seed.dart';
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
  const settings = SqliteSettingsRepository();
  const lessons = SqliteLessonRepository();
  const progress = SqliteProgressRepository();
  const DailyReviewSessionRepository dailyReviews =
      SqliteDailyReviewSessionRepository();

  late Directory testDirectory;
  late String databasePath;

  setUp(() async {
    await LocalDatabase.close();
    LocalDatabase.useDatabaseArtifactDeleterForTesting(null);
    LocalDatabase.useDatabasePathForTesting(null);

    testDirectory = await Directory.systemTemp.createTemp(
      'tingshuo_reset_test_',
    );
    databasePath = '${testDirectory.path}/local_app.db';
    LocalDatabase.useDatabasePathForTesting(databasePath);
  });

  tearDown(() async {
    try {
      await LocalDatabase.close();
    } finally {
      LocalDatabase.useDatabaseArtifactDeleterForTesting(null);
      LocalDatabase.useDatabasePathForTesting(null);
      if (await testDirectory.exists()) {
        await testDirectory.delete(recursive: true);
      }
    }
  });

  test(
    'production reset removes all learner data and reseeds bundled content',
    () async {
      await LocalDatabase.initialize();
      await learners.save(
        const LearnerProfile(
          name: 'Reset me',
          hskLevel: 3,
          dailyWordTarget: 20,
        ),
      );
      await settings.save(
        const LearnerSettings(
          showPinyin: false,
          soundEnabled: false,
          reminderEnabled: true,
          reminderHour: 7,
          pronunciationEngine: PronunciationEngine.kokoro,
          kokoroVoiceIds: ['zf_032'],
        ),
      );

      const generatedTheme = 'Reset lifecycle test topic';
      await lessons.saveGenerated(
        const Lesson(
          summary: LessonSummary(
            id: 0,
            title: 'Reset lifecycle test topic · HSK 3',
            theme: generatedTheme,
            hskLevel: 3,
          ),
          cards: [
            Flashcard(
              chinese: '清除',
              pinyin: 'qīngchú',
              englishMeaning: 'clear',
              partOfSpeech: 'verb',
              exampleChinese: '请清除记录。',
              examplePinyin: 'Qǐng qīngchú jìlù.',
              exampleEnglish: 'Please clear the record.',
              quizOptions: ['clear', 'keep'],
            ),
          ],
        ),
      );
      final generated = await lessons.findGenerated(
        theme: generatedTheme,
        hskLevel: 3,
      );
      expect(generated, isNotNull);
      final generatedCardId = generated!.cards.single.id;
      final lessonSession = await progress.startSession(generated.summary.id);
      final reviewedAt = DateTime.utc(2026, 8, 19, 1);
      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: generatedCardId,
          sessionId: lessonSession.id,
          reviewedAt: reviewedAt,
          rating: ReviewRating.good,
          wasCorrect: true,
        ),
        progress: CardProgress(
          cardId: generatedCardId,
          repetitions: 1,
          intervalDays: 3,
          dueAt: reviewedAt.add(const Duration(days: 3)),
          lastReviewedAt: reviewedAt,
        ),
      );
      final reviewDate = DateTime(2026, 8, 19);
      await dailyReviews.create(
        date: reviewDate,
        queuedCardIds: [generatedCardId],
      );

      expect(await File(databasePath).exists(), isTrue);
      expect(await learners.load(), isNotNull);
      expect(await progress.reviewHistory(), hasLength(1));
      expect(await dailyReviews.load(reviewDate), isNotNull);

      await LocalDatabase.resetAllData();

      await _expectDatabaseArtifactsAbsent(databasePath);
      await LocalDatabase.initialize();

      expect(await learners.load(), isNull);
      final restoredSettings = await settings.load();
      expect(restoredSettings.showPinyin, isTrue);
      expect(restoredSettings.soundEnabled, isTrue);
      expect(restoredSettings.reminderEnabled, isFalse);
      expect(restoredSettings.reminderHour, 18);
      expect(restoredSettings.pronunciationEngine, PronunciationEngine.melo);
      expect(restoredSettings.kokoroVoiceIds, isEmpty);
      expect(
        await lessons.findGenerated(theme: generatedTheme, hskLevel: 3),
        isNull,
      );
      expect(await progress.reviewHistory(), isEmpty);
      expect(await progress.progressForCard(generatedCardId), isNull);
      expect(await dailyReviews.load(reviewDate), isNull);

      final expectedCardCount = flashcardLessons.fold<int>(
        0,
        (total, lesson) => total + (lesson['cards'] as List<dynamic>).length,
      );
      await LocalDatabase.use<void>((db) async {
        expect(await _rowCount(db, 'learner_profiles'), 0);
        expect(await _rowCount(db, 'learner_settings'), 0);
        expect(await _rowCount(db, 'lesson_sessions'), 0);
        expect(await _rowCount(db, 'review_history'), 0);
        expect(await _rowCount(db, 'card_progress'), 0);
        expect(await _rowCount(db, 'daily_review_sessions'), 0);
        expect(await _rowCount(db, 'lessons'), flashcardLessons.length);
        expect(await _rowCount(db, 'cards'), expectedCardCount);
        expect(
          await db.query(
            'content_migrations',
            where: 'key = ?',
            whereArgs: ['tatoeba_examples_v1'],
          ),
          hasLength(1),
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      });
    },
  );

  test(
    'reset waits for active use and rejects operations started during reset',
    () async {
      await LocalDatabase.initialize();
      final leaseStarted = Completer<void>();
      final releaseLease = Completer<void>();
      final activeUse = LocalDatabase.use<void>((db) async {
        await db.rawQuery('SELECT 1');
        leaseStarted.complete();
        await releaseLease.future;
        await db.rawQuery('SELECT 1');
      });
      addTearDown(() {
        if (!releaseLease.isCompleted) releaseLease.complete();
      });
      await leaseStarted.future;

      var resetCompleted = false;
      final reset = LocalDatabase.resetAllData().then((_) {
        resetCompleted = true;
      });
      try {
        await _waitForResetToRejectNewUse();

        expect(resetCompleted, isFalse);
        expect(await File(databasePath).exists(), isTrue);
        await expectLater(
          LocalDatabase.initialize(),
          throwsA(isA<DatabaseResetInProgressException>()),
        );
      } finally {
        if (!releaseLease.isCompleted) releaseLease.complete();
      }
      await activeUse;
      await reset;

      expect(resetCompleted, isTrue);
      await _expectDatabaseArtifactsAbsent(databasePath);
    },
  );

  test('reset detects a no-op artifact deleter as a failure', () async {
    await LocalDatabase.initialize();
    await learners.save(
      const LearnerProfile(
        name: 'Still here',
        hskLevel: 2,
        dailyWordTarget: 10,
      ),
    );
    var deleteCalls = 0;
    String? deletedPath;
    LocalDatabase.useDatabaseArtifactDeleterForTesting((path) async {
      deleteCalls++;
      deletedPath = path;
    });

    await expectLater(LocalDatabase.resetAllData(), throwsA(anything));

    expect(deleteCalls, 1);
    expect(deletedPath, databasePath);
    expect(await File(databasePath).exists(), isTrue);

    await LocalDatabase.initialize();
    expect((await learners.load())?.name, 'Still here');
  });

  test('concurrent reset calls coalesce into one artifact deletion', () async {
    await LocalDatabase.initialize();
    final deletionStarted = Completer<void>();
    final allowDeletion = Completer<void>();
    addTearDown(() {
      if (!allowDeletion.isCompleted) allowDeletion.complete();
    });
    var deleteCalls = 0;
    LocalDatabase.useDatabaseArtifactDeleterForTesting((path) async {
      deleteCalls++;
      if (!deletionStarted.isCompleted) deletionStarted.complete();
      await allowDeletion.future;
      await _deleteDatabaseArtifactsStrictly(path);
    });

    final firstReset = LocalDatabase.resetAllData();
    late Future<void> trackedSecondReset;
    try {
      await deletionStarted.future;
      final secondReset = LocalDatabase.resetAllData();
      var secondCompleted = false;
      trackedSecondReset = secondReset.then((_) {
        secondCompleted = true;
      });

      await Future<void>.delayed(Duration.zero);
      expect(secondCompleted, isFalse);
      expect(deleteCalls, 1);
    } finally {
      if (!allowDeletion.isCompleted) allowDeletion.complete();
    }
    await Future.wait([firstReset, trackedSecondReset]);

    expect(deleteCalls, 1);
    await _expectDatabaseArtifactsAbsent(databasePath);
  });

  test('reset deletes the opened path when the override changes', () async {
    final openedPath = databasePath;
    final replacementPath = '${testDirectory.path}/replacement.db';
    const replacementContents = 'must not be deleted';

    await LocalDatabase.initialize();
    await LocalDatabase.use<void>((db) async {
      expect(db.path, openedPath);
    });
    await File(replacementPath).writeAsString(replacementContents, flush: true);
    LocalDatabase.useDatabasePathForTesting(replacementPath);

    final deletedPaths = <String>[];
    LocalDatabase.useDatabaseArtifactDeleterForTesting((path) async {
      deletedPaths.add(path);
      await _deleteDatabaseArtifactsStrictly(path);
    });

    await LocalDatabase.resetAllData();

    expect(deletedPaths, [openedPath]);
    await _expectDatabaseArtifactsAbsent(openedPath);
    expect(await File(replacementPath).readAsString(), replacementContents);
  });
}

Future<int> _rowCount(Database db, String table) async {
  final row = (await db.rawQuery(
    'SELECT COUNT(*) AS count FROM $table',
  )).single;
  return row['count'] as int;
}

Future<void> _waitForResetToRejectNewUse() async {
  for (var attempt = 0; attempt < 100; attempt++) {
    try {
      await LocalDatabase.use<void>((_) async {});
    } on DatabaseResetInProgressException {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Reset never rejected a newly started database operation.');
}

Future<void> _deleteDatabaseArtifactsStrictly(String path) async {
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final artifact = File('$path$suffix');
    if (await artifact.exists()) await artifact.delete();
  }
}

Future<void> _expectDatabaseArtifactsAbsent(String path) async {
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    expect(
      await File('$path$suffix').exists(),
      isFalse,
      reason: 'Expected $path$suffix to be deleted.',
    );
  }
}
