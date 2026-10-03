part of '../../main.dart';

/// Explicit self-rating for vocabulary encountered outside flashcard lessons.
class _VocabularyPracticePanel extends StatefulWidget {
  const _VocabularyPracticePanel({
    super.key,
    required this.service,
    required this.text,
    this.words,
    this.onProgressChanged,
  });

  final VocabularyStudyService service;
  final String text;
  final List<Map<String, dynamic>>? words;
  final VoidCallback? onProgressChanged;

  @override
  State<_VocabularyPracticePanel> createState() =>
      _VocabularyPracticePanelState();
}

class _VocabularyPracticePanelState extends State<_VocabularyPracticePanel> {
  late Future<List<Map<String, dynamic>>> _words;
  final _saved = <String>{};
  final _saving = <String>{};
  final _ratings = <String, ReviewRating>{};
  final _errors = <String>{};
  final _run = DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _words = widget.words == null
        ? widget.service.wordsInText(widget.text)
        : Future.value(widget.words!);
  }

  @override
  void didUpdateWidget(covariant _VocabularyPracticePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _words = widget.words == null
          ? widget.service.wordsInText(widget.text)
          : Future.value(widget.words!);
    }
  }

  Future<void> _rate(Map<String, dynamic> word, ReviewRating rating) async {
    final key = vocabularyWordKey(
      word['simplified'] as String,
      word['pinyin'] as String,
    );
    if (_saving.contains(key) || _saved.contains(key)) return;
    setState(() {
      _saving.add(key);
      _ratings.putIfAbsent(key, () => rating);
      _errors.remove(key);
    });
    try {
      await widget.service.recordWord(
        word,
        rating: _ratings[key]!,
        submissionKey: 'word-practice:$_run:${Uri.encodeComponent(key)}',
      );
      if (!mounted) return;
      setState(() => _saved.add(key));
      widget.onProgressChanged?.call();
    } catch (error) {
      debugPrint('Vocabulary practice save failed: $error');
      if (mounted) setState(() => _errors.add(key));
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _words,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton(
          onPressed: () =>
              setState(() => _words = widget.service.wordsInText(widget.text)),
          child: const Text('Retry vocabulary practice'),
        );
      }
      final words = snapshot.data;
      if (words == null || words.isEmpty) return const SizedBox.shrink();
      return Material(
        color: Colors.transparent,
        child: ExpansionTile(
          title: const Text('Practise these words'),
          subtitle: const Text('Rate words to update your vocabulary progress'),
          children: [for (final word in words) _buildWord(word)],
        ),
      );
    },
  );

  Widget _buildWord(Map<String, dynamic> word) {
    final key = vocabularyWordKey(
      word['simplified'] as String,
      word['pinyin'] as String,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${word['simplified']} · ${word['pinyin']}',
            style: TextStyle(color: AppColors.text, fontSize: 20),
          ),
          Text(
            vocabularyStudyMeaning(word),
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          if (_saved.contains(key))
            const Text('Progress saved')
          else if (_errors.contains(key))
            TextButton(
              onPressed: () => _rate(word, _ratings[key]!),
              child: const Text('Couldn’t save. Try again'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _saving.contains(key)
                      ? null
                      : () => _rate(word, ReviewRating.again),
                  child: const Text('Still learning'),
                ),
                FilledButton(
                  onPressed: _saving.contains(key)
                      ? null
                      : () => _rate(word, ReviewRating.good),
                  child: Text(_saving.contains(key) ? 'Saving…' : 'Got it'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
