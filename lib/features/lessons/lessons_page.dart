part of '../../main.dart';

class LessonsPage extends StatefulWidget {
  const LessonsPage({super.key});
  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  final _topicController = TextEditingController();
  final _pageController = PageController(viewportFraction: .82);
  int _hskLevel = 1;
  int? _selectedLessonId;
  List<Map<String, dynamic>> _topics = const [];
  List<Map<String, dynamic>> _cards = const [];
  String _lessonTitle = '';
  bool _loadingTopics = true;
  bool _generating = false;
  int _currentCard = 0;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goToCard(int index) {
    if (index < 0 || index >= _cards.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadTopics() async {
    final topics = await LocalDatabase.lessonTopics();
    if (!mounted) return;
    setState(() {
      _topics = topics;
      _selectedLessonId = topics.isEmpty ? null : topics.first['id'] as int;
      if (topics.isNotEmpty) {
        _hskLevel = topics.first['hsk_level'] as int;
      }
      _loadingTopics = false;
    });
  }

  String get _topic {
    final custom = _topicController.text.trim();
    if (custom.isNotEmpty) return custom;
    return _selectedTopic?['theme'] as String? ?? 'Daily Life';
  }

  Map<String, dynamic>? get _selectedTopic {
    for (final topic in _topics) {
      if (topic['id'] == _selectedLessonId) return topic;
    }
    return null;
  }

  Future<void> _generateLesson() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _generating = true;
      _notice = null;
    });
    try {
      final topic = _topic;
      final customTopic = _topicController.text.trim().isNotEmpty;
      final hskLevel = customTopic
          ? _hskLevel
          : (_selectedTopic?['hsk_level'] as int? ?? _hskLevel);
      final cached = await LocalDatabase.generatedLesson(
        theme: topic,
        hskLevel: hskLevel,
      );
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _lessonTitle = cached['title'] as String;
          _cards = (cached['cards'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          _currentCard = 0;
          _generating = false;
          _notice = 'Loaded an existing lesson instantly.';
        });
        return;
      }

