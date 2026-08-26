part of '../../main.dart';

const Map<int, List<String>> _hskTopicPools = {
  1: [
    'Daily Life',
    'Greetings',
    'Family',
    'Food and Drinks',
    'Numbers and Time',
  ],
  2: ['School', 'Shopping', 'Weather', 'Hobbies', 'Getting Around'],
  3: [
    'Vegetables',
    'Dining Out',
    'Work and Study',
    'Travel Plans',
    'Daily Routines',
  ],
  4: [
    'Travel',
    'Chinese Culture',
    'Technology',
    'Relationships',
    'News and Media',
  ],
  5: ['Health', 'Society', 'Environment', 'Education', 'Arts and Literature'],
  6: [
    'Business',
    'Economics',
    'Politics',
    'Science and Research',
    'History and Philosophy',
  ],
};

class LessonsPage extends StatefulWidget {
  const LessonsPage({
    super.key,
    required this.repository,
    required this.progressRepository,
    required this.settingsRepository,
    this.pronunciationService,
    this.resumeLatest = false,
    this.onProgressChanged,
  });

  final LessonRepository repository;
  final ProgressRepository progressRepository;
  final SettingsRepository settingsRepository;
  final PronunciationService? pronunciationService;
  final bool resumeLatest;
  final VoidCallback? onProgressChanged;
  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  final _topicController = TextEditingController();
  final _pageController = PageController(viewportFraction: .82);
  int _hskLevel = 1;
  String _selectedTopicTheme = _hskTopicPools[1]!.first;
  List<LessonSummary> _topics = const [];
  Map<int, LessonSession> _activeSessions = const {};
  bool _loadingTopics = true;
  bool _libraryLoadFailed = false;
  int _topicsRequestId = 0;
  List<Flashcard> _cards = const [];
  String _lessonTitle = '';
  bool _generating = false;
  bool _generationFailed = false;
  int _currentCard = 0;
  LessonSession? _session;
  String? _notice;
  final Set<int> _learnedCardIds = {};
  final Set<int> _reviewCardIds = {};
  final Set<String> _pendingAnswerKeys = {};
  bool _savingAnswer = false;
  late final PronunciationService _pronunciationService;
  late final bool _ownsPronunciationService;
  bool _soundEnabled = true;
  LearnerSettings _learnerSettings = const LearnerSettings();

  @override
  void initState() {
    super.initState();
    _ownsPronunciationService = widget.pronunciationService == null;
    _pronunciationService =
        widget.pronunciationService ?? createSystemPronunciationService();
    _beginTopicsLoad();
    unawaited(_loadSoundPreference());
  }

  @override
  void dispose() {
    _topicController.dispose();
    _pageController.dispose();
    if (_ownsPronunciationService) {
      unawaited(_pronunciationService.dispose());
    } else {
      unawaited(_pronunciationService.stop());
    }
    super.dispose();
  }

  Future<void> _loadSoundPreference() async {
    try {
      final settings = await widget.settingsRepository.load();
      if (!mounted) return;
      setState(() {
        _learnerSettings = settings;
        _soundEnabled = settings.soundEnabled;
      });
    } catch (error) {
      debugPrint('Lesson sound preference load failed: $error');
    }
  }

