part of 'main.dart';

class AiTutorPage extends StatelessWidget {
  const AiTutorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showRail = constraints.maxWidth >= 900;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: _TutorChat()),
            if (showRail) const SizedBox(width: 300, child: _TutorFocusRail()),
          ],
        );
      },
    );
  }
}

class _TutorChat extends StatelessWidget {
  const _TutorChat();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const _TutorAvatar(size: 36),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '龙老师 - Long Laoshi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'AI Mandarin Tutor · always available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: AppColors.teal),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  side: const BorderSide(color: Color(0xFF71463E)),
                  textStyle: const TextStyle(fontSize: 11),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF80621D)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: AppColors.gold,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'GPT-4o',
                      style: TextStyle(fontSize: 11, color: AppColors.gold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: _Conversation()),
        const _TutorComposer(),
      ],
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _TutorMessage(
            chinese: '今天我们学习家庭词汇。你家里有几个人？',
            pinyin:
                'Jintian women xuexi jiating cihui. Ni jiali you ji ge ren?',
            english:
                'Today we are learning family vocabulary. How many people are in your family?',
          ),
          _TipBubble('Use 几个 (ji ge) to ask "how many" for small numbers.'),
          _UserMessage('我家里有四个人。爸爸，妈妈，我，和妹妹。'),
          _TutorMessage(
            chinese: '很好！你的句子非常正确。',
            pinyin: 'Hen hao! Ni de juzi feichang zhengque.',
            english: 'Very good! Your sentence is completely correct.',
          ),
          _TipBubble('和 (he) means "and" - used to connect nouns in a list.'),
          _UserMessage('谢谢！怎么说 "older brother"?'),
          _TutorMessage(
            chinese:
                '哥哥 (gege) means older brother. 弟弟 (didi) is younger brother. Chinese has different words depending on birth order.',
            pinyin: '哥哥 / 弟弟',
            english: 'Older brother / Younger brother',
            wide: true,
          ),
          _TipBubble(
            'Similarly: 姐姐 (jiejie) = older sister, 妹妹 (meimei) = younger sister.',
          ),
        ],
      ),
    );
  }
}

class _TutorMessage extends StatelessWidget {
  const _TutorMessage({
    required this.chinese,
    required this.pinyin,
    required this.english,
    this.wide = false,
  });

  final String chinese;
  final String pinyin;
  final String english;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TutorAvatar(size: 30),
          const SizedBox(width: 10),
          Flexible(
            flex: wide ? 8 : 5,
            child: Container(
              constraints: BoxConstraints(maxWidth: wide ? 720 : 470),
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: const Color(0xFF74372F)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chinese,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pinyin,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 11,
                      letterSpacing: .3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    english,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(64, 10, 0, 26),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.darkRed,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _TipBubble extends StatelessWidget {
  const _TipBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 0, 18),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF4A3825),
            border: Border.all(color: const Color(0xFF8B671C)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Tip: $text',
            style: const TextStyle(fontSize: 11, color: AppColors.gold),
          ),
        ),
      ),
    );
  }
}

class _TutorComposer extends StatelessWidget {
  const _TutorComposer();

  @override
  Widget build(BuildContext context) {
    const prompts = [
      'How do I use 的 correctly?',
      'What are the four tones?',
      'Teach me a new character',
      'Quiz me on family words',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final prompt in prompts)
                  ActionChip(
                    label: Text(prompt),
                    onPressed: () {},
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(color: Color(0xFF73352C)),
                    labelStyle: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ask 龙老师 anything in English or 中文...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.muted),
              filled: true,
              fillColor: AppColors.surface,
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Send',
                  onPressed: () {},
                  icon: const Icon(Icons.send_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF6A241E),
                    foregroundColor: AppColors.red,
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF74372F)),
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF74372F)),
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.red),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorFocusRail extends StatelessWidget {
  const _TutorFocusRail();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      child: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel("TODAY'S FOCUS"),
            SizedBox(height: 12),
            _FocusCard(),
            SizedBox(height: 18),
            SectionLabel('VOCABULARY COVERED'),
            SizedBox(height: 12),
            _CoveredWord(hanzi: '爸爸', pinyin: 'baba', english: 'father'),
            _CoveredWord(hanzi: '妈妈', pinyin: 'mama', english: 'mother'),
            _CoveredWord(hanzi: '哥哥', pinyin: 'gege', english: 'older brother'),
            _CoveredWord(
              hanzi: '妹妹',
              pinyin: 'meimei',
              english: 'younger sister',
            ),
            _CoveredWord(hanzi: '家里', pinyin: 'jiali', english: 'at home'),
            SizedBox(height: 18),
            SectionLabel('SESSION STATS'),
            SizedBox(height: 12),
            _StatsCard(),
          ],
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: const Color(0xFF74372F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '家庭',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 25,
              color: AppColors.text,
            ),
          ),
          SizedBox(height: 4),
          Text('jiating', style: TextStyle(fontSize: 12, color: AppColors.red)),
          SizedBox(height: 4),
          Text(
            'Family / Household',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          Divider(height: 28),
          Text(
            'Lesson 3 · Unit 2',
            style: TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _CoveredWord extends StatelessWidget {
  const _CoveredWord({
    required this.hanzi,
    required this.pinyin,
    required this.english,
  });

  final String hanzi;
  final String pinyin;
  final String english;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hanzi,
              style: const TextStyle(fontSize: 13, color: AppColors.text),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                pinyin,
                style: const TextStyle(fontSize: 10, color: AppColors.red),
              ),
              const SizedBox(height: 2),
              Text(
                english,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: const Color(0xFF74372F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          _StatRow(label: 'Messages', value: '6'),
          SizedBox(height: 14),
          _StatRow(label: 'Words learned', value: '5'),
          SizedBox(height: 14),
          _StatRow(label: 'XP earned', value: '+15'),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _TutorAvatar extends StatelessWidget {
  const _TutorAvatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF4A1511),
      ),
      child: Text(
        '龙',
        style: TextStyle(
          fontSize: size * .48,
          color: AppColors.teal,
          fontFamily: 'serif',
        ),
      ),
    );
  }
}
