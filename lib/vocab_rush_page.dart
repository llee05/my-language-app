part of 'main.dart';

enum _RushDifficulty {
  beginner('入门', 'Beginner', 90, 1),
  intermediate('进阶', 'Intermediate', 60, 3),
  advanced('挑战', 'Advanced', 45, 6);

  const _RushDifficulty(this.chinese, this.english, this.seconds, this.maxHsk);

  final String chinese;
  final String english;
  final int seconds;
  final int maxHsk;
}

class VocabRushPage extends StatefulWidget {
  const VocabRushPage({super.key});

  @override
  State<VocabRushPage> createState() => _VocabRushPageState();
}

class _VocabRushPageState extends State<VocabRushPage> {
  final _random = Random();
  _RushDifficulty _difficulty = _RushDifficulty.beginner;
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
  bool _playing = false;
  bool _finished = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _cards = [
      for (final lesson in flashcardLessons)
        if ((lesson['hsk_level'] as int) <= _difficulty.maxHsk)
          for (final card in lesson['cards'] as List<dynamic>)
            card as Map<String, dynamic>,
    ];
    _cards.shuffle(_random);

    setState(() {
      _playing = true;
      _finished = false;
      _secondsLeft = _difficulty.seconds;
      _score = 0;
      _streak = 0;
      _bestStreak = 0;
      _attempts = 0;
      _selectedAnswer = null;
      _nextCard();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _finish();
      } else {
        setState(() => _secondsLeft--);
      }
    });
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
      }
    });

    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || !_playing) return;
      setState(_nextCard);
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
            'Time! You scored $_score ${_score == 1 ? 'word' : 'words'}.',
            style: const TextStyle(fontSize: 20, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          _scoreRow(),
        ],
      ],
    );
  }

  Widget _buildGame() {
    final progress = _secondsLeft / _difficulty.seconds;
    return Column(
      children: [
        Row(
          children: [
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
            ),
            const SizedBox(width: 14),
            Text(
              '${_secondsLeft}s',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
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
              '◷ ${difficulty.seconds}s   HSK ${difficulty.maxHsk}',
              style: const TextStyle(fontSize: 9, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

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
