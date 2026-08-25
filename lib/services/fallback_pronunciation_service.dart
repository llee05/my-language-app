import '../models/learning_progress.dart';
import 'pronunciation_service.dart';

class FallbackPronunciationService
    implements PronunciationService, OfflinePronunciationManager {
  FallbackPronunciationService(this._primary, this._fallback);

  final PronunciationService _primary;
  final PronunciationService _fallback;
  int _requestId = 0;
  bool _disposed = false;

  OfflinePronunciationManager get _offlineManager {
    final primary = _primary;
    if (primary is OfflinePronunciationManager) {
      return primary as OfflinePronunciationManager;
    }
    throw UnsupportedError(
      'This pronunciation service does not manage offline voice packs.',
    );
  }

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates =>
      _primary.offlineVoiceUpdates;

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() =>
      _primary.checkOfflineVoice();

  @override
  Future<void> installOfflineVoice() => _primary.installOfflineVoice();

  @override
  Stream<OfflineVoiceStatus> get voicePackUpdates {
    final primary = _primary;
    return primary is OfflinePronunciationManager
        ? (primary as OfflinePronunciationManager).voicePackUpdates
        : const Stream.empty();
  }

  @override
  Future<OfflineVoiceStatus> checkVoicePack(PronunciationEngine engine) =>
      _offlineManager.checkVoicePack(engine);

  @override
  Future<void> installVoicePack(PronunciationEngine engine) =>
      _offlineManager.installVoicePack(engine);

  @override
  List<PronunciationVoice> voicesFor(PronunciationEngine engine) =>
      _offlineManager.voicesFor(engine);

  @override
  Future<void> configurePronunciation({
    required PronunciationEngine engine,
    String? voiceId,
  }) =>
      _offlineManager.configurePronunciation(engine: engine, voiceId: voiceId);

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
