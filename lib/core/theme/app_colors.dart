part of '../../main.dart';

/// Available colour themes. Persisted by id in `learner_settings.theme_id`.
enum AppThemeId {
  classic,
  ocean,
  forest,
  violet,
  midnight,
  sakura,
  jade,
  copper,
  slate,
}

/// One complete colour palette. Every slot that the UI paints with must be
/// listed here so a theme switch recolours the whole app.
class AppColorPalette {
  const AppColorPalette({
    required this.id,
    required this.label,
    required this.background,
    required this.sidebar,
    required this.surface,
    required this.surfaceLight,
    required this.border,
    required this.red,
    required this.darkRed,
    required this.gold,
    required this.teal,
    required this.text,
    required this.muted,
    required this.faint,
  });

  final AppThemeId id;
  final String label;
  final Color background;
  final Color sidebar;
  final Color surface;
  final Color surfaceLight;
  final Color border;

  /// Primary accent. The historical name `red` refers to the original ember
  /// accent; non-red themes place their own accent colour in this slot.
  final Color red;

  /// Darker companion of the primary accent, used for tinted error surfaces.
  final Color darkRed;
  final Color gold;
  final Color teal;
  final Color text;
  final Color muted;
  final Color faint;
}

abstract final class AppThemes {
  static const classic = AppColorPalette(
    id: AppThemeId.classic,
    label: 'Classic Ember',
    background: Color(0xFF2C2423),
    sidebar: Color(0xFF3F2F2D),
    surface: Color(0xFF493B39),
    surfaceLight: Color(0xFF5E4F4B),
    border: Color(0xFFCB8E84),
    red: Color(0xFFFF6B5F),
    darkRed: Color(0xFFD8433A),
    gold: Color(0xFFFFD768),
    teal: Color(0xFF64E3D5),
    text: Color(0xFFF8F0EC),
    muted: Color(0xFFDFC3BA),
    faint: Color(0xFFD2B2AB),
  );

  static const ocean = AppColorPalette(
    id: AppThemeId.ocean,
    label: 'Ocean',
    background: Color(0xFF16232E),
    sidebar: Color(0xFF1E3140),
    surface: Color(0xFF24394A),
    surfaceLight: Color(0xFF314C61),
    border: Color(0xFF6E9BB5),
    red: Color(0xFF62C6F2),
    darkRed: Color(0xFF2E93C4),
    gold: Color(0xFFF2CE6B),
    teal: Color(0xFF6FE3D2),
    text: Color(0xFFEDF5FA),
    muted: Color(0xFFB9CFDC),
    faint: Color(0xFFA3BDCB),
  );

  static const forest = AppColorPalette(
    id: AppThemeId.forest,
    label: 'Forest',
    background: Color(0xFF17211B),
    sidebar: Color(0xFF1F2F24),
    surface: Color(0xFF26392C),
    surfaceLight: Color(0xFF334C3A),
    border: Color(0xFF7FA98A),
    red: Color(0xFF7FD98B),
    darkRed: Color(0xFF4CA65E),
    gold: Color(0xFFE7C86A),
    teal: Color(0xFF6FD9C0),
    text: Color(0xFFF0F7EF),
    muted: Color(0xFFC2D6C0),
    faint: Color(0xFFACC4AB),
  );

  static const violet = AppColorPalette(
    id: AppThemeId.violet,
    label: 'Violet',
    background: Color(0xFF201A2C),
    sidebar: Color(0xFF2B2340),
    surface: Color(0xFF342A4B),
    surfaceLight: Color(0xFF443861),
    border: Color(0xFF9A85C0),
    red: Color(0xFFC29BFF),
    darkRed: Color(0xFF8F5FD6),
    gold: Color(0xFFF2C879),
    teal: Color(0xFF74D9E3),
    text: Color(0xFFF5F0FB),
    muted: Color(0xFFCFC3E2),
    faint: Color(0xFFB9A9D1),
  );

  static const midnight = AppColorPalette(
    id: AppThemeId.midnight,
    label: 'Midnight',
    background: Color(0xFF171A21),
    sidebar: Color(0xFF1F232D),
    surface: Color(0xFF262B37),
    surfaceLight: Color(0xFF333948),
    border: Color(0xFF7C869C),
    red: Color(0xFFFFB454),
    darkRed: Color(0xFFD98A2B),
    gold: Color(0xFFFFD768),
    teal: Color(0xFF6FD9E0),
    text: Color(0xFFEFF1F5),
    muted: Color(0xFFC0C6D2),
    faint: Color(0xFFA9B1BF),
  );

