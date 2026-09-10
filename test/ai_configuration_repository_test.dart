import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/models/ai_configuration.dart';
import 'package:mylanguageapp/repositories/ai_configuration_repository.dart';

import 'ai_test_support.dart';

class _Storage extends Fake implements FlutterSecureStorage {
  final values = <String, String>{};
  Future<void>? writeGate;
  bool fail = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (fail) throw StateError('secret in storage error');
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await writeGate;
    if (fail) throw StateError('secret in storage error');
    values[key] = value!;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (fail) throw StateError('secret in storage error');
    values.remove(key);
  }
}

void main() {
  for (final legacy in {
    'openrouter': 'https://openrouter.ai/api/v1/chat/completions',
    'deepseek': 'https://api.deepseek.com/chat/completions',
    'groq': 'https://api.groq.com/openai/v1/chat/completions',
    'mistral': 'https://api.mistral.ai/v1/chat/completions',
    'xai': 'https://api.x.ai/v1/chat/completions',
  }.entries) {
    test(
      'saved ${legacy.key} credentials remain usable as a custom provider',
      () async {
        final storage = _Storage();
        storage.values[SecureAiConfigurationRepository
            .storageKey] = jsonEncode({
          'provider': legacy.key,
          'apiKey': 'saved-personal-key',
          'model': 'saved-model',
          // Old presets ignored this field; it must never redirect a saved key.
          'customEndpoint': 'https://untrusted.example/chat/completions',
        });
        final repository = SecureAiConfigurationRepository(storage: storage);
        final loaded = (await repository.load())!;
        expect(loaded.provider, AiProvider.custom);
        expect(loaded.endpoint, legacy.value);
        expect(loaded.apiKey, 'saved-personal-key');
        expect(loaded.model, 'saved-model');

        await repository.save(loaded);
        final restored = (await repository.load())!;
        expect(restored.toJson(), loaded.toJson());
        expect(
          jsonDecode(
            storage.values[SecureAiConfigurationRepository.storageKey]!,
          )['provider'],
          'custom',
        );
      },
    );
  }

  test(
    'credentials round-trip through secure storage and removal deletes only this app record',
    () async {
      final storage = _Storage()..values['unrelated'] = 'keep';
      final repository = SecureAiConfigurationRepository(storage: storage);
      expect(await repository.load(), isNull);
      await repository.save(testAiConfiguration);
      final reconstructed = SecureAiConfigurationRepository(storage: storage);
      final loaded = await reconstructed.load();
      expect(loaded?.apiKey, testAiConfiguration.apiKey);
      expect(loaded?.model, testAiConfiguration.model);
      expect(loaded?.provider, AiProvider.gemini);
      await repository.clear();
      expect(await reconstructed.load(), isNull);
      expect(storage.values, {'unrelated': 'keep'});
    },
  );

  test(
    'clear waits for an earlier save, preventing a deleted key from reappearing',
    () async {
      final gate = Completer<void>();
      final storage = _Storage()..writeGate = gate.future;
      final repository = SecureAiConfigurationRepository(storage: storage);
      final save = repository.save(testAiConfiguration);
      final clear = repository.clear();
      gate.complete();
      await Future.wait([save, clear]);
      expect(await repository.load(), isNull);
    },
  );

  test(
    'storage failures are sanitized and do not poison later operations',
    () async {
      final storage = _Storage()..fail = true;
      final repository = SecureAiConfigurationRepository(storage: storage);
      for (final operation in [
        repository.load,
        () => repository.save(testAiConfiguration),
        repository.clear,
      ]) {
        await expectLater(
          operation(),
          throwsA(
            isA<AiStorageException>().having(
              (e) => e.toString(),
              'message',
              isNot(contains('secret')),
            ),
          ),
        );
      }
      storage.fail = false;
      await repository.save(testAiConfiguration);
      expect((await repository.load())?.apiKey, testAiConfiguration.apiKey);
    },
  );

  test(
    'corrupt saved configuration fails closed and can still be removed',
    () async {
      final storage = _Storage();
      final repository = SecureAiConfigurationRepository(storage: storage);
      for (final raw in [
        'secret invalid JSON',
        jsonEncode({'apiKey': 'secret'}),
        jsonEncode({...testAiConfiguration.toJson(), 'provider': 'unknown'}),
        jsonEncode({...testAiConfiguration.toJson(), 'apiKey': 42}),
      ]) {
        storage.values[SecureAiConfigurationRepository.storageKey] = raw;
        await expectLater(
          repository.load(),
          throwsA(isA<AiStorageException>()),
        );
        await repository.clear();
        expect(await repository.load(), isNull);
      }
    },
  );
}
