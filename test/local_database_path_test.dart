import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

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

  test('migrates a consistent snapshot of a legacy WAL database', () async {
    final legacyPath = p.join(documentsDirectory.path, 'local_app.db');
    final legacyDatabase = sqlite.sqlite3.open(legacyPath);
    addTearDown(legacyDatabase.close);
    legacyDatabase.execute('PRAGMA journal_mode = WAL');
    legacyDatabase.execute('PRAGMA wal_autocheckpoint = 0');
    legacyDatabase.execute('CREATE TABLE cards (word TEXT NOT NULL)');
    legacyDatabase.execute("INSERT INTO cards VALUES ('你好')");
    expect(await File('$legacyPath-wal').exists(), isTrue);

    final destinationPath = await LocalDatabase.databasePath();

    final migratedDatabase = sqlite.sqlite3.open(
      destinationPath,
      mode: sqlite.OpenMode.readOnly,
    );
    addTearDown(migratedDatabase.close);
    expect(
      migratedDatabase.select('SELECT word FROM cards').single.columnAt(0),
      '你好',
    );
    expect(await File(legacyPath).exists(), isFalse);
    expect(await File('$legacyPath-wal').exists(), isFalse);
    expect(await Directory('$destinationPath.migration').exists(), isFalse);
    expect(await File('$destinationPath.legacy-cleanup').exists(), isFalse);
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
      throwsA(isA<sqlite.SqliteException>()),
    );

    expect(await File(legacyPath).readAsString(), 'legacy database');
    expect(await File(destinationPath).exists(), isFalse);
    expect(await Directory('$destinationPath.migration').exists(), isFalse);
  });

  test('retries interrupted legacy cleanup after activation', () async {
    await supportDirectory.create(recursive: true);
    final destinationPath = p.join(supportDirectory.path, 'local_app.db');
    final legacyPath = p.join(documentsDirectory.path, 'local_app.db');
    await File(destinationPath).writeAsString('validated destination');
    await File(legacyPath).writeAsString('legacy database');
    await File('$legacyPath-wal').writeAsString('legacy write-ahead log');
    await File('$destinationPath.legacy-cleanup').writeAsString('pending\n');

    expect(await LocalDatabase.databasePath(), destinationPath);

    expect(await File(destinationPath).readAsString(), 'validated destination');
    expect(await File(legacyPath).exists(), isFalse);
    expect(await File('$legacyPath-wal').exists(), isFalse);
    expect(await File('$destinationPath.legacy-cleanup').exists(), isFalse);
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