      final vocabulary =
          (jsonDecode(
                    await rootBundle.loadString(
                      'assets/data/hsk_vocabulary.json',
                    ),
                  )
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final candidates = vocabulary
          .where((word) => (word['hskLevel'] as int) <= hskLevel)
          .toList();
      _rankForTopic(candidates, _topic);

      List<Map<String, dynamic>> cards;
      try {
        cards = await _generateWithAi(
          topic,
          hskLevel,
          candidates.take(40).toList(),
        );
      } catch (_) {
        cards = candidates.take(10).map(_fallbackCard).toList();
        _notice =
            'AI was unavailable, so a vocabulary-based lesson was created locally.';
      }
      if (cards.isEmpty) throw StateError('No vocabulary was available.');
      final title = '$topic · HSK $hskLevel';
      await LocalDatabase.saveGeneratedLesson(
        title: title,
        theme: topic,
        hskLevel: hskLevel,
        cards: cards,
      );
      if (!mounted) return;
      setState(() {
        _lessonTitle = title;
        _cards = cards;
        _currentCard = 0;
        _generating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _notice = 'Could not generate the lesson: $error';
      });
    }
  }

  void _rankForTopic(List<Map<String, dynamic>> words, String topic) {
    final terms = topic.toLowerCase().split(RegExp(r'\s+')).toSet();
    int relevance(Map<String, dynamic> word) {
      final text =
          '${word['simplified']} ${(word['meanings'] as List).join(' ')}'
              .toLowerCase();
      return terms.where(text.contains).length;
    }

    words.sort((a, b) {
      final score = relevance(b).compareTo(relevance(a));
      return score != 0
          ? score
          : ((a['frequency'] as int?) ?? 999999).compareTo(
              (b['frequency'] as int?) ?? 999999,
            );
    });
  }

  Future<List<Map<String, dynamic>>> _generateWithAi(
    String topic,
    int hskLevel,
    List<Map<String, dynamic>> candidates,
  ) async {
    final supplied = [
      for (var i = 0; i < candidates.length; i++)
        {
          'index': i,
          'hanzi': candidates[i]['simplified'],
          'pinyin': candidates[i]['pinyin'],
          'meaning': (candidates[i]['meanings'] as List).first,
        },
    ];
    final response = await OllamaService.instance.chatText(
      maxTokens: 800,
      temperature: 0.3,
      messages: [
        {
          'role': 'system',
          'content':
              'Create a Mandarin flashcard lesson. Return JSON only: '
              '{"cards":[{"index":0,"exampleChinese":"...",'
              '"examplePinyin":"...","exampleEnglish":"..."}]}. '
              'Choose 8-10 unique indices only from the supplied vocabulary.',
        },
        {
          'role': 'user',
          'content':
              'Topic: $topic\nHSK: $hskLevel\nVocabulary: ${jsonEncode(supplied)}',
        },
      ],
    );
    final clean = response
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    final generated = jsonDecode(clean) as Map<String, dynamic>;
    final used = <int>{};
    return (generated['cards'] as List<dynamic>).map((raw) {
      final item = raw as Map<String, dynamic>;
      final index = item['index'] as int;
      if (index < 0 || index >= candidates.length || !used.add(index)) {
        throw const FormatException('AI selected invalid vocabulary.');
      }
      return {
        ..._fallbackCard(candidates[index]),
        'example_sentence_chinese': item['exampleChinese'] ?? '',
        'example_sentence_pinyin': item['examplePinyin'] ?? '',
        'example_sentence_english': item['exampleEnglish'] ?? '',
      };
    }).toList();
  }

  Map<String, dynamic> _fallbackCard(Map<String, dynamic> word) => {
    'chinese': word['simplified'],
    'traditional': word['traditional'],
    'pinyin': word['pinyin'],
    'english_meaning': (word['meanings'] as List).first,
    'part_of_speech': (word['partOfSpeech'] as List).join(', '),
    'example_sentence_chinese': '',
    'example_sentence_pinyin': '',
    'example_sentence_english': '',
  };

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.background,
    child: _cards.isEmpty ? _buildSetup() : _buildFlashcards(),
  );

  Widget _buildSetup() => SingleChildScrollView(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '课程生成器',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 36,
                color: AppColors.text,
              ),
            ),
            const Text(
              'Lesson Builder',
              style: TextStyle(fontSize: 16, color: AppColors.muted),
            ),
            const SizedBox(height: 30),
            DropdownButtonFormField<int>(
              key: ValueKey(_hskLevel),
              initialValue: _hskLevel,
              decoration: const InputDecoration(
                labelText: 'HSK level',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var level = 1; level <= 6; level++)
                  DropdownMenuItem(value: level, child: Text('HSK $level')),
              ],
              onChanged: (value) => setState(() => _hskLevel = value ?? 1),
            ),
            const SizedBox(height: 18),
            if (_loadingTopics)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<int>(
                initialValue: _selectedLessonId,
                decoration: const InputDecoration(
                  labelText: 'Previous or default topic',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final topic in _topics)
                    DropdownMenuItem(
                      value: topic['id'] as int,
                      child: Text(topic['theme'] as String),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedLessonId = value;
                    final selected = _selectedTopic;
                    if (selected != null) {
                      _hskLevel = selected['hsk_level'] as int;
                    }
                  });
                },
              ),
            const SizedBox(height: 18),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Ask AI for a lesson topic',
                hintText: 'e.g. ordering breakfast in Beijing',
                helperText: 'This overrides the selected previous topic.',
                border: OutlineInputBorder(),
              ),
            ),
            if (_notice != null) ...[
              const SizedBox(height: 14),
              Text(_notice!, style: const TextStyle(color: AppColors.gold)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generating ? null : _generateLesson,
              icon: _generating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _generating ? 'Generating lesson…' : 'Generate lesson',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildFlashcards() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _cards = const []),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                _lessonTitle,
                style: const TextStyle(fontSize: 18, color: AppColors.text),
              ),
            ),
            Text(
              '${_cards.length} cards',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
      Expanded(
        child: PageView.builder(
          itemCount: _cards.length,
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentCard = index),
          itemBuilder: (context, index) => _LessonFlashcard(
            card: _cards[index],
            index: index,
            total: _cards.length,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _currentCard == 0
                  ? null
                  : () => _goToCard(_currentCard - 1),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _currentCard >= _cards.length - 1
                  ? null
                  : () => _goToCard(_currentCard + 1),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LessonFlashcard extends StatelessWidget {
  const _LessonFlashcard({
    required this.card,
    required this.index,
    required this.total,
  });
  final Map<String, dynamic> card;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${index + 1} / $total',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          const Spacer(),
          Text(
            card['chinese'] as String,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 64,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card['pinyin'] as String,
            style: const TextStyle(fontSize: 18, color: AppColors.gold),
          ),
          const SizedBox(height: 18),
          Text(
            card['english_meaning'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, color: AppColors.text),
          ),
          if ((card['example_sentence_chinese'] as String).isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(card['example_sentence_chinese'] as String),
            Text(
              card['example_sentence_pinyin'] as String,
              style: const TextStyle(color: AppColors.muted),
            ),
            Text(
              card['example_sentence_english'] as String,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
          const Spacer(),
          const Tooltip(
            message: 'Text-to-speech support is planned',
            child: Icon(Icons.volume_up_outlined, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
