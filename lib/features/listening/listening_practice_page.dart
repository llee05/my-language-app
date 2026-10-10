part of '../../main.dart';

class ListeningPracticePage extends StatefulWidget {
  const ListeningPracticePage({
    super.key,
    required this.lessonRepository,
    required this.settingsRepository,
    this.pronunciationService,
    this.progressRepository,
    this.vocabularyRepository = const BundledVocabularyRepository(),
    this.sessionSize = 20,
    this.random,
    this.studyService,
    this.onProgressChanged,
  });

  final VocabularyStudyService? studyService;
  final VoidCallback? onProgressChanged;

  final LessonRepository lessonRepository;
  final SettingsRepository settingsRepository;
  final PronunciationService? pronunciationService;
  final ProgressRepository? progressRepository;
  final BundledVocabularyRepository vocabularyRepository;
  final int sessionSize;
  final Random? random;

  @override
  State<ListeningPracticePage> createState() => _ListeningPracticePageState();
}

class _ListeningPracticePageState extends State<ListeningPracticePage> {
  static const _slowPlaybackRate = .75;
  static const _randomMixLabel = 'Random mix';

  late final PronunciationService _pronunciationService;
  late final bool _ownsPronunciationService;
  final _topicSearchController = TextEditingController();
  LearnerSettings _learnerSettings = const LearnerSettings();
  List<LessonSummary> _topics = const [];
  Map<int, List<Flashcard>> _cardsByLesson = const {};
  Map<Flashcard, int> _cardHskLevels = const {};
  bool _sentenceMode = false;
  int? _libraryHskFilter;
  List<LessonSummary> _lastDecks = const [];
  bool _lastRandomMix = false;
  bool _lastRandomDeck = false;
  String? _startError;
  Map<int, LessonLearningProgress> _lessonLearningProgress = const {};
  List<Flashcard> _answerPool = const [];
  VocabularyQuizIndex _quizIndex = VocabularyQuizIndex(const []);
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
  String? _saveError;
  String? _pendingMeaning;
  String _practiceRunId = '';
  String? _activeTopicLabel;
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
    _topicSearchController.dispose();
    if (_ownsPronunciationService) {
      unawaited(_pronunciationService.dispose());
    } else {
      unawaited(_pronunciationService.stop());
    }
    super.dispose();
  }

  Future<void> _loadPractice() async {
    final bundle = DefaultAssetBundle.of(context);
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
      final vocabulary = await widget.vocabularyRepository.load(bundle: bundle);
      final quizIndex = VocabularyQuizIndex(vocabulary);
      final lessons = await Future.wait(
        summaries.map(
          (summary) => widget.lessonRepository.findById(summary.id),
        ),
      );
      final learningProgress = await widget.progressRepository
          ?.learningProgressForLessons(
            widget.lessonRepository,
            summaries.map((summary) => summary.id),
          );
      final cardsByLesson = <int, List<Flashcard>>{};
      final cardHskLevels = <Flashcard, int>{};
      for (final lesson in lessons.whereType<Lesson>()) {
        final cards = lesson.cards
            .where(
              (card) =>
                  card.chinese.trim().isNotEmpty &&
                  card.englishMeaning.trim().isNotEmpty,
            )
            .toList(growable: false);
        cardsByLesson[lesson.summary.id] = cards;
        for (final card in cards) {
          cardHskLevels[card] = lesson.summary.hskLevel;
        }
      }

      if (!mounted) return;
      setState(() {
        _learnerSettings = settings;
        _topics = summaries;
        _cardsByLesson = cardsByLesson;
        _cardHskLevels = cardHskLevels;
        _startError = null;
        _lessonLearningProgress = learningProgress ?? const {};
        _answerPool = const [];
        _quizIndex = quizIndex;
        _activeTopicLabel = null;
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
        _cardsByLesson = const {};
        _cardHskLevels = const {};
        _answerPool = const [];
        _cards = const [];
        _sessionStarted = false;
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _resetSessionState() {
    _practiceRunId = DateTime.now().microsecondsSinceEpoch.toString();
    _saveError = null;
    _position = 0;
    _correctAnswers = 0;
    _selectedMeaning = null;
    _answerRevealed = false;
    _complete = false;
    _audioError = null;
  }

  List<LessonSummary> get _visibleDecks => _filterFlashcardDecks(
    _topics,
    sentenceMode: _sentenceMode,
    hskFilter: _libraryHskFilter,
    query: _topicSearchController.text,
    cardsByLesson: _cardsByLesson,
  );

  List<Flashcard> _uniqueCards(Iterable<LessonSummary> decks) {
    final cards = <String, Flashcard>{};
    for (final deck in decks) {
      for (final card in _cardsByLesson[deck.id] ?? const <Flashcard>[]) {
        final identity =
            '${card.chinese}\u0000${card.pinyin}\u0000'
            '${card.englishMeaning.toLowerCase()}';
        cards.putIfAbsent(identity, () => card);
      }
    }
    return cards.values.toList(growable: false);
  }

  Future<void> _startPractice(
    List<LessonSummary> decks, {
    bool randomMix = false,
    bool randomDeck = false,
  }) async {
    if (_transitioning || decks.isEmpty) return;
    _audioRequestId++;
    setState(() {
      _transitioning = true;
      _playing = false;
      _startError = null;
    });
    try {
      await _pronunciationService.stop();
    } catch (error) {
      debugPrint('Listening practice pronunciation stop failed: $error');
    }
    if (!mounted) return;

    final available = decks
        .where((deck) => (_cardsByLesson[deck.id] ?? const []).isNotEmpty)
        .toList(growable: false);
    if (available.isEmpty) {
      setState(() {
        _transitioning = false;
        _startError = 'This deck has no listening cards. Choose another deck.';
      });
      return;
    }
    final deck = randomDeck
        ? available[_random.nextInt(available.length)]
        : available.first;
    final source = randomMix
        ? (_uniqueCards(available)..shuffle(_random))
        : List<Flashcard>.of(_cardsByLesson[deck.id]!);
    final answerPool = randomMix
        ? source
        : _uniqueCards(
            _topics.where(
              (topic) =>
                  topic.isSentencePractice == deck.isSentencePractice &&
                  topic.hskLevel <= deck.hskLevel,
            ),
          );
    final sessionSize = widget.sessionSize.clamp(1, source.length);
    setState(() {
      _lastDecks = decks;
      _lastRandomMix = randomMix;
      _lastRandomDeck = randomDeck;
      _cards = source.take(sessionSize).toList(growable: false);
      _answerPool = answerPool;
      _activeTopicLabel = randomMix
          ? _randomMixLabel
          : _flashcardDeckTitle(deck);
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
    Map<int, LessonLearningProgress>? learningProgress;
    try {
      learningProgress = await widget.progressRepository
          ?.learningProgressForLessons(
            widget.lessonRepository,
            _topics.map((topic) => topic.id),
          );
    } catch (error) {
      debugPrint('Listening deck progress refresh failed: $error');
    }
    if (!mounted) return;
    setState(() {
      if (learningProgress != null) _lessonLearningProgress = learningProgress;
      _cards = const [];
      _activeTopicLabel = null;
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
      if (error is MandarinVoiceUnavailableException) {
        _showPronunciationError(context, _pronunciationService, error);
      }
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
    final options = buildMeaningOptions(
      answer: _quizIndex.forCard(_card),
      candidates: [
        for (final card in _answerPool)
          if (card != _card) _quizIndex.forCard(card),
        for (final option in _card.quizOptions) QuizMeaning(option),
      ],
    );

    final seed = _card.id == 0
        ? Object.hash(_card.chinese, _card.pinyin, _position)
        : _card.id;
    options.shuffle(Random(seed));
    return options;
  }

  Future<void> _chooseMeaning(String meaning) => _saveAnswer(meaning);

  Future<void> _revealAnswer() => _saveAnswer(null);

  Future<void> _saveAnswer(String? meaning) async {
    if (_answerRevealed || _transitioning) return;
    final correct =
        meaning?.toLowerCase() == _card.englishMeaning.trim().toLowerCase();
    _pendingMeaning = meaning;
    setState(() {
      _transitioning = true;
      _saveError = null;
    });
    try {
      await widget.studyService?.recordCard(
        _card,
        hskLevel: _cardHskLevels[_card]!,
        rating: correct ? ReviewRating.good : ReviewRating.again,
        submissionKey: 'listening:$_practiceRunId:$_position',
      );
      if (!mounted) return;
      setState(() {
        _selectedMeaning = meaning;
        _answerRevealed = true;
        if (correct) _correctAnswers++;
      });
      widget.onProgressChanged?.call();
    } catch (error) {
      debugPrint('Listening answer save failed: $error');
      if (mounted) {
        setState(
          () => _saveError = 'Your answer could not be saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
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

  Future<void> _practiceAgain() => _startPractice(
    _lastDecks,
    randomMix: _lastRandomMix,
    randomDeck: _lastRandomDeck,
  );

  @override
  Widget build(BuildContext context) => _BackNavigationScope(
    active: _sessionStarted,
    blocked: _transitioning,
    onBack: () => unawaited(_chooseAnotherTopic()),
    child: Material(
      key: const Key('listening-practice-page'),
      color: AppColors.background,
      child: !_sessionStarted
          ? _buildSetup()
          : _complete
          ? _buildSummary()
          : _buildPractice(),
    ),
  );

  Widget _buildSetup() => _FlashcardLibrary(
    listening: true,
    enabled: !_transitioning,
    topics: _topics,
    sentenceMode: _sentenceMode,
    searchController: _topicSearchController,
    hskFilter: _libraryHskFilter,
    cardsByLesson: _cardsByLesson,
    onModeChanged: (value) => setState(() {
      _sentenceMode = value;
      _topicSearchController.clear();
      _startError = null;
    }),
    onLevelChanged: (value) => setState(() => _libraryHskFilter = value),
    onSearchChanged: () => setState(() {}),
    onClearSearch: () => setState(() => _topicSearchController.clear()),
    onShowAll: () => setState(() {
      _libraryHskFilter = null;
      _topicSearchController.clear();
    }),
    loading: _loading,
    loadFailed: _loadFailed,
    learningProgress: _lessonLearningProgress,
    onOpen: (deck) => unawaited(_startPractice([deck])),
    onRetry: () => unawaited(_loadPractice()),
    actions: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              key: const Key('listening-random-deck'),
              onPressed: _transitioning || _visibleDecks.isEmpty
                  ? null
                  : () => _startPractice(_visibleDecks, randomDeck: true),
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Random deck'),
            ),
            OutlinedButton.icon(
              key: const Key('listening-random-mix'),
              onPressed: _transitioning || _visibleDecks.isEmpty
                  ? null
                  : () => _startPractice(_visibleDecks, randomMix: true),
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text(_randomMixLabel),
            ),
          ],
        ),
        if (_startError != null) ...[
          const SizedBox(height: 12),
          Text(
            _startError!,
            key: const Key('listening-start-error'),
            style: TextStyle(color: AppColors.red),
          ),
        ],
      ],
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
              '$_activeTopicLabel · ${_position + 1} of ${_cards.length}',
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
          PronunciationButton(
            key: const Key('listening-replay'),
            requestKey: _card.id,
            busy: _playing,
            tooltip: 'Replay',
            onPressed:
                _learnerSettings.soundEnabled && !_playing && !_transitioning
                ? () => _play()
                : null,
            icon: Icons.replay_rounded,
            label: 'Replay',
          ),
          PronunciationButton(
            key: const Key('listening-slower-playback'),
            requestKey: _card.id,
            busy: _playing,
            tooltip: 'Slower · 0.75×',
            onPressed:
                _learnerSettings.soundEnabled && !_playing && !_transitioning
                ? () => _play(slow: true)
                : null,
            icon: Icons.slow_motion_video_rounded,
            label: 'Slower · 0.75×',
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
          onPressed: _transitioning || _saveError != null
              ? null
              : () => _chooseMeaning(_meaningOptions[index]),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          child: Text(_meaningOptions[index], textAlign: TextAlign.center),
        ),
        if (index != _meaningOptions.length - 1) const SizedBox(height: 10),
      ],
      if (_saveError != null)
        _AppInlineError(
          key: const Key('listening-save-error'),
          message: _saveError!,
          onRetry: () => _saveAnswer(_pendingMeaning),
          retryKey: const Key('listening-save-retry'),
        ),
      const SizedBox(height: 18),
      TextButton(
        key: const Key('listening-reveal-answer'),
        onPressed: _transitioning || _saveError != null ? null : _revealAnswer,
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
                      icon: const Icon(Icons.style_outlined),
                      label: const Text('Choose deck'),
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
