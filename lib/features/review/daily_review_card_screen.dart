part of '../../main.dart';

class DailyReviewCardScreen extends StatefulWidget {
  const DailyReviewCardScreen({
    super.key,
    required this.queue,
    this.initialPosition = 0,
    this.showPinyin = true,
    this.onClose,
    this.onAnswer,
    this.onSpeak,
    this.onStopAudio,
  });

  final List<DailyQueueCard> queue;
  final int initialPosition;
  final bool showPinyin;
  final VoidCallback? onClose;
  final Future<void> Function(Flashcard card)? onSpeak;
  final Future<void> Function()? onStopAudio;
  final Future<void> Function(
    int position,
    Flashcard card,
    ReviewRating rating,
  )?
  onAnswer;

  @override
  State<DailyReviewCardScreen> createState() => _DailyReviewCardScreenState();
}

class _DailyReviewCardScreenState extends State<DailyReviewCardScreen> {
  late int _position;
  bool _meaningRevealed = false;
  final Map<int, ReviewRating> _answers = {};
  bool _savingAnswer = false;
  String? _answerError;
  ReviewRating? _failedRating;
  bool _showSummary = false;

  @override
  void initState() {
    super.initState();
    _position = widget.queue.isEmpty
        ? 0
        : widget.initialPosition.clamp(0, widget.queue.length - 1);
  }

  @override
  void dispose() {
    _stopAudio();
    super.dispose();
  }

  void _stopAudio() {
    final onStopAudio = widget.onStopAudio;
    if (onStopAudio != null) unawaited(onStopAudio());
  }

  void _close() {
    _stopAudio();
    widget.onClose?.call();
  }

  void _finish() {
    _stopAudio();
    setState(() => _showSummary = true);
  }

  void _move(int offset) {
    if (_savingAnswer) return;
    final next = _position + offset;
    if (next < 0 || next >= widget.queue.length) return;
    _stopAudio();
    setState(() {
      _position = next;
      _meaningRevealed = false;
      _answerError = null;
      _failedRating = null;
    });
  }

