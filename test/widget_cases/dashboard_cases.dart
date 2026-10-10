part of '../widget_test.dart';

void _registerDashboardRefreshWidgetTests() {
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
}

void _registerDashboardHomeWidgetTests() {
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
}

void _registerDiscoveryRetryWidgetTests() {
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
}

void _registerDashboardLessonWidgetTests() {
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
}
