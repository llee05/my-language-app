import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/development_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';

const _profile = LearnerProfile(name: 'Mei', hskLevel: 2, dailyWordTarget: 10);

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository([
    this._settings = const LearnerSettings(showPinyin: false),
  ]);

  LearnerSettings _settings;
  bool failSaves = false;
  final failedThemes = <String>{};
  int saveCalls = 0;
  Future<void>? saveGate;
  final attemptedThemes = <String>[];

  LearnerSettings get savedSettings => _settings;

  @override
  Future<LearnerSettings> load() async => _settings;

  @override
  Future<void> save(LearnerSettings settings) async {
    attemptedThemes.add(settings.appThemeId);
    if (settings.appThemeId == 'ocean') await saveGate;
    if (failSaves || failedThemes.contains(settings.appThemeId)) {
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
    this.profileSaveGate,
  });

  final SettingsRepository settingsRepository;
  final AppThemeId initialTheme;
  final Future<void>? profileSaveGate;

  @override
  State<_ThemeHarness> createState() => _ThemeHarnessState();
}

class _ThemeHarnessState extends State<_ThemeHarness> {
  late AppThemeId _themeId = widget.initialTheme;
  ButtonAnimationStyle _buttonAnimationStyle = ButtonAnimationStyle.combined;

  @override
  Widget build(BuildContext context) {
    AppColors.apply(AppThemes.paletteOf(_themeId));
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: AppColors.red),
      ),
      child: Scaffold(
        body: Column(
          children: [
            ColoredBox(
              key: const Key('theme-probe'),
              color: AppColors.background,
              child: const SizedBox(height: 1, width: 1),
            ),
            Text(
              _buttonAnimationStyle.name,
              key: const Key('button-animation-probe'),
            ),
            Expanded(
              child: SettingsPage(
                profile: _profile,
                onProfileChanged: (_) async => await widget.profileSaveGate,
                onResetOnboarding: () async {},
                onResetAllData: () async {},
                appThemeId: _themeId,
                onThemeChanged: (themeId) => setState(() => _themeId = themeId),
                buttonAnimationStyle: _buttonAnimationStyle,
                onButtonAnimationStyleChanged: (style) =>
                    setState(() => _buttonAnimationStyle = style),
                developmentRepository: _FakeDevelopmentRepository(),
                settingsRepository: widget.settingsRepository,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _pumpHarness(
  WidgetTester tester,
  _MemorySettingsRepository settingsRepository, {
  Future<void>? profileSaveGate,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: _ThemeHarness(
        settingsRepository: settingsRepository,
        initialTheme: AppThemeId.classic,
        profileSaveGate: profileSaveGate,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (size, scale) in [
    (const Size(1000, 900), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets('settings save stays reachable while scrolling at $size', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repository = _MemorySettingsRepository();
      await _pumpHarness(tester, repository);
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      final save = find.byKey(const Key('settings-save'));
      expect(save.hitTestable(), findsOneWidget);
      final pinyin = find.widgetWithText(SwitchListTile, 'Show pinyin');
      await tester.scrollUntilVisible(
        pinyin,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(pinyin);
      await tester.pumpAndSettle();
      final appearance = find.byKey(const Key('theme-choice-ocean'));
      await tester.scrollUntilVisible(
        appearance,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.savedSettings.showPinyin, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'an older failed theme choice cannot override a later successful choice',
    (tester) async {
      final repository = _MemorySettingsRepository()..failedThemes.add('ocean');
      final gate = Completer<void>();
      repository.saveGate = gate.future;
      await _pumpHarness(tester, repository);
      final ocean = find.byKey(const Key('theme-choice-ocean'));
      await tester.ensureVisible(ocean);
      await tester.pumpAndSettle();
      await tester.tap(ocean);
      await tester.pump();
      final forest = find.byKey(const Key('theme-choice-forest'));
      await tester.ensureVisible(forest);
      await tester.tap(forest);
      gate.complete();
      await tester.pumpAndSettle();
      expect(repository.attemptedThemes, ['ocean', 'forest']);
      expect(repository.savedSettings.appThemeId, 'forest');
      expect(find.byKey(const Key('theme-save-error')), findsNothing);
    },
  );

  testWidgets('theme selection waits until a full settings save has finished', (
    tester,
  ) async {
    final repository = _MemorySettingsRepository();
    final gate = Completer<void>();
    await _pumpHarness(tester, repository, profileSaveGate: gate.future);
    final save = find.byKey(const Key('settings-save'));
    await tester.scrollUntilVisible(
      save,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pump();
    final ocean = find.byKey(const Key('theme-choice-ocean'));
    await tester.scrollUntilVisible(
      ocean,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(ocean);
    await tester.pump();
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('theme-probe'))).color,
      AppThemes.classic.background,
    );
    gate.complete();
    await tester.pumpAndSettle();
    await tester.tap(ocean);
    await tester.pumpAndSettle();
    expect(repository.savedSettings.appThemeId, 'ocean');
    expect(repository.savedSettings.showPinyin, isFalse);
  });

  testWidgets(
    'rapid theme choices persist in selection order even after leaving',
    (tester) async {
      final repository = _MemorySettingsRepository();
      final gate = Completer<void>();
      repository.saveGate = gate.future;
      await _pumpHarness(tester, repository);
      final ocean = find.byKey(const Key('theme-choice-ocean'));
      final forest = find.byKey(const Key('theme-choice-forest'));
      await tester.ensureVisible(ocean);
      await tester.pumpAndSettle();
      await tester.tap(ocean);
      await tester.pump();
      await tester.ensureVisible(forest);
      await tester.tap(forest);
      await tester.pump();
      expect(
        tester.widget<ColoredBox>(find.byKey(const Key('theme-probe'))).color,
        AppThemes.forest.background,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete();
      await tester.pumpAndSettle();
      expect(repository.savedSettings.appThemeId, 'forest');
      expect(repository.savedSettings.showPinyin, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selecting a theme applies it and persists the choice', (
    tester,
  ) async {
    final settingsRepository = _MemorySettingsRepository();
    await _pumpHarness(tester, settingsRepository);
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('设置')).style?.color,
      AppThemes.classic.red,
    );

    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('theme-probe'))).color,
      AppThemes.classic.background,
    );

    final oceanChip = find.byKey(const Key('theme-choice-ocean'));
    expect(oceanChip.hitTestable(), findsOneWidget);
    await tester.tap(oceanChip);
    await tester.pumpAndSettle();

    // The active palette changed immediately…
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('theme-probe'))).color,
      AppThemes.ocean.background,
    );
    expect(
      tester.widget<Text>(find.text('设置')).style?.color,
      AppThemes.ocean.red,
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

  testWidgets('button animation can be previewed and saved', (tester) async {
    final settingsRepository = _MemorySettingsRepository(
      const LearnerSettings(
        showPinyin: false,
        buttonAnimationStyle: ButtonAnimationStyle.bounce,
      ),
    );
    await _pumpHarness(tester, settingsRepository);

    final picker = find.byKey(const Key('settings-button-animation-picker'));
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    expect(find.text('Bounce'), findsOneWidget);

    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill transition').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('button-animation-preview')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('button-animation-probe'))).data,
      ButtonAnimationStyle.fillTransition.name,
    );
    final save = find.byKey(const Key('settings-save'));
    await tester.scrollUntilVisible(
      save,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      settingsRepository.savedSettings.buttonAnimationStyle,
      ButtonAnimationStyle.fillTransition,
    );
  });
}
