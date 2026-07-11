part of '../../main.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedNav = 0;

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
                    onSelected: (value) => setState(() => selectedNav = value),
                  ),
                ),
          body: Row(
            children: [
              if (showSidebar)
                SizedBox(
                  width: 210,
                  child: AppSidebar(
                    selectedIndex: selectedNav,
                    onSelected: (value) => setState(() => selectedNav = value),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    DashboardHeader(showMenu: !showSidebar),
                    Expanded(child: _DashboardBody(selectedNav: selectedNav)),
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
  const _DashboardBody({required this.selectedNav});
  final int selectedNav;

  @override
  Widget build(BuildContext context) {
    if (selectedNav == 1) {
      return const VocabRushPage();
    }
    if (selectedNav == 4) {
      return const AiTutorPage();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 870;
        return desktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(child: MainDashboard()),
                  ),
                  const SizedBox(width: 300, child: RightRail()),
                ],
              )
            : const SingleChildScrollView(
                child: Column(
                  children: [MainDashboard(), RightRail(compact: true)],
                ),
              );
      },
    );
  }
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.showMenu});
  final bool showMenu;

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
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '早上好，学员',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 20,
                    color: AppColors.text,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Thursday, July 3rd  ·  2 lessons remaining today',
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
