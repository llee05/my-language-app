import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../models/learning_progress.dart';
import 'fallback_pronunciation_service.dart';
import 'kokoro_voice_pack.dart';
import 'pronunciation_service.dart';
import 'pronunciation_service_system.dart';
import 'sherpa_voice_config.dart';

PronunciationService createPlatformPronunciationService() {
  return FallbackPronunciationService(
    _SherpaPronunciationService(KokoroVoicePackInstaller()),
    SystemPronunciationService(),
  );
}

class _SherpaPronunciationService
    implements PronunciationService, OfflinePronunciationManager {
  _SherpaPronunciationService(this._kokoroVoicePack) {
    _voicePackSubscriptions = [
      _kokoroVoicePack.updates.listen(_voicePackUpdates.add),
    ];
  }

  final KokoroVoicePackInstaller _kokoroVoicePack;
  final StreamController<OfflineVoiceStatus> _voicePackUpdates =
      StreamController<OfflineVoiceStatus>.broadcast(sync: true);
  late final List<StreamSubscription<OfflineVoiceStatus>>
  _voicePackSubscriptions;
  final _SherpaWorker _worker = _SherpaWorker();
  final math.Random _random = math.Random();
  AudioSource? _audioSource;
  List<PronunciationVoice> _configuredVoices = kokoroMandarinVoices;
  String? _previousKokoroVoiceId;
  int _requestId = 0;
  bool _disposed = false;

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates =>
      _kokoroVoicePack.updates;

  @override
  Stream<OfflineVoiceStatus> get voicePackUpdates => _voicePackUpdates.stream;

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() => _kokoroVoicePack.check();

  @override
  Future<void> installOfflineVoice() => _kokoroVoicePack.install();

  @override
  Future<OfflineVoiceStatus> checkVoicePack(PronunciationEngine engine) =>
      _kokoroVoicePack.check();

  @override
  Future<void> installVoicePack(PronunciationEngine engine) =>
      _kokoroVoicePack.install();

  @override
  List<PronunciationVoice> voicesFor(PronunciationEngine engine) =>
      kokoroMandarinVoices;

  @override
  Future<void> configurePronunciation({
    required PronunciationEngine engine,
    List<String> voiceIds = const [],
  }) async {
    if (_disposed) return;
    final voices = resolvePronunciationVoices(engine, voiceIds);
    if (_sameVoicePool(_configuredVoices, voices)) {
      return;
    }
    await stop();
    _configuredVoices = voices;
    if (!voices.any((voice) => voice.id == _previousKokoroVoiceId)) {
      _previousKokoroVoiceId = null;
    }
  }

  @override
  Future<void> speakMandarin(String text) async {
    if (_disposed || text.trim().isEmpty) return;
    final requestId = ++_requestId;
    await _stopPlayback();
    if (_disposed || requestId != _requestId) return;
    final voice = pickPronunciationVoice(
      _configuredVoices,
      randomIndex: _random.nextInt,
      previousVoiceId: _previousKokoroVoiceId,
    );
    final directory = await _kokoroVoicePack.installedDirectory();
    if (directory == null) throw const OfflineVoiceNotInstalledException();
    if (_disposed || requestId != _requestId) return;

    final audio = await _worker.generate(
      modelDirectory: directory.path,
      speakerId: voice.speakerId,
      text: text,
    );
    if (_disposed || requestId != _requestId) return;
    if (audio.samples.isEmpty || audio.sampleRate <= 0) {
      throw StateError('Sherpa produced no audio.');
    }
    _previousKokoroVoiceId = voice.id;

    final soLoud = SoLoud.instance;
    if (!soLoud.isInitialized) {
      await soLoud.init(automaticCleanup: true);
    }
    if (_disposed || requestId != _requestId) return;
    final source = await soLoud.loadMem(
      'ting_shuo_mandarin_$requestId.wav',
      _encodeWave(audio.samples, audio.sampleRate),
    );
    if (_disposed || requestId != _requestId) {
      await soLoud.disposeSource(source);
      return;
    }
    final handle = soLoud.play(source);
    if (handle.isError) {
      await soLoud.disposeSource(source);
      throw StateError('The audio device could not start playback.');
    }
    _audioSource = source;
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _requestId++;
    await _stopPlayback();
  }

  Future<void> _stopPlayback() async {
    final source = _audioSource;
    _audioSource = null;
    if (source != null && SoLoud.instance.isInitialized) {
      await SoLoud.instance.disposeSource(source);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _requestId++;
    await _stopPlayback();
    await _worker.dispose();
    for (final subscription in _voicePackSubscriptions) {
      await subscription.cancel();
    }
    await _kokoroVoicePack.dispose();
    await _voicePackUpdates.close();
  }
}

bool _sameVoicePool(
  List<PronunciationVoice> first,
  List<PronunciationVoice> second,
) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index].id != second[index].id) return false;
  }
  return true;
}

