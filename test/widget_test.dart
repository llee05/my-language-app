import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/database/flashcard_seed.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/development_repository.dart';
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
    await tester.pumpWidget(const HanziPathApp(initialProfile: testProfile));
    await tester.pump();

    final firstLesson = flashcardLessons.first;

    expect(find.text('你好，Mei'), findsOneWidget);
    expect(find.text(firstLesson['lesson_title'] as String), findsWidgets);
    expect(find.text('WEEKLY XP'), findsOneWidget);
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

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Saved lesson'), findsOneWidget);
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller?.page, 1);
    expect(find.text('1 of 2 words completed'), findsOneWidget);
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

      expect(selected, 2);
    },
  );

  testWidgets('vocab rush starts a timed vocabulary game', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const HanziPathApp(initialProfile: testProfile));
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

  testWidgets('lessons page exposes level and AI topic options', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const HanziPathApp(initialProfile: testProfile));
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
    expect(progress.savedSession?.currentCardIndex, 2);
    expect(progress.savedSession?.isComplete, isTrue);
    expect(find.text('Lesson complete!'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Learned words'), findsOneWidget);
    expect(find.text('Review words'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
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

    await tester.pumpWidget(const HanziPathApp(initialProfile: testProfile));
    await tester.pump();

    expect(find.text('AI Tutor'), findsOneWidget);
    await tester.tap(find.text('AI Tutor'));
    await tester.pumpAndSettle();

    expect(find.text('龙老师 - Long Laoshi'), findsOneWidget);
    expect(find.text("TODAY'S FOCUS"), findsOneWidget);
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
  Future<void> saveGenerated(Lesson lesson) async {}

  @override
  Future<List<LessonSummary>> topics() async => [lesson.summary];
}

class _MemoryProgressRepository implements ProgressRepository {
  _MemoryProgressRepository({this.hasActiveSession = true});

  final bool hasActiveSession;
  LessonSession? savedSession;
  ReviewRecord? recordedReview;
  int? startedLessonId;

  final _active = LessonSession(
    id: 3,
    lessonId: 7,
    startedAt: DateTime.utc(2026, 7, 28),
    currentCardIndex: 1,
    cardsReviewed: 1,
    correctAnswers: 1,
  );

  @override
  Future<LessonSession?> activeSessionForLesson(int lessonId) async =>
      hasActiveSession ? _active : null;

  @override
  Future<LessonSession?> latestActiveSession() async => _active;

  @override
  Future<List<CardProgress>> dueCards(DateTime through) async => const [];

  @override
  Future<CardProgress?> progressForCard(int cardId) async => null;

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    recordedReview = review;
  }

  @override
  Future<List<ReviewRecord>> reviewHistory({int? cardId, int? limit}) async =>
      const [];

  @override
  Future<LessonSession> startSession(int lessonId) async {
    startedLessonId = lessonId;
    return _active;
  }

  @override
  Future<void> updateSession(LessonSession session) async {
    savedSession = session;
  }
}
