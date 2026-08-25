import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/services/fallback_pronunciation_service.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';

void main() {
  group('FallbackPronunciationService', () {
    test('uses the primary service when it succeeds', () async {
      final primary = _FakePronunciationService();
      final fallback = _FakePronunciationService();
      final service = FallbackPronunciationService(primary, fallback);

      await service.speakMandarin('学');

      expect(primary.spokenTexts, ['学']);
      expect(fallback.spokenTexts, isEmpty);
      expect(primary.stopCalls, 1);
      expect(fallback.stopCalls, 1);
    });

    test('uses the fallback service when the primary fails', () async {
      final primary = _FakePronunciationService(
        speakError: StateError('primary unavailable'),
      );
      final fallback = _FakePronunciationService();
      final service = FallbackPronunciationService(primary, fallback);

      await service.speakMandarin('你好');

      expect(primary.spokenTexts, ['你好']);
      expect(fallback.spokenTexts, ['你好']);
      expect(primary.stopCalls, 2);
      expect(fallback.stopCalls, 1);
    });

    test('propagates an error when the fallback also fails', () async {
      final fallbackError = StateError('fallback unavailable');
      final primary = _FakePronunciationService(
        speakError: StateError('primary unavailable'),
      );
      final fallback = _FakePronunciationService(speakError: fallbackError);
      final service = FallbackPronunciationService(primary, fallback);

      await expectLater(
        service.speakMandarin('你好'),
        throwsA(same(fallbackError)),
      );

      expect(primary.spokenTexts, ['你好']);
      expect(fallback.spokenTexts, ['你好']);
    });

    test('fans out stop and dispose even when the primary fails', () async {
      final primary = _FakePronunciationService(
        stopError: StateError('primary stop failed'),
        disposeError: StateError('primary dispose failed'),
      );
      final fallback = _FakePronunciationService();
      final service = FallbackPronunciationService(primary, fallback);

      await service.stop();
      await service.dispose();
      await service.dispose();
      await service.stop();

      expect(primary.stopCalls, 1);
      expect(fallback.stopCalls, 1);
      expect(primary.disposeCalls, 1);
      expect(fallback.disposeCalls, 1);
    });

    test(
      'delegates offline status, updates, and install to the primary',
      () async {
        const status = OfflineVoiceStatus(
          state: OfflineVoiceState.downloading,
          downloadedBytes: 25,
          totalBytes: 100,
          currentFile: 'model.onnx',
        );
        const update = OfflineVoiceStatus.ready();
        final primary = _FakePronunciationService(
          status: status,
          updates: Stream.value(update),
        );
        final fallback = _FakePronunciationService();
        final service = FallbackPronunciationService(primary, fallback);

        expect(await service.checkOfflineVoice(), same(status));
        await expectLater(service.offlineVoiceUpdates, emits(same(update)));
        await service.installOfflineVoice();

        expect(primary.checkStatusCalls, 1);
        expect(primary.installCalls, 1);
        expect(fallback.checkStatusCalls, 0);
        expect(fallback.installCalls, 0);
      },
    );
  });
}

class _FakePronunciationService implements PronunciationService {
  _FakePronunciationService({
    this.status = const OfflineVoiceStatus.notInstalled(),
    this.updates = const Stream.empty(),
    this.speakError,
    this.stopError,
    this.disposeError,
  });

  final OfflineVoiceStatus status;
  final Stream<OfflineVoiceStatus> updates;
  final Object? speakError;
  final Object? stopError;
  final Object? disposeError;

  final List<String> spokenTexts = [];
  int checkStatusCalls = 0;
  int installCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => updates;

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async {
    checkStatusCalls++;
    return status;
  }

  @override
  Future<void> installOfflineVoice() async {
    installCalls++;
  }

  @override
  Future<void> speakMandarin(String text) async {
    spokenTexts.add(text);
    if (speakError case final error?) throw error;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (stopError case final error?) throw error;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    if (disposeError case final error?) throw error;
  }
}
