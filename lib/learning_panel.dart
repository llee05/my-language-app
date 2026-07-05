part of 'main.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('CONTINUE LEARNING'),
          const SizedBox(height: 12),
          const ContinueCard(),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionLabel('ALL LESSONS'),
              TextButton.icon(
                onPressed: () {},
                label: const Text(
                  'Unit 1–3',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                iconAlignment: IconAlignment.end,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const LessonTile(
            title: 'Greetings & Politeness',
            chinese: '问候与礼貌',
            unit: 'Unit 1',
            duration: '10 min',
            xp: '+40 XP',
            state: LessonState.done,
          ),
          const LessonTile(
            title: 'Numbers & Dates',
            chinese: '数字与日期',
            unit: 'Unit 1',
            duration: '14 min',
            xp: '+50 XP',
            state: LessonState.done,
          ),
          const LessonTile(
            title: 'Family & Relationships',
            chinese: '家庭与关系',
            unit: 'Unit 2',
            duration: '18 min',
            xp: '+60 XP',
            state: LessonState.active,
          ),
          const LessonTile(
            title: 'Food & Restaurants',
            chinese: '饮食与餐厅',
            unit: 'Unit 2',
            duration: '20 min',
            xp: '+70 XP',
            state: LessonState.locked,
          ),
          const LessonTile(
            title: 'Travel & Directions',
            chinese: '旅行与方向',
            unit: 'Unit 3',
            duration: '22 min',
            xp: '+80 XP',
            state: LessonState.locked,
          ),
        ],
      ),
    );
  }
}

class ContinueCard extends StatelessWidget {
  const ContinueCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF261111), Color(0xFF351311)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: const Color(0xFF632019)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;
          final details = Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.darkRed,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  size: 31,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Pill(label: 'Unit 2'),
                        SizedBox(width: 8),
                        Text(
                          'Lesson 3',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Family & Relationships',
                      style: TextStyle(fontSize: 17, color: AppColors.text),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '家庭与关系 · 18 min · 60 XP reward',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Resuming Family & Relationships…')),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            label: const Text('Resume', style: TextStyle(fontSize: 12)),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (narrow) ...[
                details,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerRight, child: button),
              ] else
                Row(
                  children: [
                    Expanded(child: details),
                    button,
                  ],
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: const LinearProgressIndicator(
                        value: .35,
                        minHeight: 5,
                        color: AppColors.red,
                        backgroundColor: Color(0xFF49302D),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '35%',
                    style: TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

enum LessonState { done, active, locked }

class LessonTile extends StatelessWidget {
  const LessonTile({
    super.key,
    required this.title,
    required this.chinese,
    required this.unit,
    required this.duration,
    required this.xp,
    required this.state,
  });
  final String title;
  final String chinese;
  final String unit;
  final String duration;
  final String xp;
  final LessonState state;

  @override
  Widget build(BuildContext context) {
    final active = state == LessonState.active;
    final done = state == LessonState.done;
    final contentColor = state == LessonState.locked
        ? AppColors.faint
        : AppColors.text;
    return Opacity(
      opacity: state == LessonState.locked ? .48 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1B0D0C) : AppColors.surface,
          border: Border.all(
            color: active ? const Color(0xFF711C14) : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(
              done
                  ? Icons.check_circle_outline_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: done
                  ? AppColors.teal
                  : (active ? AppColors.red : AppColors.faint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(fontSize: 12, color: contentColor),
                        ),
                      ),
                      if (active) ...[
                        const SizedBox(width: 8),
                        const _Pill(label: 'In progress'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$chinese · $unit · $duration',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              xp,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
