part of '../../main.dart';

class DailyReviewCardScreen extends StatefulWidget {
  const DailyReviewCardScreen({
    super.key,
    required this.queue,
    this.initialPosition = 0,
    this.showPinyin = true,
    this.onClose,
    this.onAnswer,
  });

  final List<DailyQueueCard> queue;
  final int initialPosition;
  final bool showPinyin;
  final VoidCallback? onClose;
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

  @override
  void initState() {
    super.initState();
    _position = widget.queue.isEmpty
        ? 0
        : widget.initialPosition.clamp(0, widget.queue.length - 1);
  }

  void _move(int offset) {
    final next = _position + offset;
    if (next < 0 || next >= widget.queue.length) return;
    setState(() {
      _position = next;
      _meaningRevealed = false;
    });
  }

  Future<void> _selectAnswer(ReviewRating rating) async {
    if (_savingAnswer || _answers.containsKey(_position)) return;
    setState(() {
      _savingAnswer = true;
      _answerError = null;
    });
    try {
      await widget.onAnswer?.call(
        _position,
        widget.queue[_position].card,
        rating,
      );
      if (!mounted) return;
      setState(() => _answers[_position] = rating);
    } catch (error) {
      if (!mounted) return;
      setState(() => _answerError = 'Could not save this answer. Try again.');
    } finally {
      if (mounted) setState(() => _savingAnswer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.queue.isEmpty) {
      return const Center(child: Text('There are no cards to review.'));
    }
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
                  onPressed: widget.onClose,
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
                      Text(
                        card.chinese,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 76,
                          color: AppColors.text,
                        ),
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
                                      _savingAnswer || selectedAnswer != null
                                      ? null
                                      : () => _selectAnswer(rating),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        if (_answerError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _answerError!,
                            style: const TextStyle(color: AppColors.red),
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
                    onPressed: _position == 0 ? null : () => _move(-1),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _position == widget.queue.length - 1 ||
                            selectedAnswer == null
                        ? null
                        : () => _move(1),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
  ReviewRating.again => 'Again',
  ReviewRating.hard => 'Hard',
  ReviewRating.good => 'Good',
  ReviewRating.easy => 'Easy',
};
