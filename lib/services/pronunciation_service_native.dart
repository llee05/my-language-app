import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'fallback_pronunciation_service.dart';
import 'pronunciation_service.dart';
import 'pronunciation_service_system.dart';

PronunciationService createPlatformPronunciationService() {
  final voicePack = _MeloVoicePack();
  return FallbackPronunciationService(
    _SherpaPronunciationService(voicePack),
    SystemPronunciationService(),
  );
}

const _modelRevision = 'a0d5c6a264c0ef92d70d8661d8cc502d79627cd6';
const _modelSha256 =
    'f085f5079e05f039b800aeb542f5253c26a303211b0c6465d0d9387977855a63';
const _voicePackDirectoryName = 'vits-melo-tts-zh_en-int8-v1';
const _completeMarkerName = '.complete';

const _voiceFiles = <_VoiceFile>[
  _VoiceFile('model.int8.onnx', 53517430),
  _VoiceFile('lexicon.txt', 6837671),
  _VoiceFile('tokens.txt', 655),
  _VoiceFile('date.fst', 59154),
  _VoiceFile('number.fst', 64482),
  _VoiceFile('LICENSE', 1053),
];

const _voicePackBytes = 60480445;

class _VoiceFile {
  const _VoiceFile(this.name, this.size);

  final String name;
  final int size;
}

class _MeloVoicePack {
  final StreamController<OfflineVoiceStatus> _updates =
      StreamController<OfflineVoiceStatus>.broadcast(sync: true);
  Future<void>? _installFuture;
  OfflineVoiceStatus _lastStatus = const OfflineVoiceStatus.notInstalled();
  bool _disposed = false;

  Stream<OfflineVoiceStatus> get updates => _updates.stream;

  Future<Directory> _voiceDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      p.join(support.path, 'ting_shuo', 'tts', _voicePackDirectoryName),
    );
  }

  Future<OfflineVoiceStatus> check() async {
    if (_installFuture != null) return _lastStatus;
    try {
      final directory = await _voiceDirectory();
      final installed = await _isComplete(directory);
      final status = installed
          ? const OfflineVoiceStatus.ready()
          : const OfflineVoiceStatus.notInstalled();
      _emit(status);
      return status;
    } catch (_) {
      final status = OfflineVoiceStatus(
        state: OfflineVoiceState.failed,
        message: 'The offline voice status could not be checked.',
      );
      _emit(status);
      return status;
    }
  }

  Future<Directory?> installedDirectory() async {
    final directory = await _voiceDirectory();
    return await _isComplete(directory) ? directory : null;
  }

  Future<void> install() {
    if (_disposed) {
      return Future.error(StateError('The pronunciation service is closed.'));
    }
    final pending = _installFuture;
    if (pending != null) return pending;

    late final Future<void> installFuture;
    installFuture = _install().whenComplete(() {
      if (identical(_installFuture, installFuture)) _installFuture = null;
    });
    _installFuture = installFuture;
    return installFuture;
  }

  Future<void> _install() async {
    final target = await _voiceDirectory();
    if (await _isComplete(target)) {
      _emit(const OfflineVoiceStatus.ready());
      return;
    }

    final staging = Directory('${target.path}.installing');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    final client = http.Client();
    var downloadedBytes = 0;
    try {
      for (final voiceFile in _voiceFiles) {
        _emit(
          OfflineVoiceStatus(
            state: OfflineVoiceState.downloading,
            downloadedBytes: downloadedBytes,
            totalBytes: _voicePackBytes,
            currentFile: voiceFile.name,
          ),
        );
        final destination = File(p.join(staging.path, voiceFile.name));
        final request = http.Request(
          'GET',
          Uri.parse(
            'https://huggingface.co/csukuangfj/'
            'vits-melo-tts-zh_en/resolve/$_modelRevision/'
            '${voiceFile.name}?download=true',
          ),
        );
        final response = await client.send(request);
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Voice download failed with HTTP ${response.statusCode}.',
            uri: request.url,
          );
        }

        final sink = destination.openWrite();
        var fileBytes = 0;
        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            fileBytes += chunk.length;
            _emit(
              OfflineVoiceStatus(
                state: OfflineVoiceState.downloading,
                downloadedBytes: downloadedBytes + fileBytes,
                totalBytes: _voicePackBytes,
                currentFile: voiceFile.name,
              ),
            );
          }
        } finally {
          await sink.close();
        }
        if (fileBytes != voiceFile.size) {
          throw FileSystemException(
            'The downloaded voice file has an unexpected size.',
            destination.path,
          );
        }
        downloadedBytes += fileBytes;
      }

      final model = File(p.join(staging.path, 'model.int8.onnx'));
      final digest = await sha256.bind(model.openRead()).first;
      if (digest.toString() != _modelSha256) {
        throw const FormatException(
          'The downloaded voice model failed its integrity check.',
        );
      }
      await File(p.join(staging.path, _completeMarkerName)).writeAsString(
        'revision=$_modelRevision\nsha256=$_modelSha256\n',
        flush: true,
      );

      if (await target.exists()) await target.delete(recursive: true);
      await staging.rename(target.path);
      _emit(const OfflineVoiceStatus.ready());
    } catch (error) {
      if (await staging.exists()) await staging.delete(recursive: true);
      _emit(
        OfflineVoiceStatus(
          state: OfflineVoiceState.failed,
          message: _friendlyDownloadError(error),
        ),
      );
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<bool> _isComplete(Directory directory) async {
    final marker = File(p.join(directory.path, _completeMarkerName));
    if (!await marker.exists()) return false;
    final markerContents = await marker.readAsString();
    if (!markerContents.contains(_modelRevision) ||
        !markerContents.contains(_modelSha256)) {
      return false;
    }
    for (final voiceFile in _voiceFiles) {
      final file = File(p.join(directory.path, voiceFile.name));
      if (!await file.exists() || await file.length() != voiceFile.size) {
        return false;
      }
    }
    return true;
  }

  String _friendlyDownloadError(Object error) {
    if (error is SocketException ||
        error is HttpException ||
        error is http.ClientException) {
      return 'The voice download could not connect. Check your internet and try again.';
    }
    if (error is FileSystemException) {
      return 'The voice pack could not be saved. Check available storage and try again.';
    }
    if (error is FormatException) {
      return 'The voice download was incomplete or corrupted. Please try again.';
    }
    return 'The offline voice could not be installed. Please try again.';
  }

  void _emit(OfflineVoiceStatus status) {
    _lastStatus = status;
    if (!_disposed && !_updates.isClosed) _updates.add(status);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _updates.close();
  }
}

