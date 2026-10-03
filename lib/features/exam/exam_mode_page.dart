part of '../../main.dart';

class ExamModePage extends StatefulWidget {
  const ExamModePage({
    super.key,
    this.initialLevel = 1,
    this.vocabularyRepository = const BundledVocabularyRepository(),
    required this.settingsRepository,
    required this.pronunciationService,
    this.random,
    this.studyService,
    this.onProgressChanged,
  });

  final VocabularyStudyService? studyService;
  final VoidCallback? onProgressChanged;

  final int initialLevel;
  final BundledVocabularyRepository vocabularyRepository;
  final SettingsRepository settingsRepository;
  final PronunciationService pronunciationService;
  final Random? random;

  @override
  State<ExamModePage> createState() => _ExamModePageState();
}

class _ExamModePageState extends State<ExamModePage> {
  late int _level = widget.initialLevel.clamp(1, 6);
  List<Map<String, dynamic>>? _vocabulary;
  bool _loading = true;
  bool _failed = false;
  bool _listening = false;
  bool _soundEnabled = false;
  bool _timed = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      // Cached asset loads can return a SynchronousFuture. Await directly so
      // warm and cold vocabulary caches follow the same initialization path.
      final vocabulary = await widget.vocabularyRepository.load();
      final settings = await widget.settingsRepository.load();
      if (!mounted) return;
      setState(() {
        _vocabulary = vocabulary;
        _soundEnabled = settings.soundEnabled;
        _listening = settings.soundEnabled;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Exam vocabulary load failed: $error');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _start() {
    try {
      final exam = HskExamGenerator(
        random: widget.random,
      ).generate(_vocabulary!, level: _level, includeListening: _listening);
      setState(() => _error = null);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExamSessionPage(
            studyService: widget.studyService,
            onProgressChanged: widget.onProgressChanged,
            exam: exam,
            timed: _timed,
            pronunciationService: widget.pronunciationService,
          ),
        ),
      );
    } catch (_) {
      setState(
        () => _error =
            'A full exam could not be created for this level. Please reload the vocabulary and try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _AppErrorState(
          title: 'Exam vocabulary could not be loaded',
          message: 'Please try again.',
          onRetry: _load,
        ),
      );
    }
    return SingleChildScrollView(
      key: const Key('exam-mode-page'),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'HSK Exam Mode',
                style: TextStyle(fontSize: 30, color: AppColors.text),
              ),
              const SizedBox(height: 12),
              const Text(
                'Test your reading, pinyin, written recall, and listening with fresh questions from the bundled HSK vocabulary.',
              ),
              const SizedBox(height: 12),
              Text(
                'TingShuo practice assessments, not official HSK papers. '
                'Each exam samples vocabulary from the selected level. '
                'Results are available until you leave the exam.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var level = 1; level <= 6; level++)
                    ChoiceChip(
                      key: Key('exam-level-$level'),
                      label: Text('HSK $level'),
                      selected: _level == level,
                      onSelected: (_) => setState(() {
                        _level = level;
                        _error = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${HskExam.questionsPerSection(_level) * (_listening ? 4 : 3)} questions · '
                        '${HskExam.questionsPerSection(_level)} per section',
                        key: const Key('exam-question-count'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Reading: choose the meaning\nPinyin: identify the pronunciation\nWritten recall: type the Chinese word',
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        key: const Key('exam-listening-toggle'),
                        title: const Text('Include listening'),
                        subtitle: Text(
                          _soundEnabled
                              ? 'Requires a working Mandarin voice on this device.'
                              : 'Enable sound in Settings to include listening.',
                        ),
                        value: _listening,
                        onChanged: _soundEnabled
                            ? (value) => setState(() => _listening = value)
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        key: const Key('exam-timed-toggle'),
                        title: Text('Timed exam · ${20 + _level * 5} minutes'),
                        subtitle: const Text(
                          'The clock continues while the app is in the background.',
                        ),
                        value: _timed,
                        onChanged: (value) => setState(() => _timed = value),
                      ),
                      const Text(
                        'Answers stay hidden until submission. You can skip, revisit, and change answers. Unanswered questions count as incorrect.',
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('exam-start'),
                        onPressed: _start,
                        icon: const Icon(Icons.assignment_outlined),
                        label: Text('Start HSK $_level exam'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: AppColors.red)),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Reload vocabulary'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExamSessionPage extends StatefulWidget {
  const ExamSessionPage({
    super.key,
    required this.exam,
    required this.pronunciationService,
    this.timed = true,
    this.clock,
    this.studyService,
    this.onProgressChanged,
  });

  final VocabularyStudyService? studyService;
  final VoidCallback? onProgressChanged;

  final HskExam exam;
  final PronunciationService pronunciationService;
  final bool timed;
  final DateTime Function()? clock;

  @override
  State<ExamSessionPage> createState() => _ExamSessionPageState();
}

class _ExamSessionPageState extends State<ExamSessionPage>
    with WidgetsBindingObserver {
  late final List<String?> _responses = List.filled(
    widget.exam.questions.length,
    null,
  );
  final _excluded = <int>{};
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final DateTime _deadline = _now().add(widget.exam.timeLimit);
  Timer? _timer;
  int _position = 0;
  bool _playing = false;
  int _audioRequest = 0;
  bool _audioFailed = false;
  bool _dialogOpen = false;
  bool _allowExit = false;
  ExamResult? _result;
  bool _savingProgress = false;
  String? _progressError;
  final _studyRunId = DateTime.now().microsecondsSinceEpoch.toString();
  DateTime _now() => widget.clock?.call() ?? DateTime.now();
  ExamQuestion get _question => widget.exam.questions[_position];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.timed) {
      // Anchor the deadline at session creation, before the first timer tick.
      _deadline;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
    if (state == AppLifecycleState.paused) unawaited(_stopAudio());
  }

  void _tick() {
    if (!mounted || _result != null || !widget.timed) return;
    if (!_now().isBefore(_deadline)) {
      _finish(timedOut: true);
    } else {
      setState(() {});
    }
  }

  Future<void> _stopAudio() async {
    _audioRequest++;
    _playing = false;
    try {
      await widget.pronunciationService.stop();
    } catch (_) {
      /* Optional audio. */
    }
  }

  Future<void> _play() async {
    if (_playing || _result != null) return;
    final request = ++_audioRequest;
    setState(() {
      _playing = true;
      _audioFailed = false;
    });
    try {
      await widget.pronunciationService.speakMandarin(_question.word.hanzi);
    } catch (_) {
      if (mounted && request == _audioRequest) {
        setState(() => _audioFailed = true);
      }
    } finally {
      if (mounted && request == _audioRequest) setState(() => _playing = false);
    }
  }

  void _go(int position) {
    _tick();
    if (_result != null) return;
    unawaited(_stopAudio());
    setState(() {
      _position = position;
      _audioFailed = false;
      _text.text = _responses[position] ?? '';
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _answer(String value) {
    _tick();
    if (_result != null) return;
    setState(() {
      _responses[_position] = value;
      _excluded.remove(_position);
    });
  }

  void _finish({bool timedOut = false}) {
    if (_result != null) return;
    _timer?.cancel();
    if (_dialogOpen) Navigator.of(context).pop(false);
    unawaited(_stopAudio());
    setState(
      () => _result = ExamResult(
        exam: widget.exam,
        responses: _responses,
        excluded: _excluded,
        timedOut: timedOut,
      ),
    );
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(_saveResult());
  }

  Future<void> _saveResult() async {
    final service = widget.studyService;
    final result = _result;
    if (service == null || result == null || _savingProgress) return;
    setState(() {
      _savingProgress = true;
      _progressError = null;
    });
    try {
      for (final (index, question) in widget.exam.questions.indexed) {
        if (result.excluded.contains(index) ||
            result.responses[index]?.trim().isNotEmpty != true) {
          continue;
        }
        await service.recordCard(
          Flashcard(
            chinese: question.word.hanzi,
            pinyin: question.word.pinyin,
            englishMeaning: question.word.meaning,
          ),
          hskLevel: widget.exam.level,
          rating: question.isCorrect(result.responses[index])
              ? ReviewRating.good
              : ReviewRating.again,
          submissionKey: 'exam:$_studyRunId:$index',
        );
      }
      widget.onProgressChanged?.call();
    } catch (error) {
      debugPrint('Exam vocabulary progress save failed: $error');
      if (mounted) {
        setState(
          () => _progressError =
              'Your vocabulary progress could not be saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingProgress = false);
    }
  }

  Future<void> _submit() async {
    _tick();
    if (_result != null || _dialogOpen) return;
    _dialogOpen = true;
    final unanswered =
        _responses.where((answer) => answer?.trim().isNotEmpty != true).length -
        _excluded.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit exam?'),
        content: Text(
          '$unanswered unanswered questions will count as incorrect. Answers cannot be changed after submission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep working'),
          ),
          FilledButton(
            key: const Key('exam-confirm-submit'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (mounted && confirmed == true) _finish();
  }

  Future<void> _exit() async {
    if (_dialogOpen || _savingProgress) return;
    _dialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this exam?'),
        content: Text(
          _progressError != null
              ? 'Some vocabulary progress has not been saved. Leave anyway?'
              : 'This attempt and its answers will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue exam'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave exam'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted || confirmed != true) return;
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_stopAudio());
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop:
        (_result != null && !_savingProgress && _progressError == null) ||
        _allowExit,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_exit());
    },
    child: Scaffold(
      appBar: AppBar(title: Text('HSK ${widget.exam.level} practice exam')),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _result == null
                  ? _buildQuestion()
                  : _buildResult(_result!),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildQuestion() {
    final seconds = widget.timed
        ? max(0, _deadline.difference(_now()).inSeconds)
        : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Question ${_position + 1} of ${widget.exam.questions.length}',
              key: const Key('exam-position'),
            ),
            Text(
              widget.timed
                  ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} remaining'
                  : 'Untimed',
              key: const Key('exam-timer'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value:
              (_responses
                      .where((answer) => answer?.trim().isNotEmpty == true)
                      .length +
                  _excluded.length) /
              _responses.length,
        ),
        const SizedBox(height: 20),
        Text(
          _question.section.label,
          style: TextStyle(color: AppColors.gold, fontSize: 20),
        ),
        const SizedBox(height: 16),
        Text(
          _question.prompt,
          key: const Key('exam-prompt'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28),
        ),
        const SizedBox(height: 20),
        if (_question.section == ExamSection.listening) ...[
          FilledButton.icon(
            key: const Key('exam-play'),
            onPressed: _playing ? null : _play,
            icon: const Icon(Icons.volume_up),
            label: Text(_playing ? 'Playing…' : 'Play Mandarin'),
          ),
          if (_audioFailed) ...[
            const Text(
              'Audio could not be played. Try again or skip this question without a score.',
            ),
            TextButton(
              key: const Key('exam-skip-audio'),
              onPressed: () => setState(() {
                _responses[_position] = null;
                _excluded.add(_position);
                _audioFailed = false;
              }),
              child: const Text('Skip unavailable audio'),
            ),
          ],
          if (_excluded.contains(_position))
            const Text('Audio unavailable · unscored'),
          const SizedBox(height: 12),
        ],
        if (_question.section == ExamSection.writing)
          TextField(
            key: const Key('exam-written-answer'),
            controller: _text,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: _answer,
            decoration: const InputDecoration(
              labelText: 'Type the Chinese word',
              helperText: 'Simplified or traditional characters accepted.',
              border: OutlineInputBorder(),
            ),
          )
        else ...[
          for (var i = 0; i < _question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                key: Key('exam-option-$i'),
                onPressed: () => _answer(_question.options[i]),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: _responses[_position] == _question.options[i]
                      ? AppColors.red.withValues(alpha: .15)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      _responses[_position] == _question.options[i]
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_question.options[i])),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              key: const Key('exam-previous'),
              onPressed: _position == 0 ? null : () => _go(_position - 1),
              child: const Text('Previous'),
            ),
            if (_position < widget.exam.questions.length - 1)
              FilledButton(
                key: const Key('exam-next'),
                onPressed: () => _go(_position + 1),
                child: const Text('Next'),
              ),
            TextButton(
              key: const Key('exam-submit'),
              onPressed: _submit,
              child: const Text('Submit exam'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Question navigator · filled numbers have answers'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < _responses.length; i++)
              SizedBox(
                width: 48,
                child: OutlinedButton(
                  key: Key('exam-jump-$i'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: _responses[i]?.trim().isNotEmpty == true
                        ? AppColors.teal.withValues(alpha: .2)
                        : null,
                  ),
                  onPressed: () => _go(i),
                  child: Text('${i + 1}'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildResult(ExamResult result) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        result.timedOut ? 'Time is up' : 'Exam complete',
        key: const Key('exam-complete'),
        style: const TextStyle(fontSize: 28),
      ),
      const SizedBox(height: 12),
      Text(
        '${result.correct} / ${result.total} · ${result.percentage}%',
        key: const Key('exam-score'),
        style: TextStyle(fontSize: 32, color: AppColors.gold),
      ),
      Text(
        '${result.unanswered} unanswered · Practice score, not an HSK certification result.',
      ),
      if (!widget.exam.questions.any(
        (question) => question.section == ExamSection.listening,
      ))
        const Text('Listening was not assessed.'),
      if (result.excluded.isNotEmpty)
        Text(
          '${result.excluded.length} audio questions were unscored. This is a partial assessment.',
        ),
      const SizedBox(height: 20),
      for (final section in ExamSection.values)
        if (widget.exam.questions.any(
          (question) => question.section == section,
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${section.label}: ${result.scoreFor(section).$1} / ${result.scoreFor(section).$2}',
            ),
          ),
      const SizedBox(height: 12),
      if (_savingProgress) const Text('Saving vocabulary progress…'),
      if (_progressError != null)
        _AppInlineError(
          message: _progressError!,
          onRetry: _saveResult,
          retryKey: const Key('exam-progress-retry'),
        ),
      if (widget.studyService != null &&
          !_savingProgress &&
          _progressError == null)
        const Text('Vocabulary progress saved for your answered questions.'),
      FilledButton(
        key: const Key('exam-done'),
        onPressed: _savingProgress || _progressError != null
            ? null
            : () => Navigator.of(context).pop(),
        child: const Text('Choose another exam'),
      ),
      const SizedBox(height: 24),
      const Text('Answer review', style: TextStyle(fontSize: 22)),
      for (var i = 0; i < widget.exam.questions.length; i++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ${widget.exam.questions[i].section.label} · '
                  '${result.excluded.contains(i)
                      ? 'Unscored'
                      : widget.exam.questions[i].isCorrect(result.responses[i])
                      ? 'Correct'
                      : 'Incorrect'}',
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.exam.questions[i].word.hanzi} · ${widget.exam.questions[i].word.pinyin}',
                  style: const TextStyle(fontSize: 20),
                ),
                Text(widget.exam.questions[i].word.meaning),
                Text(
                  'Your answer: ${result.responses[i]?.trim().isNotEmpty == true ? result.responses[i] : 'Unanswered'}',
                ),
                Text('Expected: ${widget.exam.questions[i].answer}'),
              ],
            ),
          ),
        ),
    ],
  );
}
