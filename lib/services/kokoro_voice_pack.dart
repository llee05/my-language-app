import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/learning_progress.dart';
import 'pronunciation_service.dart';

const kokoroArchiveBytes = 147031220;
const kokoroInstalledBytes = 215323301;
const kokoroVoicePackDirectoryName = 'kokoro-int8-multi-lang-v1_1';

const _archiveName = '$kokoroVoicePackDirectoryName.tar.bz2';
const _officialArchiveSha256 =
    'a1e94694776049035c4f2c6529f003aaece993c76aae9a78995831c3c4dcafc6';
const _archiveUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
    'tts-models/$_archiveName';
const _completeMarkerName = '.complete';

const kokoroRequiredFileSizes = <String, int>{
  'model.int8.onnx': 114299010,
  'voices.bin': 53790720,
  'tokens.txt': 1111,
  'lexicon-us-en.txt': 5956885,
  'lexicon-zh.txt': 2119465,
  'phone-zh.fst': 88630,
  'date-zh.fst': 59154,
  'number-zh.fst': 64482,
  'LICENSE': 11358,
  'espeak-ng-data/phontab': 55796,
  'espeak-ng-data/phonindex': 39074,
  'espeak-ng-data/phondata': 550424,
  'espeak-ng-data/intonations': 2040,
};

typedef VoiceSupportDirectoryProvider = Future<Directory> Function();
typedef VoiceArchiveExtractor =
    Future<void> Function(String archivePath, String outputPath);

class KokoroVoicePackInstaller {
  KokoroVoicePackInstaller({
    VoiceSupportDirectoryProvider? supportDirectoryProvider,
    http.Client Function()? clientFactory,
    VoiceArchiveExtractor? archiveExtractor,
    Uri? archiveUri,
    this.archiveBytes = kokoroArchiveBytes,
    this.archiveSha256 = _officialArchiveSha256,
  }) : _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory,
       _clientFactory = clientFactory ?? http.Client.new,
       _archiveExtractor = archiveExtractor ?? _extractArchive,
       _archiveUri = archiveUri ?? Uri.parse(_archiveUrl);

  final VoiceSupportDirectoryProvider _supportDirectoryProvider;
  final http.Client Function() _clientFactory;
  final VoiceArchiveExtractor _archiveExtractor;
  final Uri _archiveUri;
  final int archiveBytes;
  final String archiveSha256;
  final StreamController<OfflineVoiceStatus> _updates =
      StreamController<OfflineVoiceStatus>.broadcast(sync: true);

  Future<void>? _installFuture;
  http.Client? _activeClient;
  OfflineVoiceStatus _lastStatus = const OfflineVoiceStatus.notInstalled(
    engine: PronunciationEngine.kokoro,
    totalBytes: kokoroArchiveBytes,
  );
  bool _disposed = false;

  Stream<OfflineVoiceStatus> get updates => _updates.stream;

  Future<Directory> voiceDirectory() async {
    final support = await _supportDirectoryProvider();
    return Directory(
      p.join(support.path, 'ting_shuo', 'tts', kokoroVoicePackDirectoryName),
    );
  }

  Future<OfflineVoiceStatus> check() async {
    if (_installFuture != null) return _lastStatus;
    try {
      final directory = await voiceDirectory();
      final installed = await _isComplete(directory);
      final status = installed
          ? const OfflineVoiceStatus.ready(engine: PronunciationEngine.kokoro)
          : OfflineVoiceStatus.notInstalled(
              engine: PronunciationEngine.kokoro,
              totalBytes: archiveBytes,
            );
      _emit(status);
      return status;
    } catch (_) {
      final status = const OfflineVoiceStatus(
        state: OfflineVoiceState.failed,
        engine: PronunciationEngine.kokoro,
        message: 'The Kokoro voice status could not be checked.',
      );
      _emit(status);
      return status;
    }
  }

  Future<Directory?> installedDirectory() async {
    final directory = await voiceDirectory();
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
    final target = await voiceDirectory();
    if (await _isComplete(target)) {
      _emit(const OfflineVoiceStatus.ready(engine: PronunciationEngine.kokoro));
      return;
    }

    final staging = Directory('${target.path}.installing');
    final archive = File('${target.path}.download');
    if (await staging.exists()) await staging.delete(recursive: true);
    if (await archive.exists()) await archive.delete();
    await staging.create(recursive: true);

    final client = _clientFactory();
    _activeClient = client;
    try {
      _emitProgress(downloadedBytes: 0, message: 'Downloading Kokoro…');
      final request = http.Request('GET', _archiveUri);
      final response = await client.send(request);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Voice download failed with HTTP ${response.statusCode}.',
          uri: request.url,
        );
      }

