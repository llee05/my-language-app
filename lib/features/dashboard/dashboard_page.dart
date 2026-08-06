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
    required this.settingsRepository,
    required this.developmentRepository,
  });

  final LearnerProfile profile;
  final Future<void> Function(LearnerProfile profile) onProfileChanged;
  final Future<void> Function() onResetOnboarding;
  final Future<void> Function() onResetAllData;
  final LessonRepository lessonRepository;
  final ProgressRepository progressRepository;
  final SettingsRepository settingsRepository;
  final DevelopmentRepository developmentRepository;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedNav = 0;
  bool _resumeLatestLesson = false;

  void _selectNavigation(int value) {
    setState(() {
      selectedNav = value;
      _resumeLatestLesson = false;
    });
  }

  void _resumeLesson() {
    setState(() {
      selectedNav = 1;
      _resumeLatestLesson = true;
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
                    onSelected: _selectNavigation,
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    DashboardHeader(
                      showMenu: !showSidebar,
                      profile: widget.profile,
                    ),
                    Expanded(
                      child: _DashboardBody(
                        selectedNav: selectedNav,
                        resumeLatestLesson: _resumeLatestLesson,
                        onResumeLesson: _resumeLesson,
                        profile: widget.profile,
                        onProfileChanged: widget.onProfileChanged,
                        onResetOnboarding: widget.onResetOnboarding,
                        onResetAllData: widget.onResetAllData,
                        lessonRepository: widget.lessonRepository,
                        progressRepository: widget.progressRepository,
                        settingsRepository: widget.settingsRepository,
                        developmentRepository: widget.developmentRepository,
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
    required this.onResumeLesson,
    required this.profile,
    required this.onProfileChanged,
    required this.onResetOnboarding,
    required this.onResetAllData,
    required this.lessonRepository,
    required this.progressRepository,
    required this.settingsRepository,
    required this.developmentRepository,
  });
  final int selectedNav;
  final bool resumeLatestLesson;
  final VoidCallback onResumeLesson;
  final LearnerProfile profile;
  final Future<void> Function(LearnerProfile profile) onProfileChanged;
  final Future<void> Function() onResetOnboarding;
  final Future<void> Function() onResetAllData;
  final LessonRepository lessonRepository;
  final ProgressRepository progressRepository;
  final SettingsRepository settingsRepository;
  final DevelopmentRepository developmentRepository;

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
      );
    }
    if (selectedNav == 3) {
      return VocabularyPage(progressRepository: progressRepository);
    }
    if (selectedNav == 4) {
      return DailyQueuePage(
        profile: profile,
        progressRepository: progressRepository,
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
                      child: MainDashboard(onResume: onResumeLesson),
                    ),
                  ),
                  const SizedBox(width: 300, child: RightRail()),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    MainDashboard(onResume: onResumeLesson),
                    const RightRail(compact: true),
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
  });
  final bool showMenu;
  final LearnerProfile profile;

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
            child: const Row(
              children: [
                Icon(Icons.bolt_rounded, size: 15, color: AppColors.gold),
                SizedBox(width: 5),
                Text(
                  '455 XP',
                  style: TextStyle(fontSize: 12, color: AppColors.gold),
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
