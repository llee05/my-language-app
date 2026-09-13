import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/services/fallback_pronunciation_service.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';
import 'package:mylanguageapp/services/pronunciation_service_system.dart';

class _FakeTts extends FlutterTts {
  _FakeTts({this.languageResult = 1});

  Object? languageResult;
  final List<String> requestedLanguages = [];
  final List<String> spokenTexts = [];
  final List<double> requestedSpeechRates = [];
  int stopCalls = 0;

  @override
  Future<dynamic> setLanguage(String language) async {
    requestedLanguages.add(language);
    return languageResult;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    requestedSpeechRates.add(rate);
    return 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> stop() async {
    stopCalls++;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spokenTexts.add(text);
    return 1;
  }
}

class _RecordingFallbackService implements PronunciationService {
  final List<String> spokenTexts = [];
  int disposeCalls = 0;

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => const Stream.empty();

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus.unavailable();

  @override
  Future<void> installOfflineVoice() async {}

  @override
  Future<void> speakMandarin(String text) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SystemPronunciationService Mandarin voice check', () {
    test('speaks when the platform reports an available zh-CN voice', () async {
      final tts = _FakeTts(languageResult: 1);
      final service = SystemPronunciationService(tts: tts);

      await service.speakMandarin('你好');

      expect(tts.requestedLanguages, ['zh-CN']);
      expect(tts.spokenTexts, ['你好']);
      await service.dispose();
    });

    test('throws when Android reports the zh-CN voice is missing', () async {
      final tts = _FakeTts(languageResult: 0);
      final service = SystemPronunciationService(tts: tts);

      await expectLater(
        service.speakMandarin('你好'),
        throwsA(isA<MandarinVoiceUnavailableException>()),
      );

      expect(tts.spokenTexts, isEmpty);
      await service.dispose();
    });

    test('treats legacy missing-data codes as unavailable', () async {
      final tts = _FakeTts(languageResult: 2);
      final service = SystemPronunciationService(tts: tts);

      await expectLater(
        service.speakMandarin('你好'),
        throwsA(isA<MandarinVoiceUnavailableException>()),
      );

      expect(tts.spokenTexts, isEmpty);
      await service.dispose();
    });

    test('treats a false availability answer as unavailable', () async {
      final tts = _FakeTts(languageResult: false);
      final service = SystemPronunciationService(tts: tts);

      await expectLater(
        service.speakMandarin('学'),
        throwsA(isA<MandarinVoiceUnavailableException>()),
      );

      await service.dispose();
    });

    test('never blocks playback when the platform reports no status', () async {
      final tts = _FakeTts(languageResult: null);
      final service = SystemPronunciationService(tts: tts);

      await service.speakMandarin('学');

      expect(tts.spokenTexts, ['学']);
      await service.dispose();
    });

    test('supports slower listening-practice playback', () async {
      final tts = _FakeTts();
      final service = SystemPronunciationService(tts: tts);

      await service.speakMandarinAtRate('听', rate: .75);

      expect(tts.spokenTexts, ['听']);
      expect(tts.requestedSpeechRates.single, closeTo(.315, .0001));
      await service.dispose();
    });

    test('ignores blank speech and speech after dispose', () async {
      final tts = _FakeTts();
      final service = SystemPronunciationService(tts: tts);

      await service.speakMandarin('   ');
      expect(tts.spokenTexts, isEmpty);
      expect(tts.requestedLanguages, isEmpty);

      await service.dispose();
      await service.speakMandarin('你好');
      expect(tts.spokenTexts, isEmpty);
    });
  });

  group('FallbackPronunciationService with a missing system voice', () {
    test(
      'falls back when the system service reports no Mandarin voice',
      () async {
        final systemTts = _FakeTts(languageResult: 0);
        final system = SystemPronunciationService(tts: systemTts);
        final fallback = _RecordingFallbackService();
        final service = FallbackPronunciationService(system, fallback);

        await service.speakMandarin('你好');

        expect(systemTts.spokenTexts, isEmpty);
        expect(fallback.spokenTexts, ['你好']);
        await service.dispose();
        expect(fallback.disposeCalls, 1);
      },
    );
  });
}
