part of '../../main.dart';

class AiTutorPage extends StatelessWidget {
  const AiTutorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TutorChat();
  }
}

class _TutorChat extends StatefulWidget {
  const _TutorChat();

  @override
  State<_TutorChat> createState() => _TutorChatState();
}

class _TutorChatState extends State<_TutorChat> {
  static const _systemPrompt = '''
You are 龙老师 (Long Laoshi), a warm Mandarin tutor for a beginner learner.
Keep replies short and practical. Correct mistakes gently.
When useful, include Chinese, pinyin, and a plain English explanation.
Return only compact JSON with this shape:
{"chinese":"...","pinyin":"...","english":"...","tip":"..."}
Use an empty string for any field that is not needed.
''';

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  var _messages = _initialMessages;
  var _sending = false;

  static const _initialMessages = [
    _ChatMessage.assistant(
      chinese: '你好！我是龙老师。你想练习什么中文？',
      pinyin: 'Ni hao! Wo shi Long Laoshi. Ni xiang lianxi shenme Zhongwen?',
      english:
          'Hello! I am Long Laoshi. Ask me a question, practice a sentence, or choose a prompt below to start.',
      tip:
          'You can write in English, pinyin, or Chinese. I will help with corrections and examples.',
      wide: true,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? prompt]) async {
    final text = (prompt ?? _controller.text).trim();
    if (text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
      _messages = [..._messages, _ChatMessage.user(text)];
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final response = await OllamaService.instance.chatText(
        messages: [
          {'role': 'system', 'content': _systemPrompt},
          for (final message in _messages) message.toAiMessage(),
        ],
        maxTokens: 420,
        temperature: 0.45,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = [
          ..._messages,
          _ChatMessage.fromAssistantResponse(response),
        ];
        _sending = false;
      });
      _scrollToEnd();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = [
          ..._messages,
          _ChatMessage.assistant(
            chinese: '我现在连接不上本地模型。',
            pinyin: 'Wo xianzai lianjie bu shang bendi moxing.',
            english: _friendlyError(error),
            tip: 'Make sure Ollama is running and a model is installed.',
          ),
        ];
        _sending = false;
      });
      _scrollToEnd();
    }
  }

  void _reset() {
    setState(() {
      _messages = _initialMessages;
      _sending = false;
      _controller.clear();
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('Connection refused') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection failed')) {
      return 'Start Ollama with `ollama serve`, then try again.';
    }
    return 'Please try again in a moment. $text';
  }

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
                onPressed: _reset,
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
            ],
          ),
        ),
        Expanded(
          child: _Conversation(
            messages: _messages,
            sending: _sending,
            controller: _scrollController,
          ),
        ),
        _TutorComposer(
          controller: _controller,
          sending: _sending,
          onSend: _send,
          onPromptSelected: _send,
        ),
      ],
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.messages,
    required this.sending,
    required this.controller,
  });

  final List<_ChatMessage> messages;
  final bool sending;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final message in messages) ...[
            if (message.role == _ChatRole.user)
              _UserMessage(message.chinese)
            else ...[
              _TutorMessage(
                chinese: message.chinese,
                pinyin: message.pinyin,
                english: message.english,
                wide: message.wide,
              ),
              if (message.tip.isNotEmpty) _TipBubble(message.tip),
            ],
          ],
          if (sending) const _TypingMessage(),
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
                  if (pinyin.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      pinyin,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 11,
                        letterSpacing: .3,
                      ),
                    ),
                  ],
                  if (english.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      english,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
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
  const _TutorComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPromptSelected,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final ValueChanged<String> onPromptSelected;

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
                    onPressed: sending ? null : () => onPromptSelected(prompt),
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
            controller: controller,
            enabled: !sending,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: 'Ask 龙老师 anything in English or 中文...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.muted),
              filled: true,
              fillColor: AppColors.surface,
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Send',
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.red,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
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

class _TypingMessage extends StatelessWidget {
  const _TypingMessage();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TutorAvatar(size: 30),
          SizedBox(width: 10),
          Text(
            '龙老师 is thinking...',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

enum _ChatRole { assistant, user }

class _ChatMessage {
  const _ChatMessage.assistant({
    required this.chinese,
    required this.pinyin,
    required this.english,
    this.tip = '',
    this.wide = false,
  }) : role = _ChatRole.assistant;

  const _ChatMessage.user(String text)
    : role = _ChatRole.user,
      chinese = text,
      pinyin = '',
      english = '',
      tip = '',
      wide = false;

  final _ChatRole role;
  final String chinese;
  final String pinyin;
  final String english;
  final String tip;
  final bool wide;

  static _ChatMessage fromAssistantResponse(String response) {
    final normalized = response
        .trim()
        .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
        .replaceAll(RegExp(r'\s*```$'), '');

    try {
      final decoded = jsonDecode(normalized) as Map<String, dynamic>;
      return _ChatMessage.assistant(
        chinese: (decoded['chinese'] as String? ?? '').trim(),
        pinyin: (decoded['pinyin'] as String? ?? '').trim(),
        english: (decoded['english'] as String? ?? '').trim(),
        tip: (decoded['tip'] as String? ?? '').trim(),
        wide: true,
      );
    } catch (_) {
      return _ChatMessage.assistant(
        chinese: response.trim(),
        pinyin: '',
        english: '',
        wide: true,
      );
    }
  }

  Map<String, String> toAiMessage() {
    return {
      'role': role == _ChatRole.user ? 'user' : 'assistant',
      'content': role == _ChatRole.user
          ? chinese
          : [
              if (chinese.isNotEmpty) chinese,
              if (pinyin.isNotEmpty) pinyin,
              if (english.isNotEmpty) english,
              if (tip.isNotEmpty) 'Tip: $tip',
            ].join('\n'),
    };
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
