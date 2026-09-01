import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDirectory;
  late Directory supportDirectory;
  late Directory documentsDirectory;

  setUp(() async {
    await LocalDatabase.close();
    LocalDatabase.useDatabasePathForTesting(null);
    testDirectory = await Directory.systemTemp.createTemp(
      'tingshuo_database_path_test_',
    );
    supportDirectory = Directory(p.join(testDirectory.path, 'support'));
    documentsDirectory = Directory(p.join(testDirectory.path, 'documents'));
    await documentsDirectory.create(recursive: true);
    LocalDatabase.useDatabaseDirectoryProvidersForTesting(
      support: () async => supportDirectory,
      documents: () async => documentsDirectory,
    );
  });

  tearDown(() async {
    await LocalDatabase.close();
    LocalDatabase.useDatabaseDirectoryProvidersForTesting();
    LocalDatabase.useDatabasePathForTesting(null);
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('uses the application support directory for a new database', () async {
    final path = await LocalDatabase.databasePath();

    expect(path, p.join(supportDirectory.path, 'local_app.db'));
    expect(await supportDirectory.exists(), isTrue);
    expect(path, isNot(p.join(Directory.current.path, 'local_app.db')));
  });

  test('migrates the legacy database and every SQLite sidecar', () async {
    final legacyPath = p.join(documentsDirectory.path, 'local_app.db');
    final expectedContents = <String, String>{
      legacyPath: 'database',
      '$legacyPath-wal': 'write-ahead log',
      '$legacyPath-shm': 'shared memory',
      '$legacyPath-journal': 'rollback journal',
    };
    for (final entry in expectedContents.entries) {
      await File(entry.key).writeAsString(entry.value);
    }

    final destinationPath = await LocalDatabase.databasePath();

    for (final entry in expectedContents.entries) {
      final suffix = entry.key.substring(legacyPath.length);
      expect(await File('$destinationPath$suffix').readAsString(), entry.value);
      expect(await File(entry.key).exists(), isFalse);
    }
    expect(await Directory('$destinationPath.migration').exists(), isFalse);
  });

  test('keeps an existing support database authoritative', () async {
    var documentsDirectoryRequested = false;
    LocalDatabase.useDatabaseDirectoryProvidersForTesting(
      support: () async => supportDirectory,
      documents: () async {
        documentsDirectoryRequested = true;
        return documentsDirectory;
      },
    );
    await supportDirectory.create(recursive: true);
    final destinationPath = p.join(supportDirectory.path, 'local_app.db');
    final legacyPath = p.join(documentsDirectory.path, 'local_app.db');
    await File(destinationPath).writeAsString('current database');
    await File(legacyPath).writeAsString('legacy database');
    await File('$legacyPath-wal').writeAsString('legacy write-ahead log');

    expect(await LocalDatabase.databasePath(), destinationPath);
    expect(await File(destinationPath).readAsString(), 'current database');
    expect(await File(legacyPath).readAsString(), 'legacy database');
    expect(await File('$legacyPath-wal').exists(), isTrue);
    expect(documentsDirectoryRequested, isFalse);
  });

  test('leaves legacy data intact when migration cannot complete', () async {
    final legacyPath = p.join(documentsDirectory.path, 'local_app.db');
    final destinationPath = p.join(supportDirectory.path, 'local_app.db');
    await File(legacyPath).writeAsString('legacy database');
    await Directory('$legacyPath-wal').create();

    await expectLater(
      LocalDatabase.databasePath(),
      throwsA(isA<FileSystemException>()),
    );

    expect(await File(legacyPath).readAsString(), 'legacy database');
    expect(await File(destinationPath).exists(), isFalse);
    expect(await Directory('$destinationPath.migration').exists(), isFalse);
  });

  test('does not fall back to the process working directory', () async {
    LocalDatabase.useDatabaseDirectoryProvidersForTesting(
      support: () async => throw StateError('support unavailable'),
      documents: () async => fail('documents should not be queried'),
    );

    await expectLater(
      LocalDatabase.databasePath(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'support unavailable',
        ),
      ),
    );
  });
}
