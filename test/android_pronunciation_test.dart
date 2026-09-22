import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mylanguageapp/services/fallback_pronunciation_service.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';
import 'package:mylanguageapp/services/pronunciation_service_native.dart';
import 'package:mylanguageapp/services/pronunciation_service_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android pronunciation', () {
    test('always uses the system Mandarin voice without Kokoro', () async {
      final service = createAndroidAwarePronunciationService(isAndroid: true);

      expect(service, isA<SystemPronunciationService>());
      expect(service, isA<SystemVoiceInstaller>());
      expect(service, isNot(isA<OfflinePronunciationManager>()));
      await service.dispose();
    });

    test(
      'checks installed Mandarin data and targets the current engine',
      () async {
        final tts = _VoiceTts();
        final service = AndroidSystemPronunciationService(tts: tts);
        const channel = MethodChannel('tingshuo/system_voice');
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });
        addTearDown(service.dispose);

        expect(await service.isMandarinVoiceInstalled(), isFalse);
        await service.openMandarinVoiceInstaller();
        expect(calls.single.method, 'installVoiceData');
        expect(calls.single.arguments, {'engine': 'example.tts'});
        expect(await service.isMandarinVoiceInstalled(), isFalse);
        tts.installed = true;
        expect(await service.isMandarinVoiceInstalled(), isTrue);
        expect(tts.languages, everyElement('zh-CN'));
      },
    );

    test('propagates installer failures and rejects unknown status', () async {
      final tts = _VoiceTts()..installed = null;
      final service = AndroidSystemPronunciationService(tts: tts);
      const channel = MethodChannel('tingshuo/system_voice');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'voice_installer_unavailable');
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      addTearDown(service.dispose);
      await expectLater(service.isMandarinVoiceInstalled(), throwsStateError);
      await expectLater(
        service.openMandarinVoiceInstaller(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('keeps the Kokoro chain with system fallback elsewhere', () {
      final service = createAndroidAwarePronunciationService(isAndroid: false);

      expect(service, isA<FallbackPronunciationService>());
      expect(service, isA<OfflinePronunciationManager>());
    });
  });
}

class _VoiceTts extends FlutterTts {
  Object? installed = false;
  final languages = <String>[];

  @override
  Future<dynamic> isLanguageInstalled(String language) async {
    languages.add(language);
    return installed;
  }

  @override
  Future<dynamic> get getDefaultEngine async => 'example.tts';

  @override
  Future<dynamic> stop() async => 1;
}
