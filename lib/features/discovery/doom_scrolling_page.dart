part of '../../main.dart';

class DoomScrollingPage extends StatefulWidget {
  const DoomScrollingPage({
    super.key,
    required this.studyService,
    required this.settingsRepository,
    required this.pronunciationService,
    this.random,
    this.onProgressChanged,
  });

  final VocabularyStudyService studyService;
  final SettingsRepository settingsRepository;
  final PronunciationService pronunciationService;
  final Random? random;
  final VoidCallback? onProgressChanged;

  @override
  State<DoomScrollingPage> createState() => _DoomScrollingPageState();
}

class _DoomScrollingPageState extends State<DoomScrollingPage> {
  final _pages = PageController();
  late final _random = widget.random ?? Random();
  List<Map<String, dynamic>> _words = const [];
  LearnerSettings _settings = const LearnerSettings();
  final _saved = <int>{};
  final _ratings = <int, ReviewRating>{};
  String _run = '';
  int _position = 0;
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
  String? _saveError;
  int _audioRequestId = 0;
  Future<void> _audioStopQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pages.dispose();
    unawaited(_stopAudio());
    super.dispose();
  }

  Future<void> _stopAudio() {
    _audioRequestId++;
    // Finish earlier stops before starting a new word's audio.
    return _audioStopQueue = _audioStopQueue.then((_) async {
      try {
        await widget.pronunciationService.stop();
      } catch (error) {
        debugPrint('Discovery audio stop failed: $error');
      }
    });
  }

  Future<void> _load() async {
    unawaited(_stopAudio());
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final words = await widget.studyService.vocabulary.load();
      final progress = await widget.studyService.progress.vocabularyProgress();
      var settings = const LearnerSettings();
      try {
        settings = await widget.settingsRepository.load();
      } catch (error) {
        debugPrint('Discovery settings load failed: $error');
      }
      final unseen = unlearnedVocabulary(words, progress)..shuffle(_random);
      if (!mounted) return;
      if (_pages.hasClients) _pages.jumpToPage(0);
      setState(() {
        _words = unseen;
        _settings = settings;
        _position = 0;
        _saved.clear();
        _ratings.clear();
        _run = DateTime.now().microsecondsSinceEpoch.toString();
        _saveError = null;
        _loading = false;
      });
      _playCurrentWord();
    } catch (error) {
      debugPrint('Discovery vocabulary load failed: $error');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _rate(ReviewRating rating) async {
    final index = _position;
    if (_saving || index >= _words.length || _saved.contains(index)) return;
    setState(() {
      _saving = true;
      _saveError = null;
      _ratings.putIfAbsent(index, () => rating);
    });
    try {
      await widget.studyService.recordWord(
        _words[index],
        rating: _ratings[index]!,
        submissionKey: 'discovery:$_run:$index',
      );
      if (!mounted) return;
      setState(() {
        _saved.add(index);
        _saving = false;
      });
      widget.onProgressChanged?.call();
      _next();
    } catch (error) {
      debugPrint('Discovery rating save failed: $error');
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Your progress could not be saved. Try again.';
        });
      }
    }
  }

  void _next() {
    if (_saving || _saveError != null || _position >= _words.length) return;
    _move(_position + 1);
  }

  void _move(int index) {
    if (!_pages.hasClients || _saving || _saveError != null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index.clamp(0, _words.length));
      return;
    }
    _pages.animateToPage(
      index.clamp(0, _words.length),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _playCurrentWord() {
    if (_loading || _position >= _words.length || !_settings.soundEnabled) {
      unawaited(_stopAudio());
      return;
    }
    unawaited(_speak(_words[_position]));
  }

  bool _isCurrentAudioRequest(int requestId) =>
      mounted && requestId == _audioRequestId && _settings.soundEnabled;

  Future<void> _speak(Map<String, dynamic> word) async {
    if (!_settings.soundEnabled) return;
    final stop = _stopAudio();
    final requestId = _audioRequestId;
    try {
      await stop;
      if (!_isCurrentAudioRequest(requestId)) return;
      await applyPronunciationSettings(widget.pronunciationService, _settings);
      if (!_isCurrentAudioRequest(requestId)) return;
      await widget.pronunciationService.speakMandarin(
        word['simplified'] as String,
      );
    } catch (error) {
      if (mounted && _isCurrentAudioRequest(requestId)) {
        _showPronunciationError(context, widget.pronunciationService, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return _AppErrorState(
        title: 'The word feed could not be loaded',
        message: 'Please try again.',
        onRetry: _load,
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): _next,
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _move(_position - 1),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(
                    'Doom Scrolling',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    '${_saved.length} practised · ${_words.length} unlearned words',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const Key('doom-scrolling-feed'),
                controller: _pages,
                scrollDirection: Axis.vertical,
                physics: _saving || _saveError != null
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: _words.length + 1,
                onPageChanged: (index) {
                  setState(() => _position = index);
                  _playCurrentWord();
                },
                itemBuilder: (context, index) => _buildFeedItem(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedItem(int index) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerSignal: (event) {
      if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
        GestureBinding.instance.pointerSignalResolver.register(event, (_) {
          _move(_position + (event.scrollDelta.dy > 0 ? 1 : -1));
        });
      }
    },
    child: index == _words.length ? _buildEnd() : _buildWord(index),
  );

  Widget _buildEnd() => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: AppColors.gold, size: 56),
            const SizedBox(height: 20),
            Text(
              _words.isEmpty
                  ? 'You’ve learned every bundled word!'
                  : 'You’ve reached the end of this mix.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text, fontSize: 24),
            ),
            const SizedBox(height: 12),
            const Text(
              'Words you’ve mastered stay out of your feed.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.shuffle),
              label: const Text('Refresh word feed'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _showDetails(_VocabularyEntry entry) async {
    await _stopAudio();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _VocabularyDetailPage(
          entry: entry,
          studyService: widget.studyService,
          onProgressChanged: widget.onProgressChanged,
          onSpeakWord: _settings.soundEnabled
              ? () => _speak(entry.source)
              : null,
          onSpeakExample: _settings.soundEnabled && entry.hasExample
              ? () => _speak({'simplified': entry.exampleChinese})
              : null,
        ),
      ),
    );
    await _stopAudio();
  }

  Widget _buildWord(int index) {
    final word = _words[index];
    final entry = _VocabularyEntry.fromJson(word);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scrollContent =
                  constraints.maxHeight < 320 ||
                  MediaQuery.textScalerOf(context).scale(16) > 24;
              final content = LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 420;
                  return SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.all(compact ? 12 : 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'HSK ${entry.hskLevel} · ${index + 1} / ${_words.length}',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Word details',
                              onPressed: _saving
                                  ? null
                                  : () => _showDetails(entry),
                              icon: const Icon(Icons.menu_book_outlined),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 4 : 24),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              entry.simplified,
                              key: Key('discovery-word-$index'),
                              style: TextStyle(
                                fontSize: compact ? 48 : 64,
                                fontFamily: 'serif',
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ),
                        if (_settings.showPinyin)
                          Text(
                            entry.pinyin,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 18 : 24,
                              color: AppColors.gold,
                            ),
                          ),
                        SizedBox(height: compact ? 8 : 20),
                        Text(
                          vocabularyStudyMeaning(word),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 18 : 22,
                            color: AppColors.text,
                          ),
                        ),
                        if (!compact && entry.hasExample) ...[
                          const SizedBox(height: 24),
                          Text(
                            entry.exampleChinese,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 22,
                            ),
                          ),
                          if (_settings.showPinyin &&
                              entry.examplePinyin.isNotEmpty)
                            Text(
                              entry.examplePinyin,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppColors.gold),
                            ),
                          Text(
                            entry.exampleEnglish,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
              final card = Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  mainAxisSize: scrollContent
                      ? MainAxisSize.min
                      : MainAxisSize.max,
                  children: [
                    if (scrollContent) content else Expanded(child: content),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        children: [
                          if (_saveError != null && index == _position)
                            _AppInlineError(
                              message: _saveError!,
                              onRetry: () => _rate(_ratings[index]!),
                              retryKey: const Key('discovery-save-retry'),
                            )
                          else if (_saved.contains(index))
                            const Text('Progress saved')
                          else
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _rate(ReviewRating.again),
                                  child: const Text('Still learning'),
                                ),
                                FilledButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _rate(ReviewRating.good),
                                  child: Text(_saving ? 'Saving…' : 'Got it'),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _saving || _saveError != null
                                ? null
                                : _next,
                            icon: const Icon(Icons.keyboard_arrow_down),
                            label: Text(
                              scrollContent
                                  ? 'Next word'
                                  : 'Swipe up for another word',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              if (!scrollContent) return card;
              return SingleChildScrollView(
                key: Key('discovery-word-scroll-$index'),
                child: card,
              );
            },
          ),
        ),
      ),
    );
  }
}
