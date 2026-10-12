part of '../../main.dart';

class DoomScrollingPage extends StatefulWidget {
  const DoomScrollingPage({
    super.key,
    required this.studyService,
    required this.settingsRepository,
    required this.pronunciationService,
    this.sentenceRepository = const BundledListeningSentenceRepository(),
    this.random,
    this.onProgressChanged,
  });

  final VocabularyStudyService studyService;
  final SettingsRepository settingsRepository;
  final PronunciationService pronunciationService;
  final BundledListeningSentenceRepository sentenceRepository;
  final Random? random;
  final VoidCallback? onProgressChanged;

  @override
  State<DoomScrollingPage> createState() => _DoomScrollingPageState();
}

class _DoomScrollingPageState extends State<DoomScrollingPage> {
  final _pages = PageController();
  late final _random = widget.random ?? Random();
  List<Map<String, dynamic>> _words = const [];
  List<ListeningSentence> _sentences = const [];
  bool _sentenceMode = false;
  final _revealedSentences = <int>{};
  bool _sentencePracticeBlocked = false;
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

  int get _itemCount => _sentenceMode ? _sentences.length : _words.length;
  bool get _navigationBlocked =>
      _saving || _saveError != null || _sentencePracticeBlocked;

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
    // Finish earlier stops before starting the next card's audio.
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
    if (_pages.hasClients) _pages.jumpToPage(0);
    try {
      List<Map<String, dynamic>> unseen = const [];
      List<ListeningSentence> sentences = const [];
      if (_sentenceMode) {
        sentences = List.of(
          await widget.sentenceRepository.load(
            bundle: DefaultAssetBundle.of(context),
          ),
        )..shuffle(_random);
      } else {
        final words = await widget.studyService.vocabulary.load();
        final progress = await widget.studyService.progress
            .vocabularyProgress();
        unseen = unlearnedVocabulary(words, progress)..shuffle(_random);
      }
      var settings = const LearnerSettings();
      try {
        settings = await widget.settingsRepository.load();
      } catch (error) {
        debugPrint('Discovery settings load failed: $error');
      }
      if (!mounted) return;
      if (_pages.hasClients) _pages.jumpToPage(0);
      setState(() {
        _words = unseen;
        _sentences = sentences;
        _settings = settings;
        _position = 0;
        _saved.clear();
        _ratings.clear();
        _revealedSentences.clear();
        _sentencePracticeBlocked = false;
        _run = DateTime.now().microsecondsSinceEpoch.toString();
        _saveError = null;
        _loading = false;
      });
      _playCurrentItem();
    } catch (error) {
      debugPrint('Discovery feed load failed: $error');
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
    if (_sentenceMode ||
        _saving ||
        index >= _words.length ||
        _saved.contains(index)) {
      return;
    }
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
    if (_navigationBlocked || _position >= _itemCount) return;
    _move(_position + 1);
  }

