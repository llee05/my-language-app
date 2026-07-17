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
  const VocabRushPage({super.key});

  @override
  State<VocabRushPage> createState() => _VocabRushPageState();
}

class _VocabRushPageState extends State<VocabRushPage> {
  final _random = Random();
  _RushDifficulty _difficulty = _RushDifficulty.beginner;
  _RushDuration _duration = _RushDuration.threeMinutes;
  Timer? _timer;
  List<Map<String, dynamic>> _cards = const [];
  Map<String, dynamic>? _card;
  List<String> _answers = const [];
  String? _selectedAnswer;
  int _secondsLeft = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _attempts = 0;
  int _mistakes = 0;
  bool _playing = false;
  bool _finished = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _timer?.cancel();
    final vocabulary =
        jsonDecode(
              await rootBundle.loadString('assets/data/hsk_vocabulary.json'),
            )
            as List<dynamic>;
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
            'english_meaning': (card['meanings'] as List<dynamic>).first,
          },
        )
        .toList();
    _cards.shuffle(_random);

    setState(() {
      _playing = true;
      _finished = false;
      _secondsLeft = _duration.seconds ?? 0;
      _score = 0;
      _streak = 0;
      _bestStreak = 0;
      _attempts = 0;
      _mistakes = 0;
      _selectedAnswer = null;
      _nextCard();
    });

    if (_duration.seconds != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_secondsLeft <= 1) {
          _finish();
        } else {
          setState(() => _secondsLeft--);
        }
      });
    }
  }

  void _nextCard() {
    if (_cards.isEmpty) return;
    _card = _cards[_attempts % _cards.length];
    final correct = _card!['english_meaning'] as String;
    final meanings =
        _cards
            .map((card) => card['english_meaning'] as String)
            .where((meaning) => meaning != correct)
            .toSet()
            .toList()
          ..shuffle(_random);
    _answers = [correct, ...meanings.take(3)]..shuffle(_random);
    _selectedAnswer = null;
  }

  void _answer(String answer) {
    if (_selectedAnswer != null || !_playing) return;
    final correct = answer == _card!['english_meaning'];
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
    });

    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || !_playing) return;
      if (_mistakes >= 3) {
        _finish();
      } else {
        setState(_nextCard);
      }
    });
  }

  void _finish() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 0;
      _playing = false;
      _finished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
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
    );
  }

  Widget _buildLobby() {
    return Column(
      children: [
        const SizedBox(height: 36),
        _modeBadge(),
        const SizedBox(height: 20),
        const Text(
          '词汇冲刺',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 46,
            color: AppColors.text,
          ),
        ),
        const Text(
          'Vocab Rush',
          style: TextStyle(fontSize: 17, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        const Text(
          'Race the clock. Pick the correct English meaning and score as many words as you can.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.6, color: AppColors.muted),
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
        const Text(
          'CHOOSE A TIME',
          style: TextStyle(
            letterSpacing: 1.5,
            fontSize: 10,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_RushDuration>(
          segments: [
            for (final duration in _RushDuration.values)
              ButtonSegment(value: duration, label: Text(duration.label)),
          ],
          selected: {_duration},
          onSelectionChanged: (selection) =>
              setState(() => _duration = selection.first),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: 285,
          height: 54,
          child: FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.sports_martial_arts_rounded, size: 18),
            label: Text(_finished ? '再玩一次 — Play Again' : '开始游戏 — Start Game'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: AppColors.text,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        if (_finished) ...[
          const SizedBox(height: 30),
          Text(
            '${_mistakes >= 3 ? 'Three strikes!' : 'Time!'} You scored $_score ${_score == 1 ? 'word' : 'words'}.',
            style: const TextStyle(fontSize: 20, color: AppColors.text),
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
              style: const TextStyle(
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
        const Text(
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
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 64,
            color: AppColors.text,
          ),
        ),
        Text(
          _card!['pinyin'] as String,
          style: const TextStyle(fontSize: 16, color: AppColors.gold),
        ),
        const SizedBox(height: 38),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [for (final answer in _answers) _answerButton(answer)],
        ),
        const SizedBox(height: 34),
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
      onPressed: () => _answer(answer),
      style: OutlinedButton.styleFrom(
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
    return InkWell(
      onTap: () => setState(() => _difficulty = difficulty),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF211A0C) : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              difficulty.chinese,
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 20,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              difficulty.english,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Text(
              'HSK ${difficulty.minHsk}–${difficulty.maxHsk}',
              style: const TextStyle(fontSize: 9, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strikeMarker() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$_mistakes/3',
        style: const TextStyle(
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stat('$_score', 'Correct'),
        const SizedBox(width: 48),
        _stat('×$_streak', 'Streak'),
        const SizedBox(width: 48),
        _stat('×$_bestStreak', 'Best streak'),
      ],
    );
  }

  Widget _stat(String value, String label) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.muted)),
    ],
  );

  Widget _modeBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.darkRed),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
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
