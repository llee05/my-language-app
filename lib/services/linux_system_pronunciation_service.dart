import 'dart:io';

import 'desktop_voice_installation.dart';
import 'pronunciation_service.dart';

/// flutter_tts has no Linux implementation. Use the locally installed speech
/// engine directly, passing text through stdin without a shell.
class LinuxSystemPronunciationService
    implements
        PronunciationService,
        PlaybackRatePronunciationService,
        DesktopVoiceInstaller {
  LinuxSystemPronunciationService({
    LinuxSpeechLauncher? launch,
    DesktopVoiceInstaller? voiceInstaller,
  }) : _launch = launch ?? _launchSpeech,
       _voiceInstaller = voiceInstaller ?? LinuxMandarinVoiceInstaller();

  final LinuxSpeechLauncher _launch;
  final DesktopVoiceInstaller _voiceInstaller;
  LinuxSpeechProcess? _process;
  int _requestId = 0;
  bool _disposed = false;

  @override
  Future<bool> isMandarinVoiceInstalled() =>
      _voiceInstaller.isMandarinVoiceInstalled();

  @override
  Future<void> installMandarinVoice() => _voiceInstaller.installMandarinVoice();

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => const Stream.empty();

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus.unavailable(
        'Linux uses its installed eSpeak Mandarin voice.',
      );

  @override
  Future<void> installOfflineVoice() => Future.error(
    UnsupportedError('Install eSpeak NG through your Linux package manager.'),
  );

  @override
  Future<void> speakMandarin(String text) => speakMandarinAtRate(text, rate: 1);

  @override
  Future<void> speakMandarinAtRate(String text, {required double rate}) async {
    if (_disposed || text.trim().isEmpty) return;
    final request = ++_requestId;
    _cancelProcess();
    for (final executable in ['espeak-ng', 'espeak']) {
      if (_disposed || request != _requestId) return;
      LinuxSpeechProcess process;
      try {
        process = await _launch(executable, [
          '-v',
          executable == 'espeak-ng' ? 'cmn' : 'zh',
          '-s',
          (150 * rate.clamp(.5, 1.5)).round().toString(),
          '--stdin',
        ]);
      } on ProcessException catch (error) {
        // Only a missing executable should try the legacy engine. Engine
        // errors must not start a second, overlapping voice.
        if (error.errorCode == 2) continue;
        rethrow;
      }
      if (_disposed || request != _requestId) {
        process.cancel();
        return;
      }
      _process = process;
      try {
        await process.sendText(text);
        final result = await process.exitCode;
        if (!_disposed && request == _requestId && result != 0) {
          throw const MandarinVoiceUnavailableException();
        }
      } catch (_) {
        if (!_disposed && request == _requestId) rethrow;
      } finally {
        if (identical(_process, process)) _process = null;
        process.cancel();
      }
      return;
    }
    if (!_disposed && request == _requestId) {
      throw const MandarinVoiceUnavailableException();
    }
  }

  void _cancelProcess() {
    final process = _process;
    _process = null;
    process?.cancel();
  }

  @override
  Future<void> stop() async {
    _requestId++;
    _cancelProcess();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
  }
}

typedef LinuxSpeechLauncher =
    Future<LinuxSpeechProcess> Function(
      String executable,
      List<String> arguments,
    );

abstract interface class LinuxSpeechProcess {
  Future<void> sendText(String text);
  Future<int> get exitCode;
  void cancel();
}

Future<LinuxSpeechProcess> _launchSpeech(
  String executable,
  List<String> arguments,
) async {
  final process = await Process.start(executable, arguments, runInShell: false);
  // Drain both pipes so diagnostics cannot block speech or process completion.
  process.stdout.drain<void>();
  process.stderr.drain<void>();
  return _NativeSpeechProcess(process);
}

class _NativeSpeechProcess implements LinuxSpeechProcess {
  _NativeSpeechProcess(this._process);
  final Process _process;

  @override
  Future<void> sendText(String text) async {
    _process.stdin.writeln(text);
    await _process.stdin.close();
  }

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  void cancel() => _process.kill();
}
