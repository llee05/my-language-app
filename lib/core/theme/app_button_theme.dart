part of '../../main.dart';

/// The shared visual language for every Material button and chip in TingShuo.
/// Feature code should override these defaults only to communicate state or a
/// distinct semantic meaning such as success, error, or a destructive action.
abstract final class AppButtonTheme {
  static const _radius = 12.0;
  static const _minimumSize = Size(44, 44);
  static const _padding = EdgeInsets.symmetric(horizontal: 16, vertical: 11);
  static const _textStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  static ThemeData apply(
    ThemeData theme, {
    ButtonAnimationStyle animationStyle = ButtonAnimationStyle.combined,
  }) {
    final usesRipple = animationStyle == ButtonAnimationStyle.ripple;
    final usesFill = animationStyle == ButtonAnimationStyle.fillTransition;
    final splashFactory = usesRipple
        ? InkRipple.splashFactory
        : NoSplash.splashFactory;
    final overlayColor = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) return Colors.transparent;
      if (usesFill && states.contains(WidgetState.pressed)) {
        return AppColors.red.withValues(alpha: .14);
      }
      if (usesFill &&
          (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused))) {
        return AppColors.red.withValues(alpha: .07);
      }
      return Colors.transparent;
    });
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
    );
    final flatButton = ButtonStyle(
      animationDuration: const Duration(milliseconds: 160),
      minimumSize: const WidgetStatePropertyAll(_minimumSize),
      padding: const WidgetStatePropertyAll(_padding),
      textStyle: const WidgetStatePropertyAll(_textStyle),
      shape: WidgetStatePropertyAll(buttonShape),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: usesRipple ? null : overlayColor,
      splashFactory: splashFactory,
    );
    final outlinedButton = flatButton.copyWith(
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: AppColors.border.withValues(alpha: .35));
        }
        if (states.contains(WidgetState.focused) ||
            states.contains(WidgetState.pressed)) {
          return BorderSide(color: AppColors.red.withValues(alpha: .85));
        }
        return BorderSide(color: AppColors.border.withValues(alpha: .75));
      }),
    );
    final textButton = flatButton.copyWith(
      minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      ),
    );
    final iconButton = flatButton.copyWith(
      minimumSize: const WidgetStatePropertyAll(Size.square(42)),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(9)),
      shape: const WidgetStatePropertyAll(CircleBorder()),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.faint.withValues(alpha: .5);
        }
        if (states.contains(WidgetState.selected)) return AppColors.red;
        return AppColors.muted;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.red.withValues(alpha: .14);
        }
        return Colors.transparent;
      }),
      iconSize: const WidgetStatePropertyAll(20),
    );

    return theme.copyWith(
      extensions: [
        ...theme.extensions.values.where(
          (value) => value is! _ButtonMotionTheme,
        ),
        _ButtonMotionTheme(animationStyle),
      ],
      filledButtonTheme: FilledButtonThemeData(style: flatButton),
      elevatedButtonTheme: ElevatedButtonThemeData(style: flatButton),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButton),
      textButtonTheme: TextButtonThemeData(style: textButton),
      iconButtonTheme: IconButtonThemeData(style: iconButton),
      chipTheme: theme.chipTheme.copyWith(
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.red.withValues(alpha: .16),
        disabledColor: AppColors.surfaceLight.withValues(alpha: .45),
        labelStyle: _textStyle.copyWith(color: AppColors.text),
        secondaryLabelStyle: _textStyle.copyWith(color: AppColors.text),
        side: BorderSide(color: AppColors.border.withValues(alpha: .7)),
        shape: buttonShape,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
        selectedShadowColor: Colors.transparent,
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 160),
          minimumSize: const WidgetStatePropertyAll(Size(44, 42)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          textStyle: const WidgetStatePropertyAll(_textStyle),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.red
                : AppColors.muted,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.red.withValues(alpha: .14)
                : Colors.transparent,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.border.withValues(alpha: .7)),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: usesRipple ? null : overlayColor,
          splashFactory: splashFactory,
        ),
      ),
      splashFactory: splashFactory,
      splashColor: usesRipple
          ? AppColors.red.withValues(alpha: .16)
          : Colors.transparent,
      highlightColor: usesFill
          ? AppColors.red.withValues(alpha: .12)
          : Colors.transparent,
    );
  }
}
