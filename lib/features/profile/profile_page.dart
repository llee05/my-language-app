part of '../../main.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.stats,
    required this.loading,
    required this.loadError,
    required this.onRetry,
    required this.onStartReview,
    required this.onEditProfile,
  });

  final LearnerProfile profile;
  final DashboardLearningStats stats;
  final bool loading;
  final bool loadError;
  final VoidCallback onRetry;
  final VoidCallback onStartReview;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHero(profile: profile, onEditProfile: onEditProfile),
                if (loading) ...[
                  const SizedBox(height: 18),
                  LinearProgressIndicator(
                    key: const Key('profile-analytics-loading'),
                    minHeight: 2,
                    color: AppColors.red,
                    backgroundColor: AppColors.surfaceLight,
                  ),
                ],
                if (loadError) ...[
                  const SizedBox(height: 18),
                  _AppInlineError(
                    message: 'We couldn\'t load your progress analytics.',
                    onRetry: onRetry,
                    retryKey: const Key('retry-profile-analytics'),
                  ),
                ],
                const SizedBox(height: 28),
                const SectionLabel('PROGRESS OVERVIEW'),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 820
                        ? 4
                        : constraints.maxWidth >= 430
                        ? 2
                        : 1;
                    const spacing = 12.0;
                    final width =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        _AnalyticsMetric(
                          width: width,
                          valueKey: const Key('profile-total-xp'),
                          icon: Icons.bolt_rounded,
                          label: 'Total XP',
                          value: '${stats.totalXp}',
                          color: AppColors.gold,
                        ),
                        _AnalyticsMetric(
                          width: width,
                          valueKey: const Key('profile-streak-days'),
                          icon: Icons.local_fire_department_rounded,
                          label: 'Current streak',
                          value: '${stats.streakDays} days',
                          color: AppColors.red,
                        ),
                        _AnalyticsMetric(
                          width: width,
                          valueKey: const Key('profile-accuracy'),
                          icon: Icons.track_changes_rounded,
                          label: 'Answer accuracy',
                          value: stats.reviewCount == 0
                              ? '—'
                              : '${(stats.accuracy * 100).round()}%',
                          color: AppColors.teal,
                        ),
                        _AnalyticsMetric(
                          width: width,
                          valueKey: const Key('profile-review-count'),
                          icon: Icons.task_alt_rounded,
                          label: 'Reviews completed',
                          value: '${stats.reviewCount}',
                          color: AppColors.red,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _HskProgressAnalytics(stats: stats),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final weekly = _ProfilePanel(
                      title: 'THIS WEEK',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WeeklyXp(xpByDay: stats.weeklyXp),
                          const SizedBox(height: 18),
                          _SummaryRow(
                            label: 'Reviews this week',
                            value: '${stats.weeklyReviewCount}',
                          ),
                          const SizedBox(height: 10),
                          _SummaryRow(
                            label: 'All-time study days',
                            value: '${stats.activeStudyDays}',
                          ),
                        ],
                      ),
                    );
                    final vocabulary = _ProfilePanel(
                      title: 'VOCABULARY MASTERY',
                      child: _VocabularyAnalytics(stats: stats),
                    );
                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          weekly,
                          const SizedBox(height: 16),
                          vocabulary,
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: weekly),
                          const SizedBox(width: 16),
                          Expanded(child: vocabulary),
                        ],
                      ),
                    );
                  },
                ),
                if (!loading &&
                    !loadError &&
                    stats.reviewCount == 0 &&
                    stats.wordsSeen == 0) ...[
                  const SizedBox(height: 24),
                  _ProfileEmptyState(onStartReview: onStartReview),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HskProgressAnalytics extends StatelessWidget {
  const _HskProgressAnalytics({required this.stats});

  final DashboardLearningStats stats;

  @override
  Widget build(BuildContext context) {
    final reached = stats.hskLevelReached;
    final nextLevel = stats.nextHskLevel;
    final title = reached == 0 ? 'Building HSK 1' : 'HSK $reached reached';
    final detail = nextLevel == null
        ? 'All 4,991 HSK words mastered'
        : '${stats.nextHskWordsLearned} of ${stats.nextHskWordTarget} '
              'HSK $nextLevel words learned';

    return Container(
      key: const Key('profile-hsk-progress'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('HSK VOCABULARY LEVEL'),
              const SizedBox(height: 10),
              Text(
                title,
                key: const Key('profile-hsk-level-reached'),
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                key: const Key('profile-hsk-next-target'),
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              if (nextLevel != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: stats.nextHskProgress,
                    minHeight: 8,
                    color: AppColors.gold,
                    backgroundColor: AppColors.surfaceLight,
                  ),
                ),
              ],
            ],
          );
          final levels = _HskLevelSteps(reached: reached, nextLevel: nextLevel);
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [summary, const SizedBox(height: 20), levels],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: summary),
              const SizedBox(width: 34),
              Expanded(flex: 2, child: levels),
            ],
          );
        },
      ),
    );
  }
}

