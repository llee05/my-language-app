part of '../../main.dart';

/// Example browsing is independent of card ratings and learner persistence.
class _VocabularyExamples extends StatefulWidget {
  const _VocabularyExamples({
    required this.chinese,
    required this.pinyin,
    required this.repository,
    this.fallback,
    this.onSpeak,
    this.onStopAudio,
    this.showPinyin = true,
    this.inline = false,
    this.allowBundledExamples = true,
    this.pronunciationKey,
    this.chineseKey,
  });

  final String chinese;
  final String pinyin;
  final BundledVocabularyExampleRepository repository;
  final VocabularyExample? fallback;
  final Future<void> Function(String)? onSpeak;
  final Future<void> Function()? onStopAudio;
  final bool showPinyin;
  final bool inline;
  final bool allowBundledExamples;
  final Key? pronunciationKey;
  final Key? chineseKey;

  @override
  State<_VocabularyExamples> createState() => _VocabularyExamplesState();
}

class _VocabularyExamplesState extends State<_VocabularyExamples> {
  List<VocabularyExample> _examples = const [];
  int _index = 0;
  int _request = 0;
  bool _failed = false;
  bool _changing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _VocabularyExamples oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chinese != widget.chinese ||
        oldWidget.pinyin != widget.pinyin ||
        oldWidget.repository != widget.repository ||
        oldWidget.fallback?.chinese != widget.fallback?.chinese ||
        oldWidget.fallback?.pinyin != widget.fallback?.pinyin ||
        oldWidget.fallback?.english != widget.fallback?.english ||
        oldWidget.allowBundledExamples != widget.allowBundledExamples) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final fallback = widget.fallback;
    _examples = fallback != null && fallback.chinese.trim().isNotEmpty
        ? [fallback]
        : [];
    _index = 0;
    _failed = false;
    _changing = false;
    _loading = widget.allowBundledExamples;
    if (!widget.allowBundledExamples) return;
    try {
      final bundled = await widget.repository.forWord(
        widget.chinese,
        widget.pinyin,
      );
      if (!mounted || request != _request) return;
      final examples = <VocabularyExample>[];
      if (fallback != null && fallback.chinese.trim().isNotEmpty) {
        // Keep saved/custom examples intact. Matching bundled text can restore
        // its full source credit without changing the displayed content.
        examples.add(
          bundled.firstWhere(
            (example) =>
                example.chinese == fallback.chinese &&
                example.pinyin == fallback.pinyin &&
                example.english == fallback.english,
            orElse: () => fallback,
          ),
        );
      }
      final seen = examples.map((example) => example.chinese).toSet();
      for (final example in bundled) {
        if (seen.add(example.chinese)) examples.add(example);
      }
      setState(() {
        _examples = examples.take(5).toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      debugPrint('Vocabulary examples load failed: $error');
      if (mounted && request == _request) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _another() async {
    if (_changing || _examples.length < 2) return;
    final request = _request;
    setState(() => _changing = true);
    try {
      await widget.onStopAudio?.call();
    } catch (error) {
      debugPrint('Example audio stop failed: $error');
    }
    if (!mounted || request != _request) return;
    setState(() {
      _index = (_index + 1) % _examples.length;
      _changing = false;
    });
  }

  Future<void> _openSource(String id) async {
    if ((int.tryParse(id) ?? 0) <= 0) return;
    try {
      await widget.onStopAudio?.call();
      if (!mounted) return;
      if (await launchUrl(
        Uri.https('tatoeba.org', '/en/sentences/show/$id'),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (error) {
      debugPrint('Example source could not be opened: $error');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The Tatoeba source could not be opened.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alignment = widget.inline ? TextAlign.center : TextAlign.start;
    final example = _examples.isEmpty ? null : _examples[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (example == null)
          Text(
            _loading
                ? 'Loading examples…'
                : 'No example sentence is available for this word yet.',
            key: const Key('example-sentence-unavailable'),
            textAlign: alignment,
            style: TextStyle(color: AppColors.muted),
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  example.chinese,
                  key: widget.chineseKey,
                  textAlign: alignment,
                  maxLines: widget.inline ? 3 : null,
                  overflow: widget.inline ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    fontFamily: 'serif',
                    color: AppColors.text,
                    fontSize: widget.inline ? 22 : 24,
                  ),
                ),
              ),
              PronunciationButton(
                key: widget.pronunciationKey,
                requestKey: example.chinese,
                tooltip: widget.onSpeak == null
                    ? 'Pronunciation audio is disabled in Settings'
                    : 'Hear example sentence',
                onPressed: widget.onSpeak == null
                    ? null
                    : () => widget.onSpeak!(example.chinese),
              ),
            ],
          ),
          if (widget.showPinyin && example.pinyin.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              example.pinyin,
              textAlign: alignment,
              maxLines: widget.inline ? 2 : null,
              overflow: widget.inline ? TextOverflow.ellipsis : null,
              style: TextStyle(color: AppColors.gold, fontSize: 15),
            ),
          ],
          if (example.english.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              example.english,
              textAlign: alignment,
              maxLines: widget.inline ? 3 : null,
              overflow: widget.inline ? TextOverflow.ellipsis : null,
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
          if (example.source.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              example.source == 'Original'
                  ? 'Original study example'
                  : example.source == 'Tatoeba'
                  ? 'Tatoeba · CC BY 2.0 FR'
                        '${(int.tryParse(example.chineseId) ?? 0) > 0 ? ' · #${example.chineseId}' : ''}'
                        '${(int.tryParse(example.englishId) ?? 0) > 0 ? ' / #${example.englishId}' : ''}'
                  : example.source,
              textAlign: alignment,
              style: TextStyle(color: AppColors.faint, fontSize: 12),
            ),
          ],
          if (!widget.inline && example.source == 'Tatoeba') ...[
            if (example.pinyinContributor.isNotEmpty)
              Text(
                'Pinyin: ${example.pinyinContributor}',
                style: TextStyle(color: AppColors.faint, fontSize: 12),
              ),
            Wrap(
              spacing: 8,
              children: [
                if ((int.tryParse(example.chineseId) ?? 0) > 0)
                  TextButton(
                    onPressed: () => _openSource(example.chineseId),
                    child: const Text('Chinese source'),
                  ),
                if ((int.tryParse(example.englishId) ?? 0) > 0)
                  TextButton(
                    onPressed: () => _openSource(example.englishId),
                    child: const Text('English source'),
                  ),
              ],
            ),
          ],
          if (_examples.length > 1)
            Wrap(
              alignment: widget.inline
                  ? WrapAlignment.center
                  : WrapAlignment.start,
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  key: const Key('vocabulary-example-next'),
                  onPressed: _changing ? null : _another,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Another sentence'),
                ),
                Text(
                  '${_index + 1} / ${_examples.length}',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
        ],
        if (_failed)
          TextButton(
            onPressed: () {
              setState(() {});
              _load();
            },
            child: const Text('Retry examples'),
          ),
      ],
    );
  }
}
