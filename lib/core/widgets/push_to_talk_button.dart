part of '../../main.dart';

class _PushToTalkButton extends StatefulWidget {
  const _PushToTalkButton({
    super.key,
    required this.controller,
    required this.speechInputService,
    this.enabled = true,
    this.preferredLocaleId,
    this.beforeListening,
    this.animationStyle = ButtonAnimationStyle.combined,
  });

  final TextEditingController controller;
  final SpeechInputService speechInputService;
  final bool enabled;
  final String? preferredLocaleId;
  final Future<void> Function()? beforeListening;
  final ButtonAnimationStyle animationStyle;

  @override
  State<_PushToTalkButton> createState() => _PushToTalkButtonState();
}

class _PushToTalkButtonState extends State<_PushToTalkButton> {
  bool _pressed = false;
  bool _starting = false;
  bool _listening = false;
  int _session = 0;
  String _textBeforeSpeech = '';

  bool get _canStart => widget.enabled && !_starting && !_listening;

  void _press() {
    if (!_canStart) return;
    _pressed = true;
    unawaited(_startListening(++_session));
  }

  void _release() {
    _pressed = false;
    if (_listening) unawaited(_stopListening());
  }

  Future<void> _startListening(int session) async {
    _textBeforeSpeech = widget.controller.text.trimRight();
    setState(() => _starting = true);
    try {
      await widget.beforeListening?.call();
      await widget.speechInputService.startListening(
        preferredLocaleId: widget.preferredLocaleId,
        onResult: (transcript) => _applyTranscript(session, transcript),
        onError: (message) => _showError(session, message),
      );
      if (!mounted || session != _session) {
        await widget.speechInputService.cancelListening();
        return;
      }
      setState(() {
        _starting = false;
        _listening = true;
      });
      if (!_pressed) await _stopListening();
    } on SpeechInputException catch (error) {
      _finishWithError(session, error.message);
    } catch (_) {
      _finishWithError(session, 'Speech input is unavailable on this device.');
    }
  }

  void _applyTranscript(int session, String transcript) {
    if (!mounted || session != _session) return;
    final spokenText = transcript.trim();
    final separator = _textBeforeSpeech.isEmpty || spokenText.isEmpty
        ? ''
        : ' ';
    final text = '$_textBeforeSpeech$separator$spokenText';
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _showError(int session, String message) {
    if (!mounted || session != _session) return;
    setState(() {
      _starting = false;
      _listening = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _finishWithError(int session, String message) {
    if (!mounted || session != _session) return;
    _showError(session, message);
  }

  Future<void> _stopListening() async {
    if (!_starting && !_listening) return;
    try {
      await widget.speechInputService.stopListening();
    } catch (_) {
      if (mounted) {
        _showError(_session, 'Speech input could not be stopped cleanly.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
          _listening = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant _PushToTalkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled && (_starting || _listening)) {
      _pressed = false;
      unawaited(_stopListening());
    }
  }

  @override
  void dispose() {
    _session++;
    unawaited(widget.speechInputService.cancelListening());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _starting || _listening;
    return _AnimatedButtonFeedback(
      style: widget.animationStyle,
      enabled: widget.enabled,
      active: active,
      moveChild: true,
      shape: BoxShape.circle,
      child: Tooltip(
        message: active ? 'Release to stop' : 'Hold to talk',
        child: Semantics(
          button: true,
          enabled: widget.enabled,
          label: active ? 'Listening. Release to stop.' : 'Hold to talk',
          child: Material(
            color: active
                ? AppColors.red.withValues(alpha: .2)
                : Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTapDown: widget.enabled ? (_) => _press() : null,
              onTapUp: widget.enabled ? (_) => _release() : null,
              onTapCancel: widget.enabled ? _release : null,
              child: SizedBox.square(
                dimension: 42,
                child: Icon(
                  active ? Icons.mic_rounded : Icons.mic_none_rounded,
                  size: 20,
                  color: widget.enabled
                      ? (active ? AppColors.red : AppColors.muted)
                      : Theme.of(context).disabledColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
