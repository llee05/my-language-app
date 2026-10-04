import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/services/speech_input_service.dart';
import 'package:mylanguageapp/services/speech_input_service_system.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  for (final action in ['stop', 'cancel', 'dispose']) {
    test('$action prevents listening after delayed permission setup', () async {
      final engine = _SpeechEngine()..initialization = Completer<bool>();
      final service = SystemSpeechInputService(speechToText: engine);
      final pending = service.startListening(onResult: (_) {});
      await Future<void>.delayed(Duration.zero);
      switch (action) {
        case 'stop':
          await service.stopListening();
        case 'cancel':
          await service.cancelListening();
        case 'dispose':
          await service.dispose();
      }
      engine.initialization!.complete(true);
      await pending;
      expect(engine.listenCalls, 0);
      await service.dispose();
    });
  }

  test(
    'cancelling during locale lookup prevents late microphone startup',
    () async {
      final engine = _SpeechEngine()
        ..localeLookup = Completer<List<LocaleName>>();
      final service = SystemSpeechInputService(speechToText: engine);
      final pending = service.startListening(
        onResult: (_) {},
        preferredLocaleId: 'zh_CN',
      );
      await engine.lookupStarted.future;
      await service.cancelListening();
      engine.localeLookup!.complete([LocaleName('zh_CN', 'Mandarin')]);
      await pending;
      expect(engine.listenCalls, 0);
      await service.dispose();
    },
  );

  test('cancelled transcripts cannot reach a subsequent dictation', () async {
    final engine = _SpeechEngine();
    final service = SystemSpeechInputService(speechToText: engine);
    final first = <String>[];
    final second = <String>[];
    await service.startListening(onResult: first.add);
    final staleResult = engine.results.single;
    await service.cancelListening();
    staleResult(_result('旧的'));
    expect(first, isEmpty);
    await service.startListening(onResult: second.add);
    staleResult(_result('旧的'));
    engine.results.last(_result('新的'));
    expect(first, isEmpty);
    expect(second, ['新的']);
    await service.dispose();
  });

  test(
    'permission denial can be retried and stop retains the final transcript',
    () async {
      final engine = _SpeechEngine()..available = false;
      final service = SystemSpeechInputService(speechToText: engine);
      final words = <String>[];
      await expectLater(
        service.startListening(onResult: words.add),
        throwsA(isA<SpeechInputException>()),
      );
      expect(engine.listenCalls, 0);
      engine.available = true;
      await service.startListening(
        onResult: words.add,
        preferredLocaleId: 'zh-CN',
      );
      expect(engine.locale, 'zh_CN');
      await service.stopListening();
      engine.results.last(_result('你好'));
      expect(words, ['你好']);
      await service.dispose();
      engine.results.last(_result('迟到的'));
      expect(words, ['你好']);
    },
  );

  test('a disposed service cannot restart the microphone', () async {
    final engine = _SpeechEngine();
    final service = SystemSpeechInputService(speechToText: engine);
    await service.dispose();
    await service.startListening(onResult: (_) {});
    expect(engine.listenCalls, 0);
  });
}

SpeechRecognitionResult _result(String words) =>
    SpeechRecognitionResult.fromJson({
      'alternates': [
        {'recognizedWords': words, 'confidence': 1.0},
      ],
      'resultType': 2,
    });

class _SpeechEngine implements SpeechToText {
  Completer<bool>? initialization;
  Completer<List<LocaleName>>? localeLookup;
  final lookupStarted = Completer<void>();
  final results = <SpeechResultListener>[];
  bool available = true;
  int listenCalls = 0;
  String? locale;

  @override
  bool get isListening => false;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    dynamic debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async => initialization == null ? available : await initialization!.future;

  @override
  Future<List<LocaleName>> locales() async {
    if (!lookupStarted.isCompleted) lookupStarted.complete();
    return localeLookup == null
        ? [LocaleName('zh_CN', 'Mandarin')]
        : await localeLookup!.future;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #listen) {
      listenCalls++;
      results.add(invocation.namedArguments[#onResult] as SpeechResultListener);
      locale =
          (invocation.namedArguments[#listenOptions] as SpeechListenOptions)
              .localeId;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
