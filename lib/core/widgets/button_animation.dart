part of '../../main.dart';

/// Adds the learner-selected motion treatment around an existing Material
/// control. The wrapped control still owns taps, focus, and semantics.
class _AnimatedButtonFeedback extends StatefulWidget {
  const _AnimatedButtonFeedback({
    required this.style,
    required this.child,
    this.enabled = true,
    this.active = false,
    this.moveChild = false,
    this.shape = BoxShape.rectangle,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  final ButtonAnimationStyle style;
  final Widget child;
  final bool enabled;
  final bool active;
  final bool moveChild;
  final BoxShape shape;
  final BorderRadius borderRadius;

  @override
  State<_AnimatedButtonFeedback> createState() =>
      _AnimatedButtonFeedbackState();
}

class _AnimatedButtonFeedbackState extends State<_AnimatedButtonFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _pressed = false;

  bool get _usesGlow =>
      widget.style == ButtonAnimationStyle.glowPulse ||
      widget.style == ButtonAnimationStyle.combined;

  bool get _usesFill => widget.style == ButtonAnimationStyle.fillTransition;

  bool get _usesMotion =>
      widget.style == ButtonAnimationStyle.subtleScale ||
      widget.style == ButtonAnimationStyle.bounce ||
      widget.style == ButtonAnimationStyle.combined;

  bool get _usesIconMotion =>
      widget.moveChild &&
      (widget.style == ButtonAnimationStyle.iconMotion ||
          widget.style == ButtonAnimationStyle.combined);

  bool get _usesMaterialRipple => widget.style == ButtonAnimationStyle.ripple;

  Widget _materialChild(BuildContext context) {
    if (_usesMaterialRipple) return widget.child;

    final theme = Theme.of(context);
    ButtonStyle flatten(ButtonStyle? style) =>
        (style ?? const ButtonStyle()).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
        );
    return Theme(
      data: theme.copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: flatten(theme.elevatedButtonTheme.style),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: flatten(theme.filledButtonTheme.style),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: flatten(theme.outlinedButtonTheme.style),
        ),
        textButtonTheme: TextButtonThemeData(
          style: flatten(theme.textButtonTheme.style),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: flatten(theme.iconButtonTheme.style),
        ),
        chipTheme: theme.chipTheme.copyWith(
          pressElevation: 0,
          shadowColor: Colors.transparent,
          selectedShadowColor: Colors.transparent,
        ),
      ),
      child: widget.child,
    );
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _AnimatedButtonFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) _pressed = false;
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.active &&
        _usesGlow &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  void _setPressed(bool pressed) {
    if (!widget.enabled || _pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = !reduceMotion && _usesMotion && _pressed
        ? widget.style == ButtonAnimationStyle.bounce
              ? .9
              : .95
        : 1.0;
    final duration = _pressed
        ? const Duration(milliseconds: 90)
        : widget.style == ButtonAnimationStyle.bounce
        ? const Duration(milliseconds: 420)
        : const Duration(milliseconds: 180);
    final curve = !_pressed && widget.style == ButtonAnimationStyle.bounce
        ? Curves.elasticOut
        : Curves.easeOutCubic;

    return Listener(
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
      child: AnimatedBuilder(
        animation: _pulseController,
        child: _materialChild(context),
        builder: (context, child) {
          final pulse = reduceMotion ? 0.0 : sin(_pulseController.value * pi);
          final glowStrength = _usesGlow && widget.active
              ? .3 + pulse * .35
              : 0.0;
          Widget result = AnimatedSlide(
            offset: !reduceMotion && _usesIconMotion && _pressed
                ? const Offset(.07, 0)
                : Offset.zero,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: child,
          );
          result = Stack(
            clipBehavior: Clip.none,
            children: [
              result,
              if (_usesFill)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        color: _pressed
                            ? AppColors.red.withValues(alpha: .14)
                            : Colors.transparent,
                        shape: widget.shape,
                        borderRadius: widget.shape == BoxShape.circle
                            ? null
                            : widget.borderRadius,
                      ),
                    ),
                  ),
                ),
            ],
          );
          return AnimatedScale(
            scale: scale,
            duration: reduceMotion ? Duration.zero : duration,
            curve: curve,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: widget.shape,
                borderRadius: widget.shape == BoxShape.circle
                    ? null
                    : widget.borderRadius,
                boxShadow: glowStrength == 0
                    ? const []
                    : [
                        BoxShadow(
                          color: AppColors.red.withValues(alpha: glowStrength),
                          blurRadius: 7 + 9 * glowStrength,
                          spreadRadius: 1 + 2 * glowStrength,
                        ),
                      ],
              ),
              child: result,
            ),
          );
        },
      ),
    );
  }
}

/// Carries the saved motion preference through routes and modal sheets.
class _ButtonMotionTheme extends ThemeExtension<_ButtonMotionTheme> {
  const _ButtonMotionTheme(this.style);

  final ButtonAnimationStyle style;

  @override
  _ButtonMotionTheme copyWith({ButtonAnimationStyle? style}) =>
      _ButtonMotionTheme(style ?? this.style);

  @override
  _ButtonMotionTheme lerp(covariant _ButtonMotionTheme? other, double t) =>
      other == null || t < .5 ? this : other;
}
