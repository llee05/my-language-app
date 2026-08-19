part of '../../main.dart';

DateTime nextDailyQueueReset(DateTime systemTime) =>
    DateTime(systemTime.year, systemTime.month, systemTime.day + 1);

class DailyQueuePage extends StatefulWidget {
  const DailyQueuePage({
    super.key,
    required this.profile,
    required this.progressRepository,
    this.sessionRepository,
    this.settingsRepository,
    this.onStartReview,
    this.startImmediately = false,
    this.onSessionCompleted,
    this.onProgressChanged,
    this.today,
    this.clock,
  });

  final LearnerProfile profile;
  final ProgressRepository progressRepository;
  final DailyReviewSessionRepository? sessionRepository;
  final SettingsRepository? settingsRepository;
  final FutureOr<void> Function(DailyReviewSession session)? onStartReview;
  final bool startImmediately;
  final VoidCallback? onSessionCompleted;
  final VoidCallback? onProgressChanged;
  final DateTime? today;
  final DateTime Function()? clock;

  @override
  State<DailyQueuePage> createState() => _DailyQueuePageState();
}

class _DailyQueuePageState extends State<DailyQueuePage>
    with WidgetsBindingObserver {
  List<DailyQueueCard> _queue = const [];
  bool _loading = true;
  bool _hasLoadError = false;
  int _loadRequestId = 0;
  Timer? _midnightTimer;
  DateTime? _loadedDay;
  DailyReviewSession? _session;
  bool _reviewing = false;
  int _reviewStartPosition = 0;
  bool _showPinyin = true;
  bool _consumedImmediateStart = false;
  final Set<String> _pendingAnswerKeys = {};
  final Set<String> _completedAnswerKeys = {};

  DateTime _systemTime() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadQueue();
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = _systemTime();
    if (_loadedDay == null || !_isSameDay(_loadedDay!, now)) {
      _resetQueue();
    }
    _scheduleMidnightReset();
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = _systemTime();
    final delay = nextDailyQueueReset(now).difference(now);
    _midnightTimer = Timer(delay, () {
      _resetQueue();
      _scheduleMidnightReset();
    });
  }

  void _resetQueue() {
    _beginQueueLoad(force: true);
  }

  void _beginQueueLoad({bool force = false}) {
    if (!mounted || (_loading && !force)) return;
    setState(() {
      _loading = true;
      _hasLoadError = false;
    });
    unawaited(_loadQueue());
  }

  Future<LearnerSettings?> _loadSettingsSafely() async {
    try {
      return await widget.settingsRepository?.load();
    } catch (error) {
      debugPrint('Daily review settings load failed: $error');
      return null;
    }
  }

  Future<void> _applyLoadedSettings(
    Future<LearnerSettings?> settings,
    int requestId,
  ) async {
    final loadedSettings = await settings;
    if (!mounted || requestId != _loadRequestId || loadedSettings == null) {
      return;
    }
    setState(() => _showPinyin = loadedSettings.showPinyin);
  }

  Future<void> _loadQueue() async {
    final requestId = ++_loadRequestId;
    final day = widget.today ?? _systemTime();
    final settings = _loadSettingsSafely();
    try {
      final queue = await widget.progressRepository.dailyQueue(
        forDay: day,
        limit: widget.profile.dailyWordTarget,
        maxHskLevel: widget.profile.hskLevel,
      );
      final session = await widget.sessionRepository?.load(day);
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _queue = queue;
        _loading = false;
        _hasLoadError = false;
        _loadedDay = day;
        _session =
            session ??
            DailyReviewSession(
              id: 0,
              date: DateTime(day.year, day.month, day.day),
              queuedCardIds: queue
                  .map((item) => item.card.id)
                  .toList(growable: false),
            );
      });
      unawaited(_applyLoadedSettings(settings, requestId));
      if (widget.startImmediately &&
          !_consumedImmediateStart &&
          queue.isNotEmpty) {
        _consumedImmediateStart = true;
        await _startReview();
      }
    } catch (error) {
      debugPrint('Daily review queue load failed: $error');
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _queue = const [];
        _session = null;
        _loadedDay = null;
        _loading = false;
        _hasLoadError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_reviewing && _session != null && _queue.isNotEmpty) {
      return DailyReviewCardScreen(
        key: ValueKey(
          'daily-review-${_session!.id}-$_reviewStartPosition-'
          '${_session!.queuedCardIds.length}',
        ),
        queue: _queue,
        initialPosition: 0,
        showPinyin: _showPinyin,
        onAnswer: _recordAnswer,
        onClose: () {
          setState(() => _reviewing = false);
          _beginQueueLoad(force: true);
        },
      );
    }
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;
    return ColoredBox(
      color: AppColors.background,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            sliver: SliverToBoxAdapter(child: _buildQueueHeader()),
          ),
          if (_loading || _hasLoadError || _queue.isEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding),
              sliver: SliverToBoxAdapter(child: _buildStatusContent()),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(child: _buildQueueCounts()),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index.isOdd) return const SizedBox(height: 10);
                  final queueIndex = index ~/ 2;
                  return _QueueCard(
                    index: queueIndex + 1,
                    item: _queue[queueIndex],
                  );
                }, childCount: _queue.length * 2 - 1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQueueHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每日复习',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 36,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  'Today’s review queue',
                  style: TextStyle(fontSize: 16, color: AppColors.muted),
                ),
              ],
            );
            final action = FilledButton.icon(
              onPressed: _canStartReview ? _startReview : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(_isResumable ? 'Resume review' : 'Start review'),
            );
            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [heading, const SizedBox(height: 16), action],
              );
            }
            return Row(
              children: [
                const Expanded(child: heading),
                const SizedBox(width: 16),
                action,
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Cards to review and weak cards come first, followed by new words. '
          'Daily target: ${widget.profile.dailyWordTarget}.',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  bool get _isResumable =>
      _session != null &&
      !_session!.isComplete &&
      _session!.currentPosition > 0 &&
      _session!.currentPosition < _session!.queuedCardIds.length;

  bool get _canStartReview {
    final loadedDay = _loadedDay;
    final activeDay = widget.today ?? _systemTime();
    return !_loading &&
        !_hasLoadError &&
        _queue.isNotEmpty &&
        loadedDay != null &&
        _isSameDay(loadedDay, activeDay);
  }

  Future<void> _startReview() async {
    final session = _session;
    if (session == null || !_canStartReview) return;
    final requestId = _loadRequestId;
    await widget.onStartReview?.call(session);
    if (!mounted ||
        requestId != _loadRequestId ||
        !identical(session, _session) ||
        !_canStartReview) {
      return;
    }
    setState(() {
      _reviewStartPosition = session.currentPosition;
      _reviewing = true;
    });
  }

  Future<void> _recordAnswer(
    int position,
    Flashcard card,
    ReviewRating rating,
  ) async {
    final session = _session;
    final sessions = widget.sessionRepository;
    if (session == null || sessions == null || card.id == 0) return;
    final absolutePosition = _reviewStartPosition + position;
    if (session.isComplete ||
        absolutePosition < session.currentPosition ||
        absolutePosition >= session.queuedCardIds.length) {
      return;
    }
    if (absolutePosition != session.currentPosition ||
        session.queuedCardIds[absolutePosition] != card.id) {
      throw StateError('This review answer no longer matches the active card.');
    }
    final submissionKey =
        'daily:${session.id}:position:$absolutePosition:card:${card.id}';
    if (_completedAnswerKeys.contains(submissionKey) ||
        !_pendingAnswerKeys.add(submissionKey)) {
      return;
    }

    try {
      final now = _systemTime().toUtc();
      final previous = await widget.progressRepository.progressForCard(card.id);
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
          submissionKey: submissionKey,
          reviewedAt: now,
          rating: rating,
          wasCorrect: rating != ReviewRating.again,
        ),
        progress: scheduled,
      );

      final nextPosition = absolutePosition + 1;
      final completed = nextPosition >= session.queuedCardIds.length;
      if (completed) {
        final didComplete = await sessions.complete(
          sessionId: session.id,
          completedAt: now,
          expectedCardCount: session.queuedCardIds.length,
        );
        if (!didComplete) {
          widget.onProgressChanged?.call();
          _completedAnswerKeys.add(submissionKey);
          if (!mounted) return;
          setState(() {
            _reviewing = false;
            _loading = true;
          });
          await _loadQueue();
          if (!mounted) return;
          final refreshed = _session;
          if (refreshed != null && !refreshed.isComplete && _queue.isNotEmpty) {
            setState(() {
              _reviewStartPosition = refreshed.currentPosition;
              _reviewing = true;
            });
          }
          return;
        }
        widget.onSessionCompleted?.call();
      } else {
        await sessions.update(
          DailyReviewSession(
            id: session.id,
            date: session.date,
            queuedCardIds: session.queuedCardIds,
            currentPosition: nextPosition,
          ),
        );
      }
      widget.onProgressChanged?.call();
      _completedAnswerKeys.add(submissionKey);
      if (!mounted) return;
      setState(() {
        _session = DailyReviewSession(
          id: session.id,
          date: session.date,
          queuedCardIds: session.queuedCardIds,
          currentPosition: nextPosition,
          completedAt: completed ? now : null,
        );
      });
    } finally {
      _pendingAnswerKeys.remove(submissionKey);
    }
  }

  Widget _buildStatusContent() {
    if (_loading) {
      return const _DailyQueueStateCard(
        key: Key('daily-review-loading-state'),
        accent: AppColors.red,
        icon: SizedBox.square(
          dimension: 25,
          child: CircularProgressIndicator(
            color: AppColors.red,
            strokeWidth: 2.5,
            semanticsLabel: 'Loading today’s review queue',
          ),
        ),
        title: 'Preparing today’s queue',
        message:
            'Prioritising cards that are due, words that need practice, '
            'and new vocabulary.',
      );
    }
    if (_hasLoadError) {
      return _AppErrorState(
        key: const Key('daily-review-error-state'),
        title: _AppErrorCopy.dailyReviewTitle,
        message: _AppErrorCopy.dailyReviewMessage,
        onRetry: _beginQueueLoad,
        retryKey: const Key('daily-review-retry'),
      );
    }
    if (_queue.isEmpty) {
      return _DailyQueueStateCard(
        key: const Key('daily-review-empty-state'),
        accent: AppColors.teal,
        icon: const Icon(
          Icons.task_alt_rounded,
          size: 31,
          color: AppColors.teal,
        ),
        title: 'You’re all caught up',
        message:
            'Nothing is waiting in today’s queue. New and due cards will '
            'appear here when they’re ready.',
        action: OutlinedButton.icon(
          key: const Key('daily-review-refresh'),
          onPressed: _beginQueueLoad,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.teal,
            side: BorderSide(color: AppColors.teal.withValues(alpha: .65)),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Check again'),
        ),
      );
    }

    throw StateError('A queue status was requested while cards are available.');
  }

  Widget _buildQueueCounts() {
    final dueCount = _queue
        .where((item) => item.reason == DailyQueueReason.due)
        .length;
    final weakCount = _queue
        .where((item) => item.reason == DailyQueueReason.weak)
        .length;
    final newCount = _queue
        .where((item) => item.reason == DailyQueueReason.newWord)
        .length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _QueueCount(label: 'To review', count: dueCount, color: AppColors.red),
        _QueueCount(label: 'Weak', count: weakCount, color: AppColors.gold),
        _QueueCount(label: 'New', count: newCount, color: AppColors.teal),
      ],
    );
  }
}

class _DailyQueueStateCard extends StatelessWidget {
  const _DailyQueueStateCard({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final Color accent;
  final Widget icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 34),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: accent.withValues(alpha: .55)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: icon,
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 20,
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
                if (action != null) ...[const SizedBox(height: 22), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

class _QueueCount extends StatelessWidget {
  const _QueueCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.index, required this.item});

  final int index;
  final DailyQueueCard item;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (item.reason) {
      DailyQueueReason.due => ('To review', AppColors.red),
      DailyQueueReason.weak => ('Weak', AppColors.gold),
      DailyQueueReason.newWord => ('New', AppColors.teal),
    };
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border.withValues(alpha: .65)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              item.card.chinese,
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 27,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.card.pinyin,
                  style: const TextStyle(color: AppColors.gold),
                ),
                const SizedBox(height: 4),
                Text(
                  item.card.englishMeaning,
                  style: const TextStyle(color: AppColors.text),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
