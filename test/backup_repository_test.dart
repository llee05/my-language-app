import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/models/ai_configuration.dart';
import 'package:mylanguageapp/models/learner_profile.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/models/lesson.dart';
import 'package:mylanguageapp/repositories/ai_configuration_repository.dart';
import 'package:mylanguageapp/repositories/backup_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';

import 'lesson_generation_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const learners = SqliteLearnerRepository();
  const lessons = SqliteLessonRepository();
  const progress = SqliteProgressRepository();
  const settings = SqliteSettingsRepository();
  const dailyReviews = SqliteDailyReviewSessionRepository();
  const aiConfiguration = SecureAiConfigurationRepository();
  final exportedAt = DateTime.utc(2026, 9, 14, 2, 30);
  final backups = SqliteBackupRepository(() => exportedAt);

  setUp(() async {
    await LocalDatabase.resetForTesting();
    await LocalDatabase.ensureInitialized();
    await aiConfiguration.clear();
  });

  tearDown(LocalDatabase.close);

  test(
    'exports a portable preview and restores complete learning data',
    () async {
      await learners.save(
        const LearnerProfile(
          name: 'Backup Mei',
          hskLevel: 4,
          dailyWordTarget: 20,
        ),
      );
      await settings.save(
        const LearnerSettings(
          showPinyin: false,
          soundEnabled: false,
          reminderEnabled: true,
          reminderHour: 8,
          kokoroVoiceIds: ['zf_021'],
          appThemeId: 'ocean',
          buttonAnimationStyle: ButtonAnimationStyle.iconMotion,
        ),
      );
      await lessons.saveGenerated(
        const Lesson(
          guide: savedLessonGuide,
          summary: LessonSummary(
            id: 0,
            title: 'Travel practice',
            theme: 'Travel',
            hskLevel: 4,
          ),
          cards: [
            Flashcard(
              chinese: '护照',
              pinyin: 'hùzhào',
              englishMeaning: 'passport',
              quizOptions: ['passport', 'ticket'],
            ),
          ],
        ),
      );
      final lesson = await lessons.findGenerated(theme: 'Travel', hskLevel: 4);
      final session = await progress.startSession(lesson!.summary.id);
      final reviewedAt = DateTime.utc(2026, 9, 13, 8);
      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: lesson.cards.single.id,
          sessionId: session.id,
          submissionKey: 'lesson:${session.id}:card:${lesson.cards.single.id}',
          reviewedAt: reviewedAt,
          rating: ReviewRating.good,
          wasCorrect: true,
          responseTimeMs: 900,
        ),
        progress: CardProgress(
          cardId: lesson.cards.single.id,
          repetitions: 1,
          intervalDays: 3,
          dueAt: DateTime.utc(2026, 9, 16, 8),
          lastReviewedAt: reviewedAt,
        ),
      );
      await dailyReviews.create(
        date: DateTime(2026, 9, 14),
        queuedCardIds: [lesson.cards.single.id],
      );
      await aiConfiguration.save(
        const AiConfiguration(
          provider: AiProvider.openai,
          apiKey: 'sk-secret-that-must-not-be-exported',
          model: 'gpt-4.1-mini',
        ),
      );

      final bytes = await backups.exportBackup();
      final preview = backups.previewBackup(bytes);
      final document = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      expect(preview.exportedAt, exportedAt);
      expect(preview.learnerName, 'Backup Mei');
      expect(preview.hskLevel, 4);
      expect(preview.lessonCount, greaterThan(1));
      expect(preview.cardCount, greaterThan(1));
      expect(preview.reviewCount, 1);
      expect(preview.sessionCount, 2);
      expect(
        utf8.decode(bytes),
        isNot(contains('sk-secret-that-must-not-be-exported')),
      );
      expect(document.keys.toSet(), {
        'format',
        'formatVersion',
        'databaseSchemaVersion',
        'exportedAt',
        'data',
      });
      expect(
        (document['data'] as Map<String, dynamic>).keys,
        containsAll(<String>[
          'learner_profiles',
          'learner_settings',
          'lessons',
          'cards',
          'lesson_sessions',
          'review_history',
          'card_progress',
          'daily_review_sessions',
        ]),
      );

      await learners.save(
        const LearnerProfile(
          name: 'Changed locally',
          hskLevel: 1,
          dailyWordTarget: 5,
        ),
      );
      await settings.save(const LearnerSettings(appThemeId: 'classic'));

      await backups.restoreBackup(bytes);

      final restoredProfile = await learners.load();
      final restoredSettings = await settings.load();
      final restoredLesson = await lessons.findGenerated(
        theme: 'Travel',
        hskLevel: 4,
      );
      final restoredHistory = await progress.reviewHistory(
        cardId: restoredLesson!.cards.single.id,
      );
      final restoredProgress = await progress.progressForCard(
        restoredLesson.cards.single.id,
      );
      final restoredDailyReview = await dailyReviews.load(
        DateTime(2026, 9, 14),
      );

      expect(restoredLesson.guide!.toJson(), savedLessonGuide.toJson());
      expect(restoredProfile?.name, 'Backup Mei');
      expect(restoredProfile?.hskLevel, 4);
      expect(restoredSettings.showPinyin, isFalse);
      expect(restoredSettings.reminderHour, 8);
      expect(restoredSettings.kokoroVoiceIds, ['zf_021']);
      expect(restoredSettings.appThemeId, 'ocean');
      expect(
        restoredSettings.buttonAnimationStyle,
        ButtonAnimationStyle.iconMotion,
      );
      expect(restoredLesson.cards.single.chinese, '护照');
      expect(restoredHistory.single.rating, ReviewRating.good);
      expect(restoredHistory.single.responseTimeMs, 900);
      expect(restoredProgress?.repetitions, 1);
      expect(restoredDailyReview?.queuedCardIds, [
        restoredLesson.cards.single.id,
      ]);
      expect(
        (await aiConfiguration.load())?.apiKey,
        'sk-secret-that-must-not-be-exported',
      );
    },
  );

  test('invalid linked records roll back the entire restore', () async {
    await learners.save(
      const LearnerProfile(name: 'Original', hskLevel: 2, dailyWordTarget: 10),
    );
    final document =
        jsonDecode(utf8.decode(await backups.exportBackup()))
            as Map<String, dynamic>;
    final data = document['data'] as Map<String, dynamic>;
    final cards = data['cards'] as List<dynamic>;
    (cards.first as Map<String, dynamic>)['lesson_id'] = 999999;
    final invalidBytes = Uint8List.fromList(utf8.encode(jsonEncode(document)));

    await learners.save(
      const LearnerProfile(name: 'Keep me', hskLevel: 3, dailyWordTarget: 15),
    );

    await expectLater(backups.restoreBackup(invalidBytes), throwsA(anything));
    expect((await learners.load())?.name, 'Keep me');
    expect(await lessons.topics(), isNotEmpty);
  });

  test('restores an older backup without an animation preference', () async {
    await learners.save(
      const LearnerProfile(name: 'Older Mei', hskLevel: 2, dailyWordTarget: 10),
    );
    await settings.save(
      const LearnerSettings(buttonAnimationStyle: ButtonAnimationStyle.bounce),
    );
    final document =
        jsonDecode(utf8.decode(await backups.exportBackup()))
            as Map<String, dynamic>;
    document['databaseSchemaVersion'] = 12;
    for (final row in document['data']['lessons'] as List) {
      (row as Map).remove('guide_json');
    }
    final data = document['data'] as Map<String, dynamic>;
    final settingsRows = data['learner_settings'] as List<dynamic>;
    (settingsRows.single as Map<String, dynamic>).remove(
      'button_animation_style',
    );

    await backups.restoreBackup(
      Uint8List.fromList(utf8.encode(jsonEncode(document))),
    );

    expect(
      (await settings.load()).buttonAnimationStyle,
      ButtonAnimationStyle.combined,
    );
  });

  test(
    'rejects malformed lesson guides before restoring learner data',
    () async {
      await learners.save(
        const LearnerProfile(name: 'Keep me', hskLevel: 1, dailyWordTarget: 10),
      );
      final document =
          jsonDecode(utf8.decode(await backups.exportBackup()))
              as Map<String, dynamic>;
      document['data']['lessons'][0]['guide_json'] = '{"objective":3}';
      await expectLater(
        backups.restoreBackup(
          Uint8List.fromList(utf8.encode(jsonEncode(document))),
        ),
        throwsA(isA<BackupFormatException>()),
      );
      expect((await learners.load())!.name, 'Keep me');
    },
  );

  test('rejects unrelated and unsupported files before import', () {
    expect(
      () => backups.previewBackup(Uint8List.fromList(utf8.encode('{}'))),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => backups.previewBackup(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({'format': 'tingshuo-backup', 'formatVersion': 99}),
          ),
        ),
      ),
      throwsA(isA<BackupFormatException>()),
    );
  });
}
