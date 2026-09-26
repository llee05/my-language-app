part of '../../main.dart';

/// Gives immediate feedback while the speech engine prepares and starts audio.
/// The callback completes at dispatch on some engines, so this deliberately
/// does not claim to track playback duration.
class PronunciationButton extends StatefulWidget {
  const PronunciationButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Hear Mandarin pronunciation',
    this.label,
    this.icon = Icons.volume_up_outlined,
    this.requestKey,
    this.busy = false,
  });

  final Future<void> Function()? onPressed;
  final String tooltip;
  final String? label;
  final IconData icon;

  /// Changes when a reused control moves to another card or utterance.
  final Object? requestKey;
  final bool busy;

  @override
  State<PronunciationButton> createState() => _PronunciationButtonState();
}

class _PronunciationButtonState extends State<PronunciationButton> {
  bool _starting = false;
  int _request = 0;

  @override
  void didUpdateWidget(covariant PronunciationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestKey != widget.requestKey) {
      _request++;
      _starting = false;
    }
  }

  Future<void> _activate() async {
    final action = widget.onPressed;
    if (action == null || _starting || widget.busy) return;
    final request = ++_request;
    setState(() => _starting = true);
    unawaited(Feedback.forTap(context));
    try {
      await action();
    } catch (error) {
      // Most screens provide their own engine-specific recovery. Keep direct
      // callbacks (such as dialogue word previews) safe as well.
      debugPrint('Pronunciation button failed: $error');
      if (mounted && request == _request) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Mandarin audio is unavailable. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _starting || widget.busy;
    final enabled = widget.onPressed != null && !active;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final style =
        Theme.of(context).extension<_ButtonMotionTheme>()?.style ??
        ButtonAnimationStyle.combined;
    final foreground = active || enabled ? AppColors.red : AppColors.faint;
    final tooltip = active ? 'Starting audio…' : widget.tooltip;
    final indicator = SizedBox.square(
      dimension: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 150),
            child: Icon(
              active ? Icons.graphic_eq_rounded : widget.icon,
              key: ValueKey(active),
              size: active ? 16 : 22,
            ),
          ),
          if (active)
            ExcludeSemantics(
              child: CircularProgressIndicator(
                value: reduceMotion ? .75 : null,
                strokeWidth: 2,
                color: foreground,
              ),
            ),
        ],
      ),
    );
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      foregroundColor: WidgetStatePropertyAll(foreground),
      backgroundColor: WidgetStatePropertyAll(
        AppColors.red.withValues(
          alpha: active
              ? .22
              : enabled
              ? .10
              : .03,
        ),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: AppColors.red.withValues(
            alpha: states.contains(WidgetState.focused)
                ? .9
                : active
                ? .6
                : .22,
          ),
          width: states.contains(WidgetState.focused) ? 2 : 1,
        ),
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)
            ? AppColors.red.withValues(alpha: .12)
            : null,
      ),
      enableFeedback: false,
    );
    return Semantics(
      value: active ? 'Starting audio' : null,
      liveRegion: active,
      child: _AnimatedButtonFeedback(
        style: style,
        enabled: enabled,
        active: active,
        moveChild: true,
        shape: widget.label == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: BorderRadius.circular(12),
        child: widget.label == null
            ? IconButton(
                tooltip: tooltip,
                onPressed: enabled ? _activate : null,
                style: buttonStyle,
                icon: indicator,
              )
            : Tooltip(
                message: tooltip,
                child: FilledButton.tonalIcon(
                  onPressed: enabled ? _activate : null,
                  style: buttonStyle,
                  icon: indicator,
                  label: Text(widget.label!),
                ),
              ),
      ),
    );
  }
}
