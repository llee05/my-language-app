import 'package:flutter_tts/flutter_tts.dart';

import 'desktop_voice_installation.dart';
import 'pronunciation_service.dart';
import 'pronunciation_service_system.dart';

class WindowsSystemPronunciationService extends SystemPronunciationService
    implements DesktopVoiceInstaller {
  WindowsSystemPronunciationService({
    FlutterTts? tts,
    WindowsMandarinVoiceInstallation? installation,
  }) : this._(
         tts ?? FlutterTts(),
         installation ?? WindowsMandarinVoiceInstallation(),
       );

  WindowsSystemPronunciationService._(this._voiceTts, this._installation)
    : super(tts: _voiceTts);

  final FlutterTts _voiceTts;
  final WindowsMandarinVoiceInstallation _installation;

  @override
  Future<bool> isMandarinVoiceInstalled() async {
    // Query the voices exposed by the exact speech plugin used for playback.
    // A downloaded OS capability alone does not prove the app can use it.
    final voices = await _voiceTts.getVoices;
    if (voices is! List ||
        voices.any((voice) => voice is! Map || voice['locale'] is! String)) {
      throw StateError('Windows did not report its speech voices.');
    }
    return voices.any(
      (voice) =>
          (voice['locale'] as String).replaceAll('_', '-').toLowerCase() ==
          'zh-cn',
    );
  }

  @override
  Future<void> installMandarinVoice() async {
    if (await isMandarinVoiceInstalled()) return;
    await _installation.install();
  }
}
