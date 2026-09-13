part of '../../main.dart';

class ListeningPracticePage extends StatefulWidget {
  const ListeningPracticePage({
    super.key,
    required this.lessonRepository,
    required this.settingsRepository,
    required this.maxHskLevel,
    this.pronunciationService,
    this.sessionSize = 10,
    this.random,
  });

  final LessonRepository lessonRepository;
  final SettingsRepository settingsRepository;
  final int maxHskLevel;
  final PronunciationService? pronunciationService;
  final int sessionSize;
  final Random? random;

  @override
  State<ListeningPracticePage> createState() => _ListeningPracticePageState();
}

class _ListeningPracticePageState extends State<ListeningPracticePage> {
  static const _slowPlaybackRate = .75;
  static const _randomTopicKey = '__random_mix__';
  static const _randomTopicLabel = 'Random mix';

  late final PronunciationService _pronunciationService;
  late final bool _ownsPronunciationService;
  LearnerSettings _learnerSettings = const LearnerSettings();
  List<_ListeningTopic> _topics = const [];
  List<Flashcard> _answerPool = const [];
  List<Flashcard> _cards = const [];
  bool _loading = true;
  bool _loadFailed = false;
  bool _playing = false;
  bool _transitioning = false;
  bool _answerRevealed = false;
  bool _complete = false;
  bool _sessionStarted = false;
  int _position = 0;
  int _correctAnswers = 0;
  String? _selectedMeaning;
  String? _audioError;
  String? _selectedTopicKey;
  int _audioRequestId = 0;
  late final Random _random;

  Flashcard get _card => _cards[_position];

  @override
  void initState() {
    super.initState();
    _random = widget.random ?? Random();
    _ownsPronunciationService = widget.pronunciationService == null;
    _pronunciationService =
        widget.pronunciationService ?? createSystemPronunciationService();
    _loadPractice();
  }

  @override
  void dispose() {
    if (_ownsPronunciationService) {
      unawaited(_pronunciationService.dispose());
    } else {
      unawaited(_pronunciationService.stop());
    }
    super.dispose();
  }

  Future<void> _loadPractice() async {
    if (mounted && !_loading) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }

