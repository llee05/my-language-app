part of '../../main.dart';

DateTime nextDailyQueueReset(DateTime systemTime) =>
    DateTime(systemTime.year, systemTime.month, systemTime.day + 1);

class DailyQueuePage extends StatefulWidget {
  const DailyQueuePage({
    super.key,
    required this.profile,
    required this.progressRepository,
    this.today,
    this.clock,
  });

  final LearnerProfile profile;
  final ProgressRepository progressRepository;
  final DateTime? today;
  final DateTime Function()? clock;

  @override
  State<DailyQueuePage> createState() => _DailyQueuePageState();
}

class _DailyQueuePageState extends State<DailyQueuePage>
    with WidgetsBindingObserver {
  List<DailyQueueCard> _queue = const [];
  bool _loading = true;
  String? _error;
  Timer? _midnightTimer;
  DateTime? _loadedDay;

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
    if (mounted) setState(() => _loading = true);
    unawaited(_loadQueue());
  }

  Future<void> _loadQueue() async {
    try {
      final day = widget.today ?? _systemTime();
      final queue = await widget.progressRepository.dailyQueue(
        forDay: day,
        limit: widget.profile.dailyWordTarget,
        maxHskLevel: widget.profile.hskLevel,
      );
      if (!mounted) return;
      setState(() {
        _queue = queue;
        _loading = false;
        _error = null;
        _loadedDay = day;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not build today’s queue: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '每日复习',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 36,
                color: AppColors.text,
              ),
            ),
            const Text(
              'Today’s review queue',
              style: TextStyle(fontSize: 16, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Text(
              'Cards to review and weak cards come first, followed by new words. '
              'Daily target: ${widget.profile.dailyWordTarget}.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            Expanded(child: _buildContent()),
          ],
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
    if (_queue.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 46, color: AppColors.teal),
            SizedBox(height: 12),
            Text(
              'You’re all caught up.',
              style: TextStyle(color: AppColors.text, fontSize: 18),
            ),
            SizedBox(height: 5),
            Text(
              'There are no cards in today’s queue.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    final dueCount = _queue
        .where((item) => item.reason == DailyQueueReason.due)
        .length;
    final weakCount = _queue
        .where((item) => item.reason == DailyQueueReason.weak)
        .length;
    final newCount = _queue
        .where((item) => item.reason == DailyQueueReason.newWord)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QueueCount(
              label: 'To review',
              count: dueCount,
              color: AppColors.red,
            ),
            _QueueCount(label: 'Weak', count: weakCount, color: AppColors.gold),
            _QueueCount(label: 'New', count: newCount, color: AppColors.teal),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _queue.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _QueueCard(index: index + 1, item: _queue[index]),
          ),
        ),
      ],
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