class _SherpaAudio {
  const _SherpaAudio({required this.samples, required this.sampleRate});

  final Float32List samples;
  final int sampleRate;
}

class _SherpaWorker {
  final ReceivePort _responses = ReceivePort();
  final Map<int, Completer<_SherpaAudio>> _pending = {};
  StreamSubscription<dynamic>? _responseSubscription;
  Isolate? _isolate;
  SendPort? _commands;
  Future<void>? _starting;
  Object? _startupError;
  final Completer<void> _disposedByWorker = Completer<void>();
  int _nextRequestId = 0;
  bool _disposed = false;

  Future<_SherpaAudio> generate({
    required String modelDirectory,
    required int speakerId,
    required String text,
  }) async {
    if (_disposed) throw StateError('The Sherpa worker is closed.');
    final existingStartupError = _startupError;
    if (existingStartupError != null) throw existingStartupError;
    await _ensureStarted();
    if (_disposed) throw StateError('The Sherpa worker is closed.');
    final startupError = _startupError;
    if (startupError != null) throw startupError;
    final requestId = ++_nextRequestId;
    final completer = Completer<_SherpaAudio>();
    _pending[requestId] = completer;
    _commands!.send({
      'type': 'generate',
      'id': requestId,
      'modelDirectory': modelDirectory,
      'speakerId': speakerId,
      'text': text,
    });
    return completer.future;
  }

  Future<void> _ensureStarted() {
    final starting = _starting;
    if (starting != null) return starting;
    if (_commands != null) return Future.value();
    final future = _start();
    _starting = future;
    return future.whenComplete(() {
      if (identical(_starting, future)) _starting = null;
    });
  }

  Future<void> _start() async {
    final ready = Completer<void>();
    _responseSubscription ??= _responses.listen((dynamic message) {
      if (message is! Map) return;
      switch (message['type']) {
        case 'ready':
          _commands = message['commands'] as SendPort;
          if (!ready.isCompleted) ready.complete();
        case 'startupError':
          _startupError = StateError(message['error'] as String);
          if (!ready.isCompleted) ready.completeError(_startupError!);
        case 'audio':
          final id = message['id'] as int;
          final completer = _pending.remove(id);
          if (completer == null) break;
          final bytes = (message['samples'] as TransferableTypedData)
              .materialize();
          completer.complete(
            _SherpaAudio(
              samples: Float32List.view(bytes),
              sampleRate: message['sampleRate'] as int,
            ),
          );
        case 'error':
          final id = message['id'] as int;
          _pending
              .remove(id)
              ?.completeError(StateError(message['error'] as String));
        case 'disposed':
          if (!_disposedByWorker.isCompleted) _disposedByWorker.complete();
          break;
      }
    });
    try {
      _isolate = await Isolate.spawn<Map<String, Object>>(_sherpaWorkerMain, {
        'responses': _responses.sendPort,
        'numThreads': math.min(2, Platform.numberOfProcessors),
      }, debugName: 'ting-shuo-sherpa-tts');
      await ready.future;
    } catch (error) {
      _startupError ??= error;
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _starting;
    } catch (_) {
      // A failed startup has no live native object to release.
    }
    final commands = _commands;
    if (commands != null) {
      commands.send({'type': 'dispose'});
      try {
        await _disposedByWorker.future.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // The isolate may still be finishing a synthesis. It is terminated below.
      }
    }
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('The Sherpa worker was closed.'));
      }
    }
    _pending.clear();
    await _responseSubscription?.cancel();
    _responses.close();
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _commands = null;
  }
}