    try {
      LearnerSettings settings;
      try {
        settings = await widget.settingsRepository.load();
      } catch (error) {
        debugPrint('Listening settings load failed: $error');
        settings = const LearnerSettings();
      }

      final summaries = await widget.lessonRepository.topics();
      final eligible = summaries.where(
        (summary) => summary.hskLevel <= widget.maxHskLevel,
      );
      final lessons = await Future.wait(
        eligible.map((summary) => widget.lessonRepository.findById(summary.id)),
      );
      final allCards = <String, Flashcard>{};
      final topicLabels = <String, String>{};
      final cardsByTopic = <String, Map<String, Flashcard>>{};
      for (final lesson in lessons.whereType<Lesson>()) {
        final rawTopic = lesson.summary.theme.trim();
        final topicLabel = rawTopic.isEmpty
            ? lesson.summary.title.trim()
            : rawTopic;
        if (topicLabel.isEmpty) continue;
        final topicKey = topicLabel.toLowerCase();
        final isRandomMix = topicKey == _randomTopicLabel.toLowerCase();
        final topicCards = isRandomMix
            ? null
            : cardsByTopic.putIfAbsent(topicKey, () => {});
        if (!isRandomMix) {
          topicLabels.putIfAbsent(topicKey, () => topicLabel);
        }
        for (final card in lesson.cards) {
          if (card.chinese.trim().isEmpty ||
              card.englishMeaning.trim().isEmpty) {
            continue;
          }
          final identity =
              '${card.chinese}\u0000${card.pinyin}\u0000'
              '${card.englishMeaning.toLowerCase()}';
          allCards.putIfAbsent(identity, () => card);
          topicCards?.putIfAbsent(identity, () => card);
        }
      }
      final topics = [
        for (final entry in cardsByTopic.entries)
          if (entry.value.isNotEmpty)
            _ListeningTopic(
              key: entry.key,
              label: topicLabels[entry.key]!,
              cards: entry.value.values.toList(growable: false),
            ),
      ];

      if (!mounted) return;
      setState(() {
        _learnerSettings = settings;
        _topics = topics;
        _answerPool = allCards.values.toList(growable: false);
        _selectedTopicKey = topics.isEmpty ? _randomTopicKey : topics.first.key;
        _cards = const [];
        _sessionStarted = false;
        _loading = false;
        _loadFailed = false;
        _resetSessionState();
      });
    } catch (error) {
      debugPrint('Listening practice load failed: $error');
      if (!mounted) return;
      setState(() {
        _topics = const [];
        _answerPool = const [];
        _cards = const [];
        _sessionStarted = false;
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _resetSessionState() {
    _position = 0;
    _correctAnswers = 0;
    _selectedMeaning = null;
    _answerRevealed = false;
    _complete = false;
    _audioError = null;
  }

  String get _selectedTopicLabel {
    if (_selectedTopicKey == _randomTopicKey) return _randomTopicLabel;
    for (final topic in _topics) {
      if (topic.key == _selectedTopicKey) return topic.label;
    }
    return 'Listening practice';
  }

  Future<void> _startPractice() async {
    final selectedTopicKey = _selectedTopicKey;
    if (_transitioning || selectedTopicKey == null || _answerPool.isEmpty) {
      return;
    }
    _audioRequestId++;
    setState(() {
      _transitioning = true;
      _playing = false;
    });
    try {
      await _pronunciationService.stop();
    } catch (error) {
      debugPrint('Listening practice pronunciation stop failed: $error');
    }
    if (!mounted || selectedTopicKey != _selectedTopicKey) return;

    final source = selectedTopicKey == _randomTopicKey
        ? (List<Flashcard>.of(_answerPool)..shuffle(_random))
        : List<Flashcard>.of(
            _topics.firstWhere((topic) => topic.key == selectedTopicKey).cards,
          );
    final sessionSize = widget.sessionSize.clamp(1, source.length);
    final cards = source.take(sessionSize).toList(growable: false);
    setState(() {
      _cards = cards;
      _sessionStarted = true;
      _resetSessionState();
      _transitioning = false;
    });
    if (_learnerSettings.soundEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_play());
      });
    }
  }

  Future<void> _chooseAnotherTopic() async {
    if (_transitioning) return;
    _audioRequestId++;
    setState(() {
      _transitioning = true;
      _playing = false;
    });
    try {
      await _pronunciationService.stop();
    } catch (error) {
      debugPrint('Listening practice pronunciation stop failed: $error');
    }
    if (!mounted) return;
    setState(() {
      _cards = const [];
      _sessionStarted = false;
      _resetSessionState();
      _transitioning = false;
    });
  }

  Future<void> _play({bool slow = false}) async {
    if (_playing ||
        _transitioning ||
        !_learnerSettings.soundEnabled ||
        _cards.isEmpty ||
        _complete) {
      return;
    }
    final spokenCard = _card;
    final requestId = ++_audioRequestId;
    setState(() {
      _playing = true;
      _audioError = null;
    });
    try {
      await applyPronunciationSettings(_pronunciationService, _learnerSettings);
      if (!mounted ||
          requestId != _audioRequestId ||
          _card != spokenCard ||
          _complete) {
        return;
      }
      final service = _pronunciationService;
      if (slow && service is PlaybackRatePronunciationService) {
        await (service as PlaybackRatePronunciationService).speakMandarinAtRate(
          spokenCard.chinese,
          rate: _slowPlaybackRate,
        );
      } else {
        await service.speakMandarin(spokenCard.chinese);
      }
    } catch (error) {
      debugPrint('Listening practice pronunciation failed: $error');
      if (!mounted || requestId != _audioRequestId) return;
      setState(() {
        _audioError = error is MandarinVoiceUnavailableException
            ? 'No Mandarin voice is installed on this device.'
            : 'Mandarin audio is unavailable right now.';
      });
    } finally {
      if (mounted && requestId == _audioRequestId) {
        setState(() => _playing = false);
      }
    }
  }

