part of '../widget_test.dart';

void _registerNarrowLessonWidgetTests() {
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
      final rating = find.widgetWithText(OutlinedButton, 'I know this word');
      await tester.ensureVisible(rating);
      await tester.tap(rating);
      await tester.pumpAndSettle();
      expect(progress.recordReviewCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

void _registerLessonLibraryWidgetTests() {
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
}

void _registerLessonSessionWidgetTests() {
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
    await tester.tap(find.widgetWithText(OutlinedButton, 'I know this word'));
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
      'I know this word',
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
    await tester.tap(find.widgetWithText(OutlinedButton, 'I know this word'));
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
      find.widgetWithText(OutlinedButton, 'I know this word'),
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
}

void _registerLessonTileWidgetTests() {
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
