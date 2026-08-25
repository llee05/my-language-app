import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/development_repository.dart';
import 'package:mylanguageapp/repositories/daily_review_session_repository.dart';
import 'package:mylanguageapp/repositories/app_dependencies.dart';
import 'package:mylanguageapp/repositories/learner_repository.dart';
import 'package:mylanguageapp/repositories/lesson_repository.dart';
import 'package:mylanguageapp/repositories/progress_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';

const testProfile = LearnerProfile(
  name: 'Mei',
  hskLevel: 2,
  dailyWordTarget: 10,
);

Future<void> _pumpResetSettings(
  WidgetTester tester,
  _MemoryDevelopmentRepository developmentRepository, {
  Future<void> Function()? onResetOnboarding,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SettingsPage(
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: onResetOnboarding ?? () async {},
          onResetAllData: developmentRepository.resetAllData,
          developmentRepository: developmentRepository,
          settingsRepository: _MemorySettingsRepository(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSettingsResetDialog(
  WidgetTester tester,
  Key buttonKey,
) async {
  await tester.drag(find.byType(ListView), const Offset(0, -700));
  await tester.pumpAndSettle();
  final button = find.byKey(buttonKey);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

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

  testWidgets('app restores the selected pronunciation engine and voice', (
    tester,
  ) async {
    final pronunciation = _ManagedFakePronunciationService();
    await tester.pumpWidget(
      HanziPathApp(
        dependencies: AppDependencies(
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

  testWidgets('dashboard explains review loading and an empty queue', (
    tester,
  ) async {
    final result = Completer<List<DailyQueueCard>>();
    final progress = _DeferredDailyQueueRepository(result);
    final sessions = _MemoryDailyReviewSessionRepository(
      DailyReviewSession(id: 11, date: DateTime.now(), queuedCardIds: const []),
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
          dailyReviewSessionRepository: sessions,
          settingsRepository: _MemorySettingsRepository(),
          developmentRepository: _MemoryDevelopmentRepository(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Checking today’s review'), findsOneWidget);
    expect(
      find.text('Finding due, weak, and new cards for you.'),
      findsOneWidget,
    );

    result.complete(const []);
    await tester.pumpAndSettle();

    expect(
      find.text('Daily review complete — you’re all done!'),
      findsOneWidget,
    );
    expect(find.text('0 cards pending today'), findsNothing);
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
          .widget<IconButton>(
            find.byKey(const Key('daily-review-pronunciation')),
          )
          .onPressed,
      isNull,
    );
    expect(pronunciation.spoken, isEmpty);
  });

  testWidgets('dashboard daily review error can be retried', (tester) async {
    const queue = [
      DailyQueueCard(
        card: Flashcard(
          id: 33,
          chinese: '习',
          pinyin: 'xí',
          englishMeaning: 'practise',
        ),
        reason: DailyQueueReason.weak,
      ),
    ];
    final progress = _FailOnceDailyQueueRepository(queue: queue);

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
    await tester.pumpAndSettle();

    expect(find.text('We couldn’t load today’s review'), findsOneWidget);
    expect(find.textContaining('sensitive database path'), findsNothing);

    await tester.tap(find.byKey(const Key('daily-review-prompt-retry')));
    await tester.pumpAndSettle();

    expect(progress.dailyQueueCalls, 2);
    expect(find.text('1 card pending today'), findsOneWidget);
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
    expect(find.text('Loading your lesson library'), findsOneWidget);
    expect(find.textContaining('Finding your saved lessons'), findsOneWidget);
    expect(tester.takeException(), isNull);

    topics.complete(const []);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lesson-library-empty-state')), findsOneWidget);
    expect(find.text('No saved lessons yet'), findsOneWidget);
    expect(find.textContaining('create your first lesson'), findsOneWidget);
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
    expect(find.text('We couldn’t load your lessons'), findsOneWidget);
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
    expect(find.text('Loading available lessons'), findsOneWidget);

    topics.complete(const []);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('available-lessons-empty-state')),
      findsOneWidget,
    );
    expect(find.text('No saved lessons yet'), findsOneWidget);
    expect(
      find.text('Create a lesson to start building your library.'),
      findsOneWidget,
    );
  });

  testWidgets('dashboard lesson load error is retryable', (tester) async {
    final lessons = _LessonStateRepository(failFirstTopicsLoad: true);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
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

    await tester.tap(find.byKey(const Key('available-lessons-retry')));
    await tester.pumpAndSettle();

    expect(lessons.topicsCalls, 2);
    expect(find.text('Recovered lesson'), findsOneWidget);
    expect(
      find.byKey(const Key('available-lessons-error-state')),
      findsNothing,
    );
  });

  testWidgets('lesson generation error is friendly and retryable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lessons = _FailOnceGeneratedLookupRepository();

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

    final generate = find.text('Generate lesson');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lesson-generation-error')), findsOneWidget);
    expect(find.text('We couldn’t generate your lesson.'), findsOneWidget);
    expect(find.textContaining('sensitive database path'), findsNothing);
    expect(lessons.findGeneratedCalls, 1);

    await tester.tap(find.byKey(const Key('lesson-generation-retry')));
    await tester.pumpAndSettle();

    expect(lessons.findGeneratedCalls, 2);
    expect(find.byKey(const Key('lesson-generation-error')), findsNothing);
    expect(find.text('Recovered generated lesson'), findsOneWidget);
    expect(find.text('好'), findsOneWidget);
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
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTutorPage(
            settingsRepository: _MemorySettingsRepository(),
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
            settingsRepository: _MemorySettingsRepository(),
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

  testWidgets('ai tutor speaks assistant Chinese replies only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
    addTearDown(pronunciation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTutorPage(
            settingsRepository: _MemorySettingsRepository(),
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
            settingsRepository: _MemorySettingsRepository(
              const LearnerSettings(soundEnabled: false),
            ),
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
          .widget<IconButton>(find.byKey(const Key('ai-tutor-pronunciation')))
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

  testWidgets(
    'settings shows progress and confirms a successful profile save',
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

      await tester.tap(find.text('Save changes'));
      await tester.pump();

      expect(find.text('Saving…'), findsOneWidget);
      expect(find.text('Save preferences'), findsOneWidget);
      expect(find.text('Profile changes saved.'), findsNothing);

      saveGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Saving…'), findsNothing);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Profile changes saved.'), findsOneWidget);
    },
  );

  testWidgets('settings reset-all cancellation is inert', (tester) async {
    final developmentRepository = _MemoryDevelopmentRepository();
    await _pumpResetSettings(tester, developmentRepository);

    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));

    expect(find.text('Reset all local data?'), findsOneWidget);
    expect(developmentRepository.resetAllDataCalls, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 0);
    expect(find.text('Reset all local data?'), findsNothing);
  });

  testWidgets('settings reset-all confirmation invokes once with clear copy', (
    tester,
  ) async {
    final developmentRepository = _MemoryDevelopmentRepository();
    await _pumpResetSettings(tester, developmentRepository);

    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));

    expect(find.text('Reset all local data?'), findsOneWidget);
    expect(
      find.text(
        'This permanently removes the learner profile, generated lessons, '
        'and all other local app data.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reset everything'), findsOneWidget);
    expect(developmentRepository.resetAllDataCalls, 0);

    await tester.tap(find.text('Reset everything'));
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 1);
    expect(find.text('Reset all local data?'), findsNothing);
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
    await tester.tap(find.text('Reset everything'));
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 1);
    expect(find.text('We couldn’t reset your local data.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('sensitive reset path'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 2);
    expect(find.text('Reset all local data?'), findsNothing);
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
      await tester.tap(find.text('Reset everything'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(developmentRepository.resetAllDataCalls, 1);
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

  testWidgets('reset-all returns the app root to learner setup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final developmentRepository = _MemoryDevelopmentRepository();

    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
          lessons: _MemoryLessonRepository(),
          development: developmentRepository,
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
      find.text('Manage your learning preferences and local test data.'),
      findsOneWidget,
    );
    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
    await tester.tap(find.text('Reset everything'));
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 1);
    expect(find.text('Build your learning path'), findsOneWidget);
    expect(find.text('你好，Mei'), findsNothing);
  });

  testWidgets('onboarding reset returns the app root to learner setup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final learnerRepository = _MemoryLearnerRepository(testProfile);

    await tester.pumpWidget(
      HanziPathApp(
        dependencies: AppDependencies(
          learners: learnerRepository,
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
      find.text('Manage your learning preferences and local test data.'),
      findsOneWidget,
    );
    await _openSettingsResetDialog(
      tester,
      const Key('settings-reset-onboarding'),
    );
    await tester.tap(find.text('Reset setup'));
    await tester.pumpAndSettle();

    expect(learnerRepository.resetOnboardingCalls, 1);
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
    expect(find.text('Preferences saved.'), findsOneWidget);
  });

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

    final download = find.byKey(const Key('offline-voice-download'));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(download);
    await tester.pumpAndSettle();

    expect(pronunciation.installCalls, 1);
    expect(find.byKey(const Key('offline-voice-ready')), findsOneWidget);
  });

  testWidgets('settings downloads Kokoro and saves its selected voice', (
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
    await tester.ensureVisible(download);
    await tester.pumpAndSettle();
    await tester.tap(download);
    await tester.pumpAndSettle();

    expect(pronunciation.installedEngines, [PronunciationEngine.kokoro]);
    expect(find.byKey(const Key('kokoro-voice-ready')), findsOneWidget);
    expect(find.byKey(const Key('kokoro-voice-picker')), findsOneWidget);

    final enginePicker = find.byKey(const Key('pronunciation-engine-picker'));
    await tester.ensureVisible(enginePicker);
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<PronunciationEngine>>(enginePicker)
        .onChanged!(PronunciationEngine.kokoro);
    await tester.pumpAndSettle();

    final voicePicker = find.descendant(
      of: find.byKey(const Key('kokoro-voice-picker')),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    tester.widget<DropdownButtonFormField<String>>(voicePicker).onChanged!(
      'zm_041',
    );
    await tester.pumpAndSettle();

    expect(pronunciation.configuredEngine, PronunciationEngine.kokoro);
    expect(pronunciation.configuredVoiceIds, ['zm_041']);

    final save = find.text('Save preferences');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.settings.pronunciationEngine, PronunciationEngine.kokoro);
    expect(repository.settings.kokoroVoiceIds, ['zm_041']);
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

    expect(find.byKey(const Key('kokoro-voice-picker')), findsOneWidget);
    expect(find.text('Male 041'), findsOneWidget);
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
    expect(find.text('Save preferences'), findsOneWidget);
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
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();

    expect(repository.saveAttempts, hasLength(1));
    expect(find.text('Preferences saved.'), findsNothing);
    expect(
      find.byKey(const Key('settings-preferences-save-error')),
      findsOneWidget,
    );

    final retry = find.byKey(const Key('settings-preferences-save-retry'));
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
    expect(
      find.byKey(const Key('settings-preferences-save-error')),
      findsNothing,
    );
    expect(find.text('Preferences saved.'), findsOneWidget);
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

class _FakePronunciationService implements PronunciationService {
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

class _ManagedFakePronunciationService extends _FakePronunciationService
    implements OfflinePronunciationManager {
  _ManagedFakePronunciationService({
    OfflineVoiceStatus meloStatus = const OfflineVoiceStatus.ready(),
    OfflineVoiceStatus kokoroStatus = const OfflineVoiceStatus.notInstalled(
      engine: PronunciationEngine.kokoro,
      totalBytes: kokoroOfflineVoiceDownloadBytes,
    ),
  }) : statuses = {
         PronunciationEngine.melo: meloStatus,
         PronunciationEngine.kokoro: kokoroStatus,
       };

  final StreamController<OfflineVoiceStatus> _voicePackUpdates =
      StreamController<OfflineVoiceStatus>.broadcast();
  final Map<PronunciationEngine, OfflineVoiceStatus> statuses;
  final List<PronunciationEngine> installedEngines = [];
  PronunciationEngine? configuredEngine;
  List<String> configuredVoiceIds = const [];

  @override
  Stream<OfflineVoiceStatus> get voicePackUpdates => _voicePackUpdates.stream;

  @override
  Future<OfflineVoiceStatus> checkVoicePack(PronunciationEngine engine) async =>
      statuses[engine]!;

  @override
  Future<void> installVoicePack(PronunciationEngine engine) async {
    installedEngines.add(engine);
    final ready = OfflineVoiceStatus.ready(engine: engine);
    statuses[engine] = ready;
    _voicePackUpdates.add(ready);
  }

  @override
  List<PronunciationVoice> voicesFor(PronunciationEngine engine) =>
      engine == PronunciationEngine.kokoro
      ? kokoroMandarinVoices
      : const [meloPronunciationVoice];

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

class _LessonStateRepository implements LessonRepository {
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

class _FailOnceGeneratedLookupRepository implements LessonRepository {
  int findGeneratedCalls = 0;

  static const lesson = Lesson(
    summary: LessonSummary(
      id: 91,
      title: 'Recovered generated lesson',
      theme: 'Daily Life',
      hskLevel: 1,
    ),
    cards: [
      Flashcard(id: 911, chinese: '好', pinyin: 'hǎo', englishMeaning: 'good'),
    ],
  );

  @override
  Future<Lesson?> findGenerated({
    required String theme,
    required int hskLevel,
  }) async {
    findGeneratedCalls++;
    if (findGeneratedCalls == 1) {
      throw StateError('sensitive database path /private/generated.db');
    }
    return lesson;
  }

  @override
  Future<Lesson?> findById(int id) async =>
      id == lesson.summary.id ? lesson : null;

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async => card;

  @override
  Future<void> saveGenerated(Lesson lesson) async {}

  @override
  Future<List<LessonSummary>> topics() async => const [];
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
