import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
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

    test(
      'delegates multi-pack management when the primary supports it',
      () async {
        final primary = _FakeManagedPronunciationService();
        final service = FallbackPronunciationService(
          primary,
          _FakePronunciationService(),
        );

        final kokoroStatus = await service.checkVoicePack(
          PronunciationEngine.kokoro,
        );
        await service.installVoicePack(PronunciationEngine.kokoro);
        await service.configurePronunciation(
          engine: PronunciationEngine.kokoro,
          voiceIds: const ['zf_021', 'zm_041'],
        );

        expect(kokoroStatus.engine, PronunciationEngine.kokoro);
        expect(primary.checkedEngines, [PronunciationEngine.kokoro]);
        expect(primary.installedEngines, [PronunciationEngine.kokoro]);
        expect(primary.configuredEngine, PronunciationEngine.kokoro);
        expect(primary.configuredVoiceIds, ['zf_021', 'zm_041']);
        expect(service.voicesFor(PronunciationEngine.kokoro), hasLength(100));
      },
    );

    test(
      'reports unsupported multi-pack management without a capable primary',
      () {
        final service = FallbackPronunciationService(
          _FakePronunciationService(),
          _FakePronunciationService(),
        );

        expect(
          () => service.checkVoicePack(PronunciationEngine.kokoro),
          throwsUnsupportedError,
        );
        expect(service.voicePackUpdates, emitsDone);
      },
    );
  });

  test('Kokoro catalog maps all Mandarin voices to their official IDs', () {
    expect(kokoroMandarinVoices, hasLength(100));
    expect(
      kokoroMandarinVoices.map((voice) => voice.id).toSet(),
      hasLength(100),
    );
    expect(kokoroMandarinVoices.first.id, 'zf_001');
    expect(kokoroMandarinVoices.first.speakerId, 3);
    expect(kokoroMandarinVoices[54].id, 'zf_099');
    expect(kokoroMandarinVoices[54].speakerId, 57);
    expect(kokoroMandarinVoices[55].id, 'zm_009');
    expect(kokoroMandarinVoices[55].speakerId, 58);
    expect(kokoroMandarinVoices.last.id, 'zm_100');
    expect(kokoroMandarinVoices.last.speakerId, 102);
    expect(
      resolvePronunciationVoice(PronunciationEngine.kokoro, 'unknown').id,
      'zf_001',
    );
  });

  test('empty Kokoro selection resolves to the complete random pool', () {
    final voices = resolvePronunciationVoices(
      PronunciationEngine.kokoro,
      const [],
    );

    expect(voices, same(kokoroMandarinVoices));
  });

  test('Kokoro pools discard duplicates and unknown IDs', () {
    final voices = resolvePronunciationVoices(
      PronunciationEngine.kokoro,
      const ['zm_041', 'unknown', 'zf_021', 'zm_041'],
    );

    expect(voices.map((voice) => voice.id), ['zf_021', 'zm_041']);
  });

  test('random voice selection avoids an immediate repeat', () {
    final voices = resolvePronunciationVoices(
      PronunciationEngine.kokoro,
      const ['zf_001', 'zm_041'],
    );

    final selected = pickPronunciationVoice(
      voices,
      randomIndex: (_) => 0,
      previousVoiceId: 'zf_001',
    );

    expect(selected.id, 'zm_041');
  });

  test('a one-voice Kokoro pool stays fixed', () {
    final voices = resolvePronunciationVoices(
      PronunciationEngine.kokoro,
      const ['zm_041'],
    );

    final selected = pickPronunciationVoice(
      voices,
      randomIndex: (_) => fail('A one-voice pool does not need randomness.'),
    );

    expect(selected.id, 'zm_041');
  });

  test('applies a learner voice preference before pronunciation', () async {
    final service = _FakeManagedPronunciationService();

    await applyPronunciationSettings(
      service,
      const LearnerSettings(
        pronunciationEngine: PronunciationEngine.kokoro,
        kokoroVoiceIds: ['zm_041'],
      ),
    );

    expect(service.configuredEngine, PronunciationEngine.kokoro);
    expect(service.configuredVoiceIds, ['zm_041']);
  });

  test('forwards voice-pack management to a managed primary', () async {
    final primary = _FakeManagedPronunciationService();
    final fallback = _FakePronunciationService();
    final service = FallbackPronunciationService(primary, fallback);

    await service.checkVoicePack(PronunciationEngine.kokoro);
    await service.installVoicePack(PronunciationEngine.kokoro);
    expect(service.voicesFor(PronunciationEngine.kokoro), kokoroMandarinVoices);
    await service.configurePronunciation(
      engine: PronunciationEngine.kokoro,
      voiceIds: ['zm_041'],
    );

    expect(primary.checkedEngines, [PronunciationEngine.kokoro]);
    expect(primary.installedEngines, [PronunciationEngine.kokoro]);
    expect(primary.configuredEngine, PronunciationEngine.kokoro);
    expect(primary.configuredVoiceIds, ['zm_041']);
    expect(service.voicePackUpdates, same(primary.voicePackUpdates));
  });

  test('unmanaged primaries cannot manage voice packs', () async {
    final service = FallbackPronunciationService(
      _FakePronunciationService(),
      _FakePronunciationService(),
    );

    await expectLater(service.voicePackUpdates, emitsDone);
    expect(
      () => service.checkVoicePack(PronunciationEngine.kokoro),
      throwsUnsupportedError,
    );
    expect(
      () => service.installVoicePack(PronunciationEngine.kokoro),
      throwsUnsupportedError,
    );
    expect(
      () => service.configurePronunciation(engine: PronunciationEngine.kokoro),
      throwsUnsupportedError,
    );
    expect(
      () => service.voicesFor(PronunciationEngine.kokoro),
      throwsUnsupportedError,
    );
  });

  test('ignores blank speech and speech after dispose', () async {
    final primary = _FakePronunciationService();
    final fallback = _FakePronunciationService();
    final service = FallbackPronunciationService(primary, fallback);

    await service.speakMandarin('   ');
    expect(primary.spokenTexts, isEmpty);
    expect(fallback.spokenTexts, isEmpty);

    await service.dispose();
    await service.speakMandarin('你好');
    expect(primary.spokenTexts, isEmpty);
    expect(fallback.spokenTexts, isEmpty);
    expect(primary.disposeCalls, 1);
    expect(fallback.disposeCalls, 1);
  });
}

class _FakeManagedPronunciationService extends _FakePronunciationService
    implements OfflinePronunciationManager {
  final List<PronunciationEngine> checkedEngines = [];
  final List<PronunciationEngine> installedEngines = [];
  PronunciationEngine? configuredEngine;
  List<String> configuredVoiceIds = const [];

  @override
  Stream<OfflineVoiceStatus> get voicePackUpdates => const Stream.empty();

  @override
  Future<OfflineVoiceStatus> checkVoicePack(PronunciationEngine engine) async {
    checkedEngines.add(engine);
    return OfflineVoiceStatus.notInstalled(engine: engine);
  }

  @override
  Future<void> installVoicePack(PronunciationEngine engine) async {
    installedEngines.add(engine);
  }

  @override
  List<PronunciationVoice> voicesFor(PronunciationEngine engine) =>
      kokoroMandarinVoices;

  @override
  Future<void> configurePronunciation({
    required PronunciationEngine engine,
    List<String> voiceIds = const [],
  }) async {
    configuredEngine = engine;
    configuredVoiceIds = List.of(voiceIds);
  }
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
