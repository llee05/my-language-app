part of '../../main.dart';

enum _RushDifficulty {
  beginner('入门', 'Beginner', 1, 2),
  intermediate('进阶', 'Intermediate', 3, 4),
  advanced('挑战', 'Advanced', 5, 6);

  const _RushDifficulty(this.chinese, this.english, this.minHsk, this.maxHsk);

  final String chinese;
  final String english;
  final int minHsk;
  final int maxHsk;
}

enum _RushDuration {
  threeMinutes('3 minutes', 180),
  fiveMinutes('5 minutes', 300),
  unlimited('Survival', null);

  const _RushDuration(this.label, this.seconds);

  final String label;
  final int? seconds;
}

class VocabRushPage extends StatefulWidget {
  const VocabRushPage({
    super.key,
    this.lessonRepository = const SqliteLessonRepository(),
    this.progressRepository = const SqliteProgressRepository(),
    this.dailyReviewSessionRepository,
    this.settingsRepository = const SqliteSettingsRepository(),
    this.pronunciationService,
    this.initialVocabulary,
    this.vocabularyRepository = const BundledVocabularyRepository(),
    this.studyService,
    this.onProgressChanged,
    this.onNavigationBlocked,
    this.clock,
  });

  final VocabularyStudyService? studyService;
  final VoidCallback? onProgressChanged;
  final ValueChanged<bool>? onNavigationBlocked;
  final DateTime Function()? clock;

  final LessonRepository lessonRepository;
  final ProgressRepository progressRepository;
  final DailyReviewSessionRepository? dailyReviewSessionRepository;
  final SettingsRepository settingsRepository;
  final PronunciationService? pronunciationService;
  final List<Map<String, dynamic>>? initialVocabulary;
  final BundledVocabularyRepository vocabularyRepository;

  @override
  State<VocabRushPage> createState() => _VocabRushPageState();
}