  void _move(int index) {
    if (!_pages.hasClients || _navigationBlocked) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index.clamp(0, _itemCount));
      return;
    }
    _pages.animateToPage(
      index.clamp(0, _itemCount),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _playCurrentItem() {
    if (_loading || _position >= _itemCount || !_settings.soundEnabled) {
      unawaited(_stopAudio());
      return;
    }
    unawaited(
      _speak(
        _sentenceMode
            ? _sentences[_position].chinese
            : _words[_position]['simplified'] as String,
      ),
    );
  }

  bool _isCurrentAudioRequest(int requestId) =>
      mounted && requestId == _audioRequestId && _settings.soundEnabled;

  Future<void> _speak(String text, {bool slow = false}) async {
    if (!_settings.soundEnabled) return;
    final stop = _stopAudio();
    final requestId = _audioRequestId;
    try {
      await stop;
      if (!_isCurrentAudioRequest(requestId)) return;
      await applyPronunciationSettings(widget.pronunciationService, _settings);
      if (!_isCurrentAudioRequest(requestId)) return;
      final service = widget.pronunciationService;
      if (slow && service is PlaybackRatePronunciationService) {
        await (service as PlaybackRatePronunciationService).speakMandarinAtRate(
          text,
          rate: .75,
        );
      } else {
        await service.speakMandarin(text);
      }
    } catch (error) {
      if (mounted && _isCurrentAudioRequest(requestId)) {
        _showPronunciationError(context, widget.pronunciationService, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): _next,
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _move(_position - 1),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .35,
                ),
                child: SingleChildScrollView(
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
                              _sentenceMode
                                  ? '${_sentences.length} Tatoeba sentences'
                                  : '${_saved.length} practised · ${_words.length} unlearned words',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final sentenceMode in [false, true])
                              ChoiceChip(
                                label: Text(
                                  sentenceMode ? 'Sentence listening' : 'Words',
                                ),
                                selected: _sentenceMode == sentenceMode,
                                onSelected: _loading || _navigationBlocked
                                    ? null
                                    : (_) {
                                        if (_sentenceMode == sentenceMode) {
                                          return;
                                        }
                                        setState(
                                          () => _sentenceMode = sentenceMode,
                                        );
                                        _load();
                                      },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _failed
                    ? _AppErrorState(
                        title: _sentenceMode
                            ? 'The sentence feed could not be loaded'
                            : 'The word feed could not be loaded',
                        message: 'Please try again.',
                        onRetry: _load,
                      )
                    : PageView.builder(
                        key: const Key('doom-scrolling-feed'),
                        controller: _pages,
                        scrollDirection: Axis.vertical,
                        physics: _navigationBlocked
                            ? const NeverScrollableScrollPhysics()
                            : const PageScrollPhysics(),
                        itemCount: _itemCount + 1,
                        onPageChanged: (index) {
                          setState(() => _position = index);
                          _playCurrentItem();
                        },
                        itemBuilder: (context, index) => _buildFeedItem(index),
                      ),
              ),
            ],
          ),
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
    child: index == _itemCount
        ? _buildEnd()
        : _sentenceMode
        ? _buildSentence(index)
        : _buildWord(index),
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
              _sentenceMode && _sentences.isEmpty
                  ? 'No Tatoeba sentences are available.'
                  : !_sentenceMode && _words.isEmpty
                  ? 'You’ve learned every bundled word!'
                  : 'You’ve reached the end of this mix.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text, fontSize: 24),
            ),
            const SizedBox(height: 12),
            Text(
              _sentenceMode
                  ? 'Refresh for another sentence listening mix.'
                  : 'Words you’ve mastered stay out of your feed.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.shuffle),
              label: Text(
                _sentenceMode ? 'Refresh sentence feed' : 'Refresh word feed',
              ),
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
              ? () => _speak(entry.simplified)
              : null,
          onSpeakExample: _settings.soundEnabled ? _speak : null,
          onStopAudio: _stopAudio,
        ),
      ),
    );
    await _stopAudio();
  }

  Future<void> _openSentenceSource(Uri source) async {
    try {
      await _stopAudio();
      if (!mounted) return;
      if (await launchUrl(source, mode: LaunchMode.externalApplication)) return;
    } catch (error) {
      debugPrint('Tatoeba source could not be opened: $error');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The Tatoeba source could not be opened.'),
        ),
      );
    }
  }

  Widget _buildSentence(int index) {
    final sentence = _sentences[index];
    final revealed = _revealedSentences.contains(index);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.divider),
            ),
            child: SingleChildScrollView(
              key: Key('discovery-sentence-scroll-$index'),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Sentence listening · ${index + 1} / ${_sentences.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                  Icon(Icons.headphones, size: 48, color: AppColors.gold),
                  const SizedBox(height: 12),
                  Text(
                    'Listen to the sentence',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, color: AppColors.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _settings.soundEnabled
                        ? 'Try to understand it before revealing the transcript.'
                        : 'Sound is off. Enable Sound in Settings to listen, or reveal the transcript to read.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      PronunciationButton(
                        key: Key('discovery-sentence-replay-$index'),
                        requestKey: sentence.chineseId,
                        label: 'Replay sentence',
                        tooltip: 'Hear the whole sentence',
                        onPressed: _settings.soundEnabled
                            ? () => _speak(sentence.chinese)
                            : null,
                      ),
                      if (widget.pronunciationService
                          is PlaybackRatePronunciationService)
                        PronunciationButton(
                          key: Key('discovery-sentence-slow-$index'),
                          requestKey: sentence.chineseId,
                          label: 'Play slower',
                          tooltip: 'Hear the sentence at a slower speed',
                          icon: Icons.slow_motion_video,
                          onPressed: _settings.soundEnabled
                              ? () => _speak(sentence.chinese, slow: true)
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!revealed)
                    FilledButton(
                      key: Key('discovery-sentence-reveal-$index'),
                      onPressed: () =>
                          setState(() => _revealedSentences.add(index)),
                      child: const Text('Reveal transcript'),
                    )
                  else ...[
                    Text(
                      sentence.chinese,
                      key: Key('discovery-sentence-chinese-$index'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, color: AppColors.text),
                    ),
                    if (_settings.showPinyin) ...[
                      const SizedBox(height: 8),
                      Text(
                        sentence.pinyin,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: AppColors.gold),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      sentence.english,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: AppColors.text),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tatoeba · CC BY 2.0 FR',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                    if (sentence.pinyinContributor.isNotEmpty)
                      Text(
                        'Pinyin: ${sentence.pinyinContributor}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () =>
                              _openSentenceSource(sentence.chineseSource),
                          child: Text('Chinese source #${sentence.chineseId}'),
                        ),
                        TextButton(
                          onPressed: () =>
                              _openSentenceSource(sentence.englishSource),
                          child: Text('English source #${sentence.englishId}'),
                        ),
                      ],
                    ),
                    _VocabularyPracticePanel(
                      key: ValueKey('$_run:sentence:$index'),
                      service: widget.studyService,
                      text: sentence.chinese,
                      onProgressChanged: widget.onProgressChanged,
                      onNavigationBlocked: (blocked) {
                        if (mounted) {
                          setState(() => _sentencePracticeBlocked = blocked);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton.icon(
                    key: Key('discovery-sentence-next-$index'),
                    onPressed: _navigationBlocked ? null : _next,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    label: const Text('Next sentence'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
                        if (!compact) ...[
                          const SizedBox(height: 24),
                          _VocabularyExamples(
                            chinese: entry.simplified,
                            pinyin: entry.pinyin,
                            repository: widget.studyService.examples,
                            fallback: entry.example,
                            showPinyin: _settings.showPinyin,
                            inline: true,
                            onSpeak: _settings.soundEnabled ? _speak : null,
                            onStopAudio: _stopAudio,
                            pronunciationKey: Key(
                              'discovery-example-pronunciation-$index',
                            ),
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
