part of '../../main.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    this.selectedIndex = 0,
    this.hskLevel = 1,
    this.streakDays = 0,
    this.onSelected,
  });
  final int selectedIndex;
  final int hskLevel;
  final int streakDays;
  final ValueChanged<int>? onSelected;

  static const items = [
    (Icons.home_outlined, 'Home'),
    (Icons.style_outlined, 'Lessons'),
    (Icons.flag_outlined, 'Roleplay Missions'),
    (Icons.hearing_rounded, 'Listening Practice'),
    (Icons.sports_martial_arts_rounded, 'Vocab Rush'),
    (Icons.language_rounded, 'Dictionary'),
    (Icons.swipe_up_rounded, 'Doom Scrolling'),
    (Icons.chat_bubble_outline_rounded, 'AI Tutor'),
    (Icons.assignment_outlined, 'Exam Mode'),
  ];

  static const _groups = [
    ('STUDY', [0, 1, 3, 6]),
    ('PRACTICE & REFERENCE', [4, 8, 5]),
    ('AI CONVERSATION', [2, 7]),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.sidebar,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.red,
                    size: 22,
                  ),
                  SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      '听说 TingShuo',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 31, top: 6, bottom: 22),
                child: Text(
                  'Mandarin · HSK $hskLevel',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final group in _groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 0, 10),
                        child: Text(
                          group.$1,
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                            color: AppColors.faint,
                          ),
                        ),
                      ),
                      for (final index in group.$2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _NavItem(
                            icon: items[index].$1,
                            label: items[index].$2,
                            selected: selectedIndex == index,
                            onTap: () {
                              onSelected?.call(index);
                              if (Scaffold.maybeOf(context)?.hasDrawer ??
                                  false) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: .08),
                  border: Border.all(
                    color: AppColors.red.withValues(alpha: .25),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: AppColors.red,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '$streakDays-day streak',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      streakDays == 0
                          ? 'Practise a word to start your streak.'
                          : '加油！ Keep going today.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                selected: selectedIndex == items.length,
                onTap: () {
                  onSelected?.call(items.length);
                  if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? AppColors.red.withValues(alpha: .14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppColors.red : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.red : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
