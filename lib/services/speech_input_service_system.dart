import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_input_service.dart';

class SystemSpeechInputService implements SpeechInputService {
  SystemSpeechInputService({SpeechToText? speechToText})
    : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;
  bool _initialized = false;
  Future<bool>? _initialization;
  SpeechInputResult? _onResult;
  SpeechInputError? _onError;

  @override
  Future<void> startListening({
    required SpeechInputResult onResult,
    SpeechInputError? onError,
    String? preferredLocaleId,
  }) async {
    _onResult = onResult;
    _onError = onError;

    final available = await _ensureInitialized();
    if (!available) {
      throw const SpeechInputException(
        'Speech input is unavailable. Check microphone and speech recognition permissions.',
      );
    }

    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }
    final localeId = await _resolveLocale(preferredLocaleId);
    await _speechToText.listen(
      onResult: _handleResult,
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
        localeId: localeId,
      ),
    );
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    final pending = _initialization;
    if (pending != null) return pending;

    final initialization = _initialize();
    _initialization = initialization;
    try {
      _initialized = await initialization;
      return _initialized;
    } finally {
      _initialization = null;
    }
  }

  Future<bool> _initialize() async {
    try {
      return await _speechToText.initialize(
        onError: _handleError,
        options: [SpeechToText.androidNoBluetooth],
      );
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveLocale(String? preferredLocaleId) async {
    if (preferredLocaleId == null || preferredLocaleId.trim().isEmpty) {
      return null;
    }
    try {
      final preferred = _normalizeLocale(preferredLocaleId);
      final locales = await _speechToText.locales();
      for (final locale in locales) {
        if (_normalizeLocale(locale.localeId) == preferred) {
          return locale.localeId;
        }
      }
      final language = preferred.split('_').first;
      for (final locale in locales) {
        if (_normalizeLocale(locale.localeId).split('_').first == language) {
          return locale.localeId;
        }
      }
    } catch (_) {
      // The system default remains a useful fallback when locale discovery is
      // unavailable on a platform.
    }
    return null;
  }

  String _normalizeLocale(String localeId) =>
      localeId.trim().toLowerCase().replaceAll('-', '_');

  void _handleResult(SpeechRecognitionResult result) {
    _onResult?.call(result.recognizedWords);
  }

  void _handleError(SpeechRecognitionError error) {
    _onError?.call(_friendlyError(error.errorMsg));
  }

  String _friendlyError(String error) {
    if (error.contains('permission') || error.contains('disabled')) {
      return 'Microphone or speech recognition permission was denied. Enable it in system settings.';
    }
    if (error.contains('language_not_supported') ||
        error.contains('language_unavailable')) {
      return 'That speech recognition language is not installed on this device.';
    }
    if (error.contains('network')) {
      return 'Speech recognition could not connect. Check your connection or install offline speech recognition.';
    }
    if (error.contains('no_match') || error.contains('speech_timeout')) {
      return 'No speech was recognised. Hold the microphone and try again.';
    }
    return 'Speech input stopped unexpectedly. Please try again.';
  }

  @override
  Future<void> stopListening() async {
    if (_initialized) {
      await _speechToText.stop();
    }
  }

  @override
  Future<void> cancelListening() async {
    if (_initialized) {
      await _speechToText.cancel();
    }
  }

  @override
  Future<void> dispose() => cancelListening();
}
