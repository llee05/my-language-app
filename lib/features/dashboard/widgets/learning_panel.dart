part of '../../../main.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key, required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final lessons = flashcardLessons;
    final continueLesson = lessons.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('CONTINUE LEARNING'),
          const SizedBox(height: 12),
          ContinueCard(
            lessonTitle: continueLesson['lesson_title'] as String,
            theme: continueLesson['theme'] as String,
            level: continueLesson['hsk_level'] as int,
            duration: '20 cards',
            xpReward: 60,
            progress: 0.35,
            onResume: onResume,
          ),
          const SizedBox(height: 26),
          const SectionLabel('SUGGESTED LESSONS'),
          const SizedBox(height: 8),
          const SizedBox(height: 4),
          for (var i = 0; i < lessons.length; i++)
            LessonTile(
              title: lessons[i]['lesson_title'] as String,
              chinese: lessons[i]['theme'] as String,
              unit: 'HSK ${lessons[i]['hsk_level']}',
              duration: '20 cards',
              xp: '+${50 + i * 10} XP',
              state: i == 0
                  ? LessonState.active
                  : i <= 2
                  ? LessonState.done
                  : LessonState.locked,
            ),
        ],
      ),
    );
  }
}

class ContinueCard extends StatelessWidget {
  const ContinueCard({
    super.key,
    required this.lessonTitle,
    required this.theme,
    required this.level,
    required this.duration,
    required this.xpReward,
    required this.onResume,
    this.progress = .35,
  });

  final String lessonTitle;
  final String theme;
  final int level;
  final String duration;
  final int xpReward;
  final VoidCallback onResume;
  final double progress;

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
                  Icons.book_rounded,
                  size: 31,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Pill(label: 'HSK $level'),
                        const SizedBox(width: 8),
                        const Text(
                          'Lesson 1',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      lessonTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$theme · $duration · $xpReward XP reward',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: onResume,
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
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        color: AppColors.red,
                        backgroundColor: const Color(0xFF49302D),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
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
