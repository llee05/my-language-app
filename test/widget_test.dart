import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/development_repository.dart';
import 'package:mylanguageapp/repositories/daily_review_session_repository.dart';
import 'package:mylanguageapp/repositories/app_dependencies.dart';
import 'package:mylanguageapp/repositories/lesson_repository.dart';
import 'package:mylanguageapp/repositories/progress_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';

const testProfile = LearnerProfile(
  name: 'Mei',
  hskLevel: 2,
  dailyWordTarget: 10,
);

void main() {
  testWidgets('dashboard renders core learning content', (tester) async {
    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
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
    expect(find.text('AVAILABLE HSK LESSONS'), findsOneWidget);
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

  testWidgets('new learner dashboard offers a useful first step', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
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

    expect(find.text('Start your first lesson'), findsOneWidget);
    expect(find.text('Browse lessons'), findsOneWidget);
    expect(find.text('Begin first review'), findsOneWidget);
    expect(find.text('Learn your first 1 word'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);

    await tester.tap(find.text('Browse lessons'));
    await tester.pumpAndSettle();

    expect(find.text('Lesson Library'), findsOneWidget);
    expect(find.text('Saved lesson'), findsOneWidget);
  });

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

    await tester.tap(find.text('Review all'));
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
    expect(find.text('Saved · 2 cards · 60 XP reward'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('AVAILABLE HSK LESSONS'), findsOneWidget);
    expect(find.text('Saved · HSK 1 · 2 cards'), findsOneWidget);
    expect(find.text('Up to 20 XP'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Saved lesson'), findsOneWidget);
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller?.page, 1);
    expect(find.text('1 of 2 words completed'), findsOneWidget);
  });

  testWidgets('dashboard shows pending daily review and resumes it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const queue = [
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
        id: 9,
        date: DateTime.now(),
        queuedCardIds: const [1, 2],
        currentPosition: 1,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: _MemoryLessonRepository(),
          progressRepository: _MemoryProgressRepository(queue: queue),
          dailyReviewSessionRepository: sessions,
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 card pending today'), findsOneWidget);
    expect(find.text('Resume review'), findsOneWidget);
    await tester.tap(find.text('Resume review'));
    await tester.pumpAndSettle();
    expect(find.text('Daily review'), findsOneWidget);
    expect(find.text('二'), findsOneWidget);
  });

  testWidgets('dashboard replaces completed review with all-done state', (
    tester,
  ) async {
    final sessions = _MemoryDailyReviewSessionRepository(
      DailyReviewSession(
        id: 10,
        date: DateTime.now(),
        queuedCardIds: const [1],
        currentPosition: 1,
        completedAt: DateTime.now(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
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

    expect(
      find.text('Daily review complete — you’re all done!'),
      findsOneWidget,
    );
    expect(find.text('Start review'), findsNothing);
    expect(find.text('Resume review'), findsNothing);
  });

  testWidgets(
    'daily review journey creates, resumes, completes, and resets next day',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var now = DateTime(2026, 8, 6, 9);
      final reviews = _JourneyReviewRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardPage(
            profile: testProfile,
            onProfileChanged: (_) async {},
            onResetOnboarding: () async {},
            onResetAllData: () async {},
            lessonRepository: _MemoryLessonRepository(),
            progressRepository: reviews,
            dailyReviewSessionRepository: reviews,
            settingsRepository: _MemorySettingsRepository(),
            developmentRepository: _MemoryDevelopmentRepository(),
            clock: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(reviews.createdSessionCount, 1);
      expect(find.text('Learn your first 2 words'), findsOneWidget);
      expect(find.text('Begin first review'), findsOneWidget);

      await tester.tap(find.text('Begin first review'));
      await tester.pumpAndSettle();
      expect(find.text('一'), findsOneWidget);
      await tester.tap(find.text('Reveal meaning'));
      await tester.pump();
      await tester.ensureVisible(find.text('Confident'));
      await tester.tap(find.text('Confident'));
      await tester.pumpAndSettle();
      expect(reviews.sessions['2026-08-06']?.currentPosition, 1);

      await tester.tap(find.byTooltip('Back to review queue'));
      await tester.pumpAndSettle();
      expect(find.text('Resume review'), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('1 card pending today'), findsOneWidget);
      expect(find.text('Resume review'), findsOneWidget);

      await tester.tap(find.text('Resume review'));
      await tester.pumpAndSettle();
      expect(find.text('二'), findsOneWidget);
      await tester.tap(find.text('Reveal meaning'));
      await tester.pump();
      await tester.ensureVisible(find.text('No idea'));
      await tester.tap(find.text('No idea'));
      await tester.pumpAndSettle();
      expect(reviews.sessions['2026-08-06']?.isComplete, isTrue);
      expect(reviews.reviewCount, 2);

      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('Daily review complete!'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(
        find.text('Daily review complete — you’re all done!'),
        findsOneWidget,
      );

      now = DateTime(2026, 8, 7, 8);
      await tester.tap(find.text('Lessons'));
      await tester.pump();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(reviews.createdSessionCount, 2);
      expect(find.text('2 cards pending today'), findsOneWidget);
      expect(find.text('Start review'), findsOneWidget);
    },
  );

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

      expect(selected, 2);
    },
  );

  testWidgets('vocab rush starts a timed vocabulary game', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('PICK THE CORRECT MEANING'), findsOneWidget);
    expect(find.text('180s'), findsOneWidget);
  });

  testWidgets('daily review tab shows the prioritized review queue', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final progress = _MemoryProgressRepository(
      queue: [
        DailyQueueCard(
          card: const Flashcard(
            id: 1,
            chinese: '复习',
            pinyin: 'fùxí',
            englishMeaning: 'to review',
          ),
          reason: DailyQueueReason.due,
          progress: CardProgress(cardId: 1, dueAt: DateTime.utc(2026, 8, 5)),
        ),
        const DailyQueueCard(
          card: Flashcard(
            id: 2,
            chinese: '新',
            pinyin: 'xīn',
            englishMeaning: 'new',
          ),
          reason: DailyQueueReason.newWord,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          lessonRepository: _MemoryLessonRepository(),
          progressRepository: progress,
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
        ),
      ),
    );
    await tester.tap(find.text('Daily Review'));
    await tester.pumpAndSettle();

    expect(find.text('Today’s review queue'), findsOneWidget);
    expect(find.text('1 To review'), findsOneWidget);
    expect(find.text('1 New'), findsOneWidget);
    expect(find.text('复习'), findsOneWidget);
    expect(find.text('新'), findsOneWidget);
    expect(find.text('Start review'), findsOneWidget);
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

  testWidgets('lessons page exposes level and AI topic options', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
          lessons: _MemoryLessonRepository(),
          settings: _MemorySettingsRepository(),
          progress: _MemoryProgressRepository(),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Lessons'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lesson Library'), findsOneWidget);
    expect(find.text('Create a lesson'), findsOneWidget);
    expect(find.text('HSK level'), findsOneWidget);
    expect(find.text('Ask AI for a lesson topic'), findsOneWidget);
    expect(find.text('Generate lesson'), findsOneWidget);
    expect(find.text('Daily Life'), findsOneWidget);

    await tester.tap(find.text('HSK 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HSK 2').last);
    await tester.pumpAndSettle();

    expect(find.text('School'), findsOneWidget);
    expect(find.text('Daily Life'), findsNothing);
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
    expect(find.text('Lesson complete!'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Learned words'), findsOneWidget);
    expect(find.text('Review words'), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
  });

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

    save.complete();
    await tester.pumpAndSettle();
    expect(progress.recordReviewCalls, 1);
    expect(find.text('Lesson complete!'), findsOneWidget);
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

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiTutorPage())),
    );
    await tester.pump();

    expect(find.text('龙老师 - Long Laoshi'), findsOneWidget);
    expect(find.text("TODAY'S FOCUS"), findsNothing);
    expect(find.text('GPT-4o'), findsNothing);
    expect(find.text('你好！我是龙老师。你想练习什么中文？'), findsOneWidget);
    expect(find.text('我家里有四个人。爸爸，妈妈，我，和妹妹。'), findsNothing);
    expect(find.text('Ask 龙老师 anything in English or 中文...'), findsOneWidget);
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
    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(updatedProfile?.name, 'Lin');
    expect(updatedProfile?.hskLevel, 4);
    expect(updatedProfile?.dailyWordTarget, 20);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset onboarding only'));
    await tester.pumpAndSettle();
    expect(find.text('Reset learner setup?'), findsOneWidget);
    await tester.tap(find.text('Reset setup'));
    await tester.pumpAndSettle();
    expect(resetOnboarding, isTrue);
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
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();

    expect(repository.settings.showPinyin, isTrue);
    expect(repository.settings.soundEnabled, isFalse);
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

class _MemoryDevelopmentRepository implements DevelopmentRepository {
  @override
  Future<String> databasePath() async => 'memory';

  @override
  Future<void> resetAllData() async {}
}

class _MemoryLessonRepository implements LessonRepository {
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
