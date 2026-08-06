part of '../../main.dart';

class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key, this.initialEntries});

  /// Allows focused previews and tests without loading the bundled asset.
  final List<Map<String, dynamic>>? initialEntries;

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  final _searchController = TextEditingController();
  List<_VocabularyEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  int? _hskLevel;

  @override
  void initState() {
    super.initState();
    _loadVocabulary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVocabulary() async {
    try {
      final source =
          widget.initialEntries ??
          (jsonDecode(
                await rootBundle.loadString('assets/data/hsk_vocabulary.json'),
              )
              as List<dynamic>);
      final entries = source
          .map(
            (item) => _VocabularyEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load vocabulary: $error';
      });
    }
  }

  List<_VocabularyEntry> get _results {
    final query = _searchController.text.trim().toLowerCase();
    final normalizedQuery = _normalizePinyin(query);
    return _entries
        .where((entry) {
          if (_hskLevel != null && entry.hskLevel != _hskLevel) return false;
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
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.gold)),
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
            itemBuilder: (context, index) =>
                _VocabularyListItem(entry: results[index]),
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
  });

  factory _VocabularyEntry.fromJson(Map<String, dynamic> json) {
    return _VocabularyEntry(
      simplified: json['simplified'] as String,
      traditional: json['traditional'] as String,
      pinyin: json['pinyin'] as String,
      meanings: (json['meanings'] as List<dynamic>).cast<String>(),
      hskLevel: json['hskLevel'] as int,
    );
  }

  final String simplified;
  final String traditional;
  final String pinyin;
  final List<String> meanings;
  final int hskLevel;

  String get normalizedPinyin => _normalizePinyin(pinyin);
  String get compactPinyin => normalizedPinyin.replaceAll(' ', '');
}

class _VocabularyListItem extends StatelessWidget {
  const _VocabularyListItem({required this.entry});

  final _VocabularyEntry entry;

  @override
  Widget build(BuildContext context) {
    final showTraditional = entry.traditional != entry.simplified;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border.withValues(alpha: .65)),
        borderRadius: BorderRadius.circular(14),
      ),
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
                  style: const TextStyle(color: AppColors.text, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
        ],
      ),
    );
  }
}

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
