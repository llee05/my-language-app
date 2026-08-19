part of '../../../main.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({
    super.key,
    required this.onResume,
    required this.onStartLearning,
    required this.onStartReview,
    this.onRetryReview,
    this.onRetryLessons,
    required this.loadingReview,
    this.reviewLoadError = false,
    required this.pendingReviewCount,
    required this.reviewComplete,
    required this.resumeReview,
    required this.activeLesson,
    required this.activeLessonSession,
    required this.isNewLearner,
    required this.availableLessons,
    required this.loadingAvailableLessons,
    this.availableLessonsLoadError = false,
  });

  final VoidCallback onResume;
  final VoidCallback onStartLearning;
  final VoidCallback onStartReview;
  final VoidCallback? onRetryReview;
  final VoidCallback? onRetryLessons;
  final bool loadingReview;
  final bool reviewLoadError;
  final int pendingReviewCount;
  final bool reviewComplete;
  final bool resumeReview;
  final Lesson? activeLesson;
  final LessonSession? activeLessonSession;
  final bool isNewLearner;
  final List<Lesson> availableLessons;
  final bool loadingAvailableLessons;
  final bool availableLessonsLoadError;

  @override
  Widget build(BuildContext context) {
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
            hasError: reviewLoadError,
            pendingCount: pendingReviewCount,
            complete: reviewComplete,
            resume: resumeReview,
            newLearner: isNewLearner,
            onPressed: onStartReview,
            onRetry: onRetryReview,
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
          const SectionLabel('AVAILABLE HSK LESSONS'),
          const SizedBox(height: 8),
          if (loadingAvailableLessons)
            const _AvailableLessonsLoading()
          else if (availableLessonsLoadError)
            _AvailableLessonsError(onRetry: onRetryLessons)
          else if (availableLessons.isEmpty)
            _AvailableLessonsEmpty(onBrowse: onStartLearning),
          for (final availableLesson in availableLessons.take(6))
            LessonTile(
              title: availableLesson.summary.title,
              chinese: availableLesson.summary.theme,
              unit: 'HSK ${availableLesson.summary.hskLevel}',
              duration:
                  '${availableLesson.cards.length} card${availableLesson.cards.length == 1 ? '' : 's'}',
              xp: 'Up to ${availableLesson.cards.length * 10} XP',
              state: availableLesson.summary.id == activeLesson?.summary.id
                  ? LessonState.active
                  : LessonState.available,
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

class _AvailableLessonsLoading extends StatelessWidget {
  const _AvailableLessonsLoading();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('available-lessons-loading-state'),
    container: true,
    liveRegion: true,
    child: const _AvailableLessonsStateCard(
      icon: SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          color: AppColors.red,
          strokeWidth: 2.5,
          semanticsLabel: 'Loading available lessons',
        ),
      ),
      title: 'Loading available lessons',
      message: 'Finding lessons that match your current HSK level.',
    ),
  );
}

class _AvailableLessonsError extends StatelessWidget {
  const _AvailableLessonsError({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _AppErrorState(
    key: const Key('available-lessons-error-state'),
    title: _AppErrorCopy.lessonsTitle,
    message: _AppErrorCopy.lessonsMessage,
    onRetry: onRetry,
    retryKey: const Key('available-lessons-retry'),
    compact: true,
  );
}

class _AvailableLessonsEmpty extends StatelessWidget {
  const _AvailableLessonsEmpty({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('available-lessons-empty-state'),
    container: true,
    liveRegion: true,
    child: _AvailableLessonsStateCard(
      icon: const Icon(Icons.menu_book_outlined, color: AppColors.teal),
      title: 'No saved lessons yet',
      message: 'Create a lesson to start building your library.',
      action: OutlinedButton.icon(
        onPressed: onBrowse,
        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
        label: const Text('Browse lessons'),
      ),
    ),
  );
}

class _AvailableLessonsStateCard extends StatelessWidget {
  const _AvailableLessonsStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final Widget icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border.withValues(alpha: .6)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final details = Row(
          children: [
            SizedBox.square(dimension: 26, child: Center(child: icon)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final action = this.action;
        if (action == null) return details;
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [details, const SizedBox(height: 14), action],
          );
        }
        return Row(
          children: [
            Expanded(child: details),
            const SizedBox(width: 12),
            action,
          ],
        );
      },
    ),
  );
}

class _DailyReviewPrompt extends StatelessWidget {
  const _DailyReviewPrompt({
    required this.loading,
    required this.hasError,
    required this.pendingCount,
    required this.complete,
    required this.resume,
    required this.newLearner,
    required this.onPressed,
    required this.onRetry,
  });

  final bool loading;
  final bool hasError;
  final int pendingCount;
  final bool complete;
  final bool resume;
  final bool newLearner;
  final VoidCallback onPressed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: hasError ? AppColors.red : AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: loading
            ? const _DailyReviewPromptLoading()
            : hasError
            ? _DailyReviewPromptError(onRetry: onRetry)
            : complete
            ? const _DailyReviewPromptComplete()
            : _buildPending(),
      ),
    );
  }

  Widget _buildPending() => Row(
    key: const ValueKey('daily-review-prompt-pending'),
    children: [
      const Icon(Icons.style_outlined, color: AppColors.gold),
      const SizedBox(width: 12),
      Expanded(
        child: newLearner
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learn your first $pendingCount word${pendingCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Reveal each meaning and rate how well you knew it. We’ll schedule the next review for you.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              )
            : Text(
                '$pendingCount card${pendingCount == 1 ? '' : 's'} pending today',
                style: const TextStyle(color: AppColors.text),
              ),
      ),
      const SizedBox(width: 12),
      FilledButton(
        onPressed: pendingCount == 0 ? null : onPressed,
        child: Text(
          resume
              ? 'Resume review'
              : newLearner
              ? 'Begin first review'
              : 'Start review',
        ),
      ),
    ],
  );
}

class _DailyReviewPromptLoading extends StatelessWidget {
  const _DailyReviewPromptLoading();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('daily-review-prompt-loading'),
    container: true,
    liveRegion: true,
    child: const Row(
      children: [
        SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            color: AppColors.red,
            strokeWidth: 2.5,
            semanticsLabel: 'Loading daily review',
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Checking today’s review',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Finding due, weak, and new cards for you.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DailyReviewPromptComplete extends StatelessWidget {
  const _DailyReviewPromptComplete();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('daily-review-prompt-complete'),
    container: true,
    liveRegion: true,
    child: const Row(
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
    ),
  );
}

class _DailyReviewPromptError extends StatelessWidget {
  const _DailyReviewPromptError({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _AppErrorState(
    key: const ValueKey('daily-review-prompt-error'),
    title: _AppErrorCopy.dailyReviewTitle,
    message: _AppErrorCopy.dailyReviewMessage,
    onRetry: onRetry,
    retryKey: const Key('daily-review-prompt-retry'),
    compact: true,
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

enum LessonState { available, done, active, locked }

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