  List<String> get _meaningOptions {
    final correct = _card.englishMeaning.trim();
    final options = <String>[];
    final seen = <String>{};

    void add(String option) {
      final trimmed = option.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed.toLowerCase())) {
        options.add(trimmed);
      }
    }

    add(correct);
    for (final card in _answerPool) {
      if (card != _card) add(card.englishMeaning);
      if (options.length >= 4) break;
    }
    if (options.length < 4) {
      for (final option in _card.quizOptions) {
        add(option);
        if (options.length >= 4) break;
      }
    }

    final seed = _card.id == 0
        ? Object.hash(_card.chinese, _card.pinyin, _position)
        : _card.id;
    options.shuffle(Random(seed));
    return options;
  }

  void _chooseMeaning(String meaning) {
    if (_answerRevealed) return;
    final correct =
        meaning.toLowerCase() == _card.englishMeaning.trim().toLowerCase();
    setState(() {
      _selectedMeaning = meaning;
      _answerRevealed = true;
      if (correct) _correctAnswers++;
    });
  }

  void _revealAnswer() {
    if (_answerRevealed) return;
    setState(() {
      _selectedMeaning = null;
      _answerRevealed = true;
    });
  }

  Future<void> _next() async {
    if (!_answerRevealed || _transitioning) return;
    final finishing = _position == _cards.length - 1;
    _audioRequestId++;
    setState(() {
      _transitioning = true;
      _playing = false;
    });
    try {
      await _pronunciationService.stop();
    } catch (error) {
      debugPrint('Listening practice pronunciation stop failed: $error');
    }
    if (!mounted) return;
    setState(() {
      if (finishing) {
        _complete = true;
      } else {
        _position++;
      }
      _selectedMeaning = null;
      _answerRevealed = false;
      _audioError = null;
      _transitioning = false;
    });
    if (finishing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_play());
    });
  }

  Future<void> _practiceAgain() => _startPractice();

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('listening-practice-page'),
    color: AppColors.background,
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _loadFailed
        ? _buildLoadError()
        : _answerPool.isEmpty
        ? _buildEmptyState()
        : !_sessionStarted
        ? _buildSetup()
        : _complete
        ? _buildSummary()
        : _buildPractice(),
  );

  Widget _buildLoadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: _AppErrorState(
        key: const Key('listening-load-error'),
        title: 'Listening practice could not be loaded',
        message: 'Your saved lessons are still safe. Please try again.',
        onRetry: _loadPractice,
        retryKey: const Key('listening-load-retry'),
      ),
    ),
  );

  Widget _buildSetup() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '听力练习',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 34,
                color: AppColors.text,
              ),
            ),
            Text(
              'Listening practice',
              style: TextStyle(fontSize: 16, color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.headphones_rounded,
                      size: 48,
                      color: AppColors.gold,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Choose what to listen for',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pick one of your lesson topics, or use Random mix to '
                      'shuffle words from every available topic.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      key: const Key('listening-topic-picker'),
                      initialValue: _selectedTopicKey,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Topic',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: _randomTopicKey,
                          child: Row(
                            children: [
                              Icon(Icons.shuffle_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(_randomTopicLabel),
                            ],
                          ),
                        ),
                        for (final topic in _topics)
                          DropdownMenuItem(
                            value: topic.key,
                            child: Text(
                              topic.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _transitioning
                          ? null
                          : (value) =>
                                setState(() => _selectedTopicKey = value),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('listening-start-practice'),
                      onPressed: _transitioning ? null : _startPractice,
                      icon: _transitioning
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start listening'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildEmptyState() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.hearing_rounded, size: 52, color: AppColors.gold),
                const SizedBox(height: 16),
                Text(
                  'No listening words yet',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add or generate a lesson at your current HSK level, then '
                  'come back to practise its words by ear.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildPractice() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '听力练习',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 34,
                color: AppColors.text,
              ),
            ),
            Text(
              '$_selectedTopicLabel · ${_position + 1} of ${_cards.length}',
              key: const Key('listening-position'),
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: (_position + 1) / _cards.length,
              backgroundColor: AppColors.surface,
            ),
          ],
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _answerRevealed
                            ? 'Check what you heard'
                            : 'Listen and choose the meaning',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _buildAudioPrompt(),
                      const SizedBox(height: 22),
                      if (_answerRevealed) _buildAnswer() else _buildChoices(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildAudioPrompt() => Column(
    children: [
      Semantics(
        label: 'Mandarin listening prompt',
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: AppColors.darkRed,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.red.withValues(alpha: .55)),
          ),
          child: _playing
              ? Padding(
                  padding: const EdgeInsets.all(34),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.red,
                  ),
                )
              : Icon(Icons.graphic_eq_rounded, size: 48, color: AppColors.red),
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            key: const Key('listening-replay'),
            onPressed:
                _learnerSettings.soundEnabled && !_playing && !_transitioning
                ? () => _play()
                : null,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Replay'),
          ),
          OutlinedButton.icon(
            key: const Key('listening-slower-playback'),
            onPressed:
                _learnerSettings.soundEnabled && !_playing && !_transitioning
                ? () => _play(slow: true)
                : null,
            icon: const Icon(Icons.slow_motion_video_rounded),
            label: const Text('Slower · 0.75×'),
          ),
        ],
      ),
      if (!_learnerSettings.soundEnabled) ...[
        const SizedBox(height: 12),
        Text(
          'Sound is turned off in Settings. You can still reveal the answer.',
          key: const Key('listening-sound-disabled'),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.gold),
        ),
      ],
      if (_audioError != null) ...[
        const SizedBox(height: 12),
        Text(
          _audioError!,
          key: const Key('listening-audio-error'),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.red),
        ),
      ],
    ],
  );

  Widget _buildChoices() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < _meaningOptions.length; index++) ...[
        OutlinedButton(
          key: Key('listening-choice-$index'),
          onPressed: () => _chooseMeaning(_meaningOptions[index]),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          child: Text(_meaningOptions[index], textAlign: TextAlign.center),
        ),
        if (index != _meaningOptions.length - 1) const SizedBox(height: 10),
      ],
      const SizedBox(height: 18),
      TextButton(
        key: const Key('listening-reveal-answer'),
        onPressed: _revealAnswer,
        child: const Text('Reveal answer'),
      ),
    ],
  );

  Widget _buildAnswer() {
    final selected = _selectedMeaning;
    final wasCorrect =
        selected != null &&
        selected.toLowerCase() == _card.englishMeaning.trim().toLowerCase();
    return Column(
      children: [
        Icon(
          selected == null
              ? Icons.visibility_outlined
              : wasCorrect
              ? Icons.check_circle_outline
              : Icons.cancel_outlined,
          color: selected == null
              ? AppColors.gold
              : wasCorrect
              ? AppColors.teal
              : AppColors.red,
          size: 30,
        ),
        const SizedBox(height: 10),
        Text(
          selected == null
              ? 'Answer revealed'
              : wasCorrect
              ? 'Correct'
              : 'Not quite',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _card.chinese,
          key: const Key('listening-answer-hanzi'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 54,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _card.pinyin,
          key: const Key('listening-answer-pinyin'),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.gold, fontSize: 20),
        ),
        const SizedBox(height: 12),
        Text(
          _card.englishMeaning,
          key: const Key('listening-answer-meaning'),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.text, fontSize: 24),
        ),
        if (selected != null && !wasCorrect) ...[
          const SizedBox(height: 10),
          Text(
            'You chose: $selected',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 26),
        FilledButton.icon(
          key: const Key('listening-next'),
          onPressed: _transitioning ? null : _next,
          icon: Icon(
            _position == _cards.length - 1
                ? Icons.check_rounded
                : Icons.arrow_forward_rounded,
          ),
          label: Text(_position == _cards.length - 1 ? 'Finish' : 'Next sound'),
        ),
      ],
    );
  }

  Widget _buildSummary() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.headphones_rounded, size: 54, color: AppColors.gold),
                const SizedBox(height: 14),
                Text(
                  'Listening practice complete!',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '$_correctAnswers of ${_cards.length} meanings correct',
                  key: const Key('listening-score'),
                  style: TextStyle(color: AppColors.muted, fontSize: 16),
                ),
                const SizedBox(height: 26),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: const Key('listening-practice-again'),
                      onPressed: _transitioning ? null : _practiceAgain,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Practice again'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('listening-choose-topic'),
                      onPressed: _transitioning ? null : _chooseAnotherTopic,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Choose topic'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ListeningTopic {
  const _ListeningTopic({
    required this.key,
    required this.label,
    required this.cards,
  });

  final String key;
  final String label;
  final List<Flashcard> cards;
}
