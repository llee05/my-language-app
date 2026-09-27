import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/services/pronunciation_audio_cache.dart';

void main() {
  late PronunciationAudioCache cache;
  var calls = 0;

  Future<PronunciationAudio> load(
    String text, {
    int speaker = 0,
    String version = 'v1',
    String directory = '/model',
    int samples = 4,
  }) => cache.get(
    modelDirectory: directory,
    modelVersion: version,
    speakerId: speaker,
    text: text,
    synthesize: () async {
      calls++;
      return PronunciationAudio(
        samples: Float32List(samples),
        sampleRate: 24000,
      );
    },
  );

  setUp(() {
    cache = PronunciationAudioCache(maxBytes: 32, maxEntries: 8);
    calls = 0;
  });

  test('reuses earlier clips and evicts by bytes in recency order', () async {
    final first = await load('你好');
    await load('学习');
    expect(await load('你好'), same(first));
    await load('再见');
    expect(await load('你好'), same(first));
    expect(calls, 3);
    await load('学习');
    expect(calls, 4);
    expect(() => first.samples[0] = 1, throwsUnsupportedError);
  });

  test('voice, model version, directory, and text distinguish clips', () async {
    cache = PronunciationAudioCache();
    await load('你好');
    await load('你好', speaker: 1);
    await load('你好', version: 'v2');
    await load('你好', directory: '/other-model');
    await load('学习');
    await load('你好');
    expect(calls, 5);
  });

  test('oversized clips are usable but do not displace cached clips', () async {
    final small = await load('学');
    await load('long passage', samples: 9);
    expect(await load('学'), same(small));
    await load('long passage', samples: 9);
    expect(calls, 3);
  });

  test(
    'invalid synthesis is retried and pending synthesis is shared',
    () async {
      final pending = Completer<PronunciationAudio>();
      Future<PronunciationAudio> read() => cache.get(
        modelDirectory: '/model',
        modelVersion: 'v1',
        speakerId: 0,
        text: '学',
        synthesize: () => pending.future,
      );
      final first = read();
      expect(read(), same(first));
      final failure = expectLater(first, throwsStateError);
      pending.complete(
        PronunciationAudio(samples: Float32List(0), sampleRate: 0),
      );
      await failure;
      expect((await load('学')).samples, hasLength(4));
      cache.clear();
      await load('学');
      expect(calls, 2);
    },
  );
}