      final sink = archive.openWrite();
      var downloadedBytes = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          _emitProgress(
            downloadedBytes: downloadedBytes,
            message: 'Downloading Kokoro…',
          );
        }
      } finally {
        await sink.close();
      }
      if (downloadedBytes != archiveBytes) {
        throw FileSystemException(
          'The downloaded Kokoro archive has an unexpected size.',
          archive.path,
        );
      }

      _emitProgress(
        downloadedBytes: downloadedBytes,
        message: 'Verifying Kokoro…',
      );
      final digest = await sha256.bind(archive.openRead()).first;
      if (digest.toString() != archiveSha256) {
        throw const FormatException(
          'The downloaded Kokoro archive failed its integrity check.',
        );
      }

      _emitProgress(
        downloadedBytes: downloadedBytes,
        message: 'Installing Kokoro…',
      );
      await _archiveExtractor(archive.path, staging.path);
      final extracted = Directory(
        p.join(staging.path, kokoroVoicePackDirectoryName),
      );
      if (!await _hasRequiredFiles(extracted)) {
        throw const FormatException(
          'The downloaded Kokoro archive is missing required files.',
        );
      }
      await File(p.join(extracted.path, _completeMarkerName)).writeAsString(
        'archive=$_archiveName\nsha256=$archiveSha256\n',
        flush: true,
      );

      if (await target.exists()) await target.delete(recursive: true);
      await extracted.rename(target.path);
      if (await staging.exists()) await staging.delete(recursive: true);
      if (await archive.exists()) await archive.delete();
      _emit(const OfflineVoiceStatus.ready(engine: PronunciationEngine.kokoro));
    } catch (error) {
      if (await staging.exists()) await staging.delete(recursive: true);
      if (await archive.exists()) await archive.delete();
      _emit(
        OfflineVoiceStatus(
          state: OfflineVoiceState.failed,
          engine: PronunciationEngine.kokoro,
          totalBytes: archiveBytes,
          message: _friendlyDownloadError(error),
        ),
      );
      rethrow;
    } finally {
      if (identical(_activeClient, client)) _activeClient = null;
      client.close();
    }
  }

  void _emitProgress({required int downloadedBytes, required String message}) {
    _emit(
      OfflineVoiceStatus(
        state: OfflineVoiceState.downloading,
        engine: PronunciationEngine.kokoro,
        downloadedBytes: downloadedBytes,
        totalBytes: archiveBytes,
        currentFile: _archiveName,
        message: message,
      ),
    );
  }

  Future<bool> _isComplete(Directory directory) async {
    final marker = File(p.join(directory.path, _completeMarkerName));
    if (!await marker.exists()) return false;
    final contents = await marker.readAsString();
    if (!contents.contains(_archiveName) || !contents.contains(archiveSha256)) {
      return false;
    }
    return _hasRequiredFiles(directory);
  }

  Future<bool> _hasRequiredFiles(Directory directory) async {
    for (final entry in kokoroRequiredFileSizes.entries) {
      final file = File(p.join(directory.path, entry.key));
      if (!await file.exists() || await file.length() != entry.value) {
        return false;
      }
    }
    return true;
  }

  String _friendlyDownloadError(Object error) {
    if (error is SocketException ||
        error is HttpException ||
        error is http.ClientException) {
      return 'The Kokoro download could not connect. Check your internet and try again.';
    }
    if (error is FileSystemException) {
      return 'Kokoro could not be saved. It needs about 600 MB of temporary free space.';
    }
    if (error is FormatException) {
      return 'The Kokoro download was incomplete or corrupted. Please try again.';
    }
    return 'Kokoro could not be installed. Please try again.';
  }

  void _emit(OfflineVoiceStatus status) {
    _lastStatus = status;
    if (!_disposed && !_updates.isClosed) _updates.add(status);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _activeClient?.close();
    await _updates.close();
  }
}

Future<void> _extractArchive(String archivePath, String outputPath) =>
    Isolate.run(() => extractFileToDisk(archivePath, outputPath));
