part of '../widget_test.dart';

void _registerLegacyQueueWidgetTests() {
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
}

void _registerLegacyReviewWidgetTests() {
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
}
