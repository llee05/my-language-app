part of '../../main.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    required this.onResetOnboarding,
    required this.onResetAllData,
    this.onBackupRestored,
    required this.appThemeId,
    required this.onThemeChanged,
    required this.lessonRepository,
    required this.progressRepository,
    this.dailyReviewSessionRepository,
    required this.settingsRepository,
    required this.developmentRepository,
    this.aiConfigurationRepository = const SecureAiConfigurationRepository(),
    this.tutorContextRepository = const SqliteTutorContextRepository(),
    this.pronunciationService,
    this.speechInputService,
    this.clock,
    this.backupRepository = const SqliteBackupRepository(),
    this.backupFileService = const FilePickerBackupFileService(),
  });

  final LearnerProfile profile;
  final Future<void> Function(LearnerProfile profile) onProfileChanged;
  final Future<void> Function() onResetOnboarding;
  final Future<void> Function() onResetAllData;
  final Future<void> Function()? onBackupRestored;
  final AppThemeId appThemeId;
  final void Function(AppThemeId themeId) onThemeChanged;
  final LessonRepository lessonRepository;
  final ProgressRepository progressRepository;
  final DailyReviewSessionRepository? dailyReviewSessionRepository;
  final SettingsRepository settingsRepository;
  final DevelopmentRepository developmentRepository;
  final AiConfigurationRepository aiConfigurationRepository;
  final TutorContextRepository tutorContextRepository;
  final PronunciationService? pronunciationService;
  final SpeechInputService? speechInputService;
  final DateTime Function()? clock;
  final BackupRepository backupRepository;
  final BackupFileService backupFileService;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  double _menuSwipeDistance = 0;
  late final PronunciationService _pronunciationService;
  late final bool _ownsPronunciationService;
  late final SpeechInputService _speechInputService;
  late final bool _ownsSpeechInputService;
  int selectedNav = 0;
  bool _resumeLatestLesson = false;
  bool _startDailyReview = false;
  bool _loadingDailyReview = true;
  bool _dailyReviewLoadError = false;
  int _dailyReviewRequestId = 0;
  int _pendingReviewCount = 0;
  bool _dailyReviewComplete = false;
  bool _resumeDailyReview = false;
  Lesson? _activeLesson;
  LessonSession? _activeLessonSession;
  DashboardLearningStats _learningStats = const DashboardLearningStats();
  bool _loadingLearningStats = true;
  bool _learningStatsLoadError = false;
  List<Lesson> _availableLessons = const [];
  bool _loadingAvailableLessons = true;
  bool _availableLessonsLoadError = false;
  int _availableLessonsRequestId = 0;

  @override
  void initState() {
    super.initState();
    _ownsPronunciationService = widget.pronunciationService == null;
    _pronunciationService =
        widget.pronunciationService ?? createSystemPronunciationService();
    _ownsSpeechInputService = widget.speechInputService == null;
    _speechInputService =
        widget.speechInputService ?? createSystemSpeechInputService();
    _loadDailyReviewPrompt();
    _loadActiveLesson();
    _loadLearningStats();
    _loadAvailableLessons();
  }

  @override
  void dispose() {
    if (_ownsPronunciationService) {
      unawaited(_pronunciationService.dispose());
    } else {
      unawaited(_pronunciationService.stop());
    }
    if (_ownsSpeechInputService) {
      unawaited(_speechInputService.dispose());
    } else {
      unawaited(_speechInputService.cancelListening());
    }
    super.dispose();
  }

  Future<void> _loadAvailableLessons() async {
    final requestId = ++_availableLessonsRequestId;
    if (!_loadingAvailableLessons && mounted) {
      setState(() {
        _loadingAvailableLessons = true;
        _availableLessonsLoadError = false;
      });
    }
    try {
      final summaries = await widget.lessonRepository.topics();
      final lessons = await Future.wait(
        summaries.map(
          (summary) => widget.lessonRepository.findById(summary.id),
        ),
      );
      if (!mounted || requestId != _availableLessonsRequestId) return;
      setState(() {
        _availableLessons = lessons.whereType<Lesson>().toList(growable: false);
        _loadingAvailableLessons = false;
        _availableLessonsLoadError = false;
      });
    } catch (error) {
      debugPrint('Dashboard lessons load failed: $error');
      if (!mounted || requestId != _availableLessonsRequestId) return;
      setState(() {
        _availableLessons = const [];
        _loadingAvailableLessons = false;
        _availableLessonsLoadError = true;
      });
    }
  }

  Future<void> _loadLearningStats() async {
    if (!_loadingLearningStats && mounted) {
      setState(() {
        _loadingLearningStats = true;
        _learningStatsLoadError = false;
      });
    }
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
        _loadingLearningStats = false;
        _learningStatsLoadError = false;
      });
    } catch (error) {
      debugPrint('Learning analytics load failed: $error');
      if (!mounted) return;
      setState(() {
        _learningStats = const DashboardLearningStats();
        _loadingLearningStats = false;
        _learningStatsLoadError = true;
      });
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
    final requestId = ++_dailyReviewRequestId;
    if (!_loadingDailyReview && mounted) {
      setState(() {
        _loadingDailyReview = true;
        _dailyReviewLoadError = false;
      });
    }
    try {
      final now = widget.clock?.call() ?? DateTime.now();
      final queue = await widget.progressRepository.dailyQueue(
        forDay: now,
        limit: widget.profile.dailyWordTarget,
        maxHskLevel: widget.profile.hskLevel,
      );
      final session = await widget.dailyReviewSessionRepository?.load(now);
      if (!mounted || requestId != _dailyReviewRequestId) return;
      setState(() {
        _pendingReviewCount = queue.length;
        _dailyReviewComplete = session?.isComplete == true || queue.isEmpty;
        _resumeDailyReview =
            queue.isNotEmpty &&
            session != null &&
            !session.isComplete &&
            session.currentPosition > 0;
        _loadingDailyReview = false;
        _dailyReviewLoadError = false;
      });
    } catch (error) {
      debugPrint('Daily review prompt load failed: $error');
      if (!mounted || requestId != _dailyReviewRequestId) return;
      setState(() {
        _pendingReviewCount = 0;
        _dailyReviewComplete = false;
        _resumeDailyReview = false;
        _loadingDailyReview = false;
        _dailyReviewLoadError = true;
      });
    }
  }

  void _selectNavigation(int value) {
    setState(() {
      selectedNav = value;
      _resumeLatestLesson = false;
      _startDailyReview = false;
    });
    if (value == 0) {
      _refreshDashboardData();
    }
  }

  void _refreshDashboardData() {
    unawaited(_loadDailyReviewPrompt());
    unawaited(_loadActiveLesson());
    unawaited(_loadLearningStats());
    unawaited(_loadAvailableLessons());
  }

  void _resumeLesson() {
    setState(() {
      selectedNav = 1;
      _resumeLatestLesson = true;
    });
  }

  void _openLessons() {
    setState(() {
      selectedNav = 1;
      _resumeLatestLesson = false;
    });
  }

  void _openDailyReview() {
    setState(() {
      selectedNav = 6;
      _startDailyReview = true;
    });
  }

  void _openProfile() => setState(() {
    selectedNav = 9;
    _resumeLatestLesson = false;
    _startDailyReview = false;
  });

  void _openSettings() => _selectNavigation(8);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidebar = constraints.maxWidth >= 760;
        final enableMenuSwipe =
            !showSidebar &&
            Theme.of(context).platform == TargetPlatform.android;

        final scaffold = Scaffold(
          key: _scaffoldKey,
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
          body: SafeArea(
            child: Row(
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
                        profileSelected: selectedNav == 9,
                        onProfilePressed: _openProfile,
                      ),
                      Expanded(
                        child: _DashboardBody(
                          selectedNav: selectedNav,
                          resumeLatestLesson: _resumeLatestLesson,
                          startDailyReview: _startDailyReview,
                          onResumeLesson: _resumeLesson,
                          onOpenLessons: _openLessons,
                          onStartDailyReview: _openDailyReview,
                          onRetryDailyReview: _loadDailyReviewPrompt,
                          onRetryAvailableLessons: _loadAvailableLessons,
                          onDailyReviewCompleted: _loadDailyReviewPrompt,
                          onLearningProgressChanged: _loadLearningStats,
                          onLessonProgressChanged: _refreshDashboardData,
                          loadingDailyReview: _loadingDailyReview,
                          dailyReviewLoadError: _dailyReviewLoadError,
                          pendingReviewCount: _pendingReviewCount,
                          dailyReviewComplete: _dailyReviewComplete,
                          resumeDailyReview: _resumeDailyReview,
                          activeLesson: _activeLesson,
                          activeLessonSession: _activeLessonSession,
                          learningStats: _learningStats,
                          loadingLearningStats: _loadingLearningStats,
                          learningStatsLoadError: _learningStatsLoadError,
                          onRetryLearningStats: _loadLearningStats,
                          onOpenProfileSettings: _openSettings,
                          availableLessons: _availableLessons,
                          loadingAvailableLessons: _loadingAvailableLessons,
                          availableLessonsLoadError: _availableLessonsLoadError,
                          profile: widget.profile,
                          onProfileChanged: widget.onProfileChanged,
                          onResetOnboarding: widget.onResetOnboarding,
                          onResetAllData: widget.onResetAllData,
                          onBackupRestored: widget.onBackupRestored,
                          appThemeId: widget.appThemeId,
                          onThemeChanged: widget.onThemeChanged,
                          lessonRepository: widget.lessonRepository,
                          progressRepository: widget.progressRepository,
                          dailyReviewSessionRepository:
                              widget.dailyReviewSessionRepository,
                          settingsRepository: widget.settingsRepository,
                          developmentRepository: widget.developmentRepository,
                          aiConfigurationRepository:
                              widget.aiConfigurationRepository,
                          tutorContextRepository: widget.tutorContextRepository,
                          pronunciationService: _pronunciationService,
                          speechInputService: _speechInputService,
                          clock: widget.clock,
                          backupRepository: widget.backupRepository,
                          backupFileService: widget.backupFileService,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        // Child controls keep their horizontal scrolling gestures. Swipes on
        // the rest of the Android page open the menu after a deliberate drag.
        return GestureDetector(
          onHorizontalDragStart: enableMenuSwipe
              ? (_) => _menuSwipeDistance = 0
              : null,
          onHorizontalDragUpdate: enableMenuSwipe
              ? (details) => _menuSwipeDistance += details.primaryDelta ?? 0
              : null,
          onHorizontalDragEnd: enableMenuSwipe
              ? (_) {
                  if (_menuSwipeDistance >= 64) {
                    _scaffoldKey.currentState?.openDrawer();
                  }
                }
              : null,
          child: scaffold,
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
    required this.onOpenLessons,
    required this.onStartDailyReview,
    required this.onRetryDailyReview,
    required this.onRetryAvailableLessons,
    required this.onDailyReviewCompleted,
    required this.onLearningProgressChanged,
    required this.onLessonProgressChanged,
    required this.loadingDailyReview,
    required this.dailyReviewLoadError,
    required this.pendingReviewCount,
    required this.dailyReviewComplete,
    required this.resumeDailyReview,
    required this.activeLesson,
    required this.activeLessonSession,
    required this.learningStats,
    required this.loadingLearningStats,
    required this.learningStatsLoadError,
    required this.onRetryLearningStats,
    required this.onOpenProfileSettings,
    required this.availableLessons,
    required this.loadingAvailableLessons,
    required this.availableLessonsLoadError,
    required this.profile,
    required this.onProfileChanged,
    required this.onResetOnboarding,
    required this.onResetAllData,
    this.onBackupRestored,
    required this.appThemeId,
    required this.onThemeChanged,
    required this.lessonRepository,
    required this.progressRepository,
    this.dailyReviewSessionRepository,
    required this.settingsRepository,
    required this.developmentRepository,
    this.aiConfigurationRepository = const SecureAiConfigurationRepository(),
    this.tutorContextRepository = const SqliteTutorContextRepository(),
    required this.pronunciationService,
    required this.speechInputService,
    this.clock,
    this.backupRepository = const SqliteBackupRepository(),
    this.backupFileService = const FilePickerBackupFileService(),
  });
  final int selectedNav;
  final bool resumeLatestLesson;
  final bool startDailyReview;
  final VoidCallback onResumeLesson;
  final VoidCallback onOpenLessons;
  final VoidCallback onStartDailyReview;
  final VoidCallback onRetryDailyReview;
  final VoidCallback onRetryAvailableLessons;
  final VoidCallback onDailyReviewCompleted;
  final VoidCallback onLearningProgressChanged;
  final VoidCallback onLessonProgressChanged;
  final bool loadingDailyReview;
  final bool dailyReviewLoadError;
  final int pendingReviewCount;
  final bool dailyReviewComplete;
  final bool resumeDailyReview;
  final Lesson? activeLesson;
  final LessonSession? activeLessonSession;
  final DashboardLearningStats learningStats;
  final bool loadingLearningStats;
  final bool learningStatsLoadError;
  final VoidCallback onRetryLearningStats;
  final VoidCallback onOpenProfileSettings;
  final List<Lesson> availableLessons;
  final bool loadingAvailableLessons;
  final bool availableLessonsLoadError;
  final LearnerProfile profile;
  final Future<void> Function(LearnerProfile profile) onProfileChanged;
  final Future<void> Function() onResetOnboarding;
  final Future<void> Function() onResetAllData;
  final Future<void> Function()? onBackupRestored;
  final AppThemeId appThemeId;
  final void Function(AppThemeId themeId) onThemeChanged;
  final LessonRepository lessonRepository;
  final ProgressRepository progressRepository;
  final DailyReviewSessionRepository? dailyReviewSessionRepository;
  final SettingsRepository settingsRepository;
  final DevelopmentRepository developmentRepository;
  final AiConfigurationRepository aiConfigurationRepository;
  final TutorContextRepository tutorContextRepository;
  final PronunciationService pronunciationService;
  final SpeechInputService speechInputService;
  final DateTime Function()? clock;
  final BackupRepository backupRepository;
  final BackupFileService backupFileService;

  @override
  Widget build(BuildContext context) {
    if (selectedNav == 1) {
      return LessonsPage(
        aiService: AiService(
          configurationRepository: aiConfigurationRepository,
        ),
        repository: lessonRepository,
        progressRepository: progressRepository,
        settingsRepository: settingsRepository,
        pronunciationService: pronunciationService,
        speechInputService: speechInputService,
        resumeLatest: resumeLatestLesson,
        onProgressChanged: onLessonProgressChanged,
      );
    }
    if (selectedNav == 2) {
      return AiRoleplayMissionsPage(
        aiService: AiService(
          configurationRepository: aiConfigurationRepository,
        ),
        settingsRepository: settingsRepository,
        tutorContextRepository: tutorContextRepository,
        pronunciationService: pronunciationService,
        speechInputService: speechInputService,
        clock: clock,
      );
    }
    if (selectedNav == 3) {
      return ListeningPracticePage(
        lessonRepository: lessonRepository,
        settingsRepository: settingsRepository,
        pronunciationService: pronunciationService,
        maxHskLevel: profile.hskLevel,
      );
    }
    if (selectedNav == 4) {
      return VocabRushPage(
        lessonRepository: lessonRepository,
        progressRepository: progressRepository,
        dailyReviewSessionRepository: dailyReviewSessionRepository,
        settingsRepository: settingsRepository,
        pronunciationService: pronunciationService,
      );
    }
    if (selectedNav == 5) {
      return VocabularyPage(
        progressRepository: progressRepository,
        settingsRepository: settingsRepository,
        pronunciationService: pronunciationService,
      );
    }
    if (selectedNav == 6) {
      return DailyQueuePage(
        profile: profile,
        progressRepository: progressRepository,
        sessionRepository: dailyReviewSessionRepository,
        settingsRepository: settingsRepository,
        pronunciationService: pronunciationService,
        startImmediately: startDailyReview,
        onSessionCompleted: onDailyReviewCompleted,
        onProgressChanged: onLearningProgressChanged,
        clock: clock,
      );
    }
    if (selectedNav == 7) {
      return AiTutorPage(
        aiService: AiService(
          configurationRepository: aiConfigurationRepository,
        ),
        settingsRepository: settingsRepository,
        tutorContextRepository: tutorContextRepository,
        pronunciationService: pronunciationService,
        speechInputService: speechInputService,
        clock: clock,
      );
    }
    if (selectedNav == 8) {
      return SettingsPage(
        aiConfigurationRepository: aiConfigurationRepository,
        profile: profile,
        onProfileChanged: onProfileChanged,
        onResetOnboarding: onResetOnboarding,
        onResetAllData: onResetAllData,
        onBackupRestored: onBackupRestored,
        appThemeId: appThemeId,
        onThemeChanged: onThemeChanged,
        developmentRepository: developmentRepository,
        settingsRepository: settingsRepository,
        pronunciationService: pronunciationService,
        backupRepository: backupRepository,
        backupFileService: backupFileService,
      );
    }
    if (selectedNav == 9) {
      return ProfilePage(
        profile: profile,
        stats: learningStats,
        loading: loadingLearningStats,
        loadError: learningStatsLoadError,
        onRetry: onRetryLearningStats,
        onStartReview: onStartDailyReview,
        onEditProfile: onOpenProfileSettings,
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
                        onStartLearning: onOpenLessons,
                        onStartReview: onStartDailyReview,
                        onRetryReview: onRetryDailyReview,
                        onRetryLessons: onRetryAvailableLessons,
                        loadingReview: loadingDailyReview,
                        reviewLoadError: dailyReviewLoadError,
                        pendingReviewCount: pendingReviewCount,
                        reviewComplete: dailyReviewComplete,
                        resumeReview: resumeDailyReview,
                        activeLesson: activeLesson,
                        activeLessonSession: activeLessonSession,
                        isNewLearner:
                            !loadingLearningStats &&
                            activeLesson == null &&
                            learningStats.totalXp == 0 &&
                            learningStats.wordsSeen == 0,
                        availableLessons: availableLessons,
                        loadingAvailableLessons: loadingAvailableLessons,
                        availableLessonsLoadError: availableLessonsLoadError,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: RightRail(
                      stats: learningStats,
                      onReviewAll: onStartDailyReview,
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    MainDashboard(
                      onResume: onResumeLesson,
                      onStartLearning: onOpenLessons,
                      onStartReview: onStartDailyReview,
                      onRetryReview: onRetryDailyReview,
                      onRetryLessons: onRetryAvailableLessons,
                      loadingReview: loadingDailyReview,
                      reviewLoadError: dailyReviewLoadError,
                      pendingReviewCount: pendingReviewCount,
                      reviewComplete: dailyReviewComplete,
                      resumeReview: resumeDailyReview,
                      activeLesson: activeLesson,
                      activeLessonSession: activeLessonSession,
                      isNewLearner:
                          !loadingLearningStats &&
                          activeLesson == null &&
                          learningStats.totalXp == 0 &&
                          learningStats.wordsSeen == 0,
                      availableLessons: availableLessons,
                      loadingAvailableLessons: loadingAvailableLessons,
                      availableLessonsLoadError: availableLessonsLoadError,
                    ),
                    RightRail(
                      compact: true,
                      stats: learningStats,
                      onReviewAll: onStartDailyReview,
                    ),
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
    this.profileSelected = false,
    this.onProfilePressed,
  });
  final bool showMenu;
  final LearnerProfile profile;
  final int totalXp;
  final bool profileSelected;
  final VoidCallback? onProfilePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
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
                Icon(Icons.bolt_rounded, size: 15, color: AppColors.gold),
                const SizedBox(width: 5),
                Text(
                  '$totalXp XP',
                  style: TextStyle(fontSize: 12, color: AppColors.gold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Tooltip(
            message: 'Open profile',
            child: Material(
              color: profileSelected ? AppColors.red : AppColors.darkRed,
              shape: CircleBorder(
                side: BorderSide(
                  color: profileSelected ? AppColors.gold : AppColors.red,
                  width: profileSelected ? 2 : 1,
                ),
              ),
              child: InkWell(
                key: const Key('open-profile-button'),
                onTap: onProfilePressed,
                customBorder: const CircleBorder(),
                child: SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: Text(
                      '学',
                      style: TextStyle(
                        color: profileSelected
                            ? AppColors.background
                            : AppColors.red,
                        fontFamily: 'serif',
                      ),
                    ),
                  ),
                ),
              ),
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
    this.wordsSeen = 0,
    this.wordsLearning = 0,
    this.wordsLearned = 0,
    this.reviewCount = 0,
    this.correctReviewCount = 0,
    this.activeStudyDays = 0,
    this.weeklyReviewCount = 0,
    this.hskWordsLearned = const [0, 0, 0, 0, 0, 0],
    this.vocabulary = const [],
  });

  static const hskVocabularyTotals = [150, 147, 298, 598, 1298, 2500];

  final int totalXp;
  final List<int> weeklyXp;
  final int streakDays;
  final int wordsSeen;
  final int wordsLearning;
  final int wordsLearned;
  final int reviewCount;
  final int correctReviewCount;
  final int activeStudyDays;
  final int weeklyReviewCount;
  final List<int> hskWordsLearned;
  final List<VocabularyCardProgress> vocabulary;

  double get accuracy =>
      reviewCount == 0 ? 0 : correctReviewCount / reviewCount;

  int get hskLevelReached {
    var reached = 0;
    for (var index = 0; index < hskVocabularyTotals.length; index++) {
      if (hskWordsLearned[index] < hskVocabularyTotals[index]) break;
      reached = index + 1;
    }
    return reached;
  }

  int? get nextHskLevel => hskLevelReached >= 6 ? null : hskLevelReached + 1;

  int get nextHskWordsLearned {
    final next = nextHskLevel;
    return next == null ? hskVocabularyTotals.last : hskWordsLearned[next - 1];
  }

  int get nextHskWordTarget {
    final next = nextHskLevel;
    return next == null
        ? hskVocabularyTotals.last
        : hskVocabularyTotals[next - 1];
  }

  double get nextHskProgress =>
      (nextHskWordsLearned / nextHskWordTarget).clamp(0, 1);

  factory DashboardLearningStats.fromSavedData({
    required List<ReviewRecord> reviews,
    required List<VocabularyCardProgress> vocabulary,
    required DateTime now,
  }) {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weeklyXp = List<int>.filled(7, 0);
    var totalXp = 0;
    var correctReviewCount = 0;
    var weeklyReviewCount = 0;
    final activeDays = <(int, int, int)>{};

    for (final review in reviews) {
      final xp = review.wasCorrect ? 10 : 5;
      totalXp += xp;
      if (review.wasCorrect) correctReviewCount++;
      final reviewed = review.reviewedAt.toLocal();
      final day = DateTime(reviewed.year, reviewed.month, reviewed.day);
      activeDays.add((day.year, day.month, day.day));
      final offset = day.difference(weekStart).inDays;
      if (offset >= 0 && offset < 7) {
        weeklyXp[offset] += xp;
        weeklyReviewCount++;
      }
    }

    final seenVocabulary = vocabulary
        .where((word) => word.progress.timesSeen > 0)
        .toList(growable: false);
    final wordsLearned = seenVocabulary
        .where((word) => word.progress.mastery >= .8)
        .length;
    final learnedWordsByLevel = [
      for (var level = 0; level < 6; level++) <String>{},
    ];
    for (final word in seenVocabulary) {
      if (word.progress.mastery < .8) continue;
      learnedWordsByLevel[word.hskLevel - 1].add(word.chinese);
    }

    return DashboardLearningStats(
      totalXp: totalXp,
      weeklyXp: weeklyXp,
      streakDays: calculateCurrentStudyStreak(
        studiedAt: reviews.map((review) => review.reviewedAt),
        now: now,
      ),
      wordsSeen: seenVocabulary.length,
      wordsLearning: seenVocabulary.length - wordsLearned,
      wordsLearned: wordsLearned,
      reviewCount: reviews.length,
      correctReviewCount: correctReviewCount,
      activeStudyDays: activeDays.length,
      weeklyReviewCount: weeklyReviewCount,
      hskWordsLearned: learnedWordsByLevel
          .map((words) => words.length)
          .toList(growable: false),
      vocabulary: seenVocabulary.take(6).toList(growable: false),
    );
  }
}
