import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/development_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';

const _profile = LearnerProfile(name: 'Mei', hskLevel: 2, dailyWordTarget: 10);

class _MemorySettingsRepository implements SettingsRepository {
  LearnerSettings _settings = const LearnerSettings(showPinyin: false);
  bool failSaves = false;
  int saveCalls = 0;

  LearnerSettings get savedSettings => _settings;

  @override
  Future<LearnerSettings> load() async => _settings;

  @override
  Future<void> save(LearnerSettings settings) async {
    if (failSaves) {
      throw Exception('simulated settings save failure');
    }
    saveCalls++;
    _settings = settings;
  }
}

class _FakeDevelopmentRepository implements DevelopmentRepository {
  @override
  Future<String> databasePath() async => '/tmp/test.db';

  @override
  Future<void> resetAllData() async {}
}

/// Applies the selected theme the same way the real app root does and exposes
/// a probe whose colour follows the active palette.
class _ThemeHarness extends StatefulWidget {
  const _ThemeHarness({
    required this.settingsRepository,
    required this.initialTheme,
  });

  final SettingsRepository settingsRepository;
  final AppThemeId initialTheme;

  @override
  State<_ThemeHarness> createState() => _ThemeHarnessState();
}

class _ThemeHarnessState extends State<_ThemeHarness> {
  late AppThemeId _themeId = widget.initialTheme;

  @override
  Widget build(BuildContext context) {
    AppColors.apply(AppThemes.paletteOf(_themeId));
    return Scaffold(
      body: Column(
        children: [
          ColoredBox(
            key: const Key('theme-probe'),
            color: AppColors.background,
            child: const SizedBox(height: 1, width: 1),
          ),
          Expanded(
            child: SettingsPage(
              profile: _profile,
              onProfileChanged: (_) async {},
              onResetOnboarding: () async {},
              onResetAllData: () async {},
              appThemeId: _themeId,
              onThemeChanged: (themeId) => setState(() => _themeId = themeId),
              developmentRepository: _FakeDevelopmentRepository(),
              settingsRepository: widget.settingsRepository,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pumpHarness(
  WidgetTester tester,
  _MemorySettingsRepository settingsRepository,
) async {
  await tester.binding.setSurfaceSize(const Size(1000, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: _ThemeHarness(
        settingsRepository: settingsRepository,
        initialTheme: AppThemeId.classic,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selecting a theme applies it and persists the choice', (
    tester,
  ) async {
    final settingsRepository = _MemorySettingsRepository();
    await _pumpHarness(tester, settingsRepository);

    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('theme-probe'))).color,
      AppThemes.classic.background,
    );

    final oceanChip = find.byKey(const Key('theme-choice-ocean'));
    await tester.ensureVisible(oceanChip);
    await tester.pumpAndSettle();
    await tester.tap(oceanChip);
    await tester.pumpAndSettle();

    // The active palette changed immediately…
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('theme-probe'))).color,
      AppThemes.ocean.background,
    );
    // …and the choice was persisted without touching other preferences.
    expect(settingsRepository.saveCalls, 1);
    expect(settingsRepository.savedSettings.appThemeId, 'ocean');
    expect(settingsRepository.savedSettings.showPinyin, isFalse);
  });

  testWidgets('a failed theme save surfaces a retryable error', (tester) async {
    final settingsRepository = _MemorySettingsRepository()..failSaves = true;
    await _pumpHarness(tester, settingsRepository);

    final oceanChip = find.byKey(const Key('theme-choice-ocean'));
    await tester.ensureVisible(oceanChip);
    await tester.pumpAndSettle();
    await tester.tap(oceanChip);
    await tester.pumpAndSettle();

    // The theme is still applied in-session, but an inline error appears.
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('theme-probe'))).color,
      AppThemes.ocean.background,
    );
    expect(find.byKey(const Key('theme-save-error')), findsOneWidget);
    expect(settingsRepository.saveCalls, 0);

    settingsRepository.failSaves = false;
    await tester.ensureVisible(find.byKey(const Key('theme-save-retry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme-save-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('theme-save-error')), findsNothing);
    expect(settingsRepository.savedSettings.appThemeId, 'ocean');
  });
}
