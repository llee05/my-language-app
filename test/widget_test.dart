import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, SystemChannels, AssetBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/ai/gemini_service.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/models/tutor_learner_snapshot.dart';
import 'package:mylanguageapp/repositories/development_repository.dart';
import 'package:mylanguageapp/repositories/daily_review_session_repository.dart';
import 'package:mylanguageapp/repositories/app_dependencies.dart';
import 'package:mylanguageapp/repositories/bundled_vocabulary_repository.dart';
import 'package:mylanguageapp/repositories/learner_repository.dart';
import 'package:mylanguageapp/repositories/lesson_repository.dart';
import 'package:mylanguageapp/repositories/progress_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:mylanguageapp/repositories/tutor_context_repository.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';

import 'ai_test_support.dart';
import 'tutor_personality_test_support.dart';
import 'lesson_guide_test_support.dart';

const testProfile = LearnerProfile(
  name: 'Mei',
  hskLevel: 2,
  dailyWordTarget: 10,
);

Future<void> _waitForWidget(
  WidgetTester tester,
  Finder finder, {
  int maxAttempts = 100,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
}

Future<void> _pumpResetSettings(
  WidgetTester tester,
  _MemoryDevelopmentRepository developmentRepository, {
  Future<void> Function()? onResetOnboarding,
  Future<void> Function(LearnerProfile)? onProfileChanged,
  SettingsRepository? settingsRepository,
  Size surfaceSize = const Size(1000, 900),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SettingsPage(
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: onProfileChanged ?? (_) async {},
          onResetOnboarding: onResetOnboarding ?? () async {},
          onResetAllData: developmentRepository.resetAllData,
          developmentRepository: developmentRepository,
          settingsRepository: settingsRepository ?? _MemorySettingsRepository(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _revealSettingsControl(WidgetTester tester, Key buttonKey) async {
  final button = find.byKey(buttonKey);
  await tester.scrollUntilVisible(
    button,
    400,
    scrollable: find
        .descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await Scrollable.ensureVisible(tester.element(button), alignment: .5);
  await tester.pumpAndSettle();
}

Future<void> _openSettingsResetDialog(
  WidgetTester tester,
  Key buttonKey,
) async {
  await _revealSettingsControl(tester, buttonKey);
  final button = find.byKey(buttonKey);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _pumpRecordedVoiceSettings(
  WidgetTester tester,
  _RecordedFakePronunciationService pronunciation, {
  Size surfaceSize = const Size(1000, 1000),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(pronunciation.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SettingsPage(
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          developmentRepository: _MemoryDevelopmentRepository(),
          settingsRepository: _MemorySettingsRepository(),
          pronunciationService: pronunciation,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _revealSettingsControl(tester, const Key('desktop-voice-check'));
}

Future<void> _confirmAccountReset(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('account-reset-confirmation-input')),
    'RESET',
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('account-reset-confirm')));
}

void main() {
  for (final palette in AppThemes.all) {
    testWidgets('primary buttons have readable contrast in ${palette.label}', (
      tester,
    ) async {
      await tester.pumpWidget(
        HanziPathApp(
          initialProfile: testProfile,
          dependencies: AppDependencies(
            vocabulary: const _TestVocabulary(),
            lessons: _MemoryLessonRepository(),
            progress: _MemoryProgressRepository(),
            dailyReviews: _MemoryDailyReviewSessionRepository(null),
            settings: _MemorySettingsRepository(
              LearnerSettings(appThemeId: palette.id.name),
            ),
            createPronunciationService: () => _FakePronunciationService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scheme = Theme.of(
        tester.element(find.byType(DashboardPage)),
      ).colorScheme;
      final luminances = [
        scheme.primary.computeLuminance(),
        scheme.onPrimary.computeLuminance(),
      ]..sort();
      expect(
        (luminances.last + .05) / (luminances.first + .05),
        greaterThanOrEqualTo(4.5),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      AppColors.apply(AppThemes.classic);
    });
  }

  for (final width in [400.0, 1000.0]) {
    testWidgets(
      'Android Back unwinds dialogs, menu, lesson, section, then exits at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final platformCalls = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            platformCalls.add(call.method);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final pronunciation = _FakePronunciationService();
        final progress = _MemoryProgressRepository();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: DashboardPage(
              vocabularyRepository: const _TestVocabulary(),
              personalityRepository: MemoryTutorPersonalityRepository(),
              appThemeId: AppThemeId.classic,
              onThemeChanged: (_) {},
              profile: testProfile,
              onProfileChanged: (_) async {},
              onResetOnboarding: () async {},
              onResetAllData: () async {},
              lessonRepository: _MemoryLessonRepository(),
              progressRepository: progress,
              settingsRepository: _MemorySettingsRepository(),
              developmentRepository: _MemoryDevelopmentRepository(),
              pronunciationService: pronunciation,
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> openLessons() async {
          if (width < 760) {
            await tester.tap(find.byIcon(Icons.menu_rounded));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('Flashcards').first);
          await tester.pumpAndSettle();
        }

        await openLessons();
        await tester.ensureVisible(find.text('Resume'));
        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Back to flashcards'), findsOneWidget);
        if (width < 760) {
          await tester.tap(find.byIcon(Icons.menu_rounded));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(Drawer), findsNothing);
          expect(find.byTooltip('Back to flashcards'), findsOneWidget);
        }
        unawaited(
          showDialog<void>(
            context: tester.element(find.byType(LessonsPage)),
            builder: (_) => const AlertDialog(title: Text('Test dialog')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Test dialog'), findsNothing);
        expect(find.byTooltip('Back to flashcards'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LessonsPage), findsOneWidget);
        expect(find.byTooltip('Back to flashcards'), findsNothing);
        expect(pronunciation.stopCalls, greaterThan(0));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LessonsPage), findsNothing);
        expect(platformCalls, isNot(contains('SystemNavigator.pop')));
        // On-screen navigation must remove the same history entries.
        await openLessons();
        await tester.ensureVisible(find.text('Resume'));
        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Back to flashcards'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LessonsPage), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          platformCalls.where((call) => call == 'SystemNavigator.pop'),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('phone lesson library has no lesson creation controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonsPage(
            repository: _MemoryLessonRepository(),
            progressRepository: _MemoryProgressRepository(
              hasActiveSession: false,
            ),
            settingsRepository: _MemorySettingsRepository(),
            pronunciationService: _FakePronunciationService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 vocabulary deck'), findsOneWidget);
    expect(find.text('Create a lesson'), findsNothing);
    expect(find.text('Create lesson'), findsNothing);
    expect(find.text('New lesson'), findsNothing);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(find.byKey(const Key('lesson-topic-push-to-talk')), findsNothing);
    expect(find.text('Saved lesson'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(640, 360)]) {
    testWidgets('lesson answers and ratings scroll at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final progress = _MemoryProgressRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonsPage(
              repository: _MemoryLessonRepository(),
              progressRepository: progress,
              settingsRepository: _MemorySettingsRepository(),
              pronunciationService: _FakePronunciationService(),
              resumeLatest: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('学'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final rating = find.widgetWithText(
        OutlinedButton,
        'Click if you are already familiar with this word',
      );
      await tester.ensureVisible(rating);
      await tester.tap(rating);
      await tester.pumpAndSettle();
      expect(progress.recordReviewCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('dashboard refreshes statistics at midnight and on resume', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 27, 23, 59, 58);
    final progress = _CountingStatsProgress();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          vocabularyRepository: const _TestVocabulary(),
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: _MemoryLessonRepository(),
          progressRepository: progress,
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(progress.statisticsDates, [now]);
    now = DateTime(2026, 9, 28, 0, 0, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(progress.statisticsDates.last, now);
    expect(progress.statisticsDates, hasLength(2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 9, 28, 9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(progress.statisticsDates.last, now);
    expect(progress.statisticsDates, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(days: 1));
    expect(progress.statisticsDates, hasLength(3));
  });

  for (final (size, textScale) in [
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 1.5),
    (const Size(320, 640), 2.0),
    (const Size(1280, 900), 1.0),
    (const Size(640, 360), 1.0),
  ]) {
    testWidgets(
      'main screens remain usable at ${size.width.toInt()}px with $textScale text',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        rootBundle.evict('assets/data/hsk_vocabulary.json');
        addTearDown(() => rootBundle.evict('assets/data/hsk_vocabulary.json'));
        final pronunciation = _FakePronunciationService();
        addTearDown(pronunciation.dispose);
        await tester.pumpWidget(
          HanziPathApp(
            initialProfile: testProfile,
            dependencies: AppDependencies(
              vocabulary: const _TestVocabulary(),
              lessons: _MemoryLessonRepository(),
              progress: _MemoryProgressRepository(),
              dailyReviews: _MemoryDailyReviewSessionRepository(null),
              settings: _MemorySettingsRepository(),
              development: _MemoryDevelopmentRepository(),
              tutorContext: _EmptyTutorContextRepository(),
              tutorPersonalities: MemoryTutorPersonalityRepository(),
              createPronunciationService: () => pronunciation,
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final label in [
          ...AppSidebar.items.map((item) => item.$2),
          'Settings',
        ]) {
          if (size.width < 760) {
            await tester.tap(find.byIcon(Icons.menu_rounded));
            await tester.pumpAndSettle();
          }
          final navigation = find.descendant(
            of: find.byType(AppSidebar),
            matching: find.text(label),
          );
          if (label == 'Settings') {
            await tester.ensureVisible(navigation);
          } else {
            await tester.scrollUntilVisible(
              navigation,
              100,
              scrollable: find
                  .descendant(
                    of: find.byType(AppSidebar),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
          }
          await tester.pumpAndSettle();
          await tester.tap(navigation);
          if (label == 'Dictionary') {
            await _waitForWidget(
              tester,
              find.byKey(const Key('vocabulary-result-count')),
            );
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
          final pageType = switch (label) {
            'Flashcards' => LessonsPage,
            'Roleplay Missions' => AiRoleplayMissionsPage,
            'Listening Practice' => ListeningPracticePage,
            'Vocab Rush' => VocabRushPage,
            'Dictionary' => VocabularyPage,
            'Doom Scrolling' => DoomScrollingPage,
            'AI Tutor' => AiTutorPage,
            'Exam Mode' => ExamModePage,
            'Settings' => SettingsPage,
            _ => MainDashboard,
          };
          expect(find.byType(pageType), findsOneWidget, reason: label);
          if (label == 'Exam Mode') {
            expect(find.byKey(const Key('exam-start')), findsOneWidget);
          }
        }
        await tester.tap(find.byKey(const Key('open-profile-button')));
        await tester.pumpAndSettle();
        expect(find.byType(ProfilePage), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Profile');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('dashboard renders core learning content', (tester) async {
    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          lessons: _MemoryLessonRepository(),
          settings: _MemorySettingsRepository(),
          progress: _MemoryProgressRepository(),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('你好，Mei'), findsOneWidget);
    expect(find.text('WEEKLY XP'), findsOneWidget);
    expect(find.text('AVAILABLE HSK FLASHCARDS'), findsOneWidget);
  });

  testWidgets('dashboard user icon opens progress analytics', (tester) async {
    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          lessons: _MemoryLessonRepository(),
          settings: _MemorySettingsRepository(),
          progress: _MemoryProgressRepository(hasActiveSession: false),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-profile-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('PROGRESS OVERVIEW'), findsOneWidget);
    expect(find.text('Your progress story starts here'), findsOneWidget);
  });

  testWidgets('app restores the selected pronunciation engine and voice', (
    tester,
  ) async {
    final pronunciation = _ManagedFakePronunciationService();
    await tester.pumpWidget(
      HanziPathApp(
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          learners: _MemoryLearnerRepository(testProfile),
          lessons: _MemoryLessonRepository(),
          settings: _MemorySettingsRepository(
            const LearnerSettings(
              pronunciationEngine: PronunciationEngine.kokoro,
              kokoroVoiceIds: ['zm_041'],
            ),
          ),
          progress: _MemoryProgressRepository(),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
          createPronunciationService: () => pronunciation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(pronunciation.configuredEngine, PronunciationEngine.kokoro);
    expect(pronunciation.configuredVoiceIds, ['zm_041']);
  });

  testWidgets('dashboard statistics come from saved learning data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 8, 13, 12);
    final progress = _MemoryProgressRepository(
      reviews: [
        ReviewRecord(
          id: 1,
          cardId: 11,
          reviewedAt: DateTime(2026, 8, 13, 9),
          rating: ReviewRating.good,
          wasCorrect: true,
        ),
        ReviewRecord(
          id: 2,
          cardId: 11,
          reviewedAt: DateTime(2026, 8, 12, 9),
          rating: ReviewRating.again,
          wasCorrect: false,
        ),
      ],
      vocabulary: [
        VocabularyCardProgress(
          chinese: '学',
          pinyin: 'xué',
          progress: CardProgress(
            cardId: 11,
            dueAt: DateTime(2026, 8, 14),
            timesSeen: 2,
            mastery: .75,
          ),
        ),
        VocabularyCardProgress(
          chinese: '会',
          pinyin: 'huì',
          progress: CardProgress(
            cardId: 12,
            dueAt: DateTime(2026, 8, 15),
            timesSeen: 4,
            mastery: 1,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          vocabularyRepository: const _TestVocabulary(),
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: _MemoryLessonRepository(),
          progressRepository: progress,
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('15 XP'), findsNWidgets(2));
    expect(find.text('2-day streak'), findsOneWidget);
    expect(find.text('学'), findsWidgets);
    expect(find.text('会'), findsOneWidget);
    expect(find.text('猫'), findsNothing);
    expect(find.text('75%'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('words-seen-total'))).data,
      '2',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('words-learning-total'))).data,
      '1',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('words-learned-total'))).data,
      '1',
    );
  });

  for (final (size, scale) in [
    (const Size(1280, 900), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'new learner dashboard offers a useful first step at $size with $scale text',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: DashboardPage(
              vocabularyRepository: const _TestVocabulary(),
              appThemeId: AppThemeId.classic,
              onThemeChanged: (_) {},
              profile: testProfile,
              onProfileChanged: (_) async {},
              onResetOnboarding: () async {},
              onResetAllData: () async {},
              lessonRepository: _MemoryLessonRepository(),
              progressRepository: _MemoryProgressRepository(
                hasActiveSession: false,
                queue: const [
                  DailyQueueCard(
                    card: Flashcard(
                      id: 21,
                      chinese: '你好',
                      pinyin: 'nǐ hǎo',
                      englishMeaning: 'hello',
                    ),
                    reason: DailyQueueReason.newWord,
                  ),
                ],
              ),
              settingsRepository: _MemorySettingsRepository(),
              developmentRepository: _MemoryDevelopmentRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Start your first deck'), findsOneWidget);
        expect(find.text('Browse flashcards'), findsOneWidget);
        expect(find.text('Start scrolling'), findsOneWidget);
        expect(find.text('4991 unlearned words to discover'), findsOneWidget);
        expect(find.text('Resume'), findsNothing);

        await tester.ensureVisible(find.text('Browse flashcards'));
        await tester.tap(find.text('Browse flashcards'));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(LessonsPage),
            matching: find.text('Flashcards'),
          ),
          findsOneWidget,
        );
        expect(find.text('Saved lesson'), findsOneWidget);
      },
    );
  }

  testWidgets('continue card invokes resume when tapped', (tester) async {
    var resumed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContinueCard(
            lessonTitle: 'Family & Relationships',
            theme: 'Family & Relationships',
            level: 1,
            duration: '20 cards',
            xpReward: 60,
            onResume: () => resumed = true,
          ),
        ),
      ),
    );

    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();

    expect(resumed, isTrue);
  });

  testWidgets('dashboard review all action opens the review flow', (
    tester,
  ) async {
    var reviewAllPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabularyPanel(
            words: const [],
            wordsSeen: 0,
            wordsLearning: 0,
            wordsLearned: 0,
            onReviewAll: () => reviewAllPressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Discover words'));
    await tester.pump();

    expect(reviewAllPressed, isTrue);
  });

  testWidgets('dashboard resumes the latest unfinished lesson', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lessons = _MemoryLessonRepository();
    final progress = _MemoryProgressRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          vocabularyRepository: const _TestVocabulary(),
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: lessons,
          progressRepository: progress,
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Saved lesson'), findsNWidgets(2));
    expect(find.text('Saved · 2 cards · Up to 20 XP'), findsOneWidget);
    expect(find.text('50% complete'), findsOneWidget);
    expect(find.text('Lesson 1'), findsNothing);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('AVAILABLE HSK FLASHCARDS'), findsOneWidget);
    expect(find.text('Saved · HSK 1 · 2 cards'), findsOneWidget);
    expect(find.text('Up to 20 XP'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Saved lesson'), findsOneWidget);
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller?.page, 1);
    expect(find.text('1 of 2 words completed'), findsOneWidget);
  });

  testWidgets(
    'dashboard opens discovery and preserves legacy review sessions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final sessions = _MemoryDailyReviewSessionRepository(
        DailyReviewSession(
          id: 9,
          date: DateTime.now(),
          queuedCardIds: const [1, 2],
          currentPosition: 1,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardPage(
            vocabularyRepository: const _TestVocabulary(),
            appThemeId: AppThemeId.classic,
            onThemeChanged: (_) {},
            profile: testProfile,
            onProfileChanged: (_) async {},
            onResetOnboarding: () async {},
            onResetAllData: () async {},
            lessonRepository: _MemoryLessonRepository(),
            progressRepository: _MemoryProgressRepository(),
            dailyReviewSessionRepository: sessions,
            settingsRepository: _MemorySettingsRepository(),
            developmentRepository: _MemoryDevelopmentRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4991 unlearned words to discover'), findsOneWidget);
      expect(find.text('Start scrolling'), findsOneWidget);
      expect(find.text('Daily Review'), findsNothing);
      await tester.tap(find.text('Start scrolling'));
      await tester.pumpAndSettle();
      expect(find.byType(DoomScrollingPage), findsOneWidget);
      expect(sessions.session?.currentPosition, 1);
    },
  );

  testWidgets('dashboard explains discovery loading and an empty dictionary', (
    tester,
  ) async {
    final result = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          vocabularyRepository: _DeferredVocabulary(result),
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: _MemoryLessonRepository(),
          progressRepository: _MemoryProgressRepository(),
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Finding words to discover'), findsOneWidget);
    result.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('You’ve learned every bundled word!'), findsOneWidget);
    expect(find.text('Start scrolling'), findsNothing);
  });

  testWidgets(
    'app sidebar invokes onSelected callback when an item is tapped',
    (tester) async {
      var selected = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSidebar(
              selectedIndex: 1,
              onSelected: (index) => selected = index,
            ),
          ),
        ),
      );

      expect(find.text('Vocab Rush'), findsOneWidget);
      await tester.tap(find.text('Vocab Rush'));
      await tester.pumpAndSettle();

      expect(selected, 4);

      await tester.scrollUntilVisible(
        find.text('Roleplay Missions'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Roleplay Missions'));
      await tester.pumpAndSettle();

      expect(selected, 2);
    },
  );

  testWidgets('dashboard opens roleplay missions from the sidebar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          lessons: _MemoryLessonRepository(),
          settings: _MemorySettingsRepository(),
          progress: _MemoryProgressRepository(),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
          tutorContext: _EmptyTutorContextRepository(),
          createPronunciationService: () => pronunciation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Roleplay Missions'));
    await tester.pumpAndSettle();

    expect(find.byType(AiRoleplayMissionsPage), findsOneWidget);
    expect(find.text('AI roleplay missions'), findsOneWidget);
    expect(find.byType(AiTutorPage), findsNothing);
  });

  testWidgets('dashboard opens listening practice from the sidebar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          lessons: _MemoryLessonRepository(),
          settings: _MemorySettingsRepository(),
          progress: _MemoryProgressRepository(),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
          createPronunciationService: () => pronunciation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listening Practice'));
    await tester.pumpAndSettle();

    expect(find.byType(ListeningPracticePage), findsOneWidget);
    expect(find.text('Listening practice'), findsOneWidget);
    expect(pronunciation.spoken, isEmpty);

    await tester.tap(find.byKey(const Key('listening-start-7')));
    await tester.pumpAndSettle();

    expect(find.text('Listen and choose the meaning'), findsOneWidget);
    expect(pronunciation.spoken, ['你']);
    expect(find.text('你'), findsNothing);
    expect(find.text('nǐ'), findsNothing);
  });

  testWidgets('vocab rush starts a timed vocabulary game', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          progress: _MemoryProgressRepository(),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Vocab Rush'));
    await tester.pumpAndSettle();
    expect(find.text('词汇冲刺'), findsOneWidget);
    expect(find.text('开始游戏 — Start Game'), findsOneWidget);

    await tester.tap(find.text('开始游戏 — Start Game'));
    final gamePrompt = find.text('PICK THE CORRECT MEANING');
    await _waitForWidget(tester, gamePrompt);
    expect(gamePrompt, findsOneWidget);
    expect(find.text('180s'), findsOneWidget);
  });

  testWidgets('Doom Scrolling navigation opens the vertical word feed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          vocabularyRepository: const _TestVocabulary(),
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: _MemoryLessonRepository(),
          progressRepository: _MemoryProgressRepository(),
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doom Scrolling'));
    await tester.pumpAndSettle();
    expect(find.byType(DoomScrollingPage), findsOneWidget);
    expect(
      tester
          .widget<PageView>(find.byKey(const Key('doom-scrolling-feed')))
          .scrollDirection,
      Axis.vertical,
    );
  });

  testWidgets('daily queue explains loading and empty states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final result = Completer<List<DailyQueueCard>>();
    final progress = _DeferredDailyQueueRepository(result);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: DailyQueuePage(
            profile: testProfile,
            progressRepository: progress,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();
    expect(find.byKey(const Key('daily-review-loading-state')), findsOneWidget);
    expect(find.text('Preparing today’s queue'), findsOneWidget);
    expect(
      find.textContaining('Prioritising cards that are due'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start review'),
          )
          .onPressed,
      isNull,
    );

    result.complete(const []);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('daily-review-empty-state')),
    );
    await tester.pump();

    expect(find.byKey(const Key('daily-review-empty-state')), findsOneWidget);
    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily queue load error is friendly and retryable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const queue = [
      DailyQueueCard(
        card: Flashcard(
          id: 31,
          chinese: '再',
          pinyin: 'zài',
          englishMeaning: 'again',
        ),
        reason: DailyQueueReason.due,
      ),
    ];
    final progress = _FailOnceDailyQueueRepository(queue: queue);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: DailyQueuePage(
            profile: testProfile,
            progressRepository: progress,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();
    expect(find.byKey(const Key('daily-review-error-state')), findsOneWidget);
    expect(find.text('We couldn’t load today’s review'), findsOneWidget);
    expect(find.textContaining('sensitive database path'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start review'),
          )
          .onPressed,
      isNull,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pump();
    await tester.tap(find.byKey(const Key('daily-review-retry')));
    await tester.pumpAndSettle();

    expect(progress.dailyQueueCalls, 2);
    expect(find.byKey(const Key('daily-review-error-state')), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start review'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('daily queue remains available when preferences fail to load', (
    tester,
  ) async {
    final progress = _MemoryProgressRepository(
      queue: const [
        DailyQueueCard(
          card: Flashcard(
            id: 32,
            chinese: '学',
            pinyin: 'xué',
            englishMeaning: 'study',
          ),
          reason: DailyQueueReason.newWord,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DailyQueuePage(
          profile: testProfile,
          progressRepository: progress,
          settingsRepository: _FailingSettingsRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-review-error-state')), findsNothing);
    expect(find.text('学'), findsOneWidget);
    expect(find.text('Start review'), findsOneWidget);
  });

  testWidgets('daily queue does not wait for stalled preferences', (
    tester,
  ) async {
    final progress = _MemoryProgressRepository(
      queue: const [
        DailyQueueCard(
          card: Flashcard(
            id: 35,
            chinese: '写',
            pinyin: 'xiě',
            englishMeaning: 'write',
          ),
          reason: DailyQueueReason.newWord,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DailyQueuePage(
          profile: testProfile,
          progressRepository: progress,
          settingsRepository: _StalledSettingsRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-review-loading-state')), findsNothing);
    expect(find.text('写'), findsOneWidget);
    expect(find.text('Start review'), findsOneWidget);
  });

  testWidgets('daily queue keeps the last pinyin preference on reload error', (
    tester,
  ) async {
    final settings = _FailAfterFirstSettingsRepository();
    final progress = _MemoryProgressRepository(
      queue: const [
        DailyQueueCard(
          card: Flashcard(
            id: 34,
            chinese: '读',
            pinyin: 'dú',
            englishMeaning: 'read',
          ),
          reason: DailyQueueReason.newWord,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DailyQueuePage(
          profile: testProfile,
          progressRepository: progress,
          settingsRepository: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start review'));
    await tester.pumpAndSettle();
    expect(find.text('dú'), findsNothing);

    await tester.tap(find.byTooltip('Back to review queue'));
    await tester.pumpAndSettle();
    expect(settings.loadCalls, 2);

    await tester.tap(find.text('Start review'));
    await tester.pumpAndSettle();
    expect(find.text('dú'), findsNothing);
  });

  testWidgets('daily review speaks the current card with the shared service', (
    tester,
  ) async {
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);
    final progress = _MemoryProgressRepository(
      queue: const [
        DailyQueueCard(
          card: Flashcard(
            id: 36,
            chinese: '听',
            pinyin: 'tīng',
            englishMeaning: 'listen',
          ),
          reason: DailyQueueReason.newWord,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DailyQueuePage(
          profile: testProfile,
          progressRepository: progress,
          settingsRepository: _MemorySettingsRepository(),
          pronunciationService: pronunciation,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start review'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hear Mandarin pronunciation'));
    await tester.pump();

    expect(pronunciation.spoken, ['听']);

    await tester.tap(find.byTooltip('Back to review queue'));
    await tester.pumpAndSettle();
    expect(pronunciation.stopCalls, greaterThan(0));
    expect(pronunciation.disposeCalls, 0);
  });

  testWidgets('daily review disables audio when sound is turned off', (
    tester,
  ) async {
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);
    final progress = _MemoryProgressRepository(
      queue: const [
        DailyQueueCard(
          card: Flashcard(
            id: 37,
            chinese: '说',
            pinyin: 'shuō',
            englishMeaning: 'speak',
          ),
          reason: DailyQueueReason.newWord,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DailyQueuePage(
          profile: testProfile,
          progressRepository: progress,
          settingsRepository: _MemorySettingsRepository(
            const LearnerSettings(soundEnabled: false),
          ),
          pronunciationService: pronunciation,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start review'));
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Pronunciation audio is disabled in Settings'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PronunciationButton>(
            find.byKey(const Key('daily-review-pronunciation')),
          )
          .onPressed,
      isNull,
    );
    expect(pronunciation.spoken, isEmpty);
  });

  testWidgets('dashboard discovery error can be retried', (tester) async {
    final vocabulary = _FailOnceVocabulary();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          vocabularyRepository: vocabulary,
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: _MemoryLessonRepository(),
          progressRepository: _MemoryProgressRepository(),
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The word feed could not be loaded'), findsOneWidget);
    expect(find.textContaining('sensitive database path'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('discovery-prompt-retry')));
    await tester.tap(find.byKey(const Key('discovery-prompt-retry')));
    await tester.pumpAndSettle();
    expect(vocabulary.calls, 2);
    expect(find.text('4991 unlearned words to discover'), findsOneWidget);
    expect(find.text('Start scrolling'), findsOneWidget);
  });

  testWidgets('daily queue reloads at local midnight', (tester) async {
    var systemTime = DateTime(2026, 8, 6, 23, 59, 59);
    final progress = _MemoryProgressRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyQueuePage(
            profile: testProfile,
            progressRepository: progress,
            clock: () => systemTime,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(progress.dailyQueueCalls, 1);

    systemTime = DateTime(2026, 8, 7);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(progress.dailyQueueCalls, 2);
    expect(progress.requestedDays.last.day, 7);
  });

  testWidgets('daily queue ignores a stale load after midnight', (
    tester,
  ) async {
    var systemTime = DateTime(2026, 8, 6, 23, 59, 59);
    final first = Completer<List<DailyQueueCard>>();
    final second = Completer<List<DailyQueueCard>>();
    final progress = _SequencedDailyQueueRepository([first, second]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyQueuePage(
            profile: testProfile,
            progressRepository: progress,
            clock: () => systemTime,
          ),
        ),
      ),
    );
    await tester.pump();

    systemTime = DateTime(2026, 8, 7);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(progress.dailyQueueCalls, 2);

    second.complete(const [
      DailyQueueCard(
        card: Flashcard(
          id: 42,
          chinese: '今',
          pinyin: 'jīn',
          englishMeaning: 'today',
        ),
        reason: DailyQueueReason.newWord,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('今'), findsOneWidget);

    first.complete(const [
      DailyQueueCard(
        card: Flashcard(
          id: 41,
          chinese: '昨',
          pinyin: 'zuó',
          englishMeaning: 'yesterday',
        ),
        reason: DailyQueueReason.due,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('今'), findsOneWidget);
    expect(find.text('昨'), findsNothing);
  });

  testWidgets('daily queue cannot start after its loaded day changes', (
    tester,
  ) async {
    var systemTime = DateTime(2026, 8, 6, 12);
    var started = false;
    final progress = _MemoryProgressRepository(
      queue: const [
        DailyQueueCard(
          card: Flashcard(
            id: 43,
            chinese: '日',
            pinyin: 'rì',
            englishMeaning: 'day',
          ),
          reason: DailyQueueReason.newWord,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DailyQueuePage(
          profile: testProfile,
          progressRepository: progress,
          clock: () => systemTime,
          onStartReview: (_) => started = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start review'),
          )
          .onPressed,
      isNotNull,
    );

    systemTime = DateTime(2026, 8, 7, 12);
    await tester.tap(find.text('Start review'));
    await tester.pumpAndSettle();

    expect(started, isFalse);
    expect(find.text('Today’s review queue'), findsOneWidget);
    expect(find.text('Daily review'), findsNothing);
  });

  testWidgets('review action starts or resumes the persisted session', (
    tester,
  ) async {
    const queue = [
      DailyQueueCard(
        card: Flashcard(
          id: 1,
          chinese: '一',
          pinyin: 'yī',
          englishMeaning: 'one',
        ),
        reason: DailyQueueReason.newWord,
      ),
      DailyQueueCard(
        card: Flashcard(
          id: 2,
          chinese: '二',
          pinyin: 'èr',
          englishMeaning: 'two',
        ),
        reason: DailyQueueReason.newWord,
      ),
    ];
    final sessions = _MemoryDailyReviewSessionRepository(
      DailyReviewSession(
        id: 8,
        date: DateTime(2026, 8, 6),
        queuedCardIds: const [1, 2],
        currentPosition: 1,
      ),
    );
    DailyReviewSession? started;
    var reviewProgressChanges = 0;
    final progress = _MemoryProgressRepository(queue: [queue[1]]);

    await tester.pumpWidget(
      MaterialApp(
        home: DailyQueuePage(
          profile: testProfile,
          progressRepository: progress,
          sessionRepository: sessions,
          today: DateTime(2026, 8, 6),
          onStartReview: (session) => started = session,
          onProgressChanged: () => reviewProgressChanges++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resume review'), findsOneWidget);
    await tester.tap(find.text('Resume review'));
    await tester.pumpAndSettle();
    expect(started?.id, 8);
    expect(find.text('1 of 1'), findsOneWidget);
    expect(find.text('二'), findsOneWidget);

    await tester.tap(find.text('Reveal meaning'));
    await tester.pump();
    await tester.ensureVisible(find.text('Confident'));
    await tester.tap(find.text('Confident'));
    await tester.pumpAndSettle();

    expect(progress.recordedReview?.cardId, 2);
    expect(progress.recordedReview?.rating, ReviewRating.good);
    expect(progress.recordedReview?.submissionKey, 'daily:8:position:1:card:2');
    expect(progress.savedProgress?.reviewInterval, 1);
    expect(progress.savedProgress?.mastery, 0);
    expect(sessions.session?.currentPosition, 2);
    expect(sessions.session?.isComplete, isTrue);
    expect(reviewProgressChanges, 1);

    expect(find.text('Confident selected'), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('Daily review complete!'), findsOneWidget);
    expect(find.text('Cards reviewed'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Learned words'), findsOneWidget);
    expect(find.text('Review words'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
  });

  testWidgets('daily review card reveals meaning and navigates locally', (
    tester,
  ) async {
    const queue = [
      DailyQueueCard(
        card: Flashcard(
          id: 1,
          chinese: '一',
          pinyin: 'yī',
          englishMeaning: 'one',
        ),
        reason: DailyQueueReason.newWord,
      ),
      DailyQueueCard(
        card: Flashcard(
          id: 2,
          chinese: '二',
          pinyin: 'èr',
          englishMeaning: 'two',
        ),
        reason: DailyQueueReason.weak,
      ),
    ];
    await tester.pumpWidget(
      const MaterialApp(
        home: DailyReviewCardScreen(queue: queue, showPinyin: false),
      ),
    );

    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('一'), findsOneWidget);
    expect(find.text('yī'), findsNothing);
    expect(find.text('one'), findsNothing);
    await tester.tap(find.text('Reveal meaning'));
    await tester.pump();
    expect(find.text('one'), findsOneWidget);
    expect(find.text('No idea'), findsOneWidget);
    expect(find.text('Unsure'), findsOneWidget);
    expect(find.text('Confident'), findsOneWidget);
    expect(find.text('Instant'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'))
          .onPressed,
      isNull,
    );

    await tester.ensureVisible(find.text('Confident'));
    await tester.tap(find.text('Confident'));
    await tester.pumpAndSettle();
    expect(find.text('Confident selected'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('review-answer-good')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('二'), findsOneWidget);
    expect(find.text('two'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Finish'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Previous'));
    await tester.pump();
    expect(find.text('一'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Reveal meaning'));
    await tester.pump();
    await tester.ensureVisible(find.text('No idea'));
    await tester.tap(find.text('No idea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(find.text('Daily review complete!'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('+15 XP'), findsOneWidget);
  });

  testWidgets('daily review keeps a pending answer on its submitted card', (
    tester,
  ) async {
    final save = Completer<void>();
    var closes = 0;
    final submittedPositions = <int>[];
    const queue = [
      DailyQueueCard(
        card: Flashcard(
          id: 1,
          chinese: '一',
          pinyin: 'yī',
          englishMeaning: 'one',
        ),
        reason: DailyQueueReason.newWord,
      ),
      DailyQueueCard(
        card: Flashcard(
          id: 2,
          chinese: '二',
          pinyin: 'èr',
          englishMeaning: 'two',
        ),
        reason: DailyQueueReason.newWord,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: DailyReviewCardScreen(
          queue: queue,
          onClose: () => closes++,
          initialPosition: 1,
          onAnswer: (position, _, _) async {
            submittedPositions.add(position);
            if (position == 1) await save.future;
          },
        ),
      ),
    );

    await tester.tap(find.text('Reveal meaning'));
    await tester.pump();
    await tester.tap(find.text('Confident'));
    await tester.pump();

    expect(submittedPositions, [1]);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Previous'),
          )
          .onPressed,
      isNull,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(closes, 0);
    save.complete();
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Confident selected'), findsOneWidget);

    await tester.tap(find.text('Previous'));
    await tester.pump();
    await tester.tap(find.text('Reveal meaning'));
    await tester.pump();
    await tester.tap(find.text('No idea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Reveal meaning'));
    await tester.pump();
    expect(find.text('Confident selected'), findsOneWidget);
    expect(submittedPositions, [1, 0]);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(closes, 1);
  });

  testWidgets('daily review retries the exact failed answer', (tester) async {
    var calls = 0;
    final ratings = <ReviewRating>[];
    const queue = [
      DailyQueueCard(
        card: Flashcard(
          id: 41,
          chinese: '四',
          pinyin: 'sì',
          englishMeaning: 'four',
        ),
        reason: DailyQueueReason.weak,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: DailyReviewCardScreen(
          queue: queue,
          onAnswer: (_, _, rating) async {
            calls++;
            ratings.add(rating);
            if (calls == 1) {
              throw StateError('sensitive database path /private/reviews.db');
            }
          },
        ),
      ),
    );

    await tester.tap(find.text('Reveal meaning'));
    await tester.pump();
    await tester.tap(find.text('Confident'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-review-answer-error')), findsOneWidget);
    expect(find.text('We couldn’t save your answer.'), findsOneWidget);
    expect(find.textContaining('sensitive database path'), findsNothing);
    expect(calls, 1);

    await tester.tap(find.byKey(const Key('daily-review-answer-retry')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(ratings, [ReviewRating.good, ReviewRating.good]);
    expect(find.byKey(const Key('daily-review-answer-error')), findsNothing);
    expect(find.text('Confident selected'), findsOneWidget);
  });

  testWidgets('daily review reloads a card enqueued during completion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final day = DateTime(2026, 8, 6);
    final reviews = _JourneyReviewRepository();
    await reviews.create(date: day, queuedCardIds: const [1]);
    reviews.cardToAppendOnNextCompletion = 2;
    var completionCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DailyQueuePage(
          profile: testProfile,
          progressRepository: reviews,
          sessionRepository: reviews,
          today: day,
          onSessionCompleted: () => completionCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start review'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reveal meaning'));
    await tester.pump();
    await tester.tap(find.text('Confident'));
    await tester.pumpAndSettle();

    expect(reviews.savedReviews, hasLength(1));
    expect(reviews.sessions['2026-08-06']?.currentPosition, 1);
    expect(reviews.sessions['2026-08-06']?.isComplete, isFalse);
    expect(completionCalls, 0);
    expect(find.text('二'), findsOneWidget);
    expect(find.text('Confident selected'), findsNothing);

    await tester.tap(find.text('Reveal meaning'));
    await tester.pump();
    await tester.tap(find.text('No idea'));
    await tester.pumpAndSettle();

    expect(reviews.savedReviews, hasLength(2));
    expect(reviews.savedReviews.map((review) => review.submissionKey), [
      'daily:1:position:0:card:1',
      'daily:1:position:1:card:2',
    ]);
    expect(reviews.sessions['2026-08-06']?.isComplete, isTrue);
    expect(completionCalls, 1);
  });

  testWidgets('start review is disabled for an empty queue', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DailyQueuePage(
          profile: testProfile,
          progressRepository: _MemoryProgressRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start review'),
    );
    expect(button.onPressed, isNull);
  });

  test('daily queue reset is the next local midnight', () {
    final reset = nextDailyQueueReset(DateTime(2026, 12, 31, 23, 30));
    expect(reset, DateTime(2027, 1, 1));
    expect(reset.isUtc, isFalse);
  });

  testWidgets('Lessons navigation opens the library without a creator', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          lessons: _MemoryLessonRepository(),
          settings: _MemorySettingsRepository(),
          progress: _MemoryProgressRepository(),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flashcards'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(LessonsPage),
        matching: find.text('Flashcards'),
      ),
      findsOneWidget,
    );
    expect(find.text('Saved lesson'), findsOneWidget);
    expect(find.text('Create a lesson'), findsNothing);
    expect(find.text('Custom lesson topic'), findsNothing);
    expect(find.text('Create lesson'), findsNothing);
    expect(find.byKey(const Key('lesson-topic-push-to-talk')), findsNothing);
  });

  for (final width in [390.0, 1000.0]) {
    testWidgets('all 251 curriculum lessons are reachable at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final document =
          jsonDecode(
                File('assets/data/vocabulary_lessons.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final topics = <LessonSummary>[
        for (final (index, lesson) in (document['lessons'] as List).indexed)
          LessonSummary(
            id: index + 100,
            title: lesson['title'] as String,
            theme: 'HSK ${lesson['hskLevel']} vocabulary',
            hskLevel: lesson['hskLevel'] as int,
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonsPage(
              repository: _LessonStateRepository(
                firstTopics: Future.value(topics),
              ),
              progressRepository: _MemoryProgressRepository(
                hasActiveSession: false,
              ),
              settingsRepository: _MemorySettingsRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('251 vocabulary decks'), findsOneWidget);
      for (final topic in topics) {
        expect(
          find.text(topic.title.replaceAll('Lesson', 'Deck')),
          findsOneWidget,
        );
      }
      await tester.ensureVisible(find.text('HSK 6'));
      await tester.tap(find.text('HSK 6'));
      await tester.pumpAndSettle();
      expect(find.text('125 of 251 vocabulary decks'), findsOneWidget);
      expect(find.text('HSK 1 · Deck 001'), findsNothing);
      expect(find.text('HSK 6 · Deck 125'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('lesson-library-search')),
        '125',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 of 251 vocabulary decks'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('lesson-library-show-all')),
      );
      await tester.tap(find.byKey(const Key('lesson-library-show-all')));
      await tester.pumpAndSettle();
      expect(find.text('251 vocabulary decks'), findsOneWidget);
      expect(find.text('HSK 1 · Deck 001'), findsOneWidget);
      expect(find.text('HSK 6 · Deck 125'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('lesson-library-search')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.ensureVisible(find.text('HSK 6 · Deck 125'));
      await tester.pumpAndSettle();
      expect(find.text('HSK 6 · Deck 125').hitTestable(), findsOneWidget);
      expect(find.text('Create a lesson'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [360.0, 1000.0]) {
    testWidgets(
      'generated lessons can be cancelled or deleted at width $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _DeletableLessonRepository();
        var changed = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LessonsPage(
                repository: repository,
                progressRepository: _MemoryProgressRepository(
                  hasActiveSession: false,
                ),
                settingsRepository: _MemorySettingsRepository(),
                pronunciationService: _FakePronunciationService(),
                onProgressChanged: () => changed++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final delete = find.byKey(const Key('delete-lesson-91'));
        expect(find.byKey(const Key('delete-lesson-7')), findsNothing);
        await tester.ensureVisible(delete);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        expect(find.text('Delete deck?'), findsOneWidget);
        expect(find.textContaining('This cannot be undone.'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(repository.deleteCalls, 0);
        expect(find.text('My generated lesson'), findsOneWidget);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm-delete-lesson')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.deleteCalls, 1);
        expect(find.text('My generated lesson'), findsOneWidget);
        expect(find.text('Deck deleted.'), findsNothing);
        expect(tester.widget<IconButton>(delete).onPressed, isNull);
        repository.deletion.complete();
        await tester.pumpAndSettle();
        expect(find.text('My generated lesson'), findsNothing);
        expect(find.text('Saved lesson'), findsOneWidget);
        expect(find.text('Deck deleted.'), findsOneWidget);
        expect(changed, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('failed lesson deletion keeps the lesson and allows a retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _DeletableLessonRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonsPage(
            repository: repository,
            progressRepository: _MemoryProgressRepository(
              hasActiveSession: false,
            ),
            settingsRepository: _MemorySettingsRepository(),
            pronunciationService: _FakePronunciationService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final delete = find.byKey(const Key('delete-lesson-91'));
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-lesson')));
    await tester.pump();
    repository.deletion.completeError(StateError('Disk is full'));
    await tester.pumpAndSettle();
    expect(find.text('My generated lesson'), findsOneWidget);
    expect(
      find.text('Could not delete the deck. Please try again.'),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(delete).onPressed, isNotNull);
    repository.deletion = Completer<void>();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-lesson')));
    await tester.pump();
    repository.deletion.complete();
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 2);
    expect(find.text('My generated lesson'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lesson library filters saved lessons by HSK level', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lessons = _MultiLevelLessonRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonsPage(
            repository: lessons,
            progressRepository: _MemoryProgressRepository(
              hasActiveSession: false,
            ),
            settingsRepository: _MemorySettingsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('lesson-library-level-filter')),
      findsOneWidget,
    );
    expect(find.text('Morning Greetings'), findsOneWidget);
    expect(find.text('Restaurant Talk'), findsOneWidget);
    expect(find.text('Market News'), findsOneWidget);

    await tester.tap(find.text('HSK 1').first);
    await tester.pumpAndSettle();
    expect(find.text('Morning Greetings'), findsOneWidget);
    expect(find.text('Restaurant Talk'), findsNothing);
    expect(find.text('Market News'), findsNothing);

    await tester.tap(find.text('HSK 2'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('lesson-library-filtered-empty-state')),
      findsOneWidget,
    );
    expect(find.textContaining('No HSK 2 decks yet'), findsOneWidget);
    expect(find.text('Morning Greetings'), findsNothing);

    await tester.tap(find.text('All levels'));
    await tester.pumpAndSettle();
    expect(find.text('Morning Greetings'), findsOneWidget);
    expect(find.text('Restaurant Talk'), findsOneWidget);
    expect(find.text('Market News'), findsOneWidget);
    expect(
      find.byKey(const Key('lesson-library-filtered-empty-state')),
      findsNothing,
    );
  });

  testWidgets('lesson library searches titles, topics, and HSK levels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonsPage(
            repository: _MultiLevelLessonRepository(),
            progressRepository: _MemoryProgressRepository(
              hasActiveSession: false,
            ),
            settingsRepository: _MemorySettingsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byKey(const Key('lesson-library-search'));
    await tester.enterText(search, 'dining');
    await tester.pump();
    expect(find.text('Restaurant Talk'), findsOneWidget);
    expect(find.text('Morning Greetings'), findsNothing);
    expect(find.text('Market News'), findsNothing);

    await tester.enterText(search, 'HSK 4');
    await tester.pump();
    expect(find.text('Market News'), findsOneWidget);
    expect(find.text('Restaurant Talk'), findsNothing);

    await tester.enterText(search, 'missing lesson');
    await tester.pump();
    expect(
      find.byKey(const Key('lesson-library-search-empty-state')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('lesson-library-search-clear')));
    await tester.pump();
    expect(find.text('Morning Greetings'), findsOneWidget);
    expect(find.text('Restaurant Talk'), findsOneWidget);
    expect(find.text('Market News'), findsOneWidget);
  });

  testWidgets('lesson library explains loading and empty states', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final topics = Completer<List<LessonSummary>>();
    final lessons = _LessonStateRepository(firstTopics: topics.future);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: LessonsPage(
              repository: lessons,
              progressRepository: _MemoryProgressRepository(
                hasActiveSession: false,
              ),
              settingsRepository: _MemorySettingsRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('lesson-library-loading-state')),
      findsOneWidget,
    );
    expect(find.text('Loading your flashcard library'), findsOneWidget);
    expect(find.textContaining('Finding your saved decks'), findsOneWidget);
    expect(tester.takeException(), isNull);

    topics.complete(const []);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lesson-library-empty-state')), findsOneWidget);
    expect(find.text('No saved decks yet'), findsOneWidget);
    expect(
      find.text('Reopen Flashcards to load the bundled vocabulary library.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('lesson library load error is friendly and retryable', (
    tester,
  ) async {
    final lessons = _LessonStateRepository(failFirstTopicsLoad: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonsPage(
            repository: lessons,
            progressRepository: _MemoryProgressRepository(
              hasActiveSession: false,
            ),
            settingsRepository: _MemorySettingsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lesson-library-error-state')), findsOneWidget);
    expect(find.text('We couldn’t load your flashcards'), findsOneWidget);
    expect(find.textContaining('sensitive database path'), findsNothing);

    await tester.tap(find.byKey(const Key('lesson-library-retry')));
    await tester.pumpAndSettle();

    expect(lessons.topicsCalls, 2);
    expect(find.byKey(const Key('lesson-library-content')), findsOneWidget);
    expect(find.text('Recovered lesson'), findsOneWidget);
    expect(find.byKey(const Key('lesson-library-error-state')), findsNothing);
  });

  testWidgets('dashboard explains lesson loading and empty states', (
    tester,
  ) async {
    final topics = Completer<List<LessonSummary>>();
    final lessons = _LessonStateRepository(firstTopics: topics.future);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          vocabularyRepository: const _TestVocabulary(),
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: lessons,
          progressRepository: _MemoryProgressRepository(
            hasActiveSession: false,
          ),
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('available-lessons-loading-state')),
      findsOneWidget,
    );
    expect(find.text('Loading available decks'), findsOneWidget);

    topics.complete(const []);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('available-lessons-empty-state')),
      findsOneWidget,
    );
    expect(find.text('No saved decks yet'), findsOneWidget);
    expect(
      find.text('Open Flashcards to load the bundled vocabulary library.'),
      findsOneWidget,
    );
  });

  testWidgets('dashboard lesson load error is retryable', (tester) async {
    final lessons = _LessonStateRepository(failFirstTopicsLoad: true);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          vocabularyRepository: const _TestVocabulary(),
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: lessons,
          progressRepository: _MemoryProgressRepository(
            hasActiveSession: false,
          ),
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('available-lessons-error-state')),
      findsOneWidget,
    );
    expect(find.textContaining('sensitive database path'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('available-lessons-retry')),
    );
    await tester.tap(find.byKey(const Key('available-lessons-retry')));
    await tester.pumpAndSettle();

    expect(lessons.topicsCalls, 2);
    expect(find.text('Recovered lesson'), findsOneWidget);
    expect(
      find.byKey(const Key('available-lessons-error-state')),
      findsNothing,
    );
  });

  testWidgets('dashboard rotates one usable lesson from every HSK level', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lessons = _RotatingLessonRepository();
    final progress = _MemoryProgressRepository(hasActiveSession: false);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          vocabularyRepository: const _TestVocabulary(),
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: lessons,
          progressRepository: progress,
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
          random: Random(7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    List<LessonTile> visibleLessons() => tester
        .widgetList<LessonTile>(find.byType(LessonTile))
        .toList(growable: false);

    final firstSelection = visibleLessons();
    expect(lessons.requestedIds, hasLength(6));
    expect(firstSelection, hasLength(6));
    expect(firstSelection.map((lesson) => lesson.unit).toSet(), {
      for (var level = 1; level <= 6; level++) 'HSK $level',
    });

    await tester.tap(find.byKey(const Key('available-lessons-refresh')));
    await tester.pumpAndSettle();

    final refreshedSelection = visibleLessons();
    expect(lessons.requestedIds, hasLength(12));
    expect(refreshedSelection, hasLength(6));
    for (var index = 0; index < refreshedSelection.length; index++) {
      expect(
        refreshedSelection[index].title,
        isNot(firstSelection[index].title),
      );
    }

    final selectedLesson = lessons.lessons.singleWhere(
      (lesson) => lesson.summary.title == refreshedSelection.first.title,
    );
    await tester.tap(find.byType(LessonTile).first);
    await tester.pumpAndSettle();

    expect(progress.startedLessonId, selectedLesson.summary.id);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text(selectedLesson.summary.title), findsOneWidget);
  });

  testWidgets('dashboard replaces missing and empty lesson suggestions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lessons = _RotatingLessonRepository(missingIds: {11}, emptyIds: {21});
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          vocabularyRepository: const _TestVocabulary(),
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: lessons,
          progressRepository: _MemoryProgressRepository(
            hasActiveSession: false,
          ),
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
          random: _ZeroRandom(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tiles = tester.widgetList<LessonTile>(find.byType(LessonTile));
    expect(tiles, hasLength(6));
    expect(tiles.map((tile) => tile.unit).toSet(), {
      for (var level = 1; level <= 6; level++) 'HSK $level',
    });
    expect(find.text('HSK 1 lesson 1'), findsNothing);
    expect(find.text('HSK 2 lesson 1'), findsNothing);
    expect(lessons.requestedIds, hasLength(8));
  });

  for (final width in [390.0, 1000.0]) {
    testWidgets(
      'saved lesson guide works at width $width and retains card position',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _GuidedLessonRepository();
        final voice = _FakePronunciationService();
        addTearDown(voice.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LessonsPage(
                repository: repository,
                pronunciationService: voice,
                initialLessonId: 7,
                progressRepository: _MemoryProgressRepository(
                  hasActiveSession: false,
                  activeSession: LessonSession(
                    id: 3,
                    lessonId: 7,
                    startedAt: DateTime.utc(2026, 9, 27),
                  ),
                ),
                settingsRepository: _MemorySettingsRepository(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(savedLessonGuide.objective), findsOneWidget);
        await tester.tap(find.byTooltip('Hear example sentence').first);
        await tester.pumpAndSettle();
        expect(voice.spoken, [savedLessonGuide.dialogue.first.chinese]);
        final exercise = find.byKey(const ValueKey('lesson-exercise-0'));
        await tester.ensureVisible(exercise);
        await tester.tap(exercise);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: exercise,
            matching: find.text(
              savedLessonGuide.exercises.first.answer.english,
            ),
          ),
          findsOneWidget,
        );
        final answerAudio = find.descendant(
          of: exercise,
          matching: find.byTooltip('Hear example sentence'),
        );
        await tester.ensureVisible(answerAudio);
        await tester.tap(answerAudio);
        await tester.pumpAndSettle();
        expect(
          voice.spoken.last,
          savedLessonGuide.exercises.first.answer.chinese,
        );
        expect(voice.spoken, hasLength(2));
        await tester.tap(find.byKey(const Key('lesson-cards-tab')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          1,
        );
        await tester.tap(find.byKey(const Key('lesson-guide-tab')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('lesson-cards-tab')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          1,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('an archived lesson resumes through its dashboard link', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonsPage(
            repository: _ArchivedLessonRepository(),
            initialLessonId: 7,
            progressRepository: _MemoryProgressRepository(),
            settingsRepository: _MemorySettingsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved lesson'), findsOneWidget);
    expect(find.text('Resumed at card 2.'), findsOneWidget);
    expect(tester.widget<PageView>(find.byType(PageView)).controller?.page, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lesson resumes its position and records a familiar word', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lessons = _MemoryLessonRepository();
    final progress = _MemoryProgressRepository();
    var lessonProgressChanges = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonsPage(
            repository: lessons,
            progressRepository: progress,
            settingsRepository: _MemorySettingsRepository(),
            onProgressChanged: () => lessonProgressChanges++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved lesson'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller?.page, 1);
    expect(find.byTooltip('Hear Mandarin pronunciation'), findsWidgets);

    await tester.tap(find.text('学'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.widgetWithText(
        OutlinedButton,
        'Click if you are already familiar with this word',
      ),
    );
    await tester.pumpAndSettle();

    expect(progress.recordedReview?.cardId, 12);
    expect(progress.recordedReview?.wasCorrect, isTrue);
    expect(progress.recordedReview?.submissionKey, 'lesson:3:card:12');
    expect(progress.savedSession?.currentCardIndex, 2);
    expect(progress.savedSession?.isComplete, isTrue);
    expect(lessonProgressChanges, 1);
    expect(find.text('Deck complete!'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('New words'), findsOneWidget);
    expect(find.text('Words revisited'), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
  });

  testWidgets('lesson audio uses the shared pronunciation service', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonsPage(
            repository: _MemoryLessonRepository(),
            progressRepository: _MemoryProgressRepository(),
            settingsRepository: _MemorySettingsRepository(),
            pronunciationService: pronunciation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(pronunciation.prepared, contains('学'));
    expect(pronunciation.spoken, isEmpty);

    final speaker = find.byTooltip('Hear Mandarin pronunciation').hitTestable();
    expect(speaker, findsOneWidget);
    await tester.tap(speaker);
    await tester.pump();

    expect(pronunciation.spoken, ['学']);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(pronunciation.stopCalls, 1);
    expect(pronunciation.disposeCalls, 0);
  });

  for (final size in [const Size(390, 844), const Size(1000, 1100)]) {
    for (final soundEnabled in [true, false]) {
      testWidgets('lesson example audio at $size with sound $soundEnabled', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final voice = _FailOncePronunciationService();
        addTearDown(voice.dispose);
        final progress = _MemoryProgressRepository();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LessonsPage(
                repository: _ExampleLessonRepository(),
                progressRepository: progress,
                settingsRepository: _MemorySettingsRepository(
                  LearnerSettings(soundEnabled: soundEnabled),
                ),
                pronunciationService: voice,
                initialLessonId: 7,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('学').hitTestable());
        await tester.pumpAndSettle();
        final button = find.byKey(const Key('lesson-example-pronunciation'));
        await tester.ensureVisible(button);
        expect(
          tester.widget<PronunciationButton>(button).onPressed,
          soundEnabled ? isNotNull : isNull,
        );
        if (soundEnabled) {
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Mandarin audio is unavailable.'),
            findsOneWidget,
          );
          expect(voice.spoken, isEmpty);
          await tester.tap(button);
          await tester.pumpAndSettle();
        }
        expect(voice.spoken, soundEnabled ? ['我学中文。'] : isEmpty);
        expect(find.text('我学中文。'), findsOneWidget);
        expect(progress.recordReviewCalls, 0);
        // Let the audio-error snackbar expire before using the bottom nav.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Previous'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('你').hitTestable());
        await tester.pumpAndSettle();
        expect(button.hitTestable(), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('lesson answer is submitted only once while saving', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final save = Completer<void>();
    final progress = _MemoryProgressRepository(recordReviewGate: save);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonsPage(
            repository: _MemoryLessonRepository(),
            progressRepository: progress,
            settingsRepository: _MemorySettingsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('学'));
    await tester.pump(const Duration(milliseconds: 400));

    final answerButton = find.widgetWithText(
      OutlinedButton,
      'Click if you are already familiar with this word',
    );
    final submit = tester.widget<OutlinedButton>(answerButton).onPressed!;
    submit();
    submit();
    await tester.pump();
    await tester.pump();

    expect(progress.recordReviewCalls, 1);
    expect(tester.widget<OutlinedButton>(answerButton).onPressed, isNull);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_back).first,
          )
          .onPressed,
      isNull,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byTooltip('Back to flashcards'), findsOneWidget);
    save.complete();
    await tester.pumpAndSettle();
    expect(progress.recordReviewCalls, 1);
    expect(find.text('Deck complete!'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back to flashcards'), findsNothing);
  });

  testWidgets('lesson retries the exact failed answer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final progress = _FailOnceRecordReviewRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonsPage(
            repository: _MemoryLessonRepository(),
            progressRepository: progress,
            settingsRepository: _MemorySettingsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('学'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.widgetWithText(
        OutlinedButton,
        'Click if you are already familiar with this word',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lesson-answer-error')), findsOneWidget);
    expect(find.text('We couldn’t save your answer.'), findsOneWidget);
    expect(find.textContaining('sensitive database path'), findsNothing);
    expect(progress.recordReviewAttempts, 1);

    await tester.tap(find.byKey(const Key('lesson-answer-retry')));
    await tester.pumpAndSettle();

    expect(progress.recordReviewAttempts, 2);
    expect(find.byKey(const Key('lesson-answer-error')), findsNothing);
    expect(find.text('Deck complete!'), findsOneWidget);
  });

  testWidgets('lesson resume repairs an answer saved before session progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reviewedAt = DateTime.utc(2026, 8, 8, 9);
    final progress = _MemoryProgressRepository(
      activeSession: LessonSession(
        id: 3,
        lessonId: 7,
        startedAt: DateTime.utc(2026, 8, 8, 8),
        currentCardIndex: 1,
      ),
      reviews: [
        ReviewRecord(
          id: 1,
          cardId: 12,
          sessionId: 3,
          submissionKey: 'lesson:3:card:12',
          reviewedAt: reviewedAt,
          rating: ReviewRating.easy,
          wasCorrect: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonsPage(
            repository: _MemoryLessonRepository(),
            progressRepository: progress,
            settingsRepository: _MemorySettingsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(progress.savedSession?.cardsReviewed, 1);
    expect(progress.savedSession?.correctAnswers, 1);
    expect(progress.savedSession?.currentCardIndex, 0);
    expect(find.text('你'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('学'));
    await tester.pump(const Duration(milliseconds: 400));
    final recordedButton = tester.widget<OutlinedButton>(
      find.widgetWithText(
        OutlinedButton,
        'Click if you are already familiar with this word',
      ),
    );
    expect(recordedButton.onPressed, isNull);
    expect(progress.recordReviewCalls, 0);
  });

  for (final width in [390.0, 1000.0]) {
    testWidgets('lesson learned counts refresh after study at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vocabulary = [
        VocabularyCardProgress(
          chinese: '你',
          pinyin: 'nǐ',
          progress: CardProgress(
            cardId: 11,
            dueAt: DateTime.utc(2026, 10, 3),
            timesSeen: 5,
            mastery: .8,
          ),
        ),
        VocabularyCardProgress(
          chinese: '学',
          pinyin: 'xué',
          progress: CardProgress(
            cardId: 12,
            dueAt: DateTime.utc(2026, 10, 3),
            timesSeen: 5,
            mastery: .79,
          ),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonsPage(
              repository: _MemoryLessonRepository(),
              progressRepository: _MemoryProgressRepository(
                hasActiveSession: false,
                vocabulary: vocabulary,
              ),
              settingsRepository: _MemorySettingsRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final count = find.byKey(const Key('lesson-learned-count-7'));
      expect(tester.widget<Text>(count).data, '1 of 2 words learned');
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .5,
      );
      await tester.ensureVisible(find.text('Start'));
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      vocabulary.clear();
      await tester.tap(find.byTooltip('Back to flashcards'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(count).data, '0 of 2 words learned');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('saved lesson can be started directly from the lesson library', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lessons = _MemoryLessonRepository();
    final progress = _MemoryProgressRepository(hasActiveSession: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonsPage(
            repository: lessons,
            progressRepository: progress,
            settingsRepository: _MemorySettingsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved lesson'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(progress.startedLessonId, 7);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Saved lesson'), findsOneWidget);
  });

  testWidgets('ai tutor tab opens the tutor chat page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTutorPage(
            personalityRepository: MemoryTutorPersonalityRepository(),
            settingsRepository: _MemorySettingsRepository(),
            tutorContextRepository: _EmptyTutorContextRepository(),
            pronunciationService: pronunciation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('龙老师 - Long Laoshi'), findsOneWidget);
    expect(find.text("TODAY'S FOCUS"), findsNothing);
    expect(find.text('GPT-4o'), findsNothing);
    expect(find.text('你好！我是龙老师。你想练习什么中文？'), findsOneWidget);
    expect(find.text('我家里有四个人。爸爸，妈妈，我，和妹妹。'), findsNothing);
    expect(find.text('Ask 龙老师 anything in English or 中文...'), findsOneWidget);
  });

  testWidgets('ai tutor retry reuses the failed prompt without exposing it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var calls = 0;
    final requests = <List<Map<String, String>>>[];
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTutorPage(
            personalityRepository: MemoryTutorPersonalityRepository(),
            settingsRepository: _MemorySettingsRepository(),
            tutorContextRepository: _EmptyTutorContextRepository(),
            pronunciationService: pronunciation,
            request: (messages) async {
              calls++;
              requests.add([for (final message in messages) Map.of(message)]);
              if (calls == 1) {
                throw StateError(
                  'sensitive model path /private/models/teacher.gguf',
                );
              }
              return '{"chinese":"你好，梅！","pinyin":"nǐ hǎo, Méi!",'
                  '"english":"Hello, Mei!","tip":""}';
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Practise this sentence');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-tutor-error')), findsOneWidget);
    expect(
      find.text('We couldn’t reach Long Laoshi right now.'),
      findsOneWidget,
    );
    expect(find.textContaining('sensitive model path'), findsNothing);
    expect(find.text('Practise this sentence'), findsOneWidget);
    expect(calls, 1);

    await tester.tap(find.byKey(const Key('ai-tutor-retry')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(
      requests.last
          .where((message) => message['role'] == 'user')
          .map((message) => message['content']),
      ['Practise this sentence'],
    );
    expect(find.text('Practise this sentence'), findsOneWidget);
    expect(find.text('你好，梅！'), findsOneWidget);
    expect(find.byKey(const Key('ai-tutor-error')), findsNothing);
  });

  testWidgets('ai tutor configuration errors do not offer a futile retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTutorPage(
            personalityRepository: MemoryTutorPersonalityRepository(),
            settingsRepository: _MemorySettingsRepository(),
            tutorContextRepository: _EmptyTutorContextRepository(),
            pronunciationService: pronunciation,
            request: (_) async => throw const GeminiConfigurationException(
              'Gemini is not configured for this build.',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Help me practise');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(
      find.text('Gemini is not configured for this build.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-tutor-retry')), findsNothing);
  });

  testWidgets('ai tutor speaks assistant Chinese replies only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTutorPage(
            personalityRepository: MemoryTutorPersonalityRepository(),
            settingsRepository: _MemorySettingsRepository(),
            tutorContextRepository: _EmptyTutorContextRepository(),
            pronunciationService: pronunciation,
            request: (_) async =>
                '{"chinese":"你好，梅！","pinyin":"nǐ hǎo, Méi!",'
                '"english":"Hello, Mei!","tip":""}',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hear Mandarin reply'));
    await tester.pump();
    expect(pronunciation.spoken, ['你好！我是龙老师。你想练习什么中文？']);

    await tester.enterText(find.byType(TextField), 'Say hello to Mei');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-tutor-pronunciation')), findsNWidgets(2));
    await tester.tap(find.byTooltip('Hear Mandarin reply').last);
    await tester.pump();
    expect(pronunciation.spoken, ['你好！我是龙老师。你想练习什么中文？', '你好，梅！']);

    final stopsBeforeReset = pronunciation.stopCalls;
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(pronunciation.stopCalls, greaterThan(stopsBeforeReset));

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(pronunciation.disposeCalls, 0);
  });

  testWidgets('ai tutor disables reply audio when sound is turned off', (
    tester,
  ) async {
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTutorPage(
            personalityRepository: MemoryTutorPersonalityRepository(),
            settingsRepository: _MemorySettingsRepository(
              const LearnerSettings(soundEnabled: false),
            ),
            tutorContextRepository: _EmptyTutorContextRepository(),
            pronunciationService: pronunciation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Pronunciation audio is disabled in Settings'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PronunciationButton>(
            find.byKey(const Key('ai-tutor-pronunciation')),
          )
          .onPressed,
      isNull,
    );
    expect(pronunciation.spoken, isEmpty);
  });

  testWidgets(
    'dashboard header menu button opens the drawer on narrow layouts',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: Drawer(child: Text('drawer contents')),
            body: DashboardHeader(showMenu: true, profile: testProfile),
          ),
        ),
      );

      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(find.text('drawer contents'), findsOneWidget);
    },
  );

  Future<void> testMobileMenuSwipes(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: DashboardPage(
          vocabularyRepository: const _TestVocabulary(),
          personalityRepository: MemoryTutorPersonalityRepository(),
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: _MemoryLessonRepository(),
          progressRepository: _MemoryProgressRepository(),
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
          pronunciationService: pronunciation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    await tester.dragFrom(const Offset(200, 600), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(find.byType(Drawer), findsNothing);

    await tester.dragFrom(const Offset(300, 400), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);

    // Inspect the drawer before releasing: it must track the finger, including
    // reversing direction, rather than starting its animation on pointer-up.
    final drag = await tester.startGesture(const Offset(100, 400));
    await drag.moveBy(const Offset(30, 0));
    await tester.pump();
    await drag.moveBy(const Offset(80, 0));
    await tester.pump();
    final partialX = tester.getTopLeft(find.byType(Drawer)).dx;
    expect(partialX, lessThan(0));
    expect(partialX, greaterThan(-tester.getSize(find.byType(Drawer)).width));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(find.byType(Drawer)).dx, partialX);
    await drag.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byType(Drawer)).dx,
      closeTo(partialX + 40, 0.1),
    );
    await drag.moveBy(const Offset(-20, 0));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byType(Drawer)).dx,
      closeTo(partialX + 20, 0.1),
    );
    await drag.moveBy(const Offset(150, 0));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(tester.getTopLeft(find.byType(Drawer)).dx, 0);

    // Tapping the scrim and the system back action both dismiss the drawer.
    await tester.tapAt(const Offset(380, 400));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);

    // A short, slow drag settles closed after release or cancellation.
    for (final cancel in [false, true]) {
      final shortDrag = await tester.startGesture(const Offset(100, 400));
      await shortDrag.moveBy(const Offset(30, 0));
      await tester.pump();
      await shortDrag.moveBy(const Offset(50, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(Drawer), findsOneWidget);
      if (cancel) {
        await shortDrag.cancel();
      } else {
        await shortDrag.up();
      }
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
    }
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    final aitutorNav = find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('AI Tutor'),
    );
    await tester.scrollUntilVisible(
      aitutorNav,
      120,
      scrollable: find
          .descendant(
            of: find.byType(AppSidebar),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(aitutorNav);
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(AiTutorPage), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.dragFrom(const Offset(100, 400), const Offset(280, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    await tester.dragFrom(const Offset(280, 400), const Offset(-260, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Hello'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    final homeNav = find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('Home'),
    );
    await tester.scrollUntilVisible(
      homeNav,
      120,
      scrollable: find
          .descendant(
            of: find.byType(AppSidebar),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(homeNav);
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(AiTutorPage), findsNothing);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    final dictionaryNav = find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('Dictionary'),
    );
    await tester.scrollUntilVisible(
      dictionaryNav,
      120,
      scrollable: find
          .descendant(
            of: find.byType(AppSidebar),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(dictionaryNav);
    await _waitForWidget(
      tester,
      find.byKey(const Key('vocabulary-result-count')),
    );
    await tester.pumpAndSettle();

    final filters = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    final filterScrollable = tester.state<ScrollableState>(
      find.descendant(of: filters.first, matching: find.byType(Scrollable)),
    );
    final filterY = tester.getCenter(filters.first).dy;
    await tester.dragFrom(Offset(280, filterY), const Offset(-160, 0));
    await tester.pumpAndSettle();
    final filterOffset = filterScrollable.position.pixels;
    expect(filterOffset, greaterThan(0));
    await tester.dragFrom(Offset(100, filterY), const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(filterScrollable.position.pixels, lessThan(filterOffset));
    expect(find.byType(Drawer), findsNothing);
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '${platform.name} menu follows swipes across pages and still scrolls',
      (tester) => testMobileMenuSwipes(tester, platform),
    );
  }

  testWidgets('settings edits profile and can reset onboarding', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    LearnerProfile? updatedProfile;
    var resetOnboarding = false;
    final settingsRepository = _MemorySettingsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            appThemeId: AppThemeId.classic,
            onThemeChanged: (_) {},
            profile: testProfile,
            onProfileChanged: (profile) async => updatedProfile = profile,
            onResetOnboarding: () async => resetOnboarding = true,
            onResetAllData: () async {},
            developmentRepository: const SqliteDevelopmentRepository(),
            settingsRepository: settingsRepository,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Lin');
    await tester.tap(find.text('HSK 4'));
    await tester.tap(find.text('20 words'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-save')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pump();

    expect(updatedProfile?.name, 'Lin');
    expect(updatedProfile?.hskLevel, 4);
    expect(updatedProfile?.dailyWordTarget, 20);

    await tester.scrollUntilVisible(
      find.text('Reset onboarding only'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset onboarding only'));
    await tester.pumpAndSettle();
    expect(find.text('Reset learner setup?'), findsOneWidget);
    await tester.tap(find.text('Reset setup'));
    await tester.pumpAndSettle();
    expect(resetOnboarding, isTrue);
  });

  testWidgets(
    'settings shows one save action with progress and success feedback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final saveGate = Completer<void>();
      addTearDown(() {
        if (!saveGate.isCompleted) saveGate.complete();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              appThemeId: AppThemeId.classic,
              onThemeChanged: (_) {},
              profile: testProfile,
              onProfileChanged: (_) async {},
              onResetOnboarding: () async {},
              onResetAllData: () async {},
              developmentRepository: _MemoryDevelopmentRepository(),
              settingsRepository: _GatedSettingsRepository(saveGate),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-save')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('settings-save')));
      await tester.pump();

      expect(find.text('Saving…'), findsOneWidget);
      expect(find.byKey(const Key('settings-save')), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
      expect(find.text('Save preferences'), findsNothing);
      expect(find.text('Settings saved.'), findsNothing);

      saveGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Saving…'), findsNothing);
      expect(find.text('Save settings'), findsOneWidget);
      expect(find.text('Settings saved.'), findsOneWidget);
    },
  );

  testWidgets('settings reset-all cancellation is inert', (tester) async {
    final developmentRepository = _MemoryDevelopmentRepository();
    await _pumpResetSettings(tester, developmentRepository);

    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));

    expect(find.text('Reset your account?'), findsOneWidget);
    expect(developmentRepository.resetAllDataCalls, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 0);
    expect(find.text('Reset your account?'), findsNothing);
  });

  testWidgets('settings account reset is outside developer tools', (
    tester,
  ) async {
    await _pumpResetSettings(tester, _MemoryDevelopmentRepository());
    final reset = find.byKey(const Key('settings-reset-all'));
    await tester.scrollUntilVisible(
      reset,
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('settings-account-reset')),
        matching: reset,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Export a backup above'), findsOneWidget);
  });

  testWidgets('settings reset-all needs both confirmations and exact text', (
    tester,
  ) async {
    final developmentRepository = _MemoryDevelopmentRepository();
    await _pumpResetSettings(tester, developmentRepository);

    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));

    expect(find.text('Reset your account?'), findsOneWidget);
    expect(
      find.textContaining('study progress, review history'),
      findsOneWidget,
    );
    expect(find.textContaining('including API keys'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(developmentRepository.resetAllDataCalls, 0);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm account reset'), findsOneWidget);
    expect(developmentRepository.resetAllDataCalls, 0);
    final confirm = find.byKey(const Key('account-reset-confirm'));
    final input = find.byKey(const Key('account-reset-confirmation-input'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    for (final text in ['reset', 'RESE', ' RESET ', 'RESET', '']) {
      await tester.enterText(input, text);
      await tester.pump();
      if (text == 'RESET') {
        expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      } else {
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      }
      expect(developmentRepository.resetAllDataCalls, 0);
    }

    await tester.enterText(input, 'RESET');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 1);
    expect(find.text('Confirm account reset'), findsNothing);
  });

  testWidgets(
    'final account reset cancellation clears confirmation on reopen',
    (tester) async {
      final development = _MemoryDevelopmentRepository();
      await _pumpResetSettings(tester, development);
      await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('account-reset-confirmation-input')),
        'RESET',
      );
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(development.resetAllDataCalls, 0);

      await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('account-reset-confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(development.resetAllDataCalls, 0);
      expect(find.text('Confirm account reset'), findsNothing);
    },
  );

  testWidgets('account reset confirmations fit a narrow screen with keyboard', (
    tester,
  ) async {
    final development = _MemoryDevelopmentRepository();
    await _pumpResetSettings(
      tester,
      development,
      surfaceSize: const Size(390, 700),
    );
    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const Key('account-reset-confirmation-input')),
      'RESET',
    );
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(development.resetAllDataCalls, 0);
  });

  testWidgets('settings reset-all failure retries directly and safely', (
    tester,
  ) async {
    var failNextReset = true;
    final developmentRepository = _MemoryDevelopmentRepository(
      onReset: () async {
        if (failNextReset) {
          failNextReset = false;
          throw StateError('sensitive reset path /private/local_app.db');
        }
      },
    );
    await _pumpResetSettings(tester, developmentRepository);

    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
    await _confirmAccountReset(tester);
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 1);
    expect(find.text('We couldn’t reset your local data.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('sensitive reset path'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 2);
    expect(find.text('Reset your account?'), findsNothing);
    expect(find.text('We couldn’t reset your local data.'), findsNothing);
  });

  testWidgets(
    'settings onboarding reset failure retries without reconfirming',
    (tester) async {
      var resetCalls = 0;
      await _pumpResetSettings(
        tester,
        _MemoryDevelopmentRepository(),
        onResetOnboarding: () async {
          resetCalls++;
          if (resetCalls == 1) {
            throw StateError('sensitive learner path /private/learner.db');
          }
        },
      );

      await _openSettingsResetDialog(
        tester,
        const Key('settings-reset-onboarding'),
      );
      await tester.tap(find.text('Reset setup'));
      await tester.pumpAndSettle();

      expect(resetCalls, 1);
      expect(find.text('We couldn’t reset learner setup.'), findsOneWidget);
      expect(find.textContaining('sensitive learner path'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(resetCalls, 2);
      expect(find.text('Reset learner setup?'), findsNothing);
      expect(find.text('We couldn’t reset learner setup.'), findsNothing);
    },
  );

  testWidgets(
    'settings disables both reset actions while reset-all is pending',
    (tester) async {
      final resetGate = Completer<void>();
      final developmentRepository = _MemoryDevelopmentRepository(
        onReset: () => resetGate.future,
      );
      await _pumpResetSettings(tester, developmentRepository);

      await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
      await _confirmAccountReset(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(developmentRepository.resetAllDataCalls, 1);
      expect(find.text('Resetting account…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('settings-save')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('settings-export-backup')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('settings-import-backup')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('settings-reset-onboarding')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('settings-reset-all')))
            .onPressed,
        isNull,
      );

      resetGate.complete();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('settings-reset-onboarding')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('settings-reset-all')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('account reset waits for a pending profile save', (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final development = _MemoryDevelopmentRepository();
    await _pumpResetSettings(
      tester,
      development,
      onProfileChanged: (_) => gate.future,
    );
    await _revealSettingsControl(tester, const Key('settings-reset-all'));
    final reset = find.byKey(const Key('settings-reset-all'));
    final resetAction = tester.widget<OutlinedButton>(reset).onPressed!;
    await _revealSettingsControl(tester, const Key('settings-save'));
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pump();

    expect(tester.widget<OutlinedButton>(reset).onPressed, isNull);
    resetAction();
    await tester.pump();
    expect(find.text('Reset your account?'), findsNothing);
    expect(development.resetAllDataCalls, 0);

    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(reset).onPressed, isNotNull);
  });

  testWidgets('account reset waits for an immediate theme save', (
    tester,
  ) async {
    final settings = _PendingSettingsRepository();
    addTearDown(() {
      if (!settings.saveGate.isCompleted) settings.saveGate.complete();
    });
    final development = _MemoryDevelopmentRepository();
    await _pumpResetSettings(tester, development, settingsRepository: settings);
    await _revealSettingsControl(tester, const Key('theme-choice-ocean'));
    await tester.tap(find.byKey(const Key('theme-choice-ocean')));
    await tester.pumpAndSettle();
    expect(settings.saveStarted, isTrue);
    await _revealSettingsControl(tester, const Key('settings-reset-all'));
    final reset = find.byKey(const Key('settings-reset-all'));
    expect(tester.widget<OutlinedButton>(reset).onPressed, isNull);
    expect(development.resetAllDataCalls, 0);

    settings.saveGate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(reset).onPressed, isNotNull);
  });

  testWidgets('reset-all returns the app root to learner setup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final developmentRepository = _MemoryDevelopmentRepository();
    final aiRepository = MemoryAiConfigurationRepository(testAiConfiguration);

    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          lessons: _MemoryLessonRepository(),
          development: developmentRepository,
          aiConfiguration: aiRepository,
          settings: _MemorySettingsRepository(),
          progress: _MemoryProgressRepository(hasActiveSession: false),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      find.text('Manage your learning preferences and local data.'),
      findsOneWidget,
    );
    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
    await _confirmAccountReset(tester);
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 1);
    expect(aiRepository.clearCalls, 1);
    expect(aiRepository.configuration, isNull);
    expect(find.text('Build your learning path'), findsOneWidget);
    expect(find.text('你好，Mei'), findsNothing);
  });

  testWidgets('reset-all waits for secure key removal and retries failures', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final development = _MemoryDevelopmentRepository();
    final aiRepository = MemoryAiConfigurationRepository(testAiConfiguration)
      ..clearError = StateError('secret key in platform error');
    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          lessons: _MemoryLessonRepository(),
          development: development,
          aiConfiguration: aiRepository,
          settings: _MemorySettingsRepository(),
          progress: _MemoryProgressRepository(hasActiveSession: false),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
    await _confirmAccountReset(tester);
    await tester.pumpAndSettle();
    expect(development.resetAllDataCalls, 0);
    expect(aiRepository.configuration, testAiConfiguration);
    expect(find.text('We couldn’t reset your local data.'), findsOneWidget);
    expect(find.textContaining('secret key'), findsNothing);

    aiRepository.clearError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(aiRepository.configuration, isNull);
    expect(development.resetAllDataCalls, 1);
    expect(find.text('Build your learning path'), findsOneWidget);
  });

  testWidgets('onboarding reset returns the app root to learner setup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final learnerRepository = _MemoryLearnerRepository(testProfile);
    final aiRepository = MemoryAiConfigurationRepository(testAiConfiguration);

    await tester.pumpWidget(
      HanziPathApp(
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          learners: learnerRepository,
          aiConfiguration: aiRepository,
          lessons: _MemoryLessonRepository(),
          development: _MemoryDevelopmentRepository(),
          settings: _MemorySettingsRepository(),
          progress: _MemoryProgressRepository(hasActiveSession: false),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      find.text('Manage your learning preferences and local data.'),
      findsOneWidget,
    );
    await _openSettingsResetDialog(
      tester,
      const Key('settings-reset-onboarding'),
    );
    await tester.tap(find.text('Reset setup'));
    await tester.pumpAndSettle();

    expect(learnerRepository.resetOnboardingCalls, 1);
    expect(aiRepository.clearCalls, 0);
    expect(aiRepository.configuration, testAiConfiguration);
    expect(find.text('Build your learning path'), findsOneWidget);
    expect(find.text('你好，Mei'), findsNothing);
  });

  testWidgets('settings restores and saves learning preferences', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MemorySettingsRepository(
      const LearnerSettings(showPinyin: false, soundEnabled: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            appThemeId: AppThemeId.classic,
            onThemeChanged: (_) {},
            profile: testProfile,
            onProfileChanged: (_) async {},
            onResetOnboarding: () async {},
            onResetAllData: () async {},
            developmentRepository: const SqliteDevelopmentRepository(),
            settingsRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    final pinyinSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Show pinyin'),
    );
    expect(pinyinSwitch.value, isFalse);
    await tester.tap(find.text('Show pinyin'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-save')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(repository.settings.showPinyin, isTrue);
    expect(repository.settings.soundEnabled, isFalse);
    expect(find.text('Settings saved.'), findsOneWidget);
  });

  testWidgets(
    'Android voice setup rechecks on return without assuming installation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pronunciation = _FakeSystemVoiceService();
      addTearDown(pronunciation.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              appThemeId: AppThemeId.classic,
              onThemeChanged: (_) {},
              profile: testProfile,
              onProfileChanged: (_) async {},
              onResetOnboarding: () async {},
              onResetAllData: () async {},
              developmentRepository: _MemoryDevelopmentRepository(),
              settingsRepository: _MemorySettingsRepository(),
              pronunciationService: pronunciation,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final install = find.byKey(const Key('system-voice-install'));
      await tester.scrollUntilVisible(
        install,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(install), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(install);
      await tester.pumpAndSettle();
      expect(pronunciation.openCalls, 1);
      expect(install, findsOneWidget);
      expect(find.text('Offline Mandarin voices'), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(install, findsOneWidget); // Cancelled download.

      pronunciation.failOpen = true;
      await Scrollable.ensureVisible(tester.element(install), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(install);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('system-voice-error')), findsOneWidget);

      pronunciation.failCheck = true;
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('system-voice-check'))),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('system-voice-check')));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not check the Mandarin voice. Try again.'),
        findsOneWidget,
      );

      pronunciation.failCheck = false;
      pronunciation.installed = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.text('Mandarin voice installed for offline speech.'),
        findsOneWidget,
      );
      expect(install, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings installs the offline voice without manual files', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            appThemeId: AppThemeId.classic,
            onThemeChanged: (_) {},
            profile: testProfile,
            onProfileChanged: (_) async {},
            onResetOnboarding: () async {},
            onResetAllData: () async {},
            developmentRepository: _MemoryDevelopmentRepository(),
            settingsRepository: _MemorySettingsRepository(),
            pronunciationService: pronunciation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final download = find.byKey(const Key('kokoro-voice-download'));
    await tester.scrollUntilVisible(
      download,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(download);
    await tester.pumpAndSettle();

    expect(pronunciation.installCalls, 1);
    final ready = find.byKey(const Key('kokoro-voice-ready'));
    await tester.scrollUntilVisible(
      ready,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(ready, findsOneWidget);
  });

  for (final size in [const Size(400, 800), const Size(1000, 1000)]) {
    testWidgets(
      'desktop settings checks and installs fallback speech at $size',
      (tester) async {
        final pronunciation = _RecordedFakePronunciationService();
        await _pumpRecordedVoiceSettings(
          tester,
          pronunciation,
          surfaceSize: size,
        );
        expect(find.text('Recorded Mandarin audio'), findsOneWidget);
        expect(
          find.textContaining('4379 human-recorded words'),
          findsOneWidget,
        );
        expect(find.text('Offline Mandarin voices'), findsNothing);
        expect(find.byKey(const Key('kokoro-voice-download')), findsNothing);
        expect(find.byKey(const Key('kokoro-voice-picker')), findsNothing);
        expect(find.byKey(const Key('system-voice-install')), findsNothing);
        expect(pronunciation.voiceCheckCalls, 1);
        expect(pronunciation.voiceInstallCalls, 0);
        expect(find.textContaining('has not been confirmed'), findsOneWidget);

        await _revealSettingsControl(
          tester,
          const Key('desktop-voice-install'),
        );
        await tester.tap(find.byKey(const Key('desktop-voice-install')));
        await tester.pumpAndSettle();
        expect(pronunciation.voiceInstallCalls, 1);
        expect(pronunciation.voiceCheckCalls, 2);
        expect(
          find.textContaining('installed and ready offline'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('desktop-voice-install')), findsNothing);
        expect(pronunciation.spoken, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('desktop voice setup reports failures and rechecks on resume', (
    tester,
  ) async {
    final pronunciation = _RecordedFakePronunciationService()..failCheck = true;
    await _pumpRecordedVoiceSettings(tester, pronunciation);
    expect(find.textContaining('Could not check the fallback'), findsOneWidget);
    expect(find.textContaining('installed and ready offline'), findsNothing);
    pronunciation.failCheck = false;
    pronunciation.failInstall = true;
    await tester.tap(find.byKey(const Key('desktop-voice-install')));
    await tester.pumpAndSettle();
    expect(find.text('Administrator approval was cancelled.'), findsOneWidget);
    expect(find.byKey(const Key('desktop-voice-install')), findsOneWidget);
    pronunciation.installed = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('installed and ready offline'), findsOneWidget);
    expect(find.byKey(const Key('desktop-voice-error')), findsNothing);
    expect(find.byKey(const Key('desktop-voice-install')), findsNothing);
    expect(pronunciation.voiceInstallCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop setup confirms availability after installation', (
    tester,
  ) async {
    final pronunciation = _RecordedFakePronunciationService()
      ..readyAfterInstall = false;
    await _pumpRecordedVoiceSettings(tester, pronunciation);
    await tester.tap(find.byKey(const Key('desktop-voice-install')));
    await tester.pumpAndSettle();
    expect(find.textContaining('installed and ready offline'), findsNothing);
    expect(find.textContaining('installer finished, but'), findsOneWidget);
    expect(find.byKey(const Key('desktop-voice-install')), findsOneWidget);
    pronunciation.installed = true;
    await _revealSettingsControl(tester, const Key('desktop-voice-check'));
    await tester.tap(find.byKey(const Key('desktop-voice-check')));
    await tester.pumpAndSettle();
    expect(find.textContaining('installed and ready offline'), findsOneWidget);
    expect(find.byKey(const Key('desktop-voice-error')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop setup waits for installation and handles leaving settings',
    (tester) async {
      final completion = Completer<void>();
      final pronunciation = _RecordedFakePronunciationService()
        ..installationGate = completion.future;
      await _pumpRecordedVoiceSettings(tester, pronunciation);
      await tester.tap(find.byKey(const Key('desktop-voice-install')));
      await tester.pump();
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(SettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final offset = scrollable.position.pixels;
      scrollable.position.jumpTo(0);
      await tester.pump();
      scrollable.position.jumpTo(offset);
      await tester.pump();
      expect(find.text('Installing Mandarin voice…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('desktop-voice-install')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('desktop-voice-check')))
            .onPressed,
        isNull,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(pronunciation.voiceCheckCalls, 1);
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      completion.complete();
      await tester.pumpAndSettle();
      expect(pronunciation.voiceCheckCalls, 1);
      expect(pronunciation.voiceInstallCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings downloads Kokoro and saves a random voice pool', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _ManagedFakePronunciationService();
    final repository = _MemorySettingsRepository();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            appThemeId: AppThemeId.classic,
            onThemeChanged: (_) {},
            profile: testProfile,
            onProfileChanged: (_) async {},
            onResetOnboarding: () async {},
            onResetAllData: () async {},
            developmentRepository: _MemoryDevelopmentRepository(),
            settingsRepository: repository,
            pronunciationService: pronunciation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kokoro-voice-picker')), findsNothing);
    final download = find.byKey(const Key('kokoro-voice-download'));
    await tester.scrollUntilVisible(
      download,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(download);
    await tester.pumpAndSettle();

    expect(pronunciation.installedEngines, [PronunciationEngine.kokoro]);
    expect(find.byKey(const Key('kokoro-voice-ready')), findsOneWidget);
    expect(find.byKey(const Key('kokoro-voice-picker')), findsOneWidget);
    expect(find.text('All 100 voices (random)'), findsOneWidget);

    final voicePicker = find.byKey(const Key('kokoro-voice-picker'));
    await tester.ensureVisible(voicePicker);
    await tester.tap(voicePicker);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kokoro-voice-dialog')), findsOneWidget);
    expect(find.text('100 of 100 selected'), findsOneWidget);
    await tester.tap(find.byKey(const Key('kokoro-voice-clear-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kokoro-voice-empty-error')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('kokoro-voice-apply')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('kokoro-voice-choice-zf_001')));
    await tester.enterText(
      find.byKey(const Key('kokoro-voice-search')),
      'zm_041',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kokoro-voice-choice-zm_041')));
    await tester.tap(find.byKey(const Key('kokoro-voice-apply')));
    await tester.pumpAndSettle();

    expect(find.text('2 voices (random)'), findsOneWidget);

    expect(pronunciation.configuredEngine, PronunciationEngine.kokoro);
    expect(pronunciation.configuredVoiceIds, ['zf_001', 'zm_041']);

    final save = find.byKey(const Key('settings-save'));
    await tester.scrollUntilVisible(
      save,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.settings.pronunciationEngine, PronunciationEngine.kokoro);
    expect(repository.settings.kokoroVoiceIds, ['zf_001', 'zm_041']);
  });

  testWidgets('settings restores a saved Kokoro voice once installed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _ManagedFakePronunciationService(
      kokoroStatus: const OfflineVoiceStatus.ready(
        engine: PronunciationEngine.kokoro,
      ),
    );
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            appThemeId: AppThemeId.classic,
            onThemeChanged: (_) {},
            profile: testProfile,
            onProfileChanged: (_) async {},
            onResetOnboarding: () async {},
            onResetAllData: () async {},
            developmentRepository: _MemoryDevelopmentRepository(),
            settingsRepository: _MemorySettingsRepository(
              const LearnerSettings(
                pronunciationEngine: PronunciationEngine.kokoro,
                kokoroVoiceIds: ['zm_041'],
              ),
            ),
            pronunciationService: pronunciation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final picker = find.byKey(const Key('kokoro-voice-picker'));
    await tester.scrollUntilVisible(
      picker,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(picker, findsOneWidget);
    expect(find.text('Male 041'), findsOneWidget);
  });

  testWidgets('cancelling the Kokoro voice picker keeps the current pool', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _ManagedFakePronunciationService(
      kokoroStatus: const OfflineVoiceStatus.ready(
        engine: PronunciationEngine.kokoro,
      ),
    );
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            appThemeId: AppThemeId.classic,
            onThemeChanged: (_) {},
            profile: testProfile,
            onProfileChanged: (_) async {},
            onResetOnboarding: () async {},
            onResetAllData: () async {},
            developmentRepository: _MemoryDevelopmentRepository(),
            settingsRepository: _MemorySettingsRepository(
              const LearnerSettings(
                pronunciationEngine: PronunciationEngine.kokoro,
                kokoroVoiceIds: ['zf_001', 'zm_041'],
              ),
            ),
            pronunciationService: pronunciation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final picker = find.byKey(const Key('kokoro-voice-picker'));
    await tester.scrollUntilVisible(
      picker,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('2 voices (random)'), findsOneWidget);
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kokoro-voice-clear-all')));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kokoro-voice-dialog')), findsNothing);
    expect(find.text('2 voices (random)'), findsOneWidget);
    expect(pronunciation.configuredVoiceIds, isEmpty);
  });

  testWidgets('settings preference load error is friendly and retryable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FailOnceSettingsLoadRepository(
      const LearnerSettings(showPinyin: false, soundEnabled: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            appThemeId: AppThemeId.classic,
            onThemeChanged: (_) {},
            profile: testProfile,
            onProfileChanged: (_) async {},
            onResetOnboarding: () async {},
            onResetAllData: () async {},
            developmentRepository: _MemoryDevelopmentRepository(),
            settingsRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-preferences-error')), findsOneWidget);
    expect(find.text('We couldn’t load your preferences'), findsOneWidget);
    expect(find.textContaining('sensitive settings path'), findsNothing);
    expect(repository.loadCalls, 1);

    final retry = find.byKey(const Key('settings-preferences-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
    expect(find.byKey(const Key('settings-preferences-error')), findsNothing);
    expect(find.widgetWithText(SwitchListTile, 'Show pinyin'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Show pinyin'),
          )
          .value,
      isFalse,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-save')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save settings'), findsOneWidget);
    expect(find.text('Save changes'), findsNothing);
    expect(find.text('Save preferences'), findsNothing);
  });

  testWidgets('settings preference save can retry the exact changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FailOnceSettingsSaveRepository(
      const LearnerSettings(
        showPinyin: false,
        soundEnabled: false,
        reminderEnabled: true,
        reminderHour: 7,
        pronunciationEngine: PronunciationEngine.kokoro,
        kokoroVoiceIds: ['zf_021'],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            appThemeId: AppThemeId.classic,
            onThemeChanged: (_) {},
            profile: testProfile,
            onProfileChanged: (_) async {},
            onResetOnboarding: () async {},
            onResetAllData: () async {},
            developmentRepository: _MemoryDevelopmentRepository(),
            settingsRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pinyinToggle = find.text('Show pinyin');
    await tester.ensureVisible(pinyinToggle);
    await tester.tap(pinyinToggle);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-save')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(repository.saveAttempts, hasLength(1));
    expect(find.text('Settings saved.'), findsNothing);
    final saveError = find.byKey(const Key('settings-save-error'));
    await tester.scrollUntilVisible(
      saveError,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(saveError, findsOneWidget);

    final retry = find.byKey(const Key('settings-save-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(repository.saveAttempts, hasLength(2));
    final firstAttempt = repository.saveAttempts.first;
    final retryAttempt = repository.saveAttempts.last;
    expect(firstAttempt.showPinyin, isTrue);
    expect(retryAttempt.showPinyin, firstAttempt.showPinyin);
    expect(retryAttempt.soundEnabled, firstAttempt.soundEnabled);
    expect(retryAttempt.reminderEnabled, firstAttempt.reminderEnabled);
    expect(retryAttempt.reminderHour, firstAttempt.reminderHour);
    expect(retryAttempt.pronunciationEngine, firstAttempt.pronunciationEngine);
    expect(retryAttempt.kokoroVoiceIds, firstAttempt.kokoroVoiceIds);
    expect(find.byKey(const Key('settings-save-error')), findsNothing);
    expect(find.text('Settings saved.'), findsOneWidget);
  });

  testWidgets('locked lesson tile renders with reduced opacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonTile(
            title: 'Travel & Directions',
            chinese: '旅行与方向',
            unit: 'Unit 3',
            duration: '22 min',
            xp: '+80 XP',
            state: LessonState.locked,
          ),
        ),
      ),
    );

    final opacityWidget = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.text('Travel & Directions'),
            matching: find.byType(Opacity),
          )
          .first,
    );

    expect(opacityWidget.opacity, 0.48);
    expect(find.text('Travel & Directions'), findsOneWidget);
    expect(find.text('+80 XP'), findsOneWidget);
  });
}

class _FakePronunciationService
    implements PronunciationService, PreparedPronunciationService {
  final List<String> prepared = [];

  @override
  Future<void> prepareMandarin(String text) async {
    prepared.add(text);
  }

  final StreamController<OfflineVoiceStatus> _updates =
      StreamController<OfflineVoiceStatus>.broadcast();
  final List<String> spoken = [];
  OfflineVoiceStatus status = const OfflineVoiceStatus.notInstalled();
  int installCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => _updates.stream;

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async => status;

  @override
  Future<void> installOfflineVoice() async {
    installCalls++;
    status = const OfflineVoiceStatus.ready();
    _updates.add(status);
  }

  @override
  Future<void> speakMandarin(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async {
    if (disposeCalls > 0) return;
    disposeCalls++;
    await _updates.close();
  }
}

class _FailOncePronunciationService extends _FakePronunciationService {
  bool _failNext = true;

  @override
  Future<void> speakMandarin(String text) async {
    if (_failNext) {
      _failNext = false;
      throw StateError('Audio temporarily unavailable');
    }
    await super.speakMandarin(text);
  }
}

class _RecordedFakePronunciationService extends _FakePronunciationService
    implements RecordedAudioPronunciation, DesktopVoiceInstaller {
  bool installed = false;
  bool failCheck = false;
  bool failInstall = false;
  bool readyAfterInstall = true;
  int voiceCheckCalls = 0;
  int voiceInstallCalls = 0;
  Future<void>? installationGate;

  @override
  Future<bool> isMandarinVoiceInstalled() async {
    voiceCheckCalls++;
    if (failCheck) throw StateError('Voice enumeration failed');
    return installed;
  }

  @override
  Future<void> installMandarinVoice() async {
    voiceInstallCalls++;
    if (failInstall) {
      throw const DesktopVoiceInstallationException(
        'Administrator approval was cancelled.',
      );
    }
    await installationGate;
    installed = readyAfterInstall;
  }

  @override
  String get systemSpeechDescription =>
      'Missing words use system Mandarin speech.';

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus(
        state: OfflineVoiceState.ready,
        message: '4379 human-recorded words are bundled and ready offline.',
      );
}

class _ManagedFakePronunciationService extends _FakePronunciationService
    implements OfflinePronunciationManager {
  _ManagedFakePronunciationService({
    OfflineVoiceStatus kokoroStatus = const OfflineVoiceStatus.notInstalled(
      engine: PronunciationEngine.kokoro,
      totalBytes: kokoroOfflineVoiceDownloadBytes,
    ),
  }) {
    _kokoroStatus = kokoroStatus;
  }

  final StreamController<OfflineVoiceStatus> _voicePackUpdates =
      StreamController<OfflineVoiceStatus>.broadcast();
  late OfflineVoiceStatus _kokoroStatus;
  final List<PronunciationEngine> installedEngines = [];
  PronunciationEngine? configuredEngine;
  List<String> configuredVoiceIds = const [];

  @override
  Stream<OfflineVoiceStatus> get voicePackUpdates => _voicePackUpdates.stream;

  @override
  Future<OfflineVoiceStatus> checkVoicePack(PronunciationEngine engine) async =>
      _kokoroStatus;

  @override
  Future<void> installVoicePack(PronunciationEngine engine) async {
    installedEngines.add(engine);
    final ready = OfflineVoiceStatus.ready(engine: engine);
    _kokoroStatus = ready;
    _voicePackUpdates.add(ready);
  }

  @override
  List<PronunciationVoice> voicesFor(PronunciationEngine engine) =>
      kokoroMandarinVoices;

  @override
  Future<void> configurePronunciation({
    required PronunciationEngine engine,
    List<String> voiceIds = const [],
  }) async {
    configuredEngine = engine;
    configuredVoiceIds = List.of(voiceIds);
  }

  @override
  Future<void> dispose() async {
    if (!_voicePackUpdates.isClosed) await _voicePackUpdates.close();
    await super.dispose();
  }
}

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository([this.settings = const LearnerSettings()]);

  LearnerSettings settings;

  @override
  Future<LearnerSettings> load() async => settings;

  @override
  Future<void> save(LearnerSettings settings) async {
    this.settings = settings;
  }
}

class _PendingSettingsRepository extends _MemorySettingsRepository {
  final saveGate = Completer<void>();
  bool saveStarted = false;

  @override
  Future<void> save(LearnerSettings settings) async {
    saveStarted = true;
    await saveGate.future;
    await super.save(settings);
  }
}

class _EmptyTutorContextRepository implements TutorContextRepository {
  @override
  Future<TutorLearnerSnapshot> load({required DateTime asOf}) async =>
      TutorLearnerSnapshot(asOf: asOf);
}

class _GatedSettingsRepository extends _MemorySettingsRepository {
  _GatedSettingsRepository(this.saveGate);

  final Completer<void> saveGate;

  @override
  Future<void> save(LearnerSettings settings) async {
    await saveGate.future;
    await super.save(settings);
  }
}

class _FailOnceSettingsLoadRepository implements SettingsRepository {
  _FailOnceSettingsLoadRepository(this.settings);

  final LearnerSettings settings;
  int loadCalls = 0;

  @override
  Future<LearnerSettings> load() async {
    loadCalls++;
    if (loadCalls == 1) {
      throw StateError('sensitive settings path /private/preferences.db');
    }
    return settings;
  }

  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _FailOnceSettingsSaveRepository extends _MemorySettingsRepository {
  _FailOnceSettingsSaveRepository(super.settings);

  final List<LearnerSettings> saveAttempts = [];

  @override
  Future<void> save(LearnerSettings settings) async {
    saveAttempts.add(settings);
    if (saveAttempts.length == 1) {
      throw StateError('sensitive settings path /private/preferences.db');
    }
    await super.save(settings);
  }
}

class _FailingSettingsRepository implements SettingsRepository {
  @override
  Future<LearnerSettings> load() =>
      Future.error(StateError('preferences unavailable'));

  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _FailAfterFirstSettingsRepository implements SettingsRepository {
  int loadCalls = 0;

  @override
  Future<LearnerSettings> load() async {
    loadCalls++;
    if (loadCalls > 1) throw StateError('preferences temporarily unavailable');
    return const LearnerSettings(showPinyin: false);
  }

  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _StalledSettingsRepository implements SettingsRepository {
  final _result = Completer<LearnerSettings>();

  @override
  Future<LearnerSettings> load() => _result.future;

  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _MemoryDevelopmentRepository implements DevelopmentRepository {
  _MemoryDevelopmentRepository({this.onReset});

  final Future<void> Function()? onReset;
  int resetAllDataCalls = 0;

  @override
  Future<String> databasePath() async => 'memory';

  @override
  Future<void> resetAllData() async {
    resetAllDataCalls++;
    final callback = onReset;
    if (callback != null) await callback();
  }
}

class _ZeroRandom implements Random {
  int nextIntCalls = 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) {
    nextIntCalls++;
    return 0;
  }
}

class _MemoryLearnerRepository implements LearnerRepository {
  _MemoryLearnerRepository(this.profile);

  LearnerProfile? profile;
  int resetOnboardingCalls = 0;

  @override
  Future<void> resetOnboarding() async {
    resetOnboardingCalls++;
    profile = null;
  }

  @override
  Future<LearnerProfile?> load() async => profile;

  @override
  Future<void> save(LearnerProfile profile) async {
    this.profile = profile;
  }
}

class _MemoryLessonRepository implements LessonRepository {
  @override
  Future<void> deleteGenerated(int lessonId) async {
    throw UnimplementedError();
  }

  final lesson = const Lesson(
    summary: LessonSummary(
      id: 7,
      title: 'Saved lesson',
      theme: 'Saved',
      hskLevel: 1,
    ),
    cards: [
      Flashcard(id: 11, chinese: '你', pinyin: 'nǐ', englishMeaning: 'you'),
      Flashcard(id: 12, chinese: '学', pinyin: 'xué', englishMeaning: 'study'),
    ],
  );

  @override
  Future<Lesson?> findById(int id) async =>
      id == lesson.summary.id ? lesson : null;

  @override
  Future<Lesson?> findGenerated({
    required String theme,
    required int hskLevel,
  }) async => lesson;

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async => card;

  @override
  Future<void> saveGenerated(Lesson lesson) async {}

  @override
  Future<List<LessonSummary>> topics() async => [lesson.summary];
}

class _ExampleLessonRepository extends _MemoryLessonRepository {
  @override
  Future<Lesson?> findById(int id) async => Lesson(
    summary: lesson.summary,
    cards: const [
      Flashcard(
        id: 11,
        chinese: '你',
        pinyin: 'nǐ',
        englishMeaning: 'you',
        exampleChinese: '  ',
      ),
      Flashcard(
        id: 12,
        chinese: '学',
        pinyin: 'xué',
        englishMeaning: 'study',
        exampleChinese: '我学中文。',
        examplePinyin: 'Wǒ xué Zhōngwén.',
        exampleEnglish: 'I study Chinese.',
      ),
    ],
  );
}

class _ArchivedLessonRepository extends _MemoryLessonRepository {
  @override
  Future<List<LessonSummary>> topics() async => [];
}

class _GuidedLessonRepository extends _MemoryLessonRepository {
  @override
  Future<Lesson?> findById(int id) async => Lesson(
    summary: lesson.summary,
    cards: lesson.cards,
    guide: savedLessonGuide,
  );
}

class _MultiLevelLessonRepository implements LessonRepository {
  @override
  Future<void> deleteGenerated(int lessonId) async {
    throw UnimplementedError();
  }

  static const hsk1Lesson = LessonSummary(
    id: 41,
    title: 'Morning Greetings',
    theme: 'Greetings',
    hskLevel: 1,
  );
  static const hsk3Lesson = LessonSummary(
    id: 42,
    title: 'Restaurant Talk',
    theme: 'Dining Out',
    hskLevel: 3,
  );
  static const hsk4Lesson = LessonSummary(
    id: 43,
    title: 'Market News',
    theme: 'News and Media',
    hskLevel: 4,
  );

  @override
  Future<List<LessonSummary>> topics() async => const [
    hsk1Lesson,
    hsk3Lesson,
    hsk4Lesson,
  ];

  @override
  Future<Lesson?> findById(int id) async => null;

  @override
  Future<Lesson?> findGenerated({
    required String theme,
    required int hskLevel,
  }) async => null;

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async => card;

  @override
  Future<void> saveGenerated(Lesson lesson) async {}
}

class _RotatingLessonRepository implements LessonRepository {
  @override
  Future<void> deleteGenerated(int lessonId) async {
    throw UnimplementedError();
  }

  _RotatingLessonRepository({
    this.missingIds = const {},
    this.emptyIds = const {},
  });

  final Set<int> missingIds;
  final Set<int> emptyIds;
  final requestedIds = <int>[];
  late final List<Lesson> lessons = [
    for (var level = 1; level <= 6; level++)
      for (var variant = 1; variant <= 2; variant++)
        Lesson(
          summary: LessonSummary(
            id: level * 10 + variant,
            title: 'HSK $level lesson $variant',
            theme: 'Level $level theme $variant',
            hskLevel: level,
          ),
          cards: [
            Flashcard(
              id: level * 100 + variant * 10 + 1,
              chinese: '学',
              pinyin: 'xué',
              englishMeaning: 'study',
            ),
            Flashcard(
              id: level * 100 + variant * 10 + 2,
              chinese: '习',
              pinyin: 'xí',
              englishMeaning: 'practice',
            ),
          ],
        ),
  ];

  @override
  Future<List<LessonSummary>> topics() async =>
      lessons.map((lesson) => lesson.summary).toList(growable: false);

  @override
  Future<Lesson?> findById(int id) async {
    requestedIds.add(id);
    if (missingIds.contains(id)) return null;
    final lesson = lessons.cast<Lesson?>().firstWhere(
      (lesson) => lesson?.summary.id == id,
      orElse: () => null,
    );
    if (lesson != null && emptyIds.contains(id)) {
      return Lesson(summary: lesson.summary, cards: const []);
    }
    return lesson;
  }

  @override
  Future<Lesson?> findGenerated({
    required String theme,
    required int hskLevel,
  }) async => null;

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async => card;

  @override
  Future<void> saveGenerated(Lesson lesson) async {}
}

class _LessonStateRepository implements LessonRepository {
  @override
  Future<void> deleteGenerated(int lessonId) async {
    throw UnimplementedError();
  }

  _LessonStateRepository({this.firstTopics, this.failFirstTopicsLoad = false});

  final Future<List<LessonSummary>>? firstTopics;
  final bool failFirstTopicsLoad;
  int topicsCalls = 0;

  static const lesson = Lesson(
    summary: LessonSummary(
      id: 27,
      title: 'Recovered lesson',
      theme: 'Recovery',
      hskLevel: 2,
    ),
    cards: [
      Flashcard(id: 271, chinese: '好', pinyin: 'hǎo', englishMeaning: 'good'),
    ],
  );

  @override
  Future<List<LessonSummary>> topics() async {
    topicsCalls++;
    if (topicsCalls == 1) {
      if (firstTopics case final firstTopics?) return firstTopics;
      if (failFirstTopicsLoad) {
        throw StateError('sensitive database path /private/lessons.db');
      }
    }
    return [lesson.summary];
  }

  @override
  Future<Lesson?> findById(int id) async =>
      id == lesson.summary.id ? lesson : null;

  @override
  Future<Lesson?> findGenerated({
    required String theme,
    required int hskLevel,
  }) async => null;

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async => card;

  @override
  Future<void> saveGenerated(Lesson lesson) async {}
}

class _MemoryProgressRepository implements ProgressRepository {
  _MemoryProgressRepository({
    this.hasActiveSession = true,
    this.queue = const [],
    List<ReviewRecord>? reviews,
    this.vocabulary = const [],
    this.recordReviewGate,
    LessonSession? activeSession,
  }) : reviews =
           reviews ??
           (hasActiveSession
               ? [
                   ReviewRecord(
                     id: 1,
                     cardId: 11,
                     sessionId: 3,
                     submissionKey: 'lesson:3:card:11',
                     reviewedAt: DateTime.utc(2026, 7, 28, 9),
                     rating: ReviewRating.easy,
                     wasCorrect: true,
                   ),
                 ]
               : const []),
       _active =
           activeSession ??
           LessonSession(
             id: 3,
             lessonId: 7,
             startedAt: DateTime.utc(2026, 7, 28),
             currentCardIndex: 1,
             cardsReviewed: 1,
             correctAnswers: 1,
           );

  final bool hasActiveSession;
  final List<DailyQueueCard> queue;
  final List<ReviewRecord> reviews;
  final List<VocabularyCardProgress> vocabulary;
  final Completer<void>? recordReviewGate;
  int dailyQueueCalls = 0;
  int recordReviewCalls = 0;
  final List<DateTime> requestedDays = [];
  LessonSession? savedSession;
  ReviewRecord? recordedReview;
  CardProgress? savedProgress;
  int? startedLessonId;

  final LessonSession _active;

  @override
  Future<LessonSession?> activeSessionForLesson(int lessonId) async =>
      hasActiveSession ? _active : null;

  @override
  Future<LessonSession?> latestActiveSession() async =>
      hasActiveSession ? _active : null;

  @override
  Future<List<CardProgress>> dueCards(DateTime through) async => const [];

  @override
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  }) async {
    dailyQueueCalls++;
    requestedDays.add(forDay);
    return queue.take(limit).toList(growable: false);
  }

  @override
  Future<CardProgress?> progressForCard(int cardId) async => null;

  @override
  Future<List<VocabularyCardProgress>> vocabularyProgress() async => vocabulary;

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    recordReviewCalls++;
    recordedReview = review;
    savedProgress = progress;
    await recordReviewGate?.future;
  }

  @override
  Future<List<ReviewRecord>> reviewHistory({int? cardId, int? limit}) async =>
      reviews
          .where((review) => cardId == null || review.cardId == cardId)
          .take(limit ?? reviews.length)
          .toList(growable: false);

  @override
  Future<LessonSession> startSession(int lessonId) async {
    startedLessonId = lessonId;
    return _active;
  }

  @override
  Future<void> updateSessionPosition({
    required int sessionId,
    required int currentCardIndex,
    required int expectedCardsReviewed,
  }) async {}

  @override
  Future<void> updateSession(
    LessonSession session, {
    bool reconcileFromHistory = false,
    int? expectedCardsReviewed,
    int? expectedCorrectAnswers,
  }) async {
    savedSession = session;
  }
}

class _FailOnceRecordReviewRepository extends _MemoryProgressRepository {
  int recordReviewAttempts = 0;

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    recordReviewAttempts++;
    if (recordReviewAttempts == 1) {
      throw StateError('sensitive database path /private/reviews.db');
    }
    await super.recordReview(review: review, progress: progress);
  }
}

class _DeferredDailyQueueRepository extends _MemoryProgressRepository {
  _DeferredDailyQueueRepository(this.result);

  final Completer<List<DailyQueueCard>> result;

  @override
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  }) {
    dailyQueueCalls++;
    requestedDays.add(forDay);
    return result.future;
  }
}

class _FailOnceDailyQueueRepository extends _MemoryProgressRepository {
  _FailOnceDailyQueueRepository({required super.queue});

  bool _shouldFail = true;

  @override
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  }) {
    if (_shouldFail) {
      _shouldFail = false;
      dailyQueueCalls++;
      requestedDays.add(forDay);
      return Future.error(StateError('sensitive database path'));
    }
    return super.dailyQueue(
      forDay: forDay,
      limit: limit,
      weakThreshold: weakThreshold,
      maxHskLevel: maxHskLevel,
    );
  }
}

class _SequencedDailyQueueRepository extends _MemoryProgressRepository {
  _SequencedDailyQueueRepository(this.results);

  final List<Completer<List<DailyQueueCard>>> results;
  int _nextResult = 0;

  @override
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  }) {
    dailyQueueCalls++;
    requestedDays.add(forDay);
    return results[_nextResult++].future;
  }
}

class _MemoryDailyReviewSessionRepository
    implements DailyReviewSessionRepository {
  _MemoryDailyReviewSessionRepository(this.session);

  DailyReviewSession? session;

  @override
  Future<DailyReviewSession?> load(DateTime date) async => session;

  @override
  Future<DailyReviewSession> create({
    required DateTime date,
    required List<int> queuedCardIds,
  }) async => session!;

  @override
  Future<void> update(DailyReviewSession session) async {
    this.session = session;
  }

  @override
  Future<bool> complete({
    required int sessionId,
    required DateTime completedAt,
    required int expectedCardCount,
  }) async {
    final current = session!;
    session = DailyReviewSession(
      id: current.id,
      date: current.date,
      queuedCardIds: current.queuedCardIds,
      currentPosition: current.queuedCardIds.length,
      completedAt: completedAt,
    );
    return true;
  }

  @override
  Future<void> enqueueCard({
    required DateTime date,
    required int cardId,
  }) async {}
}

class _JourneyReviewRepository
    implements ProgressRepository, DailyReviewSessionRepository {
  static const _cards = [
    DailyQueueCard(
      card: Flashcard(id: 1, chinese: '一', pinyin: 'yī', englishMeaning: 'one'),
      reason: DailyQueueReason.newWord,
    ),
    DailyQueueCard(
      card: Flashcard(id: 2, chinese: '二', pinyin: 'èr', englishMeaning: 'two'),
      reason: DailyQueueReason.weak,
    ),
  ];

  final Map<String, DailyReviewSession> sessions = {};
  final Map<int, CardProgress> progress = {};
  final List<ReviewRecord> savedReviews = [];
  int createdSessionCount = 0;
  int reviewCount = 0;
  int? cardToAppendOnNextCompletion;

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  }) async {
    final key = _key(forDay);
    final session =
        sessions[key] ??
        await create(
          date: forDay,
          queuedCardIds: _cards.map((item) => item.card.id).toList(),
        );
    final cardsById = {for (final item in _cards) item.card.id: item};
    return session.queuedCardIds
        .skip(session.currentPosition)
        .map((id) => cardsById[id]!)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<DailyReviewSession> create({
    required DateTime date,
    required List<int> queuedCardIds,
  }) async {
    final key = _key(date);
    final existing = sessions[key];
    if (existing != null) return existing;
    final session = DailyReviewSession(
      id: createdSessionCount + 1,
      date: DateTime(date.year, date.month, date.day),
      queuedCardIds: List.unmodifiable(queuedCardIds),
    );
    sessions[key] = session;
    createdSessionCount++;
    return session;
  }

  @override
  Future<DailyReviewSession?> load(DateTime date) async => sessions[_key(date)];

  @override
  Future<void> update(DailyReviewSession session) async {
    sessions[_key(session.date)] = session;
  }

  @override
  Future<bool> complete({
    required int sessionId,
    required DateTime completedAt,
    required int expectedCardCount,
  }) async {
    final entry = sessions.entries.singleWhere(
      (entry) => entry.value.id == sessionId,
    );
    final current = entry.value;
    final cardToAppend = cardToAppendOnNextCompletion;
    if (cardToAppend != null) {
      cardToAppendOnNextCompletion = null;
      sessions[entry.key] = DailyReviewSession(
        id: current.id,
        date: current.date,
        queuedCardIds: [...current.queuedCardIds, cardToAppend],
        currentPosition: expectedCardCount,
      );
      return false;
    }
    sessions[entry.key] = DailyReviewSession(
      id: current.id,
      date: current.date,
      queuedCardIds: current.queuedCardIds,
      currentPosition: current.queuedCardIds.length,
      completedAt: completedAt,
    );
    return true;
  }

  @override
  Future<void> enqueueCard({
    required DateTime date,
    required int cardId,
  }) async {}

  @override
  Future<CardProgress?> progressForCard(int cardId) async => progress[cardId];

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    reviewCount++;
    savedReviews.add(review);
    this.progress[progress.cardId] = progress;
  }

  @override
  Future<LessonSession?> activeSessionForLesson(int lessonId) async => null;

  @override
  Future<List<CardProgress>> dueCards(DateTime through) async => const [];

  @override
  Future<LessonSession?> latestActiveSession() async => null;

  @override
  Future<List<ReviewRecord>> reviewHistory({int? cardId, int? limit}) async =>
      savedReviews
          .where((review) => cardId == null || review.cardId == cardId)
          .take(limit ?? savedReviews.length)
          .toList(growable: false);

  @override
  Future<LessonSession> startSession(int lessonId) =>
      throw UnimplementedError();

  @override
  Future<void> updateSessionPosition({
    required int sessionId,
    required int currentCardIndex,
    required int expectedCardsReviewed,
  }) async {}

  @override
  Future<void> updateSession(
    LessonSession session, {
    bool reconcileFromHistory = false,
    int? expectedCardsReviewed,
    int? expectedCorrectAnswers,
  }) async {}

  @override
  Future<List<VocabularyCardProgress>> vocabularyProgress() async => const [];
}

class _FakeSystemVoiceService extends _FakePronunciationService
    implements SystemVoiceInstaller {
  bool installed = false;
  bool failOpen = false;
  bool failCheck = false;
  int openCalls = 0;

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus.unavailable();

  @override
  Future<bool> isMandarinVoiceInstalled() async {
    if (failCheck) throw StateError('Speech engine unavailable');
    return installed;
  }

  @override
  Future<void> openMandarinVoiceInstaller() async {
    openCalls++;
    if (failOpen) throw StateError('No installer');
  }
}

class _CountingStatsProgress extends _MemoryProgressRepository
    implements ProgressSummaryRepository {
  _CountingStatsProgress() : super(hasActiveSession: false);

  final statisticsDates = <DateTime>[];

  @override
  Future<Map<int, LessonSession>> activeLessonSessions() async => const {};

  @override
  Future<DashboardLearningStats> learningStats(DateTime now) async {
    statisticsDates.add(now);
    return const DashboardLearningStats();
  }
}

class _DeletableLessonRepository extends _MemoryLessonRepository {
  static const generated = LessonSummary(
    id: 91,
    title: 'My generated lesson',
    theme: 'Daily Life',
    hskLevel: 1,
    isUserGenerated: true,
  );
  bool deleted = false;
  int deleteCalls = 0;
  Completer<void> deletion = Completer<void>();

  @override
  Future<List<LessonSummary>> topics() async => [
    if (!deleted) generated,
    lesson.summary,
  ];

  @override
  Future<void> deleteGenerated(int lessonId) async {
    if (lessonId != generated.id) throw StateError('Bundled lesson');
    deleteCalls++;
    await deletion.future;
    deleted = true;
  }
}

final _testVocabularyEntries =
    (jsonDecode(File('assets/data/hsk_vocabulary.json').readAsStringSync())
            as List)
        .cast<Map<String, dynamic>>();

class _TestVocabulary extends BundledVocabularyRepository {
  const _TestVocabulary();
  @override
  Future<List<Map<String, dynamic>>> load({AssetBundle? bundle}) async =>
      _testVocabularyEntries;
}

class _DeferredVocabulary extends BundledVocabularyRepository {
  _DeferredVocabulary(this.result);
  final Completer<List<Map<String, dynamic>>> result;
  @override
  Future<List<Map<String, dynamic>>> load({AssetBundle? bundle}) =>
      result.future;
}

class _FailOnceVocabulary extends _TestVocabulary {
  int calls = 0;
  @override
  Future<List<Map<String, dynamic>>> load({AssetBundle? bundle}) async {
    if (++calls == 1) throw StateError('sensitive database path');
    return super.load(bundle: bundle);
  }
}
