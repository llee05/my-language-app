part of '../../main.dart';

enum VocabularyLearningState { unseen, learning, learned, due }

class VocabularyPage extends StatefulWidget {
  const VocabularyPage({
    super.key,
    this.progressRepository = const SqliteProgressRepository(),
    this.settingsRepository = const SqliteSettingsRepository(),
    this.pronunciationService,
    this.initialEntries,
    this.initialProgress,
    this.clock,
  });

  /// Allows focused previews and tests without loading the bundled asset.
  final List<Map<String, dynamic>>? initialEntries;
  final ProgressRepository progressRepository;
  final SettingsRepository settingsRepository;
  final PronunciationService? pronunciationService;
  final List<VocabularyCardProgress>? initialProgress;
  final DateTime Function()? clock;

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  final _searchController = TextEditingController();
  List<_VocabularyEntry> _entries = const [];
  bool _loading = true;
  bool _loadFailed = false;
  bool _soundEnabled = true;
  int? _hskLevel;
  VocabularyLearningState? _learningState;
  late final PronunciationService _pronunciationService;
  late final bool _ownsPronunciationService;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _ownsPronunciationService = widget.pronunciationService == null;
    _pronunciationService =
        widget.pronunciationService ?? createSystemPronunciationService();
    _loadVocabulary();
    unawaited(_loadSoundPreference());
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_ownsPronunciationService) {
      unawaited(_pronunciationService.dispose());
    } else {
      unawaited(_stopPronunciation());
    }
    super.dispose();
  }

  Future<void> _loadSoundPreference() async {
    try {
      final settings = await widget.settingsRepository.load();
      if (!mounted) return;
      setState(() => _soundEnabled = settings.soundEnabled);
    } catch (error) {
      debugPrint('Vocabulary sound preference load failed: $error');
    }
  }

  Future<void> _speak(String text) async {
    if (!_soundEnabled || text.trim().isEmpty) return;
    try {
      await _pronunciationService.speakMandarin(text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mandarin audio is unavailable. Check your device text-to-speech voices.',
          ),
        ),
      );
    }
  }

  Future<void> _stopPronunciation() async {
    try {
      await _pronunciationService.stop();
    } catch (error) {
      debugPrint('Vocabulary pronunciation stop failed: $error');
    }
  }

  Future<void> _loadVocabulary() async {
    if (!_loading && mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final source =
          widget.initialEntries ??
          (jsonDecode(
                await rootBundle.loadString('assets/data/hsk_vocabulary.json'),
              )
              as List<dynamic>);
      final progress =
          widget.initialProgress ??
          (widget.initialEntries == null
              ? await widget.progressRepository.vocabularyProgress()
              : const <VocabularyCardProgress>[]);
      final progressByWord = <String, CardProgress>{};
      for (final item in progress) {
        progressByWord.putIfAbsent(
          _vocabularyProgressKey(item.chinese, item.pinyin),
          () => item.progress,
        );
      }
      final entries = source
          .map((item) {
            final json = item as Map<String, dynamic>;
            return _VocabularyEntry.fromJson(
              json,
              progress:
                  progressByWord[_vocabularyProgressKey(
                    json['simplified'] as String,
                    json['pinyin'] as String,
                  )],
            );
          })
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _loadFailed = false;
      });
    } catch (error) {
      debugPrint('Vocabulary load failed: $error');
      if (!mounted) return;
      setState(() {
        _entries = const [];
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  List<_VocabularyEntry> get _results {
    final query = _searchController.text.trim().toLowerCase();
    final normalizedQuery = _normalizePinyin(query);
    return _entries
        .where((entry) {
          if (_hskLevel != null && entry.hskLevel != _hskLevel) return false;
          if (_learningState != null &&
              entry.learningState(_now()) != _learningState) {
            return false;
          }
          if (query.isEmpty) return true;
          return entry.simplified.toLowerCase().contains(query) ||
              entry.traditional.toLowerCase().contains(query) ||
              (normalizedQuery.isNotEmpty &&
                  (entry.normalizedPinyin.contains(normalizedQuery) ||
                      entry.compactPinyin.contains(
                        normalizedQuery.replaceAll(' ', ''),
                      ))) ||
              entry.meanings.any(
                (meaning) => meaning.toLowerCase().contains(query),
              );
        })
        .toList(growable: false);
  }

  Future<void> _openDetails(_VocabularyEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _VocabularyDetailPage(
          entry: entry,
          onSpeakWord: _soundEnabled ? () => _speak(entry.simplified) : null,
          onSpeakExample: _soundEnabled && entry.hasExample
              ? () => _speak(entry.exampleChinese)
              : null,
        ),
      ),
    );
    await _stopPronunciation();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '词汇',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 36,
                  color: AppColors.text,
                ),
              ),
              const Text(
                'Vocabulary',
                style: TextStyle(fontSize: 16, color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              TextField(
                key: const Key('vocabulary-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search Hanzi, pinyin, or English',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _LevelChip(
                      label: 'All levels',
                      selected: _hskLevel == null,
                      onSelected: () => setState(() => _hskLevel = null),
                    ),
                    for (var level = 1; level <= 6; level++) ...[
                      const SizedBox(width: 8),
                      _LevelChip(
                        label: 'HSK $level',
                        selected: _hskLevel == level,
                        onSelected: () => setState(() => _hskLevel = level),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _LevelChip(
                      label: 'All states',
                      selected: _learningState == null,
                      onSelected: () => setState(() => _learningState = null),
                    ),
                    for (final state in VocabularyLearningState.values) ...[
                      const SizedBox(width: 8),
                      _LevelChip(
                        label: _learningStateLabel(state),
                        selected: _learningState == state,
                        onSelected: () =>
                            setState(() => _learningState = state),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadFailed) {
      return _AppErrorState(
        key: const Key('vocabulary-error-state'),
        title: _AppErrorCopy.vocabularyTitle,
        message: _AppErrorCopy.vocabularyMessage,
        onRetry: _loadVocabulary,
        retryKey: const Key('vocabulary-retry'),
        compact: true,
      );
    }
    final results = _results;
    if (results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 42, color: AppColors.muted),
            SizedBox(height: 12),
            Text(
              'No vocabulary found.',
              style: TextStyle(color: AppColors.text),
            ),
            SizedBox(height: 4),
            Text(
              'Try another Hanzi, pinyin, or English search.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${results.length} ${results.length == 1 ? 'word' : 'words'}',
          key: const Key('vocabulary-result-count'),
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _VocabularyListItem(
              entry: results[index],
              learningState: results[index].learningState(_now()),
              onTap: () => unawaited(_openDetails(results[index])),
            ),
          ),
        ),
      ],
    );
  }
}

class _VocabularyEntry {
  const _VocabularyEntry({
    required this.simplified,
    required this.traditional,
    required this.pinyin,
    required this.meanings,
    required this.hskLevel,
    required this.partOfSpeech,
    required this.exampleChinese,
    required this.examplePinyin,
    required this.exampleEnglish,
    this.progress,
  });

  factory _VocabularyEntry.fromJson(
    Map<String, dynamic> json, {
    CardProgress? progress,
  }) {
    final simplified = json['simplified'] as String;
    final example = _seededVocabularyExamples[simplified];
    return _VocabularyEntry(
      simplified: simplified,
      traditional: json['traditional'] as String,
      pinyin: json['pinyin'] as String,
      meanings: (json['meanings'] as List<dynamic>).cast<String>(),
      hskLevel: json['hskLevel'] as int,
      partOfSpeech: (json['partOfSpeech'] as List<dynamic>? ?? const [])
          .cast<String>(),
      exampleChinese:
          (json['exampleChinese'] ??
                  json['example_sentence_chinese'] ??
                  example?['example_sentence_chinese'] ??
                  '')
              as String,
      examplePinyin:
          (json['examplePinyin'] ??
                  json['example_sentence_pinyin'] ??
                  example?['example_sentence_pinyin'] ??
                  '')
              as String,
      exampleEnglish:
          (json['exampleEnglish'] ??
                  json['example_sentence_english'] ??
                  example?['example_sentence_english'] ??
                  '')
              as String,
      progress: progress,
    );
  }

  final String simplified;
  final String traditional;
  final String pinyin;
  final List<String> meanings;
  final int hskLevel;
  final List<String> partOfSpeech;
  final String exampleChinese;
  final String examplePinyin;
  final String exampleEnglish;
  final CardProgress? progress;

  String get normalizedPinyin => _normalizePinyin(pinyin);
  String get compactPinyin => normalizedPinyin.replaceAll(' ', '');
  bool get hasExample => exampleChinese.isNotEmpty;

  VocabularyLearningState learningState(DateTime now) {
    final value = progress;
    if (value == null || value.timesSeen == 0) {
      return VocabularyLearningState.unseen;
    }
    if (!value.nextReview.isAfter(now)) return VocabularyLearningState.due;
    if (value.mastery >= .8) return VocabularyLearningState.learned;
    return VocabularyLearningState.learning;
  }
}

class _VocabularyListItem extends StatelessWidget {
  const _VocabularyListItem({
    required this.entry,
    required this.learningState,
    required this.onTap,
  });

  final _VocabularyEntry entry;
  final VocabularyLearningState learningState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showTraditional = entry.traditional != entry.simplified;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.border.withValues(alpha: .65)),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Text(
                  entry.simplified,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 30,
                    height: 1.15,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.pinyin,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                    if (showTraditional) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Traditional: ${entry.traditional}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.faint,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      entry.meanings.join(' · '),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'HSK ${entry.hskLevel}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _VocabularyStateBadge(state: learningState),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VocabularyStateBadge extends StatelessWidget {
  const _VocabularyStateBadge({required this.state});

  final VocabularyLearningState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      VocabularyLearningState.unseen => AppColors.muted,
      VocabularyLearningState.learning => AppColors.gold,
      VocabularyLearningState.learned => AppColors.teal,
      VocabularyLearningState.due => AppColors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _learningStateLabel(state),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _VocabularyDetailPage extends StatelessWidget {
  const _VocabularyDetailPage({
    required this.entry,
    this.onSpeakWord,
    this.onSpeakExample,
  });

  final _VocabularyEntry entry;
  final Future<void> Function()? onSpeakWord;
  final Future<void> Function()? onSpeakExample;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Word details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailHeader(entry: entry, onSpeak: onSpeakWord),
                const SizedBox(height: 18),
                _DetailSection(
                  title: 'Meanings',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var index = 0;
                        index < entry.meanings.length;
                        index++
                      )
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == entry.meanings.length - 1 ? 0 : 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '${index + 1}.',
                                  style: const TextStyle(
                                    color: AppColors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.meanings[index],
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _DetailSection(
                  title: 'Example sentence',
                  child: entry.hasExample
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.exampleChinese,
                                    key: const Key('example-sentence-chinese'),
                                    style: const TextStyle(
                                      fontFamily: 'serif',
                                      color: AppColors.text,
                                      fontSize: 24,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  key: const Key(
                                    'vocabulary-example-pronunciation',
                                  ),
                                  tooltip: onSpeakExample == null
                                      ? 'Pronunciation audio is disabled in Settings'
                                      : 'Hear example sentence',
                                  onPressed: onSpeakExample == null
                                      ? null
                                      : () => unawaited(onSpeakExample!()),
                                  icon: const Icon(Icons.volume_up_outlined),
                                ),
                              ],
                            ),
                            if (entry.examplePinyin.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                entry.examplePinyin,
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                            if (entry.exampleEnglish.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                entry.exampleEnglish,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        )
                      : const Row(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              color: AppColors.muted,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No example sentence is available for this word yet.',
                                key: Key('example-sentence-unavailable'),
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.entry, this.onSpeak});

  final _VocabularyEntry entry;
  final Future<void> Function()? onSpeak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border.withValues(alpha: .65)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.simplified,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 54,
                          height: 1.05,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('vocabulary-word-pronunciation'),
                      tooltip: onSpeak == null
                          ? 'Pronunciation audio is disabled in Settings'
                          : 'Hear word pronunciation',
                      onPressed: onSpeak == null
                          ? null
                          : () => unawaited(onSpeak!()),
                      icon: const Icon(Icons.volume_up_outlined),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'HSK ${entry.hskLevel}',
                  style: const TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.pinyin,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (entry.traditional != entry.simplified) ...[
            const SizedBox(height: 8),
            Text(
              'Traditional: ${entry.traditional}',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
          if (entry.partOfSpeech.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in entry.partOfSpeech)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(label),
                    side: const BorderSide(color: AppColors.border),
                    backgroundColor: AppColors.surfaceLight,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border.withValues(alpha: .65)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

final Map<String, Map<String, dynamic>> _seededVocabularyExamples = () {
  final examples = <String, Map<String, dynamic>>{};
  for (final lesson in flashcardLessons) {
    for (final card in (lesson['cards'] as List<dynamic>)) {
      final data = card as Map<String, dynamic>;
      examples.putIfAbsent(data['chinese'] as String, () => data);
    }
  }
  return examples;
}();

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.red.withValues(alpha: .2),
      side: BorderSide(color: selected ? AppColors.red : AppColors.border),
      labelStyle: TextStyle(color: selected ? AppColors.text : AppColors.muted),
    );
  }
}

String _normalizePinyin(String value) {
  const replacements = {
    'ā': 'a',
    'á': 'a',
    'ǎ': 'a',
    'à': 'a',
    'ē': 'e',
    'é': 'e',
    'ě': 'e',
    'è': 'e',
    'ī': 'i',
    'í': 'i',
    'ǐ': 'i',
    'ì': 'i',
    'ō': 'o',
    'ó': 'o',
    'ǒ': 'o',
    'ò': 'o',
    'ū': 'u',
    'ú': 'u',
    'ǔ': 'u',
    'ù': 'u',
    'ǖ': 'v',
    'ǘ': 'v',
    'ǚ': 'v',
    'ǜ': 'v',
    'ü': 'v',
  };
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final character = String.fromCharCode(rune);
    buffer.write(replacements[character] ?? character);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r"[^a-z0-9\s']"), '')
      .replaceAll(RegExp(r"[\s']+"), ' ')
      .trim();
}

String _vocabularyProgressKey(String chinese, String pinyin) =>
    '$chinese|${_normalizePinyin(pinyin).replaceAll(' ', '')}';

String _learningStateLabel(VocabularyLearningState state) => switch (state) {
  VocabularyLearningState.unseen => 'Unseen',
  VocabularyLearningState.learning => 'Learning',
  VocabularyLearningState.learned => 'Learned',
  VocabularyLearningState.due => 'To review',
};
