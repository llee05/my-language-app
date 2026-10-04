part of '../../../main.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({
    super.key,
    required this.onResume,
    required this.onStartLearning,
    required this.onStartReview,
    this.onRetryReview,
    this.onRetryLessons,
    required this.onLessonSelected,
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
  final ValueChanged<Lesson> onLessonSelected;
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
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
        28,
        MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('DOOM SCROLLING'),
          const SizedBox(height: 12),
          _DiscoveryPrompt(
            loading: loadingReview,
            hasError: reviewLoadError,
            pendingCount: pendingReviewCount,
            complete: reviewComplete,
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
          Row(
            children: [
              const Expanded(child: SectionLabel('AVAILABLE HSK LESSONS')),
              IconButton(
                key: const Key('available-lessons-refresh'),
                tooltip: 'Refresh lessons',
                onPressed: loadingAvailableLessons ? null : onRetryLessons,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (loadingAvailableLessons)
            const _AvailableLessonsLoading()
          else if (availableLessonsLoadError)
            _AvailableLessonsError(onRetry: onRetryLessons)
          else if (availableLessons.isEmpty)
            _AvailableLessonsEmpty(onBrowse: onStartLearning),
          for (final availableLesson in availableLessons.take(6))
            LessonTile(
              key: ValueKey('available-lesson-${availableLesson.summary.id}'),
              title: availableLesson.summary.title,
              chinese: availableLesson.summary.theme,
              unit: 'HSK ${availableLesson.summary.hskLevel}',
              duration:
                  '${availableLesson.cards.length} card${availableLesson.cards.length == 1 ? '' : 's'}',
              xp: 'Up to ${availableLesson.cards.length * 10} XP',
              state: availableLesson.summary.id == activeLesson?.summary.id
                  ? LessonState.active
                  : LessonState.available,
              onTap: () => onLessonSelected(availableLesson),
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
    child: LayoutBuilder(
      builder: (context, constraints) {
        final details = Row(
          children: [
            Icon(Icons.waving_hand_rounded, color: AppColors.gold, size: 34),
            const SizedBox(width: 16),
            Expanded(
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
          ],
        );
        final action = FilledButton(
          onPressed: onPressed,
          child: const Text('Browse lessons'),
        );
        if (constraints.maxWidth < 440) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [details, const SizedBox(height: 16), action],
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

class _AvailableLessonsLoading extends StatelessWidget {
  const _AvailableLessonsLoading();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('available-lessons-loading-state'),
    container: true,
    liveRegion: true,
    child: _AvailableLessonsStateCard(
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
      icon: Icon(Icons.menu_book_outlined, color: AppColors.teal),
      title: 'No saved lessons yet',
      message: 'Open Lessons to load the bundled vocabulary library.',
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
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
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

class _DiscoveryPrompt extends StatelessWidget {
  const _DiscoveryPrompt({
    required this.loading,
    required this.hasError,
    required this.pendingCount,
    required this.complete,
    required this.onPressed,
    required this.onRetry,
  });

  final bool loading;
  final bool hasError;
  final int pendingCount;
  final bool complete;
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
            ? const _DiscoveryPromptLoading()
            : hasError
            ? _DiscoveryPromptError(onRetry: onRetry)
            : complete
            ? const _DiscoveryPromptComplete()
            : _buildPending(),
      ),
    );
  }

  Widget _buildPending() => Column(
    key: const ValueKey('discovery-prompt-pending'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$pendingCount unlearned word${pendingCount == 1 ? '' : 's'} to discover',
        style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text(
        'Swipe through a random mix. Rate a word when you practise it.',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.swipe_up_rounded),
        label: const Text('Start scrolling'),
      ),
    ],
  );
}

class _DiscoveryPromptLoading extends StatelessWidget {
  const _DiscoveryPromptLoading();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('discovery-prompt-loading'),
    container: true,
    liveRegion: true,
    child: Row(
      children: [
        SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            color: AppColors.red,
            strokeWidth: 2.5,
            semanticsLabel: 'Loading word feed',
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finding words to discover',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Checking your vocabulary progress.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DiscoveryPromptComplete extends StatelessWidget {
  const _DiscoveryPromptComplete();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('discovery-prompt-complete'),
    container: true,
    liveRegion: true,
    child: Row(
      children: [
        Icon(Icons.task_alt, color: AppColors.teal),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'You’ve learned every bundled word!',
            style: TextStyle(color: AppColors.text),
          ),
        ),
      ],
    ),
  );
}

class _DiscoveryPromptError extends StatelessWidget {
  const _DiscoveryPromptError({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _AppErrorState(
    key: const ValueKey('discovery-prompt-error'),
    title: 'The word feed could not be loaded',
    message: 'Please try again.',
    onRetry: onRetry,
    retryKey: const Key('discovery-prompt-retry'),
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
                child: Icon(
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Pill(label: 'HSK $level'),
                        Text(
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
                      style: TextStyle(fontSize: 17, color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$theme · $duration · $xpReward XP reward',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: onResume,
            label: const Text('Resume'),
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
    this.onTap,
  });
  final String title;
  final String chinese;
  final String unit;
  final String duration;
  final String xp;
  final LessonState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = state == LessonState.active;
    final done = state == LessonState.done;
    final contentColor = state == LessonState.locked
        ? AppColors.faint
        : AppColors.text;
    return Opacity(
      opacity: state == LessonState.locked ? .48 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: active ? const Color(0xFF1B0D0C) : AppColors.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: active ? const Color(0xFF711C14) : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: state == LessonState.locked ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 380;
                  final xpLabel = Text(
                    xp,
                    style: TextStyle(fontSize: 10, color: AppColors.muted),
                  );
                  return Row(
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
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: contentColor,
                                  ),
                                ),
                                if (active) const _Pill(label: 'In progress'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$chinese · $unit · $duration',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                            if (compact) ...[
                              const SizedBox(height: 6),
                              xpLabel,
                            ],
                          ],
                        ),
                      ),
                      if (!compact) ...[const SizedBox(width: 10), xpLabel],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