class _HskLevelSteps extends StatelessWidget {
  const _HskLevelSteps({required this.reached, required this.nextLevel});

  final int reached;
  final int? nextLevel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 12,
      children: [
        for (var level = 1; level <= 6; level++)
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: level <= reached
                      ? AppColors.teal
                      : level == nextLevel
                      ? AppColors.gold.withValues(alpha: .18)
                      : AppColors.surfaceLight,
                  border: Border.all(
                    color: level <= reached
                        ? AppColors.teal
                        : level == nextLevel
                        ? AppColors.gold
                        : AppColors.border,
                  ),
                ),
                child: level <= reached
                    ? Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: AppColors.background,
                      )
                    : Text(
                        '$level',
                        style: TextStyle(
                          color: level == nextLevel
                              ? AppColors.gold
                              : AppColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
              ),
              const SizedBox(height: 5),
              Text(
                'HSK $level',
                style: TextStyle(color: AppColors.muted, fontSize: 8),
              ),
            ],
          ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, required this.onEditProfile});

  final LearnerProfile profile;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.darkRed,
                child: Text(
                  '学',
                  style: TextStyle(
                    color: AppColors.red,
                    fontFamily: 'serif',
                    fontSize: 25,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      key: const Key('profile-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'HSK ${profile.hskLevel} learner  ·  ${profile.dailyWordTarget}-word daily goal',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
          final editButton = OutlinedButton.icon(
            key: const Key('edit-profile-button'),
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit profile'),
          );
          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: editButton),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 12),
              editButton,
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({
    required this.width,
    required this.valueKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final double width;
  final Key valueKey;
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  key: valueKey,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SectionLabel(title), const SizedBox(height: 16), child],
      ),
    );
  }
}

class _VocabularyAnalytics extends StatelessWidget {
  const _VocabularyAnalytics({required this.stats});

  final DashboardLearningStats stats;

  @override
  Widget build(BuildContext context) {
    final masteryProgress = stats.wordsSeen == 0
        ? 0.0
        : stats.wordsLearned / stats.wordsSeen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${(masteryProgress * 100).round()}%',
              key: const Key('profile-mastery-percent'),
              style: TextStyle(
                color: AppColors.text,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  'of seen words learned',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: masteryProgress,
            minHeight: 9,
            color: AppColors.teal,
            backgroundColor: AppColors.surfaceLight,
          ),
        ),
        const SizedBox(height: 22),
        _SummaryRow(label: 'Words seen', value: '${stats.wordsSeen}'),
        const SizedBox(height: 10),
        _SummaryRow(label: 'Still learning', value: '${stats.wordsLearning}'),
        const SizedBox(height: 10),
        _SummaryRow(label: 'Learned', value: '${stats.wordsLearned}'),
        const SizedBox(height: 10),
        _SummaryRow(
          label: 'Correct answers',
          value: '${stats.correctReviewCount}',
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.muted, fontSize: 11)),
        Text(
          value,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfileEmptyState extends StatelessWidget {
  const _ProfileEmptyState({required this.onStartReview});

  final VoidCallback onStartReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkRed.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, color: AppColors.red, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your progress story starts here',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete reviews to build your accuracy, XP, streak, and mastery trends.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onStartReview,
            child: const Text('Start review'),
          ),
        ],
      ),
    );
  }
}
