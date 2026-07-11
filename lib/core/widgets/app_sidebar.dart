part of '../../main.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, this.selectedIndex = 0, this.onSelected});
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  static const items = [
    (Icons.home_outlined, 'Home'),
    (Icons.style_outlined, 'Lessons'),
    (Icons.sports_martial_arts_rounded, 'Vocab Rush'),
    (Icons.language_rounded, 'Vocabulary'),
    (Icons.bar_chart_rounded, 'Progress'),
    (Icons.chat_bubble_outline_rounded, 'AI Tutor'),
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
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.red,
                    size: 22,
                  ),
                  SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      '汉字路',
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
              const Padding(
                padding: EdgeInsets.only(left: 31, top: 4, bottom: 24),
                child: Text(
                  'Mandarin · Beginner',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _NavItem(
                    icon: items[i].$1,
                    label: items[i].$2,
                    selected: selectedIndex == i,
                    onTap: () {
                      onSelected?.call(i);
                      if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0B09),
                  border: Border.all(color: const Color(0xFF5A1E16)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: AppColors.red,
                        ),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '7-day streak',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Text(
                      '加油！ Keep going today.',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Divider(),
              const _NavItem(icon: Icons.settings_outlined, label: 'Settings'),
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
    return Material(
      color: selected ? const Color(0xFF2A0D0A) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppColors.red : AppColors.muted,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? AppColors.red : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
