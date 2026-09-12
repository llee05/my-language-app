import 'package:flutter_tts/flutter_tts.dart';

import 'pronunciation_service.dart';

PronunciationService createPlatformPronunciationService() =>
    SystemPronunciationService();

class SystemPronunciationService implements PronunciationService {
  SystemPronunciationService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _disposed = false;

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => const Stream.empty();

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus.unavailable(
        'Offline voice downloads are available in the installed app.',
      );

  @override
  Future<void> installOfflineVoice() => Future.error(
    UnsupportedError('Offline voice downloads are unavailable here.'),
  );

  @override
  Future<void> speakMandarin(String text) async {
    if (_disposed || text.trim().isEmpty) return;
    await _tts.stop();
    final languageResult = await _tts.setLanguage('zh-CN');
    if (_isMandarinVoiceMissing(languageResult)) {
      throw const MandarinVoiceUnavailableException();
    }
    await _tts.setSpeechRate(.42);
    await _tts.setPitch(1);
    await _tts.speak(text);
  }

  /// The plugin reports `1` when a platform voice is available and `0` when
  /// it is missing; older plugin versions reported `2` for missing voice
  /// data, and iOS may answer with a boolean. An unreported result is treated
  /// as available so playback is never blocked by a missing status.
  bool _isMandarinVoiceMissing(Object? result) {
    if (result is num) return result != 1;
    if (result is bool) return !result;
    if (result is String) {
      final code = num.tryParse(result);
      return code != null && code != 1;
    }
    return false;
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    await _tts.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    try {
      await _tts.stop();
    } catch (_) {
      // Platform channels may already be gone during app/test teardown.
    }
    _disposed = true;
  }
}
