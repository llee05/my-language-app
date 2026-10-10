part of '../widget_test.dart';

void _registerSettingsPreferencesWidgetTests() {
  testWidgets('settings restores and saves learning preferences', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MemorySettingsRepository(
      const LearnerSettings(showPinyin: false, soundEnabled: false),
    );

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
            developmentRepository: const SqliteDevelopmentRepository(),
            settingsRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    final pinyinSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Show pinyin'),
    );
    expect(pinyinSwitch.value, isFalse);
    await tester.tap(find.text('Show pinyin'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-save')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(repository.settings.showPinyin, isTrue);
    expect(repository.settings.soundEnabled, isFalse);
    expect(find.text('Settings saved.'), findsOneWidget);
  });

  testWidgets(
    'Android voice setup rechecks on return without assuming installation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pronunciation = _FakeSystemVoiceService();
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
      final install = find.byKey(const Key('system-voice-install'));
      await tester.scrollUntilVisible(
        install,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(install), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(install);
      await tester.pumpAndSettle();
      expect(pronunciation.openCalls, 1);
      expect(install, findsOneWidget);
      expect(find.text('Offline Mandarin voices'), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(install, findsOneWidget); // Cancelled download.

      pronunciation.failOpen = true;
      await Scrollable.ensureVisible(tester.element(install), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(install);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('system-voice-error')), findsOneWidget);

      pronunciation.failCheck = true;
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('system-voice-check'))),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('system-voice-check')));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not check the Mandarin voice. Try again.'),
        findsOneWidget,
      );

      pronunciation.failCheck = false;
      pronunciation.installed = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.text('Mandarin voice installed for offline speech.'),
        findsOneWidget,
      );
      expect(install, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings installs the offline voice without manual files', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _FakePronunciationService();
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

    final download = find.byKey(const Key('kokoro-voice-download'));
    await tester.scrollUntilVisible(
      download,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(download);
    await tester.pumpAndSettle();

    expect(pronunciation.installCalls, 1);
    final ready = find.byKey(const Key('kokoro-voice-ready'));
    await tester.scrollUntilVisible(
      ready,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(ready, findsOneWidget);
  });

  for (final size in [const Size(400, 800), const Size(1000, 1000)]) {
    testWidgets(
      'desktop settings checks and installs fallback speech at $size',
      (tester) async {
        final pronunciation = _RecordedFakePronunciationService();
        await _pumpRecordedVoiceSettings(
          tester,
          pronunciation,
          surfaceSize: size,
        );
        expect(find.text('Recorded Mandarin audio'), findsOneWidget);
        expect(
          find.textContaining('4379 human-recorded words'),
          findsOneWidget,
        );
        expect(find.text('Offline Mandarin voices'), findsNothing);
        expect(find.byKey(const Key('kokoro-voice-download')), findsNothing);
        expect(find.byKey(const Key('kokoro-voice-picker')), findsNothing);
        expect(find.byKey(const Key('system-voice-install')), findsNothing);
        expect(pronunciation.voiceCheckCalls, 1);
        expect(pronunciation.voiceInstallCalls, 0);
        expect(find.textContaining('has not been confirmed'), findsOneWidget);

        await _revealSettingsControl(
          tester,
          const Key('desktop-voice-install'),
        );
        await tester.tap(find.byKey(const Key('desktop-voice-install')));
        await tester.pumpAndSettle();
        expect(pronunciation.voiceInstallCalls, 1);
        expect(pronunciation.voiceCheckCalls, 2);
        expect(
          find.textContaining('installed and ready offline'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('desktop-voice-install')), findsNothing);
        expect(pronunciation.spoken, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('desktop voice setup reports failures and rechecks on resume', (
    tester,
  ) async {
    final pronunciation = _RecordedFakePronunciationService()..failCheck = true;
    await _pumpRecordedVoiceSettings(tester, pronunciation);
    expect(find.textContaining('Could not check the fallback'), findsOneWidget);
    expect(find.textContaining('installed and ready offline'), findsNothing);
    pronunciation.failCheck = false;
    pronunciation.failInstall = true;
    await tester.tap(find.byKey(const Key('desktop-voice-install')));
    await tester.pumpAndSettle();
    expect(find.text('Administrator approval was cancelled.'), findsOneWidget);
    expect(find.byKey(const Key('desktop-voice-install')), findsOneWidget);
    pronunciation.installed = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('installed and ready offline'), findsOneWidget);
    expect(find.byKey(const Key('desktop-voice-error')), findsNothing);
    expect(find.byKey(const Key('desktop-voice-install')), findsNothing);
    expect(pronunciation.voiceInstallCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop setup confirms availability after installation', (
    tester,
  ) async {
    final pronunciation = _RecordedFakePronunciationService()
      ..readyAfterInstall = false;
    await _pumpRecordedVoiceSettings(tester, pronunciation);
    await tester.tap(find.byKey(const Key('desktop-voice-install')));
    await tester.pumpAndSettle();
    expect(find.textContaining('installed and ready offline'), findsNothing);
    expect(find.textContaining('installer finished, but'), findsOneWidget);
    expect(find.byKey(const Key('desktop-voice-install')), findsOneWidget);
    pronunciation.installed = true;
    await _revealSettingsControl(tester, const Key('desktop-voice-check'));
    await tester.tap(find.byKey(const Key('desktop-voice-check')));
    await tester.pumpAndSettle();
    expect(find.textContaining('installed and ready offline'), findsOneWidget);
    expect(find.byKey(const Key('desktop-voice-error')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop setup waits for installation and handles leaving settings',
    (tester) async {
      final completion = Completer<void>();
      final pronunciation = _RecordedFakePronunciationService()
        ..installationGate = completion.future;
      await _pumpRecordedVoiceSettings(tester, pronunciation);
      await tester.tap(find.byKey(const Key('desktop-voice-install')));
      await tester.pump();
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(SettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final offset = scrollable.position.pixels;
      scrollable.position.jumpTo(0);
      await tester.pump();
      scrollable.position.jumpTo(offset);
      await tester.pump();
      expect(find.text('Installing Mandarin voice…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('desktop-voice-install')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('desktop-voice-check')))
            .onPressed,
        isNull,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(pronunciation.voiceCheckCalls, 1);
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      completion.complete();
      await tester.pumpAndSettle();
      expect(pronunciation.voiceCheckCalls, 1);
      expect(pronunciation.voiceInstallCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings downloads Kokoro and saves a random voice pool', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _ManagedFakePronunciationService();
    final repository = _MemorySettingsRepository();
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
            settingsRepository: repository,
            pronunciationService: pronunciation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kokoro-voice-picker')), findsNothing);
    final download = find.byKey(const Key('kokoro-voice-download'));
    await tester.scrollUntilVisible(
      download,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(download);
    await tester.pumpAndSettle();

    expect(pronunciation.installedEngines, [PronunciationEngine.kokoro]);
    expect(find.byKey(const Key('kokoro-voice-ready')), findsOneWidget);
    expect(find.byKey(const Key('kokoro-voice-picker')), findsOneWidget);
    expect(find.text('All 100 voices (random)'), findsOneWidget);

    final voicePicker = find.byKey(const Key('kokoro-voice-picker'));
    await tester.ensureVisible(voicePicker);
    await tester.tap(voicePicker);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kokoro-voice-dialog')), findsOneWidget);
    expect(find.text('100 of 100 selected'), findsOneWidget);
    await tester.tap(find.byKey(const Key('kokoro-voice-clear-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kokoro-voice-empty-error')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('kokoro-voice-apply')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('kokoro-voice-choice-zf_001')));
    await tester.enterText(
      find.byKey(const Key('kokoro-voice-search')),
      'zm_041',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kokoro-voice-choice-zm_041')));
    await tester.tap(find.byKey(const Key('kokoro-voice-apply')));
    await tester.pumpAndSettle();

    expect(find.text('2 voices (random)'), findsOneWidget);

    expect(pronunciation.configuredEngine, PronunciationEngine.kokoro);
    expect(pronunciation.configuredVoiceIds, ['zf_001', 'zm_041']);

    final save = find.byKey(const Key('settings-save'));
    await tester.scrollUntilVisible(
      save,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.settings.pronunciationEngine, PronunciationEngine.kokoro);
    expect(repository.settings.kokoroVoiceIds, ['zf_001', 'zm_041']);
  });

  testWidgets('settings restores a saved Kokoro voice once installed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _ManagedFakePronunciationService(
      kokoroStatus: const OfflineVoiceStatus.ready(
        engine: PronunciationEngine.kokoro,
      ),
    );
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
            settingsRepository: _MemorySettingsRepository(
              const LearnerSettings(
                pronunciationEngine: PronunciationEngine.kokoro,
                kokoroVoiceIds: ['zm_041'],
              ),
            ),
            pronunciationService: pronunciation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final picker = find.byKey(const Key('kokoro-voice-picker'));
    await tester.scrollUntilVisible(
      picker,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(picker, findsOneWidget);
    expect(find.text('Male 041'), findsOneWidget);
  });

  testWidgets('cancelling the Kokoro voice picker keeps the current pool', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pronunciation = _ManagedFakePronunciationService(
      kokoroStatus: const OfflineVoiceStatus.ready(
        engine: PronunciationEngine.kokoro,
      ),
    );
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
            settingsRepository: _MemorySettingsRepository(
              const LearnerSettings(
                pronunciationEngine: PronunciationEngine.kokoro,
                kokoroVoiceIds: ['zf_001', 'zm_041'],
              ),
            ),
            pronunciationService: pronunciation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final picker = find.byKey(const Key('kokoro-voice-picker'));
    await tester.scrollUntilVisible(
      picker,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('2 voices (random)'), findsOneWidget);
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kokoro-voice-clear-all')));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kokoro-voice-dialog')), findsNothing);
    expect(find.text('2 voices (random)'), findsOneWidget);
    expect(pronunciation.configuredVoiceIds, isEmpty);
  });

  testWidgets('settings preference load error is friendly and retryable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FailOnceSettingsLoadRepository(
      const LearnerSettings(showPinyin: false, soundEnabled: false),
    );

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
            settingsRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-preferences-error')), findsOneWidget);
    expect(find.text('We couldn’t load your preferences'), findsOneWidget);
    expect(find.textContaining('sensitive settings path'), findsNothing);
    expect(repository.loadCalls, 1);

    final retry = find.byKey(const Key('settings-preferences-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
    expect(find.byKey(const Key('settings-preferences-error')), findsNothing);
    expect(find.widgetWithText(SwitchListTile, 'Show pinyin'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Show pinyin'),
          )
          .value,
      isFalse,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-save')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save settings'), findsOneWidget);
    expect(find.text('Save changes'), findsNothing);
    expect(find.text('Save preferences'), findsNothing);
  });

  testWidgets('settings preference save can retry the exact changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FailOnceSettingsSaveRepository(
      const LearnerSettings(
        showPinyin: false,
        soundEnabled: false,
        reminderEnabled: true,
        reminderHour: 7,
        pronunciationEngine: PronunciationEngine.kokoro,
        kokoroVoiceIds: ['zf_021'],
      ),
    );

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
            settingsRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pinyinToggle = find.text('Show pinyin');
    await tester.ensureVisible(pinyinToggle);
    await tester.tap(pinyinToggle);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-save')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(repository.saveAttempts, hasLength(1));
    expect(find.text('Settings saved.'), findsNothing);
    final saveError = find.byKey(const Key('settings-save-error'));
    await tester.scrollUntilVisible(
      saveError,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(saveError, findsOneWidget);

    final retry = find.byKey(const Key('settings-save-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(repository.saveAttempts, hasLength(2));
    final firstAttempt = repository.saveAttempts.first;
    final retryAttempt = repository.saveAttempts.last;
    expect(firstAttempt.showPinyin, isTrue);
    expect(retryAttempt.showPinyin, firstAttempt.showPinyin);
    expect(retryAttempt.soundEnabled, firstAttempt.soundEnabled);
    expect(retryAttempt.reminderEnabled, firstAttempt.reminderEnabled);
    expect(retryAttempt.reminderHour, firstAttempt.reminderHour);
    expect(retryAttempt.pronunciationEngine, firstAttempt.pronunciationEngine);
    expect(retryAttempt.kokoroVoiceIds, firstAttempt.kokoroVoiceIds);
    expect(find.byKey(const Key('settings-save-error')), findsNothing);
    expect(find.text('Settings saved.'), findsOneWidget);
  });
}
