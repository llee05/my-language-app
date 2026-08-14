part of '../../../main.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({
    super.key,
    required this.onResume,
    required this.onStartLearning,
    required this.onStartReview,
    required this.loadingReview,
    required this.pendingReviewCount,
    required this.reviewComplete,
    required this.resumeReview,
    required this.activeLesson,
    required this.activeLessonSession,
    required this.isNewLearner,
  });

  final VoidCallback onResume;
  final VoidCallback onStartLearning;
  final VoidCallback onStartReview;
  final bool loadingReview;
  final int pendingReviewCount;
  final bool reviewComplete;
  final bool resumeReview;
  final Lesson? activeLesson;
  final LessonSession? activeLessonSession;
  final bool isNewLearner;

  @override
  Widget build(BuildContext context) {
    final lessons = flashcardLessons;
    final lesson = activeLesson;
    final session = activeLessonSession;
    final lessonProgress =
        lesson == null || session == null || lesson.cards.isEmpty
        ? 0.0
        : (session.cardsReviewed / lesson.cards.length)
              .clamp(0.0, 1.0)
              .toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('DAILY REVIEW'),
          const SizedBox(height: 12),
          _DailyReviewPrompt(
            loading: loadingReview,
            pendingCount: pendingReviewCount,
            complete: reviewComplete,
            resume: resumeReview,
            onPressed: onStartReview,
          ),
          if (isNewLearner) ...[
            const SizedBox(height: 26),
            _NewLearnerPrompt(onPressed: onStartLearning),
          ],
          if (lesson != null && session != null) ...[
            const SizedBox(height: 26),
            const SectionLabel('CONTINUE LEARNING'),
            const SizedBox(height: 12),
            ContinueCard(
              lessonTitle: lesson.summary.title,
              theme: lesson.summary.theme,
              level: lesson.summary.hskLevel,
              duration: '${lesson.cards.length} cards',
              xpReward: 60,
              progress: lessonProgress,
              onResume: onResume,
            ),
          ],
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
                  : !isNewLearner && i <= 2
                  ? LessonState.done
                  : LessonState.locked,
            ),
        ],
      ),
    );
  }
}

class _NewLearnerPrompt extends StatelessWidget {
  const _NewLearnerPrompt({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1310), Color(0xFF25120F)],
      ),
      border: Border.all(color: const Color(0xFF5D4514)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.waving_hand_rounded, color: AppColors.gold, size: 34),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start your first lesson',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Learn a few words to begin building your streak, XP, and vocabulary mastery.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(onPressed: onPressed, child: const Text('Browse lessons')),
      ],
    ),
  );
}

class _DailyReviewPrompt extends StatelessWidget {
  const _DailyReviewPrompt({
    required this.loading,
    required this.pendingCount,
    required this.complete,
    required this.resume,
    required this.onPressed,
  });

  final bool loading;
  final int pendingCount;
  final bool complete;
  final bool resume;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: loading
        ? const LinearProgressIndicator(color: AppColors.red)
        : complete
        ? const Row(
            children: [
              Icon(Icons.task_alt, color: AppColors.teal),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Daily review complete — you’re all done!',
                  style: TextStyle(color: AppColors.text),
                ),
              ),
            ],
          )
        : Row(
            children: [
              const Icon(Icons.style_outlined, color: AppColors.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$pendingCount card${pendingCount == 1 ? '' : 's'} pending today',
                  style: const TextStyle(color: AppColors.text),
                ),
              ),
              FilledButton(
                onPressed: pendingCount == 0 ? null : onPressed,
                child: Text(resume ? 'Resume review' : 'Start review'),
              ),
            ],
          ),
  );
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
