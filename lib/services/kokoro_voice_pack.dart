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
      final resumableBytes = installed ? 0 : await _resumableArchiveBytes();
      final status = installed
          ? const OfflineVoiceStatus.ready(engine: PronunciationEngine.kokoro)
          : OfflineVoiceStatus.notInstalled(
              engine: PronunciationEngine.kokoro,
              downloadedBytes: resumableBytes,
              totalBytes: archiveBytes,
              message: resumableBytes > 0
                  ? 'The last download was interrupted; '
                      '${(resumableBytes / (1000 * 1000)).toStringAsFixed(1)} '
                      'MB can be reused.'
                  : null,
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
    final archive = File('${target.path}.download.tar.bz2');
    if (await staging.exists()) await staging.delete(recursive: true);
    // A partial archive from an interrupted attempt is deliberately kept so
    // the download can resume; _downloadArchive decides how to reuse it.
    await staging.create(recursive: true);

    final client = _clientFactory();
    _activeClient = client;
    try {
      final downloadedBytes = await _downloadArchive(client, archive);

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
      final resumableBytes = await _resumableArchiveBytes();
      if (error is FormatException || resumableBytes == 0) {
        // A failed integrity check means the bytes on disk are unusable, but a
        // truncated archive from a dropped connection is kept so the next
        // attempt can resume instead of restarting the 147 MB download.
        if (await archive.exists()) await archive.delete();
      }
      _emit(
        OfflineVoiceStatus(
          state: OfflineVoiceState.failed,
          engine: PronunciationEngine.kokoro,
          downloadedBytes: resumableBytes,
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

  /// Downloads the archive, resuming a previous partial attempt with an HTTP
  /// Range request so an interrupted mobile connection does not restart the
  /// 147 MB download from scratch.
  Future<int> _downloadArchive(http.Client client, File archive) async {
    var resumeFrom = 0;
    if (await archive.exists()) {
      final existingBytes = await archive.length();
      if (existingBytes >= archiveBytes) {
        // A previous attempt may have finished downloading before failing;
        // let the integrity check decide whether the bytes are usable.
        return existingBytes;
      }
      resumeFrom = existingBytes;
    }

    final resuming = resumeFrom > 0;
    _emitProgress(downloadedBytes: resumeFrom, message: 'Downloading Kokoro…');
    final request = http.Request('GET', _archiveUri);
    if (resuming) request.headers['range'] = 'bytes=$resumeFrom-';
    final response = await client.send(request);

    if (resuming &&
        response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
      // The partial file no longer matches the upstream resource; start over.
      await archive.delete();
      return _downloadArchive(client, archive);
    }
    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      throw HttpException(
        'Voice download failed with HTTP ${response.statusCode}.',
        uri: request.url,
      );
    }
    final append =
        resuming && response.statusCode == HttpStatus.partialContent;
    if (append) {
      final declaredStart = _rangeStart(response.headers['content-range']);
      if (declaredStart != resumeFrom) {
        // The server cannot continue from our offset; start over.
        await archive.delete();
        return _downloadArchive(client, archive);
      }
    }

    final sink = archive.openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );
    // A non-resumed response rewrites the file from scratch, so the counter
    // restarts at zero unless we are appending to the partial archive.
    var downloadedBytes = append ? resumeFrom : 0;
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
    return downloadedBytes;
  }

  int? _rangeStart(String? contentRange) {
    if (contentRange == null) return null;
    final match = RegExp(
      r'^bytes (\d+)-\d+/\d+$',
    ).firstMatch(contentRange.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Bytes of a partial archive that a retry can continue from.
  Future<int> _resumableArchiveBytes() async {
    try {
      final archive = File('${(await voiceDirectory()).path}.download.tar.bz2');
      if (!await archive.exists()) return 0;
      final length = await archive.length();
      return length > 0 && length < archiveBytes ? length : 0;
    } catch (_) {
      return 0;
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
