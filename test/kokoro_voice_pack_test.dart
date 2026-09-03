import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/services/kokoro_voice_pack.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory supportDirectory;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'tingshuo_kokoro_pack_test_',
    );
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test(
    'downloads, verifies, extracts, and atomically installs Kokoro',
    () async {
      final archiveBytes = <int>[1, 3, 3, 7];
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        expect(request.url, Uri.parse('https://example.test/kokoro.tar.bz2'));
        return http.Response.bytes(archiveBytes, HttpStatus.ok);
      });
      final installer = KokoroVoicePackInstaller(
        supportDirectoryProvider: () async => supportDirectory,
        clientFactory: () => client,
        archiveExtractor: (archivePath, outputPath) async {
          expect(await File(archivePath).readAsBytes(), archiveBytes);
          await _createRequiredPack(outputPath);
        },
        archiveUri: Uri.parse('https://example.test/kokoro.tar.bz2'),
        archiveBytes: archiveBytes.length,
        archiveSha256: sha256.convert(archiveBytes).toString(),
      );
      final updates = <OfflineVoiceStatus>[];
      final subscription = installer.updates.listen(updates.add);

      final firstInstall = installer.install();
      final duplicateInstall = installer.install();
      expect(identical(firstInstall, duplicateInstall), isTrue);
      await firstInstall;

      final directory = await installer.installedDirectory();
      expect(directory, isNotNull);
      expect(await directory!.exists(), isTrue);
      expect(await File(p.join(directory.path, '.complete')).exists(), isTrue);
      expect(requestCount, 1);
      expect(updates.first.engine, PronunciationEngine.kokoro);
      expect(updates.first.state, OfflineVoiceState.downloading);
      expect(updates.last.state, OfflineVoiceState.ready);
      expect((await installer.check()).state, OfflineVoiceState.ready);

      await subscription.cancel();
      await installer.dispose();
    },
  );

  test('rejects a corrupted archive and removes staging files', () async {
    final archiveBytes = <int>[4, 2];
    var extracted = false;
    final installer = KokoroVoicePackInstaller(
      supportDirectoryProvider: () async => supportDirectory,
      clientFactory: () => MockClient(
        (_) async => http.Response.bytes(archiveBytes, HttpStatus.ok),
      ),
      archiveExtractor: (_, _) async => extracted = true,
      archiveUri: Uri.parse('https://example.test/kokoro.tar.bz2'),
      archiveBytes: archiveBytes.length,
      archiveSha256: List.filled(64, '0').join(),
    );
    final updates = <OfflineVoiceStatus>[];
    final subscription = installer.updates.listen(updates.add);

    await expectLater(installer.install(), throwsFormatException);

    final target = await installer.voiceDirectory();
    expect(extracted, isFalse);
    expect(await target.exists(), isFalse);
    expect(await Directory('${target.path}.installing').exists(), isFalse);
    expect(await File('${target.path}.download.tar.bz2').exists(), isFalse);
    expect(updates.last.state, OfflineVoiceState.failed);
    expect(updates.last.message, contains('corrupted'));

    await subscription.cancel();
    await installer.dispose();
  });

  test('reports not-installed before any download', () async {
    final installer = KokoroVoicePackInstaller(
      supportDirectoryProvider: () async => supportDirectory,
      clientFactory: () => fail('No network is expected before an install.'),
    );

    final status = await installer.check();

    expect(status.engine, PronunciationEngine.kokoro);
    expect(status.state, OfflineVoiceState.notInstalled);
    expect(status.totalBytes, kokoroArchiveBytes);
    expect(await installer.installedDirectory(), isNull);

    await installer.dispose();
  });

  test('reports connection failures with a friendly message', () async {
    final installer = KokoroVoicePackInstaller(
      supportDirectoryProvider: () async => supportDirectory,
      clientFactory: () =>
          MockClient((_) async => throw const SocketException('offline')),
      archiveUri: Uri.parse('https://example.test/kokoro.tar.bz2'),
    );
    final updates = <OfflineVoiceStatus>[];
    final subscription = installer.updates.listen(updates.add);

    await expectLater(installer.install(), throwsA(isA<SocketException>()));

    expect(updates.last.state, OfflineVoiceState.failed);
    expect(updates.last.message, contains('could not connect'));
    expect(await installer.installedDirectory(), isNull);

    await subscription.cancel();
    await installer.dispose();
  });

  test('rejects an archive missing required files', () async {
    final archiveBytes = <int>[9, 9];
    String? stagingPath;
    final installer = KokoroVoicePackInstaller(
      supportDirectoryProvider: () async => supportDirectory,
      clientFactory: () => MockClient(
        (_) async => http.Response.bytes(archiveBytes, HttpStatus.ok),
      ),
      archiveExtractor: (archivePath, outputPath) async {
        stagingPath = outputPath;
        final root = Directory(
          p.join(outputPath, kokoroVoicePackDirectoryName),
        );
        await root.create(recursive: true);
        // Write only the first required file; the rest stay missing.
        final entry = kokoroRequiredFileSizes.entries.first;
        final file = File(p.join(root.path, entry.key));
        final handle = await file.open(mode: FileMode.write);
        try {
          await handle.truncate(entry.value);
        } finally {
          await handle.close();
        }
      },
      archiveUri: Uri.parse('https://example.test/kokoro.tar.bz2'),
      archiveBytes: archiveBytes.length,
      archiveSha256: sha256.convert(archiveBytes).toString(),
    );
    final updates = <OfflineVoiceStatus>[];
    final subscription = installer.updates.listen(updates.add);

    await expectLater(installer.install(), throwsFormatException);

    expect(updates.last.state, OfflineVoiceState.failed);
    expect(
      updates.last.message,
      'The Kokoro download was incomplete or corrupted. Please try again.',
    );
    expect(await Directory(stagingPath!).exists(), isFalse);
    expect(await installer.installedDirectory(), isNull);

    await subscription.cancel();
    await installer.dispose();
  });

  test('emits progress while streaming, verifying, and installing', () async {
    final archiveBytes = List<int>.generate(96, (index) => index & 0xFF);
    final installer = KokoroVoicePackInstaller(
      supportDirectoryProvider: () async => supportDirectory,
      clientFactory: () => MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.fromIterable([
            archiveBytes.sublist(0, 48),
            archiveBytes.sublist(48),
          ]),
          HttpStatus.ok,
        ),
      ),
      archiveExtractor: (archivePath, outputPath) async =>
          _createRequiredPack(outputPath),
      archiveUri: Uri.parse('https://example.test/kokoro.tar.bz2'),
      archiveBytes: archiveBytes.length,
      archiveSha256: sha256.convert(archiveBytes).toString(),
    );
    final updates = <OfflineVoiceStatus>[];
    final subscription = installer.updates.listen(updates.add);

    await installer.install();

    final progress = updates
        .where((status) => status.state == OfflineVoiceState.downloading)
        .toList();
    expect(progress.first.downloadedBytes, 0);
    expect(
      progress.map((status) => status.downloadedBytes),
      containsAllInOrder([0, 48, 96]),
    );
    expect(
      updates.map((status) => status.message),
      containsAllInOrder([
        'Downloading Kokoro…',
        'Verifying Kokoro…',
        'Installing Kokoro…',
      ]),
    );
    expect(updates.last.state, OfflineVoiceState.ready);
    expect(
      (await installer.installedDirectory())?.path,
      endsWith(kokoroVoicePackDirectoryName),
    );

    await subscription.cancel();
    await installer.dispose();
  });
}

Future<void> _createRequiredPack(String outputPath) async {
  final root = Directory(p.join(outputPath, kokoroVoicePackDirectoryName));
  for (final entry in kokoroRequiredFileSizes.entries) {
    final file = File(p.join(root.path, entry.key));
    await file.parent.create(recursive: true);
    final handle = await file.open(mode: FileMode.write);
    try {
      await handle.truncate(entry.value);
    } finally {
      await handle.close();
    }
  }
}
