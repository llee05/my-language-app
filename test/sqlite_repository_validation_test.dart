import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/models/learner_profile.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/models/lesson.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const learners = SqliteLearnerRepository();
  const lessons = SqliteLessonRepository();
  const settings = SqliteSettingsRepository();
  const progress = SqliteProgressRepository();
  const dailyReviews = SqliteDailyReviewSessionRepository();

  late Directory testDirectory;

  setUp(() async {
    await LocalDatabase.close();
    testDirectory = await Directory.systemTemp.createTemp(
      'hanzipath_validation_test_',
    );
    LocalDatabase.useDatabasePathForTesting(
      '${testDirectory.path}/local_app.db',
    );
    await LocalDatabase.initialize();
    await learners.save(
      const LearnerProfile(name: 'Mei', hskLevel: 2, dailyWordTarget: 10),
    );
  });

  tearDown(() async {
    await LocalDatabase.close();
    LocalDatabase.useDatabasePathForTesting(null);
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  group('recordReview input validation', () {
    test('rejects reviews and progress for different cards', () async {
      await expectLater(
        progress.recordReview(
          review: ReviewRecord(
            id: 0,
            cardId: 1,
            reviewedAt: DateTime.utc(2026, 9, 1),
            rating: ReviewRating.good,
            wasCorrect: true,
          ),
          progress: CardProgress(cardId: 2, dueAt: DateTime.utc(2026, 9, 2)),
        ),
        throwsArgumentError,
      );
    });

    test(
      'rejects lesson submission keys that mismatch their session',
      () async {
        await expectLater(
          progress.recordReview(
            review: ReviewRecord(
              id: 0,
              cardId: 1,
              sessionId: 5,
              submissionKey: 'custom:key',
              reviewedAt: DateTime.utc(2026, 9, 1),
              rating: ReviewRating.good,
              wasCorrect: true,
            ),
            progress: CardProgress(cardId: 1, dueAt: DateTime.utc(2026, 9, 2)),
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('settings decoding robustness', () {
    test('a corrupted voice pool decodes to an empty pool', () async {
      await settings.save(
        const LearnerSettings(kokoroVoiceIds: ['zf_001', 'zm_041']),
      );
      await LocalDatabase.use<void>((db) async {
        await db.update(
          'learner_settings',
          {'kokoro_voice_ids': 'not-json'},
          where: 'learner_id = ?',
          whereArgs: [1],
        );
      });

      final loaded = await settings.load();

      expect(loaded.kokoroVoiceIds, isEmpty);
      expect(loaded.pronunciationEngine, PronunciationEngine.kokoro);
    });

    test('non-string and blank voice ids are dropped', () async {
      await settings.save(
        const LearnerSettings(kokoroVoiceIds: ['zf_001', 'zm_041']),
      );
      await LocalDatabase.use<void>((db) async {
        await db.update(
          'learner_settings',
          {
            'kokoro_voice_ids': jsonEncode([
              'zf_001',
              '   ',
              42,
              'zm_041',
              null,
            ]),
          },
          where: 'learner_id = ?',
          whereArgs: [1],
        );
      });

      expect((await settings.load()).kokoroVoiceIds, ['zf_001', 'zm_041']);
    });
  });

  group('daily review session validation', () {
    test('update rejects positions outside the queued card range', () async {
      final session = await dailyReviews.create(
        date: DateTime(2026, 9, 2),
        queuedCardIds: [1, 2, 3],
      );

      await expectLater(
        dailyReviews.update(
          DailyReviewSession(
            id: session.id,
            date: session.date,
            queuedCardIds: session.queuedCardIds,
            currentPosition: 4,
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        dailyReviews.update(
          DailyReviewSession(
            id: session.id,
            date: session.date,
            queuedCardIds: session.queuedCardIds,
            currentPosition: -1,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('update reports a missing session', () async {
      await expectLater(
        dailyReviews.update(
          DailyReviewSession(
            id: 999,
            date: DateTime(2026, 9, 9),
            queuedCardIds: const [1],
          ),
        ),
        throwsStateError,
      );
    });

    test('creating a session twice returns the stored session', () async {
      final date = DateTime(2026, 9, 3);
      final first = await dailyReviews.create(date: date, queuedCardIds: [7]);
      final second = await dailyReviews.create(
        date: date,
        queuedCardIds: [8, 9],
      );

      expect(second.id, first.id);
      expect(second.queuedCardIds, [7]);
      final stored = await dailyReviews.load(date);
      expect(stored?.queuedCardIds, [7]);
    });
  });

  group('lesson repository lookups', () {
    test('findGenerated matches themes case-insensitively', () async {
      const lesson = Lesson(
        summary: LessonSummary(
          id: 0,
          title: 'Food & Drink · HSK 2',
          theme: 'Food & Drink',
          hskLevel: 2,
        ),
        cards: [
          Flashcard(
            chinese: '米饭',
            pinyin: 'mǐfàn',
            englishMeaning: 'cooked rice',
          ),
        ],
      );
      await lessons.saveGenerated(lesson);

      final found = await lessons.findGenerated(
        theme: '  food & drink  ',
        hskLevel: 2,
      );

      expect(found, isNotNull);
      expect(found!.summary.theme, 'Food & Drink');
      expect(
        await lessons.findGenerated(theme: 'Food & Drink', hskLevel: 3),
        isNull,
      );
    });
  });
}
