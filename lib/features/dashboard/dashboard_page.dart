part of '../../main.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    required this.onResetOnboarding,
    required this.onResetAllData,
    required this.lessonRepository,
    required this.progressRepository,
    this.dailyReviewSessionRepository,
    required this.settingsRepository,
    required this.developmentRepository,
    this.clock,
  });

  final LearnerProfile profile;
  final Future<void> Function(LearnerProfile profile) onProfileChanged;
  final Future<void> Function() onResetOnboarding;
  final Future<void> Function() onResetAllData;
  final LessonRepository lessonRepository;
  final ProgressRepository progressRepository;
  final DailyReviewSessionRepository? dailyReviewSessionRepository;
  final SettingsRepository settingsRepository;
  final DevelopmentRepository developmentRepository;
  final DateTime Function()? clock;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedNav = 0;
  bool _resumeLatestLesson = false;
  bool _startDailyReview = false;
  bool _loadingDailyReview = true;
  int _pendingReviewCount = 0;
  bool _dailyReviewComplete = false;
  bool _resumeDailyReview = false;
  Lesson? _activeLesson;
  LessonSession? _activeLessonSession;
  DashboardLearningStats _learningStats = const DashboardLearningStats();

  @override
  void initState() {
    super.initState();
    _loadDailyReviewPrompt();
    _loadActiveLesson();
    _loadLearningStats();
  }

  Future<void> _loadLearningStats() async {
    try {
      final results = await Future.wait([
        widget.progressRepository.reviewHistory(),
        widget.progressRepository.vocabularyProgress(),
      ]);
      final now = widget.clock?.call() ?? DateTime.now();
      final reviews = results[0] as List<ReviewRecord>;
      final vocabulary = results[1] as List<VocabularyCardProgress>;
      if (!mounted) return;
      setState(() {
        _learningStats = DashboardLearningStats.fromSavedData(
          reviews: reviews,
          vocabulary: vocabulary,
          now: now,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _learningStats = const DashboardLearningStats());
    }
  }

  Future<void> _loadActiveLesson() async {
    try {
      final session = await widget.progressRepository.latestActiveSession();
      final lesson = session == null
          ? null
          : await widget.lessonRepository.findById(session.lessonId);
      if (!mounted) return;
      setState(() {
        _activeLessonSession = lesson == null ? null : session;
        _activeLesson = lesson;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeLessonSession = null;
        _activeLesson = null;
      });
    }
  }

  Future<void> _loadDailyReviewPrompt() async {
    try {
      final now = widget.clock?.call() ?? DateTime.now();
      final queue = await widget.progressRepository.dailyQueue(
        forDay: now,
        limit: widget.profile.dailyWordTarget,
        maxHskLevel: widget.profile.hskLevel,
      );
      final session = await widget.dailyReviewSessionRepository?.load(now);
      if (!mounted) return;
      setState(() {
        _pendingReviewCount = queue.length;
        _dailyReviewComplete = session?.isComplete ?? queue.isEmpty;
        _resumeDailyReview =
            session != null &&
            !session.isComplete &&
            session.currentPosition > 0;
        _loadingDailyReview = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDailyReview = false);
    }
  }

  void _selectNavigation(int value) {
    setState(() {
      selectedNav = value;
      _resumeLatestLesson = false;
      _startDailyReview = false;
    });
    if (value == 0) {
      unawaited(_loadDailyReviewPrompt());
      unawaited(_loadActiveLesson());
      unawaited(_loadLearningStats());
    }
  }

  void _resumeLesson() {
    setState(() {
      selectedNav = 1;
      _resumeLatestLesson = true;
    });
  }

  void _openDailyReview() {
    setState(() {
      selectedNav = 4;
      _startDailyReview = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidebar = constraints.maxWidth >= 760;

        return Scaffold(
          drawer: showSidebar
              ? null
              : Drawer(
                  child: AppSidebar(
                    selectedIndex: selectedNav,
                    hskLevel: widget.profile.hskLevel,
                    streakDays: _learningStats.streakDays,
                    onSelected: _selectNavigation,
                  ),
                ),
          body: Row(
            children: [
              if (showSidebar)
                SizedBox(
                  width: 210,
                  child: AppSidebar(
                    selectedIndex: selectedNav,
                    hskLevel: widget.profile.hskLevel,
                    streakDays: _learningStats.streakDays,
                    onSelected: _selectNavigation,
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    DashboardHeader(
                      showMenu: !showSidebar,
                      profile: widget.profile,
                      totalXp: _learningStats.totalXp,
                    ),
                    Expanded(
                      child: _DashboardBody(
                        selectedNav: selectedNav,
                        resumeLatestLesson: _resumeLatestLesson,
                        startDailyReview: _startDailyReview,
                        onResumeLesson: _resumeLesson,
                        onStartDailyReview: _openDailyReview,
                        onDailyReviewCompleted: _loadDailyReviewPrompt,
                        loadingDailyReview: _loadingDailyReview,
                        pendingReviewCount: _pendingReviewCount,
                        dailyReviewComplete: _dailyReviewComplete,
                        resumeDailyReview: _resumeDailyReview,
                        activeLesson: _activeLesson,
                        activeLessonSession: _activeLessonSession,
                        learningStats: _learningStats,
                        profile: widget.profile,
                        onProfileChanged: widget.onProfileChanged,
                        onResetOnboarding: widget.onResetOnboarding,
                        onResetAllData: widget.onResetAllData,
                        lessonRepository: widget.lessonRepository,
                        progressRepository: widget.progressRepository,
                        dailyReviewSessionRepository:
                            widget.dailyReviewSessionRepository,
                        settingsRepository: widget.settingsRepository,
                        developmentRepository: widget.developmentRepository,
                        clock: widget.clock,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.selectedNav,
    required this.resumeLatestLesson,
    required this.startDailyReview,
    required this.onResumeLesson,
    required this.onStartDailyReview,
    required this.onDailyReviewCompleted,
    required this.loadingDailyReview,
    required this.pendingReviewCount,
    required this.dailyReviewComplete,
    required this.resumeDailyReview,
    required this.activeLesson,
    required this.activeLessonSession,
    required this.learningStats,
    required this.profile,
    required this.onProfileChanged,
    required this.onResetOnboarding,
    required this.onResetAllData,
    required this.lessonRepository,
    required this.progressRepository,
    this.dailyReviewSessionRepository,
    required this.settingsRepository,
    required this.developmentRepository,
    this.clock,
  });
  final int selectedNav;
  final bool resumeLatestLesson;
  final bool startDailyReview;
  final VoidCallback onResumeLesson;
  final VoidCallback onStartDailyReview;
  final VoidCallback onDailyReviewCompleted;
  final bool loadingDailyReview;
  final int pendingReviewCount;
  final bool dailyReviewComplete;
  final bool resumeDailyReview;
  final Lesson? activeLesson;
  final LessonSession? activeLessonSession;
  final DashboardLearningStats learningStats;
  final LearnerProfile profile;
  final Future<void> Function(LearnerProfile profile) onProfileChanged;
  final Future<void> Function() onResetOnboarding;
  final Future<void> Function() onResetAllData;
  final LessonRepository lessonRepository;
  final ProgressRepository progressRepository;
  final DailyReviewSessionRepository? dailyReviewSessionRepository;
  final SettingsRepository settingsRepository;
  final DevelopmentRepository developmentRepository;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    if (selectedNav == 1) {
      return LessonsPage(
        repository: lessonRepository,
        progressRepository: progressRepository,
        settingsRepository: settingsRepository,
        resumeLatest: resumeLatestLesson,
      );
    }
    if (selectedNav == 2) {
      return VocabRushPage(
        lessonRepository: lessonRepository,
        progressRepository: progressRepository,
        dailyReviewSessionRepository: dailyReviewSessionRepository,
      );
    }
    if (selectedNav == 3) {
      return VocabularyPage(progressRepository: progressRepository);
    }
    if (selectedNav == 4) {
      return DailyQueuePage(
        profile: profile,
        progressRepository: progressRepository,
        sessionRepository: dailyReviewSessionRepository,
        settingsRepository: settingsRepository,
        startImmediately: startDailyReview,
        onSessionCompleted: onDailyReviewCompleted,
        clock: clock,
      );
    }
    if (selectedNav == 5) {
      return const AiTutorPage();
    }
    if (selectedNav == 6) {
      return SettingsPage(
        profile: profile,
        onProfileChanged: onProfileChanged,
        onResetOnboarding: onResetOnboarding,
        onResetAllData: onResetAllData,
        developmentRepository: developmentRepository,
        settingsRepository: settingsRepository,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 870;
        return desktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: MainDashboard(
                        onResume: onResumeLesson,
                        onStartReview: onStartDailyReview,
                        loadingReview: loadingDailyReview,
                        pendingReviewCount: pendingReviewCount,
                        reviewComplete: dailyReviewComplete,
                        resumeReview: resumeDailyReview,
                        activeLesson: activeLesson,
                        activeLessonSession: activeLessonSession,
                      ),
                    ),
                  ),
                  SizedBox(width: 300, child: RightRail(stats: learningStats)),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    MainDashboard(
                      onResume: onResumeLesson,
                      onStartReview: onStartDailyReview,
                      loadingReview: loadingDailyReview,
                      pendingReviewCount: pendingReviewCount,
                      reviewComplete: dailyReviewComplete,
                      resumeReview: resumeDailyReview,
                      activeLesson: activeLesson,
                      activeLessonSession: activeLessonSession,
                    ),
                    RightRail(compact: true, stats: learningStats),
                  ],
                ),
              );
      },
    );
  }
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.showMenu,
    required this.profile,
    this.totalXp = 0,
  });
  final bool showMenu;
  final LearnerProfile profile;
  final int totalXp;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (showMenu) ...[
            Builder(
              builder: (context) => IconButton(
                onPressed: Scaffold.of(context).openDrawer,
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '你好，${profile.name}',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 20,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'HSK ${profile.hskLevel}  ·  ${profile.dailyWordTarget} words today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF5D4514)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 15, color: AppColors.gold),
                const SizedBox(width: 5),
                Text(
                  '$totalXp XP',
                  style: const TextStyle(fontSize: 12, color: AppColors.gold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Icon(
            Icons.notifications_none_rounded,
            size: 20,
            color: AppColors.muted,
          ),
          const SizedBox(width: 14),
          const CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.darkRed,
            child: Text(
              '学',
              style: TextStyle(color: AppColors.red, fontFamily: 'serif'),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardLearningStats {
  const DashboardLearningStats({
    this.totalXp = 0,
    this.weeklyXp = const [0, 0, 0, 0, 0, 0, 0],
    this.streakDays = 0,
    this.vocabulary = const [],
  });

  final int totalXp;
  final List<int> weeklyXp;
  final int streakDays;
  final List<VocabularyCardProgress> vocabulary;

  factory DashboardLearningStats.fromSavedData({
    required List<ReviewRecord> reviews,
    required List<VocabularyCardProgress> vocabulary,
    required DateTime now,
  }) {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weeklyXp = List<int>.filled(7, 0);
    final activeDays = <DateTime>{};
    var totalXp = 0;

    for (final review in reviews) {
      final xp = review.wasCorrect ? 10 : 5;
      totalXp += xp;
      final reviewed = review.reviewedAt.toLocal();
      final day = DateTime(reviewed.year, reviewed.month, reviewed.day);
      activeDays.add(day);
      final offset = day.difference(weekStart).inDays;
      if (offset >= 0 && offset < 7) weeklyXp[offset] += xp;
    }

    var streakDays = 0;
    var cursor = activeDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    while (activeDays.contains(cursor)) {
      streakDays++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return DashboardLearningStats(
      totalXp: totalXp,
      weeklyXp: weeklyXp,
      streakDays: streakDays,
      vocabulary: vocabulary.take(6).toList(growable: false),
    );
  }
}
