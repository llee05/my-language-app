import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';

void main() {
  setUp(() => AppColors.apply(AppThemes.classic));

  test(
    'all Material button variants share sizing, shape, and flat elevation',
    () {
      final theme = AppButtonTheme.apply(
        ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.red,
            brightness: Brightness.dark,
          ),
        ),
      );
      final styles = [
        theme.filledButtonTheme.style!,
        theme.elevatedButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
      ];

      for (final style in styles) {
        expect(style.minimumSize?.resolve({}), const Size(44, 44));
        expect(
          style.padding?.resolve({}),
          const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        );
        expect(style.elevation?.resolve({}), 0);
        expect(style.shadowColor?.resolve({}), Colors.transparent);
        final shape = style.shape?.resolve({}) as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(12));
      }

      expect(
        theme.textButtonTheme.style?.minimumSize?.resolve({}),
        const Size(40, 40),
      );
      expect(
        theme.iconButtonTheme.style?.minimumSize?.resolve({}),
        const Size.square(42),
      );
      expect(
        theme.iconButtonTheme.style?.shape?.resolve({}),
        const CircleBorder(),
      );
    },
  );

  test('chips and segmented controls use the same flat visual language', () {
    final theme = AppButtonTheme.apply(
      ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.red,
          brightness: Brightness.dark,
        ),
      ),
    );

    expect(theme.chipTheme.elevation, 0);
    expect(theme.chipTheme.pressElevation, 0);
    expect(theme.chipTheme.shadowColor, Colors.transparent);
    expect(theme.chipTheme.shape, isA<RoundedRectangleBorder>());

    final segmented = theme.segmentedButtonTheme.style!;
    expect(segmented.minimumSize?.resolve({}), const Size(44, 42));
    expect(segmented.elevation?.resolve({}), 0);
    expect(segmented.shadowColor?.resolve({}), Colors.transparent);
    expect(
      segmented.foregroundColor?.resolve({WidgetState.selected}),
      AppColors.red,
    );
  });
}
