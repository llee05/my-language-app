import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalDatabase {
  LocalDatabase._();

  static Database? _database;
  static const String _dbName = 'local_app.db';
  static const String _tableName = 'app_data';

  static Future<Database> ensureInitialized() async {
    if (_database != null) {
      return _database!;
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    Directory documentsDirectory;
    try {
      documentsDirectory = await getApplicationDocumentsDirectory();
    } catch (_) {
      documentsDirectory = Directory.current;
    }

    final databasePath = p.join(documentsDirectory.path, _dbName);

    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT NOT NULL UNIQUE,
            value TEXT
          )
        ''');
      },
    );

    return _database!;
  }

  static Future<void> resetForTesting() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final database = _database;
    if (database != null) {
      await database.close();
      _database = null;
    }

    Directory documentsDirectory;
    try {
      documentsDirectory = await getApplicationDocumentsDirectory();
    } catch (_) {
      documentsDirectory = Directory.current;
    }

    final databasePath = p.join(documentsDirectory.path, _dbName);
    await databaseFactory.deleteDatabase(databasePath);
  }

  static Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}
