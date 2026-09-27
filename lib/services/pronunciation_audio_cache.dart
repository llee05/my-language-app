import 'dart:typed_data';

import 'async_lru_cache.dart';

class PronunciationAudio {
  const PronunciationAudio({required this.samples, required this.sampleRate});

  final Float32List samples;
  final int sampleRate;
}

/// Caches synthesis, independent of playback rate and native audio handles.
class PronunciationAudioCache {
  PronunciationAudioCache({
    int maxBytes = 16 * 1024 * 1024,
    int maxEntries = 64,
  }) : _cache =
           AsyncLruCache<(String, String, int, String), PronunciationAudio>(
             maxEntries: maxEntries,
             maxWeight: maxBytes,
             weightOf: (audio) => audio.samples.lengthInBytes,
           );

  final AsyncLruCache<(String, String, int, String), PronunciationAudio> _cache;

  Future<PronunciationAudio> get({
    required String modelDirectory,
    required String modelVersion,
    required int speakerId,
    required String text,
    required Future<PronunciationAudio> Function() synthesize,
  }) => _cache.get((modelDirectory, modelVersion, speakerId, text), () async {
    final audio = await synthesize();
    if (audio.samples.isEmpty || audio.sampleRate <= 0) {
      throw StateError('Speech synthesis produced no audio.');
    }
    return PronunciationAudio(
      samples: audio.samples.asUnmodifiableView(),
      sampleRate: audio.sampleRate,
    );
  });

  void clear() => _cache.clear();
}
