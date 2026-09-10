import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/ai_configuration.dart';

import 'ai_test_support.dart';

Future<void> _pump(
  WidgetTester tester,
  MemoryAiConfigurationRepository repository, {
  AiConnectionTest? testConnection,
  Size size = const Size(600, 1100),
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AiSettingsCard(
                repository: repository,
                testConnection: testConnection,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, AiProvider provider) async {
  final field = find.byType(DropdownButtonFormField<AiProvider>);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  final option = find.text(provider.label).last;
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a removed preset opens as custom without losing its saved key', (
    tester,
  ) async {
    final repository = MemoryAiConfigurationRepository(
      AiConfiguration.fromJson({
        'provider': 'deepseek',
        'apiKey': 'saved-key',
        'model': 'saved-model',
        'customEndpoint': '',
      }),
    );
    await _pump(tester, repository);
    final dropdown = tester.widget<DropdownButton<AiProvider>>(
      find.byType(DropdownButton<AiProvider>),
    );
    expect(dropdown.items!.map((item) => item.value), [
      AiProvider.gemini,
      AiProvider.openai,
      AiProvider.anthropic,
      AiProvider.custom,
    ]);
    expect(find.byKey(const Key('ai-provider-custom')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ai-endpoint')))
          .controller!
          .text,
      'https://api.deepseek.com/chat/completions',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ai-api-key')))
          .controller!
          .text,
      isEmpty,
    );
    await _tap(tester, 'ai-save');
    expect(repository.configuration!.apiKey, 'saved-key');
    expect(repository.configuration!.model, 'saved-model');
    expect(
      repository.configuration!.endpoint,
      'https://api.deepseek.com/chat/completions',
    );
  });

  testWidgets(
    'saving a personal key is local, masked, and restored without displaying it',
    (tester) async {
      final repository = MemoryAiConfigurationRepository();
      var tests = 0;
      await _pump(tester, repository, testConnection: (_) async => tests++);
      final key = find.byKey(const Key('ai-api-key'));
      expect(tester.widget<TextField>(key).obscureText, isTrue);
      await tester.enterText(key, '  my-test-key  ');
      await _tap(tester, 'ai-save');
      expect(repository.configuration?.apiKey, 'my-test-key');
      expect(repository.configuration?.provider, AiProvider.gemini);
      expect(tests, 0, reason: 'Saving does not make a paid API request.');
      expect(tester.widget<TextField>(key).controller!.text, isEmpty);
      expect(find.textContaining('AI settings saved.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, repository);
      expect(
        find.textContaining('A Google Gemini key is saved securely'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(key).controller!.text, isEmpty);
      await tester.enterText(
        find.byKey(const Key('ai-model')),
        'gemini-other-model',
      );
      await _tap(tester, 'ai-save');
      expect(repository.configuration?.apiKey, 'my-test-key');
      expect(repository.configuration?.model, 'gemini-other-model');
    },
  );

  testWidgets(
    'switching providers requires a new key and sends test only on explicit action',
    (tester) async {
      final repository = MemoryAiConfigurationRepository(testAiConfiguration);
      final tested = <AiConfiguration>[];
      await _pump(
        tester,
        repository,
        testConnection: (configuration) async => tested.add(configuration),
      );
      await _select(tester, AiProvider.openai);
      await _tap(tester, 'ai-test');
      expect(tested, isEmpty);
      expect(find.text('Enter an API key for this provider.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('ai-api-key')),
        'openai-test-key',
      );
      await _tap(tester, 'ai-test');
      expect(tested.single.provider, AiProvider.openai);
      expect(tested.single.apiKey, 'openai-test-key');
      expect(repository.configuration?.provider, AiProvider.gemini);
      await _tap(tester, 'ai-save');
      expect(repository.configuration?.provider, AiProvider.openai);
      expect(repository.configuration?.apiKey, 'openai-test-key');
    },
  );

  testWidgets(
    'custom endpoints cannot silently reuse a key for a previous destination',
    (tester) async {
      final repository = MemoryAiConfigurationRepository(
        const AiConfiguration(
          provider: AiProvider.custom,
          apiKey: 'saved-key',
          model: 'model/example',
          customEndpoint: 'https://one.example/v1/chat/completions',
        ),
      );
      final tested = <AiConfiguration>[];
      await _pump(
        tester,
        repository,
        testConnection: (configuration) async => tested.add(configuration),
      );
      await tester.enterText(
        find.byKey(const Key('ai-endpoint')),
        'https://two.example/chat/completions',
      );
      await _tap(tester, 'ai-test');
      expect(tested, isEmpty);
      expect(find.text('Enter an API key for this provider.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ai-api-key')), 'new-key');
      await _tap(tester, 'ai-test');
      expect(tested.single.endpoint, 'https://two.example/chat/completions');
      expect(tested.single.apiKey, 'new-key');
    },
  );

  testWidgets(
    'storage and connection failures keep the draft and hide sensitive errors',
    (tester) async {
      final repository = MemoryAiConfigurationRepository()
        ..saveError = StateError('secret key in platform error');
      await _pump(
        tester,
        repository,
        testConnection: (_) async => throw StateError('secret key in request'),
      );
      await tester.enterText(find.byKey(const Key('ai-api-key')), 'draft-key');
      await _tap(tester, 'ai-save');
      expect(
        find.textContaining('could not be saved securely'),
        findsOneWidget,
      );
      expect(find.textContaining('secret key'), findsNothing);
      expect(repository.configuration, isNull);
      await _tap(tester, 'ai-test');
      expect(find.textContaining('connection test failed'), findsOneWidget);
      expect(find.textContaining('secret key'), findsNothing);
      repository.saveError = null;
      await _tap(tester, 'ai-save');
      expect(repository.configuration?.apiKey, 'draft-key');
    },
  );

  testWidgets('removal is awaited and can recover after failure', (
    tester,
  ) async {
    final repository = MemoryAiConfigurationRepository(testAiConfiguration)
      ..clearError = StateError('private key');
    await _pump(tester, repository);
    await _tap(tester, 'ai-remove');
    expect(repository.configuration, isNotNull);
    expect(find.textContaining('could not be removed'), findsOneWidget);
    repository.clearError = null;
    await _tap(tester, 'ai-remove');
    expect(repository.configuration, isNull);
    expect(find.text('No personal key saved.'), findsOneWidget);
    expect(find.byKey(const Key('ai-remove')), findsNothing);
  });

  testWidgets(
    'a failed load can retry without overwriting stored credentials',
    (tester) async {
      final repository = MemoryAiConfigurationRepository(testAiConfiguration)
        ..loadError = StateError('private key');
      await _pump(tester, repository);
      expect(find.byKey(const Key('ai-save')), findsNothing);
      expect(find.textContaining('private key'), findsNothing);
      repository.loadError = null;
      await _tap(tester, 'ai-settings-retry');
      expect(
        find.textContaining('A Google Gemini key is saved securely'),
        findsOneWidget,
      );
      expect(repository.saves, isEmpty);
    },
  );

  testWidgets('unreadable saved settings can be removed for a fresh start', (
    tester,
  ) async {
    final repository = MemoryAiConfigurationRepository(testAiConfiguration)
      ..loadError = const FormatException('corrupt saved configuration');
    await _pump(tester, repository);
    await _tap(tester, 'ai-remove');
    expect(repository.configuration, isNull);
    expect(find.text('No personal key saved.'), findsOneWidget);
    expect(find.byKey(const Key('ai-save')), findsOneWidget);
  });

  testWidgets('pending saves disable edits and do not announce success early', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = MemoryAiConfigurationRepository()
      ..saveGate = gate.future;
    await _pump(tester, repository);
    await tester.enterText(find.byKey(const Key('ai-api-key')), 'pending-key');
    await tester.tap(find.byKey(const Key('ai-save')));
    await tester.pump();
    expect(find.textContaining('AI settings saved.'), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(const Key('ai-api-key'))).enabled,
      isFalse,
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('ai-test'))).onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(repository.configuration?.apiKey, 'pending-key');
  });

  testWidgets(
    'a completed save after navigation does not update a disposed widget',
    (tester) async {
      final gate = Completer<void>();
      final repository = MemoryAiConfigurationRepository()
        ..saveGate = gate.future;
      await _pump(tester, repository);
      await tester.enterText(
        find.byKey(const Key('ai-api-key')),
        'pending-key',
      );
      await tester.tap(find.byKey(const Key('ai-save')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(repository.configuration?.apiKey, 'pending-key');
    },
  );

  testWidgets(
    'provider fields and actions fit a narrow screen with large text',
    (tester) async {
      await _pump(
        tester,
        MemoryAiConfigurationRepository(),
        size: const Size(320, 750),
        scale: 1.6,
      );
      await _select(tester, AiProvider.custom);
      await tester.enterText(
        find.byKey(const Key('ai-endpoint')),
        'https://custom.example/v1/chat/completions',
      );
      await tester.enterText(find.byKey(const Key('ai-api-key')), 'my-key');
      await tester.enterText(
        find.byKey(const Key('ai-model')),
        'provider/model',
      );
      await _tap(tester, 'ai-save');
      expect(tester.takeException(), isNull);
      expect(find.textContaining('AI settings saved.'), findsOneWidget);
    },
  );
}
