part of '../../../main.dart';

class RightRail extends StatelessWidget {
  const RightRail({super.key, this.compact = false, required this.stats});
  final bool compact;
  final DashboardLearningStats stats;

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
          ? Wrap(
              spacing: 22,
              runSpacing: 24,
              children: [
                SizedBox(width: 270, child: WeeklyXp(xpByDay: stats.weeklyXp)),
                SizedBox(
                  width: 270,
                  child: VocabularyPanel(words: stats.vocabulary),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WeeklyXp(xpByDay: stats.weeklyXp),
                  const SizedBox(height: 26),
                  VocabularyPanel(words: stats.vocabulary),
                ],
              ),
            ),
    );
  }
}

class WeeklyXp extends StatelessWidget {
  const WeeklyXp({super.key, required this.xpByDay});
  final List<int> xpByDay;

  @override
  Widget build(BuildContext context) {
    final maxXp = xpByDay.fold<int>(0, max);
    final heights = xpByDay
        .map((xp) => maxXp == 0 ? 0.0 : 58 * xp / maxXp)
        .toList(growable: false);
    final totalXp = xpByDay.fold<int>(0, (total, xp) => total + xp);
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'This week',
                    style: TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                  Text(
                    '$totalXp XP',
                    style: const TextStyle(
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
  const VocabularyPanel({super.key, required this.words});
  final List<VocabularyCardProgress> words;

  @override
  Widget build(BuildContext context) {
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
        if (words.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Review vocabulary to see mastery here.',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ),
        for (final word in words)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: VocabularyCard(
              hanzi: word.chinese,
              pinyin: word.pinyin,
              mastery: word.progress.mastery,
              color: word.progress.mastery >= .8
                  ? AppColors.teal
                  : word.progress.mastery >= .5
                  ? AppColors.gold
                  : AppColors.red,
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
