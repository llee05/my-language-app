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
    expect(await File('${target.path}.download').exists(), isFalse);
    expect(updates.last.state, OfflineVoiceState.failed);
    expect(updates.last.message, contains('corrupted'));

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