  Future<void> _speak(Flashcard card) async {
    if (!_soundEnabled) return;
    try {
      await applyPronunciationSettings(_pronunciationService, _learnerSettings);
      await _pronunciationService.speakMandarin(card.chinese);
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

  void _goToCard(int index) {
    if (index < 0 || index >= _cards.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _beginTopicsLoad() {
    unawaited(_loadTopics());
  }

  Future<void> _loadTopics() async {
    final requestId = ++_topicsRequestId;
    if (!_loadingTopics && mounted) {
      setState(() {
        _loadingTopics = true;
        _libraryLoadFailed = false;
      });
    }
    try {
      final topics = await widget.repository.topics();
      final activeSessions = await Future.wait(
        topics.map(
          (topic) => widget.progressRepository.activeSessionForLesson(topic.id),
        ),
      );
      if (!mounted || requestId != _topicsRequestId) return;
      final sessions = <int, LessonSession>{
        for (var index = 0; index < topics.length; index++)
          topics[index].id: ?activeSessions[index],
      };
      setState(() {
        _topics = topics;
        _activeSessions = sessions;
        _loadingTopics = false;
        _libraryLoadFailed = false;
      });
      if (!widget.resumeLatest) return;
      final session = await widget.progressRepository.latestActiveSession();
      if (session == null) return;
      final lesson = await widget.repository.findById(session.lessonId);
      if (lesson != null && mounted) {
        await _openLesson(lesson, session: session, resumed: true);
      }
    } catch (error) {
      debugPrint('Lesson library load failed: $error');
      if (!mounted || requestId != _topicsRequestId) return;
      setState(() {
        _topics = const [];
        _activeSessions = const {};
        _loadingTopics = false;
        _libraryLoadFailed = true;
      });
    }
  }

  Future<void> _startLesson(LessonSummary summary) async {
    setState(() => _notice = null);
    try {
      final lesson = await widget.repository.findById(summary.id);
      if (lesson == null) {
        throw StateError('Lesson ${summary.id} was not found.');
      }
      if (!mounted) return;
      final session = _activeSessions[summary.id];
      await _openLesson(lesson, session: session, resumed: session != null);
    } catch (error) {
      debugPrint('Lesson open failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text(_AppErrorCopy.openLesson),
          action: SnackBarAction(
            label: 'Try again',
            onPressed: () => unawaited(_startLesson(summary)),
          ),
        ),
      );
    }
  }

  Future<void> _openLesson(
    Lesson lesson, {
    LessonSession? session,
    bool resumed = false,
  }) async {
    var active =
        session ??
        await widget.progressRepository.activeSessionForLesson(
          lesson.summary.id,
        ) ??
        await widget.progressRepository.startSession(lesson.summary.id);
    if (!mounted) return;
    final savedReviews = await _loadSessionWordCounts(active, lesson.cards);
    if (!active.isComplete &&
        (savedReviews.reviewed != active.cardsReviewed ||
            savedReviews.correct != active.correctAnswers ||
            savedReviews.reviewed >= lesson.cards.length)) {
      final expectedCardsReviewed = active.cardsReviewed;
      final expectedCorrectAnswers = active.correctAnswers;
      final reviewedCardIds = {..._learnedCardIds, ..._reviewCardIds};
      final isComplete = savedReviews.reviewed >= lesson.cards.length;
      var nextIndex = lesson.cards.length;
      if (!isComplete) {
        final startingIndex = active.currentCardIndex.clamp(
          0,
          lesson.cards.length - 1,
        );
        for (var offset = 0; offset < lesson.cards.length; offset++) {
          final candidate = (startingIndex + offset) % lesson.cards.length;
          if (!reviewedCardIds.contains(lesson.cards[candidate].id)) {
            nextIndex = candidate;
            break;
          }
        }
      }
      active = LessonSession(
        id: active.id,
        lessonId: active.lessonId,
        startedAt: active.startedAt,
        completedAt: isComplete ? savedReviews.lastReviewedAt : null,
        currentCardIndex: nextIndex,
        cardsReviewed: savedReviews.reviewed,
        correctAnswers: savedReviews.correct,
      );
      await widget.progressRepository.updateSession(
        active,
        reconcileFromHistory: true,
        expectedCardsReviewed: expectedCardsReviewed,
        expectedCorrectAnswers: expectedCorrectAnswers,
      );
    }
    if (!mounted) return;
    final index = active.currentCardIndex.clamp(0, lesson.cards.length - 1);
    setState(() {
      final sessions = {..._activeSessions};
      if (active.isComplete) {
        sessions.remove(lesson.summary.id);
      } else {
        sessions[lesson.summary.id] = active;
      }
      _activeSessions = sessions;
      _lessonTitle = lesson.summary.title;
      _cards = lesson.cards;
      _currentCard = index;
      _session = active;
      _generating = false;
      _generationFailed = false;
      if (resumed || index > 0) {
        _notice = 'Resumed at card ${index + 1}.';
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) _pageController.jumpToPage(index);
    });
  }

  Future<({int reviewed, int correct, DateTime? lastReviewedAt})>
  _loadSessionWordCounts(LessonSession session, List<Flashcard> cards) async {
    final learned = <int>{};
    final review = <int>{};
    var correct = 0;
    DateTime? lastReviewedAt;
    for (final card in cards.where((card) => card.id != 0)) {
      final history = await widget.progressRepository.reviewHistory(
        cardId: card.id,
      );
      ReviewRecord? sessionReview;
      for (final record in history) {
        if (record.sessionId == session.id) {
          sessionReview = record;
          break;
        }
      }
      if (sessionReview == null) continue;
      if (sessionReview.wasCorrect) correct++;
      if (lastReviewedAt == null ||
          sessionReview.reviewedAt.isAfter(lastReviewedAt)) {
        lastReviewedAt = sessionReview.reviewedAt;
      }
      final hadEarlierReview = history.any(
        (record) => record.sessionId != session.id,
      );
      (hadEarlierReview ? review : learned).add(card.id);
    }
    _learnedCardIds
      ..clear()
      ..addAll(learned);
    _reviewCardIds
      ..clear()
      ..addAll(review);
    return (
      reviewed: learned.length + review.length,
      correct: correct,
      lastReviewedAt: lastReviewedAt,
    );
  }

  String get _topic {
    final custom = _topicController.text.trim();
    if (custom.isNotEmpty) return custom;
    return _selectedTopicTheme;
  }

  List<String> get _availableTopics {
    final themes = <String>{...?_hskTopicPools[_hskLevel]};
    for (final topic in _topics) {
      if (topic.hskLevel == _hskLevel) {
        themes.add(topic.theme);
      }
    }
    return themes.toList();
  }

  Future<void> _generateLesson() async {
    if (_generating) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _generating = true;
      _generationFailed = false;
      _notice = null;
    });
    try {
      final topic = _topic;
      final hskLevel = _hskLevel;
      final cached = await widget.repository.findGenerated(
        theme: topic,
        hskLevel: hskLevel,
      );
      if (cached != null) {
        await _openLesson(cached);
        if (mounted && _currentCard == 0) {
          setState(() => _notice = 'Loaded an existing lesson instantly.');
        }
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

      List<Flashcard> cards;
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
      await widget.repository.saveGenerated(
        Lesson(
          summary: LessonSummary(
            id: 0,
            title: title,
            theme: topic,
            hskLevel: hskLevel,
          ),
          cards: cards,
        ),
      );
      final saved = await widget.repository.findGenerated(
        theme: topic,
        hskLevel: hskLevel,
      );
      if (saved == null) throw StateError('The lesson could not be reloaded.');
      await _openLesson(saved);
    } catch (error) {
      debugPrint('Lesson generation failed: $error');
      if (!mounted) return;
      setState(() {
        _generating = false;
        _generationFailed = true;
        _notice = null;
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

  Future<List<Flashcard>> _generateWithAi(
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
          'meaning': vocabularyStudyMeaning(candidates[i]),
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
      return _fallbackCard(candidates[index]).copyWith(
        exampleChinese: item['exampleChinese'] as String? ?? '',
        examplePinyin: item['examplePinyin'] as String? ?? '',
        exampleEnglish: item['exampleEnglish'] as String? ?? '',
      );
    }).toList();
  }

  Flashcard _fallbackCard(Map<String, dynamic> word) => Flashcard(
    chinese: word['simplified'] as String,
    pinyin: word['pinyin'] as String,
    englishMeaning: vocabularyStudyMeaning(word),
    partOfSpeech: (word['partOfSpeech'] as List).join(', '),
  );

  Future<void> _savePosition(int index) async {
    final session = _session;
    if (session == null || session.isComplete) return;
    await widget.progressRepository.updateSessionPosition(
      sessionId: session.id,
      currentCardIndex: index,
      expectedCardsReviewed: session.cardsReviewed,
    );
  }

  Future<void> _recordAnswer(Flashcard card, ReviewRating rating) async {
    final session = _session;
    if (session == null ||
        session.isComplete ||
        card.id == 0 ||
        _savingAnswer ||
        _learnedCardIds.contains(card.id) ||
        _reviewCardIds.contains(card.id)) {
      return;
    }
    final submittedIndex = _cards.indexWhere((item) => item.id == card.id);
    if (submittedIndex < 0) return;
    final submissionKey = 'lesson:${session.id}:card:${card.id}';
    if (!_pendingAnswerKeys.add(submissionKey)) return;
    setState(() {
      _savingAnswer = true;
      _notice = null;
    });

    try {
      final history = await widget.progressRepository.reviewHistory(
        cardId: card.id,
      );
      ReviewRecord? existing;
      for (final record in history) {
        if (record.sessionId == session.id) {
          existing = record;
          break;
        }
      }
      final previous = await widget.progressRepository.progressForCard(card.id);
      final now = DateTime.now().toUtc();
      final correct = existing?.wasCorrect ?? rating != ReviewRating.again;
      final scheduled = scheduleCardReview(
        cardId: card.id,
        rating: rating,
        reviewedAt: now,
        previous: previous,
      );
      await widget.progressRepository.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: card.id,
          sessionId: session.id,
          submissionKey: submissionKey,
          reviewedAt: now,
          rating: rating,
          wasCorrect: correct,
        ),
        progress: scheduled,
      );

      final savedHistory = await widget.progressRepository.reviewHistory(
        cardId: card.id,
      );
      ReviewRecord? savedReview;
      for (final record in savedHistory) {
        if (record.sessionId == session.id) {
          savedReview = record;
          break;
        }
      }
      final savedCorrect = savedReview?.wasCorrect ?? correct;
      final savedAt = savedReview?.reviewedAt ?? now;

      final isComplete = session.cardsReviewed + 1 >= _cards.length;
      final reviewedCardIds = {..._learnedCardIds, ..._reviewCardIds, card.id};
      final nextIndex = isComplete
          ? _cards.length
          : _nextUnreviewedCardIndex(
              reviewedCardIds,
              fromIndex: submittedIndex,
            );
      final updated = LessonSession(
        id: session.id,
        lessonId: session.lessonId,
        startedAt: session.startedAt,
        completedAt: isComplete ? savedAt : null,
        currentCardIndex: nextIndex,
        cardsReviewed: session.cardsReviewed + 1,
        correctAnswers: session.correctAnswers + (savedCorrect ? 1 : 0),
      );
      await widget.progressRepository.updateSession(updated);
      _session = updated;
      widget.onProgressChanged?.call();
      if (!mounted) return;
      final hadEarlierReview = history.any(
        (record) => record.sessionId != session.id,
      );
      setState(() {
        (hadEarlierReview ? _reviewCardIds : _learnedCardIds).add(card.id);
        if (isComplete) {
          _activeSessions = {..._activeSessions}..remove(session.lessonId);
          _notice = 'Lesson complete — your reviews were saved.';
        } else {
          _activeSessions = {..._activeSessions, session.lessonId: updated};
        }
      });
      if (!isComplete) _goToCard(nextIndex);
    } catch (error) {
      debugPrint('Lesson answer save failed: $error');
      rethrow;
    } finally {
      _pendingAnswerKeys.remove(submissionKey);
      if (mounted) setState(() => _savingAnswer = false);
    }
  }

  int _nextUnreviewedCardIndex(
    Set<int> reviewedCardIds, {
    required int fromIndex,
  }) {
    for (var offset = 1; offset <= _cards.length; offset++) {
      final index = (fromIndex + offset) % _cards.length;
      if (!reviewedCardIds.contains(_cards[index].id)) return index;
    }
    return (fromIndex + 1) % _cards.length;
  }

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
              '课程',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 36,
                color: AppColors.text,
              ),
            ),
            const Text(
              'Lesson Library',
              style: TextStyle(fontSize: 16, color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _buildLessonLibrary(),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 20),
            const Text(
              'Create a lesson',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a topic or ask AI for something new.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              key: ValueKey(_hskLevel),
              initialValue: _hskLevel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'HSK level',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var level = 1; level <= 6; level++)
                  DropdownMenuItem(value: level, child: Text('HSK $level')),
              ],
              onChanged: (value) {
                final level = value ?? 1;
                setState(() {
                  _hskLevel = level;
                  _selectedTopicTheme = _hskTopicPools[level]!.first;
                });
              },
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              key: ValueKey('topics-$_hskLevel'),
              initialValue: _selectedTopicTheme,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Topic for this HSK level',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final topic in _availableTopics)
                  DropdownMenuItem(
                    value: topic,
                    child: Text(topic, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(
                () => _selectedTopicTheme = value ?? _availableTopics.first,
              ),
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
            if (_generationFailed) ...[
              const SizedBox(height: 14),
              _AppInlineError(
                key: const Key('lesson-generation-error'),
                message: _AppErrorCopy.generateLesson,
              ),
            ],
            const SizedBox(height: 24),
            if (_generationFailed)
              _AppRetryButton(
                key: const Key('lesson-generation-retry'),
                onPressed: _generateLesson,
              )
            else
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

  Widget _buildLessonLibrary() {
    if (_loadingTopics) {
      return const _LessonLibraryStateCard(
        key: Key('lesson-library-loading-state'),
        accent: AppColors.red,
        icon: SizedBox.square(
          dimension: 25,
          child: CircularProgressIndicator(
            color: AppColors.red,
            strokeWidth: 2.5,
            semanticsLabel: 'Loading saved lessons',
          ),
        ),
        title: 'Loading your lesson library',
        message: 'Finding your saved lessons and current progress.',
      );
    }
    if (_libraryLoadFailed) {
      return _AppErrorState(
        key: const Key('lesson-library-error-state'),
        title: _AppErrorCopy.lessonsTitle,
        message: _AppErrorCopy.lessonsMessage,
        onRetry: _beginTopicsLoad,
        retryKey: const Key('lesson-library-retry'),
      );
    }
    if (_topics.isEmpty) {
      return const _LessonLibraryStateCard(
        key: Key('lesson-library-empty-state'),
        accent: AppColors.teal,
        icon: Icon(Icons.menu_book_outlined, size: 30, color: AppColors.teal),
        title: 'No saved lessons yet',
        message:
            'Choose a topic below to create your first lesson. It will appear '
            'here when you’re ready to return to it.',
      );
    }

    return Column(
      key: const Key('lesson-library-content'),
      children: [
        for (final topic in _topics) ...[
          _LessonLibraryCard(
            summary: topic,
            isActive: _activeSessions.containsKey(topic.id),
            onPressed: () => _startLesson(topic),
          ),
          if (topic != _topics.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildFlashcards() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: _savingAnswer
                  ? null
                  : () => setState(() {
                      _cards = const [];
                      _session = null;
                      _learnedCardIds.clear();
                      _reviewCardIds.clear();
                    }),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lessonTitle,
                    style: const TextStyle(fontSize: 18, color: AppColors.text),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _lessonProgress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_session?.cardsReviewed ?? 0} of '
                    '${_cards.length} words completed',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: _session?.isComplete == true
            ? _buildCompletionSummary()
            : PageView.builder(
                itemCount: _cards.length,
                controller: _pageController,
                physics: _savingAnswer
                    ? const NeverScrollableScrollPhysics()
                    : null,
                onPageChanged: (index) {
                  setState(() => _currentCard = index);
                  _savePosition(index);
                },
                itemBuilder: (context, index) => _LessonFlashcard(
                  key: ValueKey('lesson-card-${_cards[index].id}'),
                  card: _cards[index],
                  index: index,
                  total: _cards.length,
                  alreadyRated:
                      _learnedCardIds.contains(_cards[index].id) ||
                      _reviewCardIds.contains(_cards[index].id),
                  onRated: (rating) => _recordAnswer(_cards[index], rating),
                  onSpeak: _soundEnabled ? () => _speak(_cards[index]) : null,
                ),
              ),
      ),
      if (_session?.isComplete != true)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _savingAnswer || _currentCard == 0
                    ? null
                    : () => _goToCard(_currentCard - 1),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _savingAnswer || _currentCard >= _cards.length - 1
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

  double get _lessonProgress {
    if (_cards.isEmpty) return 0;
    return ((_session?.cardsReviewed ?? 0) / _cards.length).clamp(0, 1);
  }

  int get _xpEarned =>
      (_learnedCardIds.length * 10) + (_reviewCardIds.length * 5);

  Widget _buildCompletionSummary() {
    final reviewed = _session?.cardsReviewed ?? 0;
    final correct = _session?.correctAnswers ?? 0;
    final accuracy = reviewed == 0 ? 0 : ((correct / reviewed) * 100).round();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    size: 52,
                    color: AppColors.gold,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Lesson complete!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lessonTitle,
                    style: const TextStyle(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SummaryStat(
                        icon: Icons.track_changes,
                        label: 'Accuracy',
                        value: '$accuracy%',
                      ),
                      _SummaryStat(
                        icon: Icons.school_outlined,
                        label: 'Learned words',
                        value: '${_learnedCardIds.length}',
                      ),
                      _SummaryStat(
                        icon: Icons.replay_outlined,
                        label: 'Review words',
                        value: '${_reviewCardIds.length}',
                      ),
                      _SummaryStat(
                        icon: Icons.bolt,
                        label: 'XP earned',
                        value: '+$_xpEarned XP',
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => setState(() {
                      _cards = const [];
                      _session = null;
                      _learnedCardIds.clear();
                      _reviewCardIds.clear();
                      _notice = null;
                    }),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: AppColors.gold),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LessonLibraryStateCard extends StatelessWidget {
  const _LessonLibraryStateCard({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.message,
  });

  final Color accent;
  final Widget icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: accent.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: icon,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    ),
  );
}

class _LessonLibraryCard extends StatelessWidget {
  const _LessonLibraryCard({
    required this.summary,
    required this.isActive,
    required this.onPressed,
  });

  final LessonSummary summary;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.darkRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book_outlined),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.theme} · HSK ${summary.hskLevel}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onPressed,
              child: Text(isActive ? 'Resume' : 'Start'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LessonFlashcard extends StatefulWidget {
  const _LessonFlashcard({
    super.key,
    required this.card,
    required this.index,
    required this.total,
    required this.alreadyRated,
    required this.onRated,
    required this.onSpeak,
  });
  final Flashcard card;
  final int index;
  final int total;
  final bool alreadyRated;
  final Future<void> Function(ReviewRating rating) onRated;
  final Future<void> Function()? onSpeak;

  @override
  State<_LessonFlashcard> createState() => _LessonFlashcardState();
}

class _LessonFlashcardState extends State<_LessonFlashcard> {
  bool _showAnswer = false;
  bool _submitting = false;
  late bool _rated;
  String? _ratingError;
  ReviewRating? _failedRating;

  @override
  void initState() {
    super.initState();
    _rated = widget.alreadyRated;
  }

  @override
  void didUpdateWidget(covariant _LessonFlashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _showAnswer = false;
      _rated = widget.alreadyRated;
      _ratingError = null;
      _failedRating = null;
    } else if (widget.alreadyRated) {
      _rated = true;
    }
  }

  void _flip() => setState(() => _showAnswer = !_showAnswer);

  Future<void> _rate(ReviewRating rating) async {
    if (_submitting || _rated) return;
    setState(() {
      _submitting = true;
      _ratingError = null;
      _failedRating = null;
    });
    try {
      await widget.onRated(rating);
      if (mounted) setState(() => _rated = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _ratingError = _AppErrorCopy.saveAnswer;
          _failedRating = rating;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: _showAnswer ? 'Flashcard answer' : 'Flashcard question',
    hint: 'Tap to flip the card',
    child: GestureDetector(
      onTap: _flip,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            final rotation = Tween(begin: pi, end: 0.0).animate(animation);
            return AnimatedBuilder(
              animation: rotation,
              child: child,
              builder: (context, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(rotation.value),
                child: child,
              ),
            );
          },
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [...previousChildren, ?currentChild],
          ),
          child: _showAnswer
              ? _buildAnswer(key: const ValueKey('answer'))
              : _buildQuestion(key: const ValueKey('question')),
        ),
      ),
    ),
  );

  Widget _buildQuestion({required Key key}) => _cardSide(
    key: key,
    children: [
      const Spacer(),
      Text(
        widget.card.chinese,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'serif',
          fontSize: 64,
          color: AppColors.text,
        ),
      ),
      IconButton(
        tooltip: widget.onSpeak == null
            ? 'Pronunciation audio is disabled in Settings'
            : 'Hear Mandarin pronunciation',
        onPressed: widget.onSpeak,
        icon: const Icon(Icons.volume_up_outlined),
      ),
      const Spacer(),
    ],
  );

  Widget _buildAnswer({required Key key}) => _cardSide(
    key: key,
    children: [
      const Spacer(),
      Text(
        widget.card.pinyin,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, color: AppColors.gold),
      ),
      IconButton(
        tooltip: widget.onSpeak == null
            ? 'Pronunciation audio is disabled in Settings'
            : 'Hear Mandarin pronunciation',
        onPressed: widget.onSpeak,
        icon: const Icon(Icons.volume_up_outlined),
      ),
      const SizedBox(height: 18),
      Text(
        widget.card.englishMeaning,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 26, color: AppColors.text),
      ),
      if (widget.card.exampleChinese.isNotEmpty) ...[
        const SizedBox(height: 28),
        Text(widget.card.exampleChinese, textAlign: TextAlign.center),
        if (widget.card.examplePinyin.isNotEmpty)
          Text(
            widget.card.examplePinyin,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        Text(
          widget.card.exampleEnglish,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        if (widget.card.exampleSource.isNotEmpty)
          Text(
            '${widget.card.exampleSource} · sentence ${widget.card.exampleSourceId}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.faint),
          ),
      ],
      const Spacer(),
      OutlinedButton(
        onPressed: _submitting || _rated || _ratingError != null
            ? null
            : () => _rate(ReviewRating.easy),
        child: const Text('Click if you are already familiar with this word'),
      ),
      if (_ratingError != null) ...[
        const SizedBox(height: 8),
        _AppInlineError(
          key: const Key('lesson-answer-error'),
          message: _ratingError!,
          onRetry: _failedRating == null ? null : () => _rate(_failedRating!),
          retryKey: const Key('lesson-answer-retry'),
        ),
      ],
      const SizedBox(height: 12),
    ],
  );

  Widget _cardSide({required Key key, required List<Widget> children}) =>
      Padding(
        key: key,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${widget.index + 1} / ${widget.total}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            ...children,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flip, size: 18, color: AppColors.muted),
                const SizedBox(width: 8),
                Text(
                  _showAnswer ? 'Tap for word' : 'Tap for answer',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
      );
}