  static const sakura = AppColorPalette(
    id: AppThemeId.sakura,
    label: 'Sakura',
    background: Color(0xFF211823),
    sidebar: Color(0xFF2D202C),
    surface: Color(0xFF382736),
    surfaceLight: Color(0xFF493447),
    border: Color(0xFFB889A3),
    red: Color(0xFFFF9ABD),
    darkRed: Color(0xFFC66889),
    gold: Color(0xFFF0C982),
    teal: Color(0xFF91D5BC),
    text: Color(0xFFFFF2F7),
    muted: Color(0xFFDFC2D0),
    faint: Color(0xFFCBB0BF),
  );

  static const jade = AppColorPalette(
    id: AppThemeId.jade,
    label: 'Jade',
    background: Color(0xFF142622),
    sidebar: Color(0xFF1D332D),
    surface: Color(0xFF264139),
    surfaceLight: Color(0xFF335449),
    border: Color(0xFF82ADA0),
    red: Color(0xFF70E0BC),
    darkRed: Color(0xFF42A785),
    gold: Color(0xFFE3D081),
    teal: Color(0xFFA4DDD6),
    text: Color(0xFFEBF8F2),
    muted: Color(0xFFBCD8CB),
    faint: Color(0xFFACC8BC),
  );

  static const copper = AppColorPalette(
    id: AppThemeId.copper,
    label: 'Copper',
    background: Color(0xFF251D18),
    sidebar: Color(0xFF32261F),
    surface: Color(0xFF3F3026),
    surfaceLight: Color(0xFF524030),
    border: Color(0xFFBC9778),
    red: Color(0xFFF0B786),
    darkRed: Color(0xFFB77A4A),
    gold: Color(0xFFF2D58E),
    teal: Color(0xFF92CFBD),
    text: Color(0xFFFBF1E8),
    muted: Color(0xFFDCCAB8),
    faint: Color(0xFFC9B49F),
  );

  static const slate = AppColorPalette(
    id: AppThemeId.slate,
    label: 'Slate',
    background: Color(0xFF1C1E22),
    sidebar: Color(0xFF26292E),
    surface: Color(0xFF30343B),
    surfaceLight: Color(0xFF414751),
    border: Color(0xFF939CAB),
    red: Color(0xFFD2D9E4),
    darkRed: Color(0xFF8795AA),
    gold: Color(0xFFE6CC92),
    teal: Color(0xFF9ED6C7),
    text: Color(0xFFF2F4F8),
    muted: Color(0xFFCDD1DA),
    faint: Color(0xFFB8BFCD),
  );

  static const all = [
    classic,
    ocean,
    forest,
    violet,
    midnight,
    sakura,
    jade,
    copper,
    slate,
  ];

  static AppColorPalette paletteOf(AppThemeId id) => switch (id) {
    AppThemeId.classic => classic,
    AppThemeId.ocean => ocean,
    AppThemeId.forest => forest,
    AppThemeId.violet => violet,
    AppThemeId.midnight => midnight,
    AppThemeId.sakura => sakura,
    AppThemeId.jade => jade,
    AppThemeId.copper => copper,
    AppThemeId.slate => slate,
  };

  /// Returns the theme with the given persisted id, or null when unknown so
  /// callers can fall back to the classic theme.
  static AppThemeId? tryParseId(String? value) {
    for (final id in AppThemeId.values) {
      if (id.name == value) return id;
    }
    return null;
  }
}

/// The active palette as static fields.
///
/// Fields are mutable (not `const`) so selecting a theme in Settings recolours
/// the whole app. Call [apply] before building the material app; widgets must
/// not cache these colours inside `const` expressions.
abstract final class AppColors {
  static Color background = AppThemes.classic.background;
  static Color sidebar = AppThemes.classic.sidebar;
  static Color surface = AppThemes.classic.surface;
  static Color surfaceLight = AppThemes.classic.surfaceLight;
  static Color border = AppThemes.classic.border;
  static Color red = AppThemes.classic.red;
  static Color darkRed = AppThemes.classic.darkRed;
  static Color gold = AppThemes.classic.gold;
  static Color teal = AppThemes.classic.teal;
  static Color text = AppThemes.classic.text;
  static Color muted = AppThemes.classic.muted;
  static Color faint = AppThemes.classic.faint;

  /// Quiet separators and card outlines leave emphasis to selected controls.
  static Color get divider => border.withValues(alpha: .20);
  static Color get outline => border.withValues(alpha: .38);

  static void apply(AppColorPalette palette) {
    background = palette.background;
    sidebar = palette.sidebar;
    surface = palette.surface;
    surfaceLight = palette.surfaceLight;
    border = palette.border;
    red = palette.red;
    darkRed = palette.darkRed;
    gold = palette.gold;
    teal = palette.teal;
    text = palette.text;
    muted = palette.muted;
    faint = palette.faint;
  }
}
