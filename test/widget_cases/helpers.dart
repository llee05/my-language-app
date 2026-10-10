part of '../widget_test.dart';

Future<void> _waitForWidget(
  WidgetTester tester,
  Finder finder, {
  int maxAttempts = 100,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
}

Future<void> _pumpResetSettings(
  WidgetTester tester,
  _MemoryDevelopmentRepository developmentRepository, {
  Future<void> Function()? onResetOnboarding,
  Future<void> Function(LearnerProfile)? onProfileChanged,
  SettingsRepository? settingsRepository,
  Size surfaceSize = const Size(1000, 900),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SettingsPage(
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: onProfileChanged ?? (_) async {},
          onResetOnboarding: onResetOnboarding ?? () async {},
          onResetAllData: developmentRepository.resetAllData,
          developmentRepository: developmentRepository,
          settingsRepository: settingsRepository ?? _MemorySettingsRepository(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _revealSettingsControl(WidgetTester tester, Key buttonKey) async {
  final button = find.byKey(buttonKey);
  await tester.scrollUntilVisible(
    button,
    400,
    scrollable: find
        .descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await Scrollable.ensureVisible(tester.element(button), alignment: .5);
  await tester.pumpAndSettle();
}

Future<void> _openSettingsResetDialog(
  WidgetTester tester,
  Key buttonKey,
) async {
  await _revealSettingsControl(tester, buttonKey);
  final button = find.byKey(buttonKey);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _pumpRecordedVoiceSettings(
  WidgetTester tester,
  _RecordedFakePronunciationService pronunciation, {
  Size surfaceSize = const Size(1000, 1000),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(pronunciation.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SettingsPage(
          appThemeId: AppThemeId.classic,
          onThemeChanged: (_) {},
          profile: testProfile,
          onProfileChanged: (_) async {},
          onResetOnboarding: () async {},
          onResetAllData: () async {},
          developmentRepository: _MemoryDevelopmentRepository(),
          settingsRepository: _MemorySettingsRepository(),
          pronunciationService: pronunciation,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _revealSettingsControl(tester, const Key('desktop-voice-check'));
}

Future<void> _confirmAccountReset(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('account-reset-confirmation-input')),
    'RESET',
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('account-reset-confirm')));
}
