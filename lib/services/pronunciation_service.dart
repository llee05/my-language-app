import 'dart:async';

enum OfflineVoiceState { unavailable, notInstalled, downloading, ready, failed }

class OfflineVoiceStatus {
  const OfflineVoiceStatus({
    required this.state,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.currentFile,
    this.message,
  });

  const OfflineVoiceStatus.unavailable([String? message])
    : this(state: OfflineVoiceState.unavailable, message: message);

  const OfflineVoiceStatus.notInstalled()
    : this(state: OfflineVoiceState.notInstalled);

  const OfflineVoiceStatus.ready() : this(state: OfflineVoiceState.ready);

  final OfflineVoiceState state;
  final int downloadedBytes;
  final int totalBytes;
  final String? currentFile;
  final String? message;

  double? get progress {
    if (state != OfflineVoiceState.downloading || totalBytes <= 0) return null;
    return (downloadedBytes / totalBytes).clamp(0, 1);
  }
}

class OfflineVoiceNotInstalledException implements Exception {
  const OfflineVoiceNotInstalledException();

  @override
  String toString() => 'The offline Mandarin voice is not installed.';
}

abstract interface class PronunciationService {
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates;

  Future<OfflineVoiceStatus> checkOfflineVoice();

  Future<void> installOfflineVoice();

  Future<void> speakMandarin(String text);

  Future<void> stop();

  Future<void> dispose();
}

typedef PronunciationServiceFactory = PronunciationService Function();
