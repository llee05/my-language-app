import 'pronunciation_service.dart';

class FallbackPronunciationService implements PronunciationService {
  FallbackPronunciationService(this._primary, this._fallback);

  final PronunciationService _primary;
  final PronunciationService _fallback;
  int _requestId = 0;
  bool _disposed = false;

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates =>
      _primary.offlineVoiceUpdates;

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() =>
      _primary.checkOfflineVoice();

  @override
  Future<void> installOfflineVoice() => _primary.installOfflineVoice();

  @override
  Future<void> speakMandarin(String text) async {
    if (_disposed || text.trim().isEmpty) return;
    final requestId = ++_requestId;
    await _stopChildren();
    if (_disposed || requestId != _requestId) return;
    try {
      await _primary.speakMandarin(text);
    } catch (_) {
      if (_disposed || requestId != _requestId) return;
      try {
        await _primary.stop();
      } catch (_) {
        // A failed cleanup must not prevent the working fallback from speaking.
      }
      if (_disposed || requestId != _requestId) return;
      await _fallback.speakMandarin(text);
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _requestId++;
    await _stopChildren();
  }

  Future<void> _stopChildren() async {
    try {
      await _primary.stop();
    } catch (_) {
      // Stopping is best-effort; continue so the other engine is also stopped.
    }
    try {
      await _fallback.stop();
    } catch (_) {
      // Speaking will still surface an error if neither engine can play audio.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _requestId++;
    for (final service in [_primary, _fallback]) {
      try {
        await service.dispose();
      } catch (_) {
        // Cleanup is best-effort and both engines must get a chance to close.
      }
    }
  }
}
