import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';

void main() {
  tearDown(() {
    // Keep the default palette for other tests regardless of what a test
    // applied to the global AppColors.
    AppColors.apply(AppThemes.classic);
  });

  group('AppThemes.tryParseId', () {
    test('parses every persisted theme id', () {
      for (final id in AppThemeId.values) {
        expect(AppThemes.tryParseId(id.name), id);
      }
    });

    test('returns null for unknown, blank, or missing ids', () {
      expect(AppThemes.tryParseId('bogus'), isNull);
      expect(AppThemes.tryParseId(''), isNull);
      expect(AppThemes.tryParseId('  '), isNull);
      expect(AppThemes.tryParseId(null), isNull);
    });
  });

  group('AppThemes.palettes', () {
    test('every theme id has a complete palette with a label', () {
      expect(AppThemes.all.map((p) => p.id), AppThemeId.values);
      for (final palette in AppThemes.all) {
        expect(palette.label, isNotEmpty);
        for (final color in [
          palette.background,
          palette.sidebar,
          palette.surface,
          palette.surfaceLight,
          palette.border,
          palette.red,
          palette.darkRed,
          palette.gold,
          palette.teal,
          palette.text,
          palette.muted,
          palette.faint,
        ]) {
          expect(color, isA<Color>());
        }
      }
    });

    test('paletteOf returns the palette registered for the id', () {
      expect(AppThemes.paletteOf(AppThemeId.classic).id, AppThemeId.classic);
      expect(AppThemes.paletteOf(AppThemeId.ocean).label, 'Ocean');
      expect(AppThemes.paletteOf(AppThemeId.forest).label, 'Forest');
      expect(AppThemes.paletteOf(AppThemeId.violet).label, 'Violet');
      expect(AppThemes.paletteOf(AppThemeId.midnight).label, 'Midnight');
    });
  });

  group('AppColors.apply', () {
    test('replaces every static colour slot with the palette values', () {
      expect(AppColors.background, AppThemes.classic.background);

      AppColors.apply(AppThemes.ocean);

      expect(AppColors.background, AppThemes.ocean.background);
      expect(AppColors.sidebar, AppThemes.ocean.sidebar);
      expect(AppColors.surface, AppThemes.ocean.surface);
      expect(AppColors.surfaceLight, AppThemes.ocean.surfaceLight);
      expect(AppColors.border, AppThemes.ocean.border);
      expect(AppColors.red, AppThemes.ocean.red);
      expect(AppColors.darkRed, AppThemes.ocean.darkRed);
      expect(AppColors.gold, AppThemes.ocean.gold);
      expect(AppColors.teal, AppThemes.ocean.teal);
      expect(AppColors.text, AppThemes.ocean.text);
      expect(AppColors.muted, AppThemes.ocean.muted);
      expect(AppColors.faint, AppThemes.ocean.faint);

      AppColors.apply(AppThemes.classic);

      expect(AppColors.background, AppThemes.classic.background);
      expect(AppColors.red, AppThemes.classic.red);
    });
  });
}
