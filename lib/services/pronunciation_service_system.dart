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
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(.42);
    await _tts.setPitch(1);
    await _tts.speak(text);
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