  Future<void> _selectAnswer(ReviewRating rating) async {
    if (_savingAnswer || _answers.containsKey(_position)) return;
    _stopAudio();
    final submittedPosition = _position;
    final submittedCard = widget.queue[submittedPosition].card;
    setState(() {
      _savingAnswer = true;
      _answerError = null;
      _failedRating = null;
    });
    try {
      await widget.onAnswer?.call(submittedPosition, submittedCard, rating);
      if (!mounted) return;
      setState(() => _answers[submittedPosition] = rating);
    } catch (error) {
      debugPrint('Daily review answer save failed: $error');
      if (!mounted) return;
      setState(() {
        _answerError = _AppErrorCopy.saveAnswer;
        _failedRating = rating;
      });
    } finally {
      if (mounted) setState(() => _savingAnswer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.queue.isEmpty) {
      return ColoredBox(
        color: AppColors.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = constraints.hasBoundedHeight
                ? max(0.0, constraints.maxHeight - 48)
                : 0.0;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: _DailyQueueStateCard(
                  key: const Key('daily-review-cards-empty-state'),
                  accent: AppColors.teal,
                  icon: const Icon(
                    Icons.task_alt_rounded,
                    size: 31,
                    color: AppColors.teal,
                  ),
                  title: 'You’re all caught up',
                  message: 'There are no cards to review.',
                  action: widget.onClose == null
                      ? null
                      : OutlinedButton.icon(
                          onPressed: _close,
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Back to review queue'),
                        ),
                ),
              ),
            );
          },
        ),
      );
    }
    if (_showSummary) return _buildCompletionSummary();
    final card = widget.queue[_position].card;
    final selectedAnswer = _answers[_position];
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back to review queue',
                  onPressed: _savingAnswer ? null : _close,
                  icon: const Icon(Icons.close),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Daily review',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${_position + 1} of ${widget.queue.length}',
                  key: const Key('daily-review-position'),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (_position + 1) / widget.queue.length,
              color: AppColors.red,
              backgroundColor: AppColors.surface,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: Text(
                              card.chinese,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'serif',
                                fontSize: 76,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              key: const Key('daily-review-pronunciation'),
                              tooltip: widget.onSpeak == null
                                  ? 'Pronunciation audio is disabled in Settings'
                                  : 'Hear Mandarin pronunciation',
                              onPressed: widget.onSpeak == null
                                  ? null
                                  : () => unawaited(widget.onSpeak!(card)),
                              icon: const Icon(Icons.volume_up_outlined),
                            ),
                          ),
                        ],
                      ),
                      if (widget.showPinyin) ...[
                        const SizedBox(height: 8),
                        Text(
                          card.pinyin,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      if (_meaningRevealed) ...[
                        Text(
                          card.englishMeaning,
                          key: const Key('daily-review-meaning'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: ReviewRating.values
                              .map(
                                (rating) => _ReviewAnswerButton(
                                  rating: rating,
                                  selected: selectedAnswer == rating,
                                  onPressed:
                                      _savingAnswer ||
                                          selectedAnswer != null ||
                                          _answerError != null
                                      ? null
                                      : () => _selectAnswer(rating),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        if (_answerError != null) ...[
                          const SizedBox(height: 8),
                          _AppInlineError(
                            key: const Key('daily-review-answer-error'),
                            message: _answerError!,
                            onRetry: _failedRating == null
                                ? null
                                : () => _selectAnswer(_failedRating!),
                            retryKey: const Key('daily-review-answer-retry'),
                          ),
                        ],
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: selectedAnswer == null
                              ? const Text(
                                  'Choose how well you remembered this card.',
                                  key: Key('review-answer-prompt'),
                                  style: TextStyle(color: AppColors.muted),
                                )
                              : Text(
                                  '${_ratingLabel(selectedAnswer)} selected',
                                  key: const Key('selected-review-answer'),
                                  style: const TextStyle(
                                    color: AppColors.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ] else
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _meaningRevealed = true),
                          child: const Text('Reveal meaning'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _savingAnswer || _position == 0
                        ? null
                        : () => _move(-1),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: selectedAnswer == null
                        ? null
                        : _position == widget.queue.length - 1
                        ? _finish
                        : () => _move(1),
                    icon: Icon(
                      _position == widget.queue.length - 1
                          ? Icons.check
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      _position == widget.queue.length - 1 ? 'Finish' : 'Next',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionSummary() {
    final reviewed = _answers.length;
    final correct = _answers.values
        .where((rating) => rating != ReviewRating.again)
        .length;
    final accuracy = reviewed == 0 ? 0 : ((correct / reviewed) * 100).round();
    final answeredPositions = _answers.keys;
    final learned = answeredPositions
        .where(
          (index) => widget.queue[index].reason == DailyQueueReason.newWord,
        )
        .length;
    final reviewWords = reviewed - learned;
    final xp = learned * 10 + reviewWords * 5;
    return ColoredBox(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      size: 54,
                      color: AppColors.gold,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Daily review complete!',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _DailyReviewSummaryStat(
                          label: 'Cards reviewed',
                          value: '$reviewed',
                        ),
                        _DailyReviewSummaryStat(
                          label: 'Accuracy',
                          value: '$accuracy%',
                        ),
                        _DailyReviewSummaryStat(
                          label: 'Learned words',
                          value: '$learned',
                        ),
                        _DailyReviewSummaryStat(
                          label: 'Review words',
                          value: '$reviewWords',
                        ),
                        _DailyReviewSummaryStat(
                          label: 'XP earned',
                          value: '+$xp XP',
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: widget.onClose == null ? null : _close,
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyReviewSummaryStat extends StatelessWidget {
  const _DailyReviewSummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _ReviewAnswerButton extends StatelessWidget {
  const _ReviewAnswerButton({
    required this.rating,
    required this.selected,
    required this.onPressed,
  });

  final ReviewRating rating;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = _ratingLabel(rating);
    if (selected) {
      return FilledButton.icon(
        key: Key('review-answer-${rating.name}'),
        onPressed: onPressed,
        icon: const Icon(Icons.check, size: 17),
        label: Text(label),
      );
    }
    return OutlinedButton(
      key: Key('review-answer-${rating.name}'),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

String _ratingLabel(ReviewRating rating) => switch (rating) {
  ReviewRating.again => 'No idea',
  ReviewRating.hard => 'Unsure',
  ReviewRating.good => 'Confident',
  ReviewRating.easy => 'Instant',
};