class _VocabRushPageState extends State<VocabRushPage>
    with WidgetsBindingObserver {
  final _random = Random();
  late final PronunciationService _pronunciationService;
  late final bool _ownsPronunciationService;
  late final VocabularyStudyService _studyService;
  _RushDifficulty _difficulty = _RushDifficulty.beginner;
  _RushDuration _duration = _RushDuration.threeMinutes;
  Timer? _timer;
  Timer? _feedbackTimer;
  DateTime? _deadline;
  String _finishReason = 'Game ended.';
  int _gameGeneration = 0;
  List<Map<String, dynamic>> _cards = const [];
  Map<String, dynamic>? _card;
  List<String> _answers = const [];
  String? _selectedAnswer;
  _RushAnswerSubmission? _pendingAnswer;
  bool _savingAnswer = false;
  bool _feedbackElapsed = false;
  String? _saveError;
  String? _requestedFinishReason;
  int _secondsLeft = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _attempts = 0;
  int _mistakes = 0;
  String _gameRunId = '';
  bool _playing = false;
  bool _finished = false;
  bool _starting = false;
  String? _startError;
  bool _soundEnabled = true;
  LearnerSettings _learnerSettings = const LearnerSettings();

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _studyService =
        widget.studyService ??
        VocabularyStudyService(
          lessons: widget.lessonRepository,
          progress: widget.progressRepository,
          clock: widget.clock,
        );
    _ownsPronunciationService = widget.pronunciationService == null;
    _pronunciationService =
        widget.pronunciationService ?? createSystemPronunciationService();
    unawaited(_loadSoundPreference());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _feedbackTimer?.cancel();
    if (_ownsPronunciationService) {
      unawaited(_pronunciationService.dispose());
    } else {
      unawaited(_stopPronunciation());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
    if (state == AppLifecycleState.paused) unawaited(_stopPronunciation());
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    if (_pendingAnswer == null) return AppExitResponse.exit;
    _finish();
    return AppExitResponse.cancel;
  }

  void _tick() {
    final deadline = _deadline;
    if (!mounted ||
        !_playing ||
        deadline == null ||
        _requestedFinishReason != null) {
      return;
    }
    final remaining = deadline.difference(_now()).inMilliseconds;
    if (remaining <= 0) {
      _finish(reason: 'Time!');
    } else {
      final seconds = (remaining / Duration.millisecondsPerSecond).ceil();
      if (seconds != _secondsLeft) setState(() => _secondsLeft = seconds);
    }
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
      debugPrint('Vocab Rush sound preference load failed: $error');
    }
  }

  Future<void> _speakCurrentCard() async {
    final card = _card;
    if (!_soundEnabled || card == null) return;
    try {
      await applyPronunciationSettings(_pronunciationService, _learnerSettings);
      await _pronunciationService.speakMandarin(card['chinese'] as String);
    } catch (error) {
      if (!mounted) return;
      _showPronunciationError(context, _pronunciationService, error);
    }
  }

  Future<void> _stopPronunciation() async {
    try {
      await _pronunciationService.stop();
    } catch (error) {
      debugPrint('Vocab Rush pronunciation stop failed: $error');
    }
  }

  Future<void> _start() async {
    if (_starting || _playing || _pendingAnswer != null) return;
    setState(() {
      _starting = true;
      _startError = null;
    });
    _timer?.cancel();
    try {
      _feedbackTimer?.cancel();
      final vocabulary =
          widget.initialVocabulary ??
          await widget.vocabularyRepository.load(
            bundle: DefaultAssetBundle.of(context),
          );
      if (!mounted) return;
      _cards = vocabulary
          .cast<Map<String, dynamic>>()
          .where((card) {
            final level = card['hskLevel'] as int;
            return level >= _difficulty.minHsk && level <= _difficulty.maxHsk;
          })
          .map(
            (card) => {
              'chinese': card['simplified'],
              'pinyin': card['pinyin'],
              'english_meaning': vocabularyStudyMeaning(card),
              'meanings': card['meanings'] ?? const <String>[],
              'hsk_level': card['hskLevel'],
              'part_of_speech':
                  (card['partOfSpeech'] as List<dynamic>? ?? const []).join(
                    ', ',
                  ),
            },
          )
          .toList();
      if (_cards.isEmpty) {
        setState(
          () => _startError =
              'No words are available for this difficulty. Choose another difficulty.',
        );
        return;
      }
      _cards.shuffle(_random);
      final gameRunId = DateTime.now()
          .toUtc()
          .microsecondsSinceEpoch
          .toString();

      setState(() {
        _gameGeneration++;
        _playing = true;
        _finished = false;
        _secondsLeft = _duration.seconds ?? 0;
        _deadline = _duration.seconds == null
            ? null
            : _now().add(Duration(seconds: _duration.seconds!));
        _score = 0;
        _streak = 0;
        _bestStreak = 0;
        _attempts = 0;
        _mistakes = 0;
        _gameRunId = gameRunId;
        _selectedAnswer = null;
        _requestedFinishReason = null;
        _saveError = null;
        _feedbackElapsed = false;
        _nextCard();
      });

      if (_duration.seconds != null) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      }
    } catch (error) {
      debugPrint('Vocab Rush vocabulary load failed: $error');
      if (mounted) {
        setState(
          () => _startError = 'Words could not be loaded. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _nextCard() {
    if (_cards.isEmpty) return;
    _card = _cards[_attempts % _cards.length];
    final candidates = List<Map<String, dynamic>>.of(_cards)..shuffle(_random);
    QuizMeaning meaningFor(Map<String, dynamic> card) => QuizMeaning(
      card['english_meaning'] as String,
      pinyin: card['pinyin'] as String,
      meanings: (card['meanings'] as List).cast<String>(),
    );
    _answers = buildMeaningOptions(
      answer: meaningFor(_card!),
      candidates: candidates.map(meaningFor),
    )..shuffle(_random);
    _selectedAnswer = null;
  }

  void _answer(String answer) {
    _tick();
    if (_selectedAnswer != null || !_playing) return;
    final generation = _gameGeneration;
    unawaited(_stopPronunciation());
    final source = Map<String, dynamic>.of(_card!);
    final correct = answer == source['english_meaning'];
    setState(() {
      _selectedAnswer = answer;
      _attempts++;
      if (correct) {
        _score++;
        _streak++;
        _bestStreak = max(_bestStreak, _streak);
      } else {
        _streak = 0;
        _mistakes++;
      }
      _feedbackElapsed = false;
      _pendingAnswer = _RushAnswerSubmission(
        card: Flashcard(
          chinese: source['chinese'] as String,
          pinyin: source['pinyin'] as String,
          englishMeaning: source['english_meaning'] as String,
          partOfSpeech: source['part_of_speech'] as String,
        ),
        hskLevel: source['hsk_level'] as int,
        correct: correct,
        submissionKey: 'vocab-rush:$_gameRunId:attempt:$_attempts',
        queueDate: _now(),
      );
    });
    widget.onNavigationBlocked?.call(true);
    unawaited(_savePractice());
    _feedbackTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || !_playing || generation != _gameGeneration) return;
      _feedbackElapsed = true;
      _advanceAfterAnswer();
    });
  }

  void _advanceAfterAnswer() {
    if (!mounted || !_playing || _pendingAnswer != null) return;
    if (_requestedFinishReason case final reason?) {
      _finish(reason: reason);
      return;
    }
    if (!_feedbackElapsed) return;
    _tick();
    if (!_playing) return;
    if (_mistakes >= 3) {
      _finish(reason: 'Three strikes!');
    } else {
      setState(_nextCard);
    }
  }

  Future<void> _savePractice() async {
    final submission = _pendingAnswer;
    if (submission == null || _savingAnswer) return;
    setState(() {
      _savingAnswer = true;
      _saveError = null;
    });
    try {
      if (submission.savedCard == null) {
        submission.savedCard = await _studyService.recordCard(
          submission.card,
          hskLevel: submission.hskLevel,
          rating: submission.correct ? ReviewRating.good : ReviewRating.again,
          submissionKey: submission.submissionKey,
        );
        if (mounted) widget.onProgressChanged?.call();
      }
      if (!submission.correct) {
        await widget.dailyReviewSessionRepository?.enqueueCard(
          date: submission.queueDate,
          cardId: submission.savedCard!.id,
        );
      }
      if (!mounted) return;
      setState(() => _pendingAnswer = null);
      widget.onNavigationBlocked?.call(false);
      _advanceAfterAnswer();
    } catch (error) {
      debugPrint('Vocab Rush review queue update failed: $error');
      if (mounted) {
        setState(
          () => _saveError = submission.savedCard == null
              ? 'Your vocabulary progress could not be saved.'
              : _AppErrorCopy.addToReview,
        );
      }
    } finally {
      if (mounted) setState(() => _savingAnswer = false);
    }
  }

  void _finish({String reason = 'Game ended.'}) {
    _timer?.cancel();
    unawaited(_stopPronunciation());
    if (_pendingAnswer != null) {
      setState(() {
        _secondsLeft = 0;
        _requestedFinishReason ??= reason;
      });
      return;
    }
    _feedbackTimer?.cancel();
    setState(() {
      _secondsLeft = 0;
      _playing = false;
      _finished = true;
      _finishReason = reason;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _pendingAnswer != null) _finish();
      },
      child: _BackNavigationScope(
        active: _playing,
        blocked: _pendingAnswer != null,
        onBack: _finish,
        child: ColoredBox(
          color: AppColors.background,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 600 ? 20 : 48,
                vertical: 34,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _playing ? _buildGame() : _buildLobby(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLobby() {
    return Column(
      children: [
        const SizedBox(height: 12),
        _modeBadge(),
        const SizedBox(height: 20),
        const _AppPageHeader(
          title: 'Vocab Rush',
          hanzi: '词汇冲刺',
          centered: true,
          description:
              'Pick the correct English meaning and see how many words you know.',
        ),
        const SizedBox(height: 32),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final difficulty in _RushDifficulty.values)
              _difficultyCard(difficulty),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'CHOOSE A TIME',
          style: TextStyle(
            letterSpacing: 1.5,
            fontSize: 10,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final duration in _RushDuration.values)
              ChoiceChip(
                label: Text(duration.label),
                selected: _duration == duration,
                onSelected: _starting
                    ? null
                    : (_) => setState(() => _duration = duration),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Three mistakes end the game. The clock continues while the app is in the background.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.6, color: AppColors.muted),
        ),
        if (_startError != null) ...[
          const SizedBox(height: 16),
          _AppInlineError(message: _startError!),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: 285,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
            onPressed: _starting ? null : _start,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_martial_arts_rounded, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _starting
                        ? 'Loading words…'
                        : _finished
                        ? '再玩一次 — Play Again'
                        : '开始游戏 — Start Game',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_finished) ...[
          const SizedBox(height: 30),
          Text(
            '$_finishReason You scored $_score ${_score == 1 ? 'word' : 'words'}.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          _scoreRow(),
        ],
      ],
    );
  }

  Widget _buildGame() {
    final durationSeconds = _duration.seconds;
    final progress = durationSeconds == null
        ? null
        : _secondsLeft / durationSeconds;
    return Column(
      children: [
        Row(
          children: [
            if (progress != null)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    color: progress < .25 ? AppColors.red : AppColors.gold,
                    backgroundColor: AppColors.surface,
                  ),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 14),
            Text(
              durationSeconds == null ? '∞' : '${_secondsLeft}s',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(width: 20),
            _strikeMarker(),
          ],
        ),
        const SizedBox(height: 52),
        Text(
          'PICK THE CORRECT MEANING',
          style: TextStyle(
            letterSpacing: 1.5,
            fontSize: 10,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _card!['chinese'] as String,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 64,
            color: AppColors.text,
          ),
        ),
        if (_learnerSettings.showPinyin)
          Text(
            _card!['pinyin'] as String,
            style: TextStyle(fontSize: 16, color: AppColors.gold),
          ),
        PronunciationButton(
          requestKey: _attempts,
          key: const Key('vocab-rush-pronunciation'),
          tooltip: _soundEnabled
              ? 'Hear Mandarin pronunciation'
              : 'Pronunciation audio is disabled in Settings',
          onPressed: _soundEnabled ? _speakCurrentCard : null,
        ),
        const SizedBox(height: 38),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 480;
            final width = twoColumns
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final answer in _answers)
                  SizedBox(width: width, child: _answerButton(answer)),
              ],
            );
          },
        ),
        const SizedBox(height: 34),
        if (_saveError != null) ...[
          _AppInlineError(
            key: const Key('vocab-rush-save-error'),
            message: _saveError!,
            onRetry: _savingAnswer ? null : () => unawaited(_savePractice()),
            retryKey: const Key('vocab-rush-retry-save'),
          ),
          const SizedBox(height: 16),
        ] else if (_savingAnswer) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              _requestedFinishReason == null
                  ? 'Saving your answer…'
                  : 'Finishing the game after your answer is saved…',
              key: const Key('vocab-rush-saving'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _scoreRow(),
      ],
    );
  }

  Widget _answerButton(String answer) {
    final correct = _card!['english_meaning'] as String;
    Color border = AppColors.border;
    Color background = AppColors.surface;
    if (_selectedAnswer != null && answer == correct) {
      border = AppColors.teal;
      background = AppColors.teal.withValues(alpha: .12);
    } else if (_selectedAnswer == answer) {
      border = AppColors.red;
      background = AppColors.red.withValues(alpha: .12);
    }
    return OutlinedButton(
      onPressed: _selectedAnswer == null ? () => _answer(answer) : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        foregroundColor: AppColors.text,
        backgroundColor: background,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(answer, textAlign: TextAlign.center),
    );
  }

  Widget _difficultyCard(_RushDifficulty difficulty) {
    final selected = difficulty == _difficulty;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !_starting,
      child: InkWell(
        onTap: _starting
            ? null
            : () => setState(() => _difficulty = difficulty),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    AppColors.gold.withValues(alpha: .12),
                    AppColors.surface,
                  )
                : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.divider,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                difficulty.chinese,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 20,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                difficulty.english,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'HSK ${difficulty.minHsk}–${difficulty.maxHsk}',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _strikeMarker() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$_mistakes/3',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
      const SizedBox(width: 6),
      for (var strike = 0; strike < 3; strike++) ...[
        Icon(
          Icons.close_rounded,
          size: 20,
          color: strike < _mistakes ? AppColors.red : AppColors.border,
        ),
        if (strike < 2) const SizedBox(width: 2),
      ],
    ],
  );

  Widget _scoreRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 32,
      runSpacing: 16,
      children: [
        _stat('$_score', 'Correct'),
        _stat('×$_streak', 'Streak'),
        _stat('×$_bestStreak', 'Best streak'),
      ],
    );
  }

  Widget _stat(String value, String label) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 9, color: AppColors.muted)),
    ],
  );

  Widget _modeBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.darkRed),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.sports_martial_arts_rounded, size: 13, color: AppColors.red),
        SizedBox(width: 7),
        Text(
          'GAME MODE',
          style: TextStyle(
            letterSpacing: 1.4,
            fontSize: 9,
            color: AppColors.red,
          ),
        ),
      ],
    ),
  );
}

class _RushAnswerSubmission {
  _RushAnswerSubmission({
    required this.card,
    required this.hskLevel,
    required this.correct,
    required this.submissionKey,
    required this.queueDate,
  });

  final Flashcard card;
  final int hskLevel;
  final bool correct;
  final String submissionKey;
  final DateTime queueDate;
  // A queue retry must not re-record an already committed vocabulary review.
  Flashcard? savedCard;
}
