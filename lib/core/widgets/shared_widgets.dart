part of '../../main.dart';

abstract final class _AppErrorCopy {
  static const dailyReviewTitle = 'We couldn’t load today’s review';
  static const dailyReviewMessage =
      'Something went wrong while preparing today’s review cards.';
  static const lessonsTitle = 'We couldn’t load your lessons';
  static const lessonsMessage =
      'Something went wrong while opening your saved lessons.';
  static const vocabularyTitle = 'We couldn’t load vocabulary';
  static const vocabularyMessage =
      'Something went wrong while opening your vocabulary library.';
  static const profileTitle = 'We couldn’t load your profile';
  static const profileMessage =
      'Something went wrong while opening your learning profile.';
  static const preferencesTitle = 'We couldn’t load your preferences';
  static const preferencesMessage =
      'Something went wrong while opening your saved preferences.';

  static const saveProfile = 'We couldn’t save your profile.';
  static const saveChanges = 'We couldn’t save your changes.';
  static const saveAnswer = 'We couldn’t save your answer.';
  static const generateLesson = 'We couldn’t generate your lesson.';
  static const openLesson = 'We couldn’t open this lesson.';
  static const tutor = 'We couldn’t reach Long Laoshi right now.';
  static const addToReview = 'We couldn’t add this word to your review queue.';
  static const resetSetup = 'We couldn’t reset learner setup.';
  static const resetData = 'We couldn’t reset your local data.';
}

class _AppErrorState extends StatelessWidget {
  const _AppErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryKey,
    this.compact = false,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final Key? retryKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final action = _AppRetryButton(
      key: retryKey,
      onPressed: onRetry,
      compact: compact,
    );

    if (compact) {
      return Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border.withValues(alpha: .6)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final details = _AppErrorDetails(title: title, message: message);
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
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 34),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.red.withValues(alpha: .55)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 30,
                    color: AppColors.red,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppErrorDetails extends StatelessWidget {
  const _AppErrorDetails({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox.square(
          dimension: 26,
          child: Center(
            child: Icon(
              Icons.error_outline_rounded,
              size: 24,
              color: AppColors.red,
            ),
          ),
        ),
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
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppRetryButton extends StatelessWidget {
  const _AppRetryButton({
    super.key,
    required this.onPressed,
    this.compact = false,
  });

  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.refresh_rounded, size: 18);
    const label = Text('Try again');
    return compact
        ? OutlinedButton.icon(onPressed: onPressed, icon: icon, label: label)
        : FilledButton.icon(onPressed: onPressed, icon: icon, label: label);
  }
}

class _AppInlineError extends StatelessWidget {
  const _AppInlineError({
    super.key,
    required this.message,
    this.onRetry,
    this.retryKey,
  });

  final String message;
  final VoidCallback? onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkRed.withValues(alpha: .55),
        border: Border.all(color: AppColors.red.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: AppColors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.red,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: _AppRetryButton(
                key: retryKey,
                onPressed: onRetry,
                compact: true,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 9,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.darkRed,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, color: AppColors.red),
      ),
    );
  }
}
