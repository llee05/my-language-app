import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import 'recorded_pronunciation_service.dart';

class SoLoudRecordedAudioPlayer implements RecordedAudioPlayer {
  AudioSource? _source;
  int _requestId = 0;
  bool _disposed = false;
  Future<void>? _initializing;

  @override
  Future<void> play(Uint8List bytes, {required double rate}) async {
    if (_disposed) return;
    final request = ++_requestId;
    await _stopSource();
    final soLoud = SoLoud.instance;
    if (!soLoud.isInitialized) {
      try {
        await (_initializing ??= soLoud.init());
      } finally {
        _initializing = null;
      }
    }
    if (_disposed || request != _requestId) return;
    final source = await soLoud.loadMem('mandarin-recording-$request', bytes);
    if (_disposed || request != _requestId) {
      await soLoud.disposeSource(source);
      return;
    }
    try {
      final handle = soLoud.play(source);
      if (handle.isError) throw StateError('Audio playback could not start.');
      soLoud.setRelativePlaySpeed(handle, rate);
      _source = source;
    } catch (_) {
      await soLoud.disposeSource(source);
      rethrow;
    }
  }

  Future<void> _stopSource() async {
    final source = _source;
    _source = null;
    if (source != null && SoLoud.instance.isInitialized) {
      await SoLoud.instance.disposeSource(source);
    }
  }

  @override
  Future<void> stop() async {
    _requestId++;
    await _stopSource();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
  }
}
