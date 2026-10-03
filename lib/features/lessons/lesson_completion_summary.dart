part of '../../main.dart';

class _LessonCompletionSummary extends StatelessWidget {
  const _LessonCompletionSummary({
    super.key,
    this.vocabularyPractice,
    required this.title,
    required this.isSentence,
    required this.reviewed,
    required this.correct,
    required this.newCards,
    required this.revisitedCards,
    required this.cardsToRevisit,
    required this.ratings,
    required this.nextLessonTitle,
    required this.openingNextLesson,
    required this.onNextLesson,
    required this.onDone,
    required this.onSpeak,
  });

  final Widget? vocabularyPractice;
  final String title;
  final bool isSentence;
  final int reviewed;
  final int correct;
  final int newCards;
  final int revisitedCards;
  final List<Flashcard> cardsToRevisit;
  final Map<int, ReviewRating> ratings;
  final String? nextLessonTitle;
  final bool openingNextLesson;
  final VoidCallback? onNextLesson;
  final VoidCallback? onDone;
  final Future<void> Function(Flashcard)? onSpeak;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final summary = _buildSummary(context, compact: compact);
      if (!compact) return summary;
      return Column(
        children: [
          Expanded(child: summary),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (nextLessonTitle != null) ...[
                  Text(
                    'Up next: $nextLessonTitle',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                ],
                _buildActions(),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _buildSummary(BuildContext context, {required bool compact}) {
    final accuracy = reviewed == 0 ? 0 : (correct * 100 / reviewed).round();
    final xp = correct * 10 + (reviewed - correct) * 5;
    final noun = isSentence ? 'sentences' : 'words';
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SingleChildScrollView(
      key: const Key('lesson-completion-summary'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 20 : 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                    AppColors.gold.withValues(alpha: .08),
                    AppColors.surface,
                  ),
                  AppColors.surface,
                ],
              ),
              border: Border.all(color: AppColors.gold.withValues(alpha: .4)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, child) => Column(
                    children: [
                      ExcludeSemantics(
                        child: SizedBox.square(
                          dimension: 160,
                          child: CustomPaint(
                            painter: _LessonCelebrationPainter(
                              progress: progress,
                              gold: AppColors.gold,
                              accent: AppColors.teal,
                            ),
                            child: Center(
                              child: Transform.scale(
                                scale:
                                    .7 +
                                    .3 *
                                        Curves.easeOutBack.transform(
                                          (progress * 2).clamp(0.0, 1.0),
                                        ),
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.gold.withValues(
                                      alpha: .12,
                                    ),
                                    border: Border.all(
                                      color: AppColors.gold.withValues(
                                        alpha: .45,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.emoji_events_rounded,
                                    size: 54,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(
                          'Lesson complete!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        label: '$xp XP earned',
                        child: ExcludeSemantics(
                          child: SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '+${(xp * progress).round()} XP',
                                key: const Key('lesson-completion-xp'),
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'XP earned',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  cardsToRevisit.isEmpty
                      ? 'A strong finish. Keep coming back to make it stick.'
                      : 'You finished the whole lesson. A little more practice '
                            'will help the tricky $noun stick.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.text, height: 1.5),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SummaryStat(
                      icon: Icons.task_alt_rounded,
                      label: isSentence
                          ? 'Sentences practiced'
                          : 'Words practiced',
                      value: '$reviewed',
                    ),
                    _SummaryStat(
                      icon: Icons.track_changes,
                      label: 'Accuracy',
                      value: '$accuracy%',
                    ),
                    _SummaryStat(
                      icon: Icons.school_outlined,
                      label: isSentence ? 'New sentences' : 'New words',
                      value: '$newCards',
                    ),
                    _SummaryStat(
                      icon: Icons.replay_outlined,
                      label: isSentence
                          ? 'Sentences revisited'
                          : 'Words revisited',
                      value: '$revisitedCards',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppColors.teal,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your ratings are saved and your next reviews are scheduled.',
                        style: TextStyle(color: AppColors.muted, height: 1.4),
                      ),
                    ),
                  ],
                ),
                if (cardsToRevisit.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Material(
                    color: Colors.transparent,
                    child: ExpansionTile(
                      key: const Key('lesson-revisit-list'),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      title: Text(
                        isSentence
                            ? 'Sentences to revisit'
                            : 'Words to revisit',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${cardsToRevisit.length} rated Again or Hard',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      children: [
                        for (final card in cardsToRevisit)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        card.chinese,
                                        style: TextStyle(
                                          fontSize: 22,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      Text(
                                        card.pinyin,
                                        style: TextStyle(color: AppColors.gold),
                                      ),
                                      Text(
                                        card.englishMeaning,
                                        style: TextStyle(
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ratings[card.id] == ReviewRating.again
                                            ? 'Again'
                                            : 'Hard',
                                        style: TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (onSpeak != null)
                                  PronunciationButton(
                                    key: ValueKey(
                                      'lesson-revisit-audio-${card.id}',
                                    ),
                                    requestKey: card.id,
                                    onPressed: () => onSpeak!(card),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                ?vocabularyPractice,
                if (!compact && nextLessonTitle != null) ...[
                  const SizedBox(height: 24),
                  const SectionLabel('UP NEXT'),
                  const SizedBox(height: 8),
                  Text(
                    nextLessonTitle!,
                    key: const Key('lesson-completion-next-title'),
                    style: TextStyle(color: AppColors.text, fontSize: 16),
                  ),
                ],
                if (!compact) ...[const SizedBox(height: 24), _buildActions()],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() => Wrap(
    alignment: WrapAlignment.center,
    spacing: 12,
    runSpacing: 12,
    children: [
      if (nextLessonTitle != null)
        FilledButton.icon(
          key: const Key('lesson-completion-next'),
          onPressed: onNextLesson,
          icon: openingNextLesson
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_rounded),
          label: Text(openingNextLesson ? 'Opening lesson…' : 'Next lesson'),
        ),
      if (nextLessonTitle != null)
        OutlinedButton.icon(
          key: const Key('lesson-completion-done'),
          onPressed: onDone,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Done'),
        )
      else
        FilledButton.icon(
          key: const Key('lesson-completion-done'),
          onPressed: onDone,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Done'),
        ),
    ],
  );
}

class _LessonCelebrationPainter extends CustomPainter {
  const _LessonCelebrationPainter({
    required this.progress,
    required this.gold,
    required this.accent,
  });

  final double progress;
  final Color gold;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ring = Paint()
      ..color = gold.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 58),
      -pi / 2,
      2 * pi * progress,
      false,
      ring,
    );
    for (var index = 0; index < 12; index++) {
      final angle = index * pi / 6 - pi / 2;
      final radius = 48 + 26 * progress;
      final position = center + Offset(cos(angle), sin(angle)) * radius;
      final paint = Paint()
        ..color = (index.isEven ? gold : accent).withValues(
          alpha: .8 * (1 - progress) + .2,
        );
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle + progress * pi);
      if (index.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-2, -4, 4, 8),
            const Radius.circular(1),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LessonCelebrationPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      gold != oldDelegate.gold ||
      accent != oldDelegate.accent;
}
