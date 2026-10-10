part of '../widget_test.dart';

void _registerSettingsResetWidgetTests() {
  testWidgets('settings edits profile and can reset onboarding', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    LearnerProfile? updatedProfile;
    var resetOnboarding = false;
    final settingsRepository = _MemorySettingsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            appThemeId: AppThemeId.classic,
            onThemeChanged: (_) {},
            profile: testProfile,
            onProfileChanged: (profile) async => updatedProfile = profile,
            onResetOnboarding: () async => resetOnboarding = true,
            onResetAllData: () async {},
            developmentRepository: const SqliteDevelopmentRepository(),
            settingsRepository: settingsRepository,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Lin');
    await tester.tap(find.text('HSK 4'));
    await tester.tap(find.text('20 words'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-save')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pump();

    expect(updatedProfile?.name, 'Lin');
    expect(updatedProfile?.hskLevel, 4);
    expect(updatedProfile?.dailyWordTarget, 20);

    await tester.scrollUntilVisible(
      find.text('Reset onboarding only'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset onboarding only'));
    await tester.pumpAndSettle();
    expect(find.text('Reset learner setup?'), findsOneWidget);
    await tester.tap(find.text('Reset setup'));
    await tester.pumpAndSettle();
    expect(resetOnboarding, isTrue);
  });

  testWidgets(
    'settings shows one save action with progress and success feedback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final saveGate = Completer<void>();
      addTearDown(() {
        if (!saveGate.isCompleted) saveGate.complete();
      });

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
              settingsRepository: _GatedSettingsRepository(saveGate),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-save')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('settings-save')));
      await tester.pump();

      expect(find.text('Saving…'), findsOneWidget);
      expect(find.byKey(const Key('settings-save')), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
      expect(find.text('Save preferences'), findsNothing);
      expect(find.text('Settings saved.'), findsNothing);

      saveGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Saving…'), findsNothing);
      expect(find.text('Save settings'), findsOneWidget);
      expect(find.text('Settings saved.'), findsOneWidget);
    },
  );

  testWidgets('settings reset-all cancellation is inert', (tester) async {
    final developmentRepository = _MemoryDevelopmentRepository();
    await _pumpResetSettings(tester, developmentRepository);

    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));

    expect(find.text('Reset your account?'), findsOneWidget);
    expect(developmentRepository.resetAllDataCalls, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 0);
    expect(find.text('Reset your account?'), findsNothing);
  });

  testWidgets('settings account reset is outside developer tools', (
    tester,
  ) async {
    await _pumpResetSettings(tester, _MemoryDevelopmentRepository());
    final reset = find.byKey(const Key('settings-reset-all'));
    await tester.scrollUntilVisible(
      reset,
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('settings-account-reset')),
        matching: reset,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Export a backup above'), findsOneWidget);
  });

  testWidgets('settings reset-all needs both confirmations and exact text', (
    tester,
  ) async {
    final developmentRepository = _MemoryDevelopmentRepository();
    await _pumpResetSettings(tester, developmentRepository);

    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));

    expect(find.text('Reset your account?'), findsOneWidget);
    expect(
      find.textContaining('study progress, review history'),
      findsOneWidget,
    );
    expect(find.textContaining('including API keys'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(developmentRepository.resetAllDataCalls, 0);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm account reset'), findsOneWidget);
    expect(developmentRepository.resetAllDataCalls, 0);
    final confirm = find.byKey(const Key('account-reset-confirm'));
    final input = find.byKey(const Key('account-reset-confirmation-input'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    for (final text in ['reset', 'RESE', ' RESET ', 'RESET', '']) {
      await tester.enterText(input, text);
      await tester.pump();
      if (text == 'RESET') {
        expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      } else {
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      }
      expect(developmentRepository.resetAllDataCalls, 0);
    }

    await tester.enterText(input, 'RESET');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 1);
    expect(find.text('Confirm account reset'), findsNothing);
  });

  testWidgets(
    'final account reset cancellation clears confirmation on reopen',
    (tester) async {
      final development = _MemoryDevelopmentRepository();
      await _pumpResetSettings(tester, development);
      await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('account-reset-confirmation-input')),
        'RESET',
      );
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(development.resetAllDataCalls, 0);

      await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('account-reset-confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(development.resetAllDataCalls, 0);
      expect(find.text('Confirm account reset'), findsNothing);
    },
  );

  testWidgets('account reset confirmations fit a narrow screen with keyboard', (
    tester,
  ) async {
    final development = _MemoryDevelopmentRepository();
    await _pumpResetSettings(
      tester,
      development,
      surfaceSize: const Size(390, 700),
    );
    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const Key('account-reset-confirmation-input')),
      'RESET',
    );
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(development.resetAllDataCalls, 0);
  });

  testWidgets('settings reset-all failure retries directly and safely', (
    tester,
  ) async {
    var failNextReset = true;
    final developmentRepository = _MemoryDevelopmentRepository(
      onReset: () async {
        if (failNextReset) {
          failNextReset = false;
          throw StateError('sensitive reset path /private/local_app.db');
        }
      },
    );
    await _pumpResetSettings(tester, developmentRepository);

    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
    await _confirmAccountReset(tester);
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 1);
    expect(find.text('We couldn’t reset your local data.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('sensitive reset path'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 2);
    expect(find.text('Reset your account?'), findsNothing);
    expect(find.text('We couldn’t reset your local data.'), findsNothing);
  });

  testWidgets(
    'settings onboarding reset failure retries without reconfirming',
    (tester) async {
      var resetCalls = 0;
      await _pumpResetSettings(
        tester,
        _MemoryDevelopmentRepository(),
        onResetOnboarding: () async {
          resetCalls++;
          if (resetCalls == 1) {
            throw StateError('sensitive learner path /private/learner.db');
          }
        },
      );

      await _openSettingsResetDialog(
        tester,
        const Key('settings-reset-onboarding'),
      );
      await tester.tap(find.text('Reset setup'));
      await tester.pumpAndSettle();

      expect(resetCalls, 1);
      expect(find.text('We couldn’t reset learner setup.'), findsOneWidget);
      expect(find.textContaining('sensitive learner path'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(resetCalls, 2);
      expect(find.text('Reset learner setup?'), findsNothing);
      expect(find.text('We couldn’t reset learner setup.'), findsNothing);
    },
  );

  testWidgets(
    'settings disables both reset actions while reset-all is pending',
    (tester) async {
      final resetGate = Completer<void>();
      final developmentRepository = _MemoryDevelopmentRepository(
        onReset: () => resetGate.future,
      );
      await _pumpResetSettings(tester, developmentRepository);

      await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
      await _confirmAccountReset(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(developmentRepository.resetAllDataCalls, 1);
      expect(find.text('Resetting account…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('settings-save')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('settings-export-backup')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('settings-import-backup')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('settings-reset-onboarding')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('settings-reset-all')))
            .onPressed,
        isNull,
      );

      resetGate.complete();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('settings-reset-onboarding')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('settings-reset-all')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('account reset waits for a pending profile save', (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final development = _MemoryDevelopmentRepository();
    await _pumpResetSettings(
      tester,
      development,
      onProfileChanged: (_) => gate.future,
    );
    await _revealSettingsControl(tester, const Key('settings-reset-all'));
    final reset = find.byKey(const Key('settings-reset-all'));
    final resetAction = tester.widget<OutlinedButton>(reset).onPressed!;
    await _revealSettingsControl(tester, const Key('settings-save'));
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pump();

    expect(tester.widget<OutlinedButton>(reset).onPressed, isNull);
    resetAction();
    await tester.pump();
    expect(find.text('Reset your account?'), findsNothing);
    expect(development.resetAllDataCalls, 0);

    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(reset).onPressed, isNotNull);
  });

  testWidgets('account reset waits for an immediate theme save', (
    tester,
  ) async {
    final settings = _PendingSettingsRepository();
    addTearDown(() {
      if (!settings.saveGate.isCompleted) settings.saveGate.complete();
    });
    final development = _MemoryDevelopmentRepository();
    await _pumpResetSettings(tester, development, settingsRepository: settings);
    await _revealSettingsControl(tester, const Key('theme-choice-ocean'));
    await tester.tap(find.byKey(const Key('theme-choice-ocean')));
    await tester.pumpAndSettle();
    expect(settings.saveStarted, isTrue);
    await _revealSettingsControl(tester, const Key('settings-reset-all'));
    final reset = find.byKey(const Key('settings-reset-all'));
    expect(tester.widget<OutlinedButton>(reset).onPressed, isNull);
    expect(development.resetAllDataCalls, 0);

    settings.saveGate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(reset).onPressed, isNotNull);
  });

  testWidgets('reset-all returns the app root to learner setup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final developmentRepository = _MemoryDevelopmentRepository();
    final aiRepository = MemoryAiConfigurationRepository(testAiConfiguration);

    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          lessons: _MemoryLessonRepository(),
          development: developmentRepository,
          aiConfiguration: aiRepository,
          settings: _MemorySettingsRepository(),
          progress: _MemoryProgressRepository(hasActiveSession: false),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      find.text('Manage your learning preferences and local data.'),
      findsOneWidget,
    );
    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
    await _confirmAccountReset(tester);
    await tester.pumpAndSettle();

    expect(developmentRepository.resetAllDataCalls, 1);
    expect(aiRepository.clearCalls, 1);
    expect(aiRepository.configuration, isNull);
    expect(find.text('Build your learning path'), findsOneWidget);
    expect(find.text('你好，Mei'), findsNothing);
  });

  testWidgets('reset-all waits for secure key removal and retries failures', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final development = _MemoryDevelopmentRepository();
    final aiRepository = MemoryAiConfigurationRepository(testAiConfiguration)
      ..clearError = StateError('secret key in platform error');
    await tester.pumpWidget(
      HanziPathApp(
        initialProfile: testProfile,
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          lessons: _MemoryLessonRepository(),
          development: development,
          aiConfiguration: aiRepository,
          settings: _MemorySettingsRepository(),
          progress: _MemoryProgressRepository(hasActiveSession: false),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await _openSettingsResetDialog(tester, const Key('settings-reset-all'));
    await _confirmAccountReset(tester);
    await tester.pumpAndSettle();
    expect(development.resetAllDataCalls, 0);
    expect(aiRepository.configuration, testAiConfiguration);
    expect(find.text('We couldn’t reset your local data.'), findsOneWidget);
    expect(find.textContaining('secret key'), findsNothing);

    aiRepository.clearError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(aiRepository.configuration, isNull);
    expect(development.resetAllDataCalls, 1);
    expect(find.text('Build your learning path'), findsOneWidget);
  });

  testWidgets('onboarding reset returns the app root to learner setup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final learnerRepository = _MemoryLearnerRepository(testProfile);
    final aiRepository = MemoryAiConfigurationRepository(testAiConfiguration);

    await tester.pumpWidget(
      HanziPathApp(
        dependencies: AppDependencies(
          vocabulary: const _TestVocabulary(),
          learners: learnerRepository,
          aiConfiguration: aiRepository,
          lessons: _MemoryLessonRepository(),
          development: _MemoryDevelopmentRepository(),
          settings: _MemorySettingsRepository(),
          progress: _MemoryProgressRepository(hasActiveSession: false),
          dailyReviews: _MemoryDailyReviewSessionRepository(null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      find.text('Manage your learning preferences and local data.'),
      findsOneWidget,
    );
    await _openSettingsResetDialog(
      tester,
      const Key('settings-reset-onboarding'),
    );
    await tester.tap(find.text('Reset setup'));
    await tester.pumpAndSettle();

    expect(learnerRepository.resetOnboardingCalls, 1);
    expect(aiRepository.clearCalls, 0);
    expect(aiRepository.configuration, testAiConfiguration);
    expect(find.text('Build your learning path'), findsOneWidget);
    expect(find.text('你好，Mei'), findsNothing);
  });
}