class _SherpaPronunciationService implements PronunciationService {
  _SherpaPronunciationService(this._voicePack);

  final _MeloVoicePack _voicePack;
  final _SherpaWorker _worker = _SherpaWorker();
  AudioSource? _audioSource;
  int _requestId = 0;
  bool _disposed = false;

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => _voicePack.updates;

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() => _voicePack.check();

  @override
  Future<void> installOfflineVoice() => _voicePack.install();

  @override
  Future<void> speakMandarin(String text) async {
    if (_disposed || text.trim().isEmpty) return;
    final requestId = ++_requestId;
    await _stopPlayback();
    final directory = await _voicePack.installedDirectory();
    if (directory == null) throw const OfflineVoiceNotInstalledException();
    if (_disposed || requestId != _requestId) return;

    final audio = await _worker.generate(
      modelDirectory: directory.path,
      text: text,
    );
    if (_disposed || requestId != _requestId) return;
    if (audio.samples.isEmpty || audio.sampleRate <= 0) {
      throw StateError('Sherpa produced no audio.');
    }

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
    await _voicePack.dispose();
  }
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
    required String text,
  }) async {
    if (_disposed) throw StateError('The Sherpa worker is closed.');
    final existingStartupError = _startupError;
    if (existingStartupError != null) throw existingStartupError;
    await _ensureStarted(modelDirectory);
    if (_disposed) throw StateError('The Sherpa worker is closed.');
    final startupError = _startupError;
    if (startupError != null) throw startupError;
    final requestId = ++_nextRequestId;
    final completer = Completer<_SherpaAudio>();
    _pending[requestId] = completer;
    _commands!.send({'type': 'generate', 'id': requestId, 'text': text});
    return completer.future;
  }

  Future<void> _ensureStarted(String modelDirectory) {
    final starting = _starting;
    if (starting != null) return starting;
    if (_commands != null) return Future.value();
    final future = _start(modelDirectory);
    _starting = future;
    return future.whenComplete(() {
      if (identical(_starting, future)) _starting = null;
    });
  }

  Future<void> _start(String modelDirectory) async {
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
        'modelDirectory': modelDirectory,
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
  try {
    sherpa_onnx.initBindings();
    final directory = setup['modelDirectory']! as String;
    String path(String name) => p.join(directory, name);
    tts = sherpa_onnx.OfflineTts(
      sherpa_onnx.OfflineTtsConfig(
        model: sherpa_onnx.OfflineTtsModelConfig(
          vits: sherpa_onnx.OfflineTtsVitsModelConfig(
            model: path('model.int8.onnx'),
            lexicon: path('lexicon.txt'),
            tokens: path('tokens.txt'),
          ),
          numThreads: setup['numThreads']! as int,
          debug: false,
          provider: 'cpu',
        ),
        ruleFsts: '${path('date.fst')},${path('number.fst')}',
        maxNumSenetences: 1,
      ),
    );
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
        final audio = tts!.generateWithConfig(
          text: message['text'] as String,
          config: const sherpa_onnx.OfflineTtsGenerationConfig(
            sid: 0,
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
  final dataLength = samples.length * bytesPerSample;
  final output = Uint8List(headerSize + dataLength);
  final data = ByteData.view(output.buffer);

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
    final sample = samples[index].clamp(-1.0, 1.0);
    final pcm = sample < 0
        ? (sample * 32768).round()
        : (sample * 32767).round();
    data.setInt16(headerSize + index * bytesPerSample, pcm, Endian.little);
  }
  return output;
}