void _sherpaWorkerMain(Map<String, Object> setup) {
  final responses = setup['responses']! as SendPort;
  sherpa_onnx.OfflineTts? tts;
  String? loadedModelKey;
  try {
    sherpa_onnx.initBindings();
    final commands = ReceivePort();
    responses.send({'type': 'ready', 'commands': commands.sendPort});
    commands.listen((dynamic message) {
      if (message is! Map) return;
      if (message['type'] == 'dispose') {
        tts?.free();
        tts = null;
        responses.send({'type': 'disposed'});
        commands.close();
        Isolate.exit();
      }
      if (message['type'] != 'generate') return;
      final id = message['id'] as int;
      try {
        final modelDirectory = message['modelDirectory'] as String;
        if (loadedModelKey != modelDirectory) {
          tts?.free();
          tts = null;
          loadedModelKey = null;
          final nextTts = sherpa_onnx.OfflineTts(
            createSherpaVoiceConfig(
              modelDirectory: modelDirectory,
              numThreads: setup['numThreads']! as int,
            ),
          );
          tts = nextTts;
          loadedModelKey = modelDirectory;
        }
        final speakerId = message['speakerId'] as int;
        if (speakerId < 0 || speakerId >= tts!.numSpeakers) {
          throw RangeError.range(
            speakerId,
            0,
            tts!.numSpeakers - 1,
            'speakerId',
          );
        }
        final audio = tts!.generateWithConfig(
          text: message['text'] as String,
          config: sherpa_onnx.OfflineTtsGenerationConfig(
            sid: speakerId,
            speed: .92,
            silenceScale: .2,
          ),
        );
        responses.send({
          'type': 'audio',
          'id': id,
          'sampleRate': audio.sampleRate,
          'samples': TransferableTypedData.fromList([
            audio.samples.buffer.asUint8List(
              audio.samples.offsetInBytes,
              audio.samples.lengthInBytes,
            ),
          ]),
        });
      } catch (error) {
        responses.send({'type': 'error', 'id': id, 'error': '$error'});
      }
    });
  } catch (error) {
    tts?.free();
    responses.send({'type': 'startupError', 'error': '$error'});
  }
}

Uint8List _encodeWave(Float32List samples, int sampleRate) {
  const headerSize = 44;
  const bytesPerSample = 2;
  const targetPeak = .85;
  const maximumGain = 12.0;
  final dataLength = samples.length * bytesPerSample;
  final output = Uint8List(headerSize + dataLength);
  final data = ByteData.view(output.buffer);

  var peak = 0.0;
  for (final sample in samples) {
    if (sample.isFinite) peak = math.max(peak, sample.abs());
  }
  final gain = peak > 0 ? math.min(maximumGain, targetPeak / peak) : 1.0;

  void writeText(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      output[offset + index] = value.codeUnitAt(index);
    }
  }

  writeText(0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  writeText(8, 'WAVE');
  writeText(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * bytesPerSample, Endian.little);
  data.setUint16(32, bytesPerSample, Endian.little);
  data.setUint16(34, 16, Endian.little);
  writeText(36, 'data');
  data.setUint32(40, dataLength, Endian.little);

  for (var index = 0; index < samples.length; index++) {
    final rawSample = samples[index];
    final sample = (rawSample.isFinite ? rawSample * gain : 0.0).clamp(
      -1.0,
      1.0,
    );
    final pcm = sample < 0
        ? (sample * 32768).round()
        : (sample * 32767).round();
    data.setInt16(headerSize + index * bytesPerSample, pcm, Endian.little);
  }
  return output;
}
