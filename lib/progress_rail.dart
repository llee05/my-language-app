part of 'main.dart';

class RightRail extends StatelessWidget {
  const RightRail({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: compact
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            )
          : const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.border)),
            ),
      padding: EdgeInsets.fromLTRB(
        compact ? 32 : 20,
        28,
        compact ? 32 : 20,
        32,
      ),
      child: compact
          ? const Wrap(
              spacing: 22,
              runSpacing: 24,
              children: [
                SizedBox(width: 270, child: WeeklyXp()),
                SizedBox(width: 270, child: VocabularyPanel()),
                SizedBox(width: 270, child: Achievements()),
              ],
            )
          : const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WeeklyXp(),
                  SizedBox(height: 26),
                  VocabularyPanel(),
                  SizedBox(height: 26),
                  Achievements(),
                ],
              ),
            ),
    );
  }
}

class WeeklyXp extends StatelessWidget {
  const WeeklyXp({super.key});

  @override
  Widget build(BuildContext context) {
    const heights = [30.0, 47.0, 23.0, 58.0, 38.0, 43.0, 20.0];
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('WEEKLY XP'),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 78,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < heights.length; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 24,
                              height: heights[i],
                              decoration: BoxDecoration(
                                color: i == 6
                                    ? AppColors.red
                                    : const Color(0xFF5B1A16),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              days[i],
                              style: TextStyle(
                                fontSize: 9,
                                color: i == 6 ? AppColors.red : AppColors.faint,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 20),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'This week',
                    style: TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                  Text(
                    '660 XP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VocabularyPanel extends StatelessWidget {
  const VocabularyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    const words = [
      ('猫', 'māo', .85, AppColors.teal),
      ('家', 'jiā', .72, AppColors.gold),
      ('朋友', 'péngyǒu', .60, AppColors.gold),
      ('水', 'shuǐ', .91, AppColors.teal),
      ('山', 'shān', .33, AppColors.red),
      ('龙', 'lóng', .48, AppColors.red),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel('VOCABULARY'),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Practice all',
                style: TextStyle(fontSize: 10, color: AppColors.red),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        for (final word in words)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: VocabularyCard(
              hanzi: word.$1,
              pinyin: word.$2,
              mastery: word.$3,
              color: word.$4,
            ),
          ),
      ],
    );
  }
}

class VocabularyCard extends StatefulWidget {
  const VocabularyCard({
    super.key,
    required this.hanzi,
    required this.pinyin,
    required this.mastery,
    required this.color,
  });
  final String hanzi;
  final String pinyin;
  final double mastery;
  final Color color;

  @override
  State<VocabularyCard> createState() => _VocabularyCardState();
}

class _VocabularyCardState extends State<VocabularyCard> {
  bool revealed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => setState(() => revealed = !revealed),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(width: 2, height: 34, color: widget.color),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 40,
                    child: Text(
                      widget.hanzi,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 22,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          revealed ? widget.pinyin : '••••',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          revealed ? 'tap to hide' : 'tap to reveal',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: widget.mastery,
                  minHeight: 4,
                  color: widget.color,
                  backgroundColor: const Color(0xFF3B2A28),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mastery',
                    style: TextStyle(fontSize: 9, color: AppColors.muted),
                  ),
                  Text(
                    '${(widget.mastery * 100).round()}%',
                    style: const TextStyle(fontSize: 9, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Achievements extends StatelessWidget {
  const Achievements({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('ACHIEVEMENTS'),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _Achievement(
                icon: Icons.local_fire_department_outlined,
                label: '7-Day\nStreak',
                color: AppColors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Achievement(
                icon: Icons.star_border_rounded,
                label: 'First 100\nXP',
                color: AppColors.gold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Achievement(
                icon: Icons.bolt_outlined,
                label: 'Speed\nLearner',
                color: AppColors.gold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Achievement extends StatelessWidget {
  const _Achievement({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: const Color(0xFF594018)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.muted,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
