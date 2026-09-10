import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/ai_configuration.dart';

abstract interface class AiConfigurationRepository {
  Future<AiConfiguration?> load();
  Future<void> save(AiConfiguration configuration);
  Future<void> clear();
}

class AiStorageException implements Exception {
  const AiStorageException();

  @override
  String toString() => 'AI settings could not be accessed securely.';
}

/// Personal credentials stay outside SQLite and the app's ordinary settings.
class SecureAiConfigurationRepository implements AiConfigurationRepository {
  const SecureAiConfigurationRepository({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      // Report inaccessible credentials instead of silently deleting them.
      aOptions: AndroidOptions(resetOnError: false),
    ),
  }) : _secureStorage = storage;

  static const storageKey = 'tingshuo.ai.configuration';
  final FlutterSecureStorage _secureStorage;

  // Keep a reset/removal ordered after a save started by a previous screen.
  static Future<void>? _pending;

  Future<T> _use<T>(Future<T> Function() operation) {
    Future<T> run() async {
      try {
        return await operation();
      } catch (_) {
        // Platform errors can contain the data passed to storage.
        throw const AiStorageException();
      }
    }

    final previous = _pending;
    final result = previous == null ? run() : previous.then((_) => run());
    final pending = result.then<void>((_) {}, onError: (Object _) {});
    _pending = pending;
    pending.then((_) {
      if (identical(_pending, pending)) _pending = null;
    });
    return result;
  }

  @override
  Future<AiConfiguration?> load() => _use(() async {
    final value = await _secureStorage.read(key: storageKey);
    return value == null ? null : AiConfiguration.fromJson(jsonDecode(value));
  });

  @override
  Future<void> save(AiConfiguration configuration) {
    final error = configuration.validationError;
    if (error != null) throw ArgumentError(error);
    return _use(
      () => _secureStorage.write(
        key: storageKey,
        value: jsonEncode(configuration.toJson()),
      ),
    );
  }

  @override
  Future<void> clear() => _use(() => _secureStorage.delete(key: storageKey));
}
