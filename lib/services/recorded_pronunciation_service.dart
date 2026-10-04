import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'async_lru_cache.dart';
import 'pronunciation_service.dart';

abstract interface class RecordedAudioLibrary {
  Future<int> count();
  Future<Uint8List?> load(String text);
  void clear();
}

abstract interface class RecordedAudioPlayer {
  Future<void> play(Uint8List bytes, {required double rate});
  Future<void> stop();
  Future<void> dispose();
}

/// Native CMake bundles install the pack beside the executable, outside the
/// Flutter asset bundle so it is never included in Android or Apple builds.
class BundledRecordedAudioLibrary implements RecordedAudioLibrary {
  BundledRecordedAudioLibrary({Directory Function()? directory})
    : _directory = directory ?? _bundleDirectory;

  final Directory Function() _directory;
  Future<Map<String, _RecordedClip>>? _catalog;
  final _cache = AsyncLruCache<String, Uint8List>(
    maxEntries: 64,
    maxWeight: 4 * 1024 * 1024,
    weightOf: (bytes) => bytes.length,
  );

  static Directory _bundleDirectory() => Directory(
    p.join(p.dirname(Platform.resolvedExecutable), 'data', 'mandarin_audio'),
  );

  Future<Map<String, _RecordedClip>> _loadCatalog() {
    return _catalog ??= _readCatalog().onError<Object>((error, stack) {
      _catalog = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<Map<String, _RecordedClip>> _readCatalog() async {
    final json = jsonDecode(
      await File(p.join(_directory().path, 'catalog.json')).readAsString(),
    );
    if (json is! Map<String, dynamic> ||
        json['version'] != 1 ||
        json['clips'] is! List ||
        (json['clips'] as List).isEmpty) {
      throw const FormatException('Invalid recorded audio catalog.');
    }
    final clips = <String, _RecordedClip>{};
    for (final entry in json['clips'] as List) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid recorded audio entry.');
      }
      final text = entry['text'];
      final digest = entry['sha256'];
      final filename = entry['file'];
      final length = entry['bytes'];
      if (text is! String ||
          text.isEmpty ||
          text != text.trim() ||
          digest is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
          filename != '$digest.mp3' ||
          length is! int ||
          length <= 0 ||
          length > 1024 * 1024 ||
          clips.containsKey(text)) {
        throw const FormatException('Invalid recorded audio entry.');
      }
      clips[text] = _RecordedClip(digest, length);
    }
    return Map.unmodifiable(clips);
  }

  @override
  Future<int> count() async => (await _loadCatalog()).length;

  @override
  Future<Uint8List?> load(String text) async {
    final clip = (await _loadCatalog())[text.trim()];
    if (clip == null) return null;
    return _cache.get(clip.digest, () async {
      final bytes = await File(
        p.join(_directory().path, 'clips', '${clip.digest}.mp3'),
      ).readAsBytes();
      if (bytes.length != clip.length ||
          sha256.convert(bytes).toString() != clip.digest) {
        throw const FormatException('The recorded audio clip is damaged.');
      }
      return bytes;
    });
  }

  @override
  void clear() {
    _catalog = null;
    _cache.clear();
  }
}

class _RecordedClip {
  const _RecordedClip(this.digest, this.length);
  final String digest;
  final int length;
}

class RecordedPronunciationService
    implements
        PronunciationService,
        RecordedAudioPronunciation,
        PreparedPronunciationService,
        PlaybackRatePronunciationService {
  RecordedPronunciationService(
    this._library,
    this._player,
    this._fallback, {
    required this.systemSpeechDescription,
  });

  final RecordedAudioLibrary _library;
  final RecordedAudioPlayer _player;
  final PronunciationService _fallback;
  @override
  final String systemSpeechDescription;
  int _requestId = 0;
  bool _disposed = false;
  Future<void> _stopQueue = Future.value();

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => const Stream.empty();

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async {
    try {
      final count = await _library.count();
      return OfflineVoiceStatus(
        state: OfflineVoiceState.ready,
        message: '$count human-recorded words are bundled and ready offline.',
      );
    } catch (_) {
      return const OfflineVoiceStatus(
        state: OfflineVoiceState.failed,
        message:
            'The bundled recordings could not be loaded. Reinstall the desktop app to restore them. System speech is still available.',
      );
    }
  }

  @override
  Future<void> installOfflineVoice() => Future.error(
    UnsupportedError('Recordings are included with the desktop app.'),
  );

  @override
  Future<void> prepareMandarin(String text) async {
    if (_disposed || text.trim().isEmpty) return;
    try {
      await _library.load(text);
    } catch (_) {
      // Preparation must not block study; playback can retry or use speech.
    }
  }

  @override
  Future<void> speakMandarin(String text) => speakMandarinAtRate(text, rate: 1);

  @override
  Future<void> speakMandarinAtRate(String text, {required double rate}) async {
    if (_disposed || text.trim().isEmpty) return;
    final request = ++_requestId;
    await _stopChildren();
    if (!_isCurrent(request)) return;
    try {
      final bytes = await _library.load(text);
      if (!_isCurrent(request)) return;
      if (bytes != null) {
        await _player.play(bytes, rate: rate.clamp(.5, 1.5));
        return;
      }
    } catch (_) {
      if (!_isCurrent(request)) return;
      await _stopChildren();
    }
    if (!_isCurrent(request)) return;
    final fallback = _fallback;
    if (fallback is PlaybackRatePronunciationService) {
      await (fallback as PlaybackRatePronunciationService).speakMandarinAtRate(
        text,
        rate: rate,
      );
    } else {
      await fallback.speakMandarin(text);
    }
  }

  bool _isCurrent(int request) => !_disposed && request == _requestId;

  Future<void> _stopChildren() {
    // A newer request waits for earlier shutdowns before starting either
    // engine, so a late system stop cannot cut off the new phrase.
    return _stopQueue = _stopQueue.then((_) async {
      try {
        await _player.stop();
      } catch (_) {
        // The optional device may already be unavailable.
      }
      try {
        await _fallback.stop();
      } catch (_) {
        // A missing system engine must not block a recording.
      }
    });
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _requestId++;
    await _stopChildren();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _requestId++;
    _library.clear();
    await _stopQueue;
    try {
      await _player.dispose();
    } finally {
      await _fallback.dispose();
    }
  }
}
