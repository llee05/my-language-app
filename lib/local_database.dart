import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'database/flashcard_seed.dart';
import 'database/migrations.dart';

class DatabaseResetInProgressException implements Exception {
  const DatabaseResetInProgressException();

  @override
  String toString() => 'The local database is temporarily unavailable.';
}

typedef DatabaseArtifactDeleter = Future<void> Function(String path);

class LocalDatabase {
  LocalDatabase._();

  static Database? _database;
  static Future<Database>? _initialization;
  static Future<void>? _resetOperation;
  static Future<void>? _closeOperation;
  static int _activeOperations = 0;
  static Completer<void>? _operationsDrained;
  static final Object _leaseKey = Object();
  static const String _dbName = 'local_app.db';
  static const String _tableName = 'app_data';
  static const String _lessonTable = 'lessons';
  static const String _cardTable = 'cards';
  static String? _databasePathOverride;
  static String? _openedDatabasePath;
  static DatabaseArtifactDeleter? _artifactDeleterOverride;

  static void useDatabasePathForTesting(String? path) {
    _databasePathOverride = path;
    if (_database == null && _initialization == null) {
      _openedDatabasePath = null;
    }
  }

  static void useDatabaseArtifactDeleterForTesting(
    DatabaseArtifactDeleter? deleter,
  ) {
    _artifactDeleterOverride = deleter;
  }

  static Future<String> databasePath() async {
    if (_openedDatabasePath case final path?) return path;
    return _resolveDatabasePath();
  }

  static Future<T> use<T>(
    Future<T> Function(Database database) operation,
  ) async {
    final leasedDatabase = Zone.current[_leaseKey];
    if (leasedDatabase is Database) return operation(leasedDatabase);

    if (_resetOperation != null || _closeOperation != null) {
      throw const DatabaseResetInProgressException();
    }

    _activeOperations++;
    try {
      final database = await _ensureInitialized();
      return await runZoned<Future<T>>(
        () => operation(database),
        zoneValues: {_leaseKey: database},
      );
    } finally {
      _activeOperations--;
      if (_activeOperations == 0) {
        final drained = _operationsDrained;
        _operationsDrained = null;
        drained?.complete();
      }
    }
  }

  static Future<void> initialize() => use((_) async {});

  /// Exposes the raw handle for database migration and integration tests.
  /// Production operations should use [use] so resets can wait for them.
  static Future<Database> ensureInitialized() {
    if (_resetOperation != null || _closeOperation != null) {
      return Future.error(const DatabaseResetInProgressException());
    }
    return _ensureInitialized();
  }

  static Future<Database> _ensureInitialized() {
    if (_database case final database?) return Future.value(database);
    if (_initialization case final initialization?) return initialization;

    final initialization = _openAndInitialize();
    _initialization = initialization;
    return initialization;
  }

  static Future<Database> _openAndInitialize() async {
    Database? openedDatabase;
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      openedDatabase = await openDatabase(
        await databasePath(),
        version: databaseSchemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createSchema(db);
          await migrateDatabase(db, fromVersion: 1, toVersion: version);
          await _seedDefaultLessons(db);
        },
        onUpgrade: (db, oldVersion, newVersion) =>
            migrateDatabase(db, fromVersion: oldVersion, toVersion: newVersion),
        onDowngrade: (db, oldVersion, newVersion) => throw StateError(
          'Database downgrade is not supported: $oldVersion → $newVersion.',
        ),
      );

      await _maybeSeedDefaultLessons(openedDatabase);
      await _applyTatoebaExamples(openedDatabase);
      _database = openedDatabase;
      _openedDatabasePath = openedDatabase.path;
      return openedDatabase;
    } catch (_) {
      await openedDatabase?.close();
      rethrow;
    } finally {
      _initialization = null;
    }
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_lessonTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_title TEXT NOT NULL,
        theme TEXT NOT NULL,
        hsk_level INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_cardTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL,
        chinese TEXT NOT NULL,
        pinyin TEXT NOT NULL,
        english_meaning TEXT NOT NULL,
        part_of_speech TEXT NOT NULL,
        hsk_level INTEGER NOT NULL,
        example_sentence_chinese TEXT NOT NULL,
        example_sentence_pinyin TEXT NOT NULL,
        example_sentence_english TEXT NOT NULL,
        quiz_options TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES $_lessonTable (id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _maybeSeedDefaultLessons(Database db) async {
    await _seedDefaultLessons(db);
  }

  static Future<void> _seedDefaultLessons(Database db) async {
    await db.transaction((txn) async {
      final existingRows = await txn.query(
        _lessonTable,
        columns: ['lesson_title'],
        where: 'is_listed = ?',
        whereArgs: [1],
      );
      final existingTitles = existingRows
          .map((row) => row['lesson_title'] as String)
          .toSet();
      for (final lesson in flashcardLessons) {
        final title = lesson['lesson_title'] as String;
        if (existingTitles.contains(title)) continue;
        final lessonId = await txn.insert(_lessonTable, {
          'lesson_title': title,
          'theme': lesson['theme'],
          'hsk_level': lesson['hsk_level'],
          'is_listed': 1,
        });

        final cards = lesson['cards'] as List<dynamic>;
        for (final rawCard in cards) {
          final card = rawCard as Map<String, dynamic>;
          await txn.insert(_cardTable, {
            'lesson_id': lessonId,
            'chinese': card['chinese'],
            'pinyin': card['pinyin'],
            'english_meaning': card['english_meaning'],
            'part_of_speech': card['part_of_speech'],
            'hsk_level': lesson['hsk_level'],
            'example_sentence_chinese': card['example_sentence_chinese'],
            'example_sentence_pinyin': card['example_sentence_pinyin'],
            'example_sentence_english': card['example_sentence_english'],
            'quiz_options': jsonEncode(card['quiz_options']),
            'correct_answer': card['correct_answer'],
          });
        }
      }
    });
  }

  static Future<void> _applyTatoebaExamples(Database db) async {
    const marker = 'tatoeba_examples_v1';
    final applied = await db.query(
      'content_migrations',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [marker],
      limit: 1,
    );
    if (applied.isNotEmpty) return;

    final raw = await rootBundle.loadString(
      'assets/data/tatoeba/flashcard_candidates.json',
    );
    final candidates = jsonDecode(raw) as List<dynamic>;
    final bundledTitles = flashcardLessons
        .map((lesson) => lesson['lesson_title'] as String)
        .toList(growable: false);
    final placeholders = List.filled(bundledTitles.length, '?').join(',');

    await db.transaction((txn) async {
      final lessonRows = await txn.query(
        _lessonTable,
        columns: ['id'],
        where: 'lesson_title IN ($placeholders)',
        whereArgs: bundledTitles,
      );
      final lessonIds = lessonRows
          .map((row) => row['id'] as int)
          .toList(growable: false);
      if (lessonIds.isNotEmpty) {
        final lessonPlaceholders = List.filled(lessonIds.length, '?').join(',');
        for (final rawEntry in candidates) {
          final entry = rawEntry as Map<String, dynamic>;
          final matches = entry['candidates'] as List<dynamic>;
          if (matches.isEmpty) continue;
          final best = matches.first as Map<String, dynamic>;
          await txn.update(
            _cardTable,
            {
              'example_sentence_chinese': best['chinese'] as String,
              'example_sentence_pinyin': '',
              'example_sentence_english': best['english'] as String,
              'example_source': 'Tatoeba',
              'example_source_id': '${best['chineseId']}',
              'example_translation_id': '${best['englishId']}',
            },
            where: 'chinese = ? AND lesson_id IN ($lessonPlaceholders)',
            whereArgs: [entry['target'], ...lessonIds],
          );
        }
      }
      await txn.insert('content_migrations', {
        'key': marker,
        'applied_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  static Future<void> resetAllData() {
    if (_resetOperation case final reset?) return reset;
    if (_closeOperation case final close?) {
      return close.then((_) => resetAllData());
    }

    final reset = _performReset();
    _resetOperation = reset;
    return reset;
  }

  static Future<void> _performReset() async {
    try {
      await _waitForOperationsToDrain();
      await _waitForInitialization();

      final database = _database;
      final path =
          database?.path ?? _openedDatabasePath ?? await _resolveDatabasePath();
      if (database != null) await database.close();
      _database = null;
      _openedDatabasePath = path;

      final deleter = _artifactDeleterOverride ?? _deleteDatabaseArtifacts;
      await deleter(path);
      await _verifyDatabaseArtifactsDeleted(path);
      _openedDatabasePath = null;
    } finally {
      _resetOperation = null;
    }
  }

  static Future<void> resetForTesting() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await resetAllData();
  }

  static Future<void> close() {
    if (_resetOperation case final reset?) return reset;
    if (_closeOperation case final close?) return close;

    final close = _performClose();
    _closeOperation = close;
    return close;
  }

  static Future<void> _performClose() async {
    try {
      await _waitForOperationsToDrain();
      await _waitForInitialization();
      final database = _database;
      if (database != null) await database.close();
      _database = null;
    } finally {
      _closeOperation = null;
    }
  }

  static Future<void> _waitForOperationsToDrain() {
    if (_activeOperations == 0) return Future.value();
    return (_operationsDrained ??= Completer<void>()).future;
  }

  static Future<void> _waitForInitialization() async {
    final initialization = _initialization;
    if (initialization == null) return;
    try {
      await initialization;
    } catch (_) {
      // A reset still removes files left behind by failed initialization.
    }
  }

  static Future<String> _resolveDatabasePath() async {
    if (_databasePathOverride case final path?) return path;

    Directory documentsDirectory;
    try {
      documentsDirectory = await getApplicationDocumentsDirectory();
    } catch (_) {
      documentsDirectory = Directory.current;
    }
    return p.join(documentsDirectory.path, _dbName);
  }

  static List<String> _databaseArtifactPaths(String path) {
    if (path == inMemoryDatabasePath) return const [];
    return ['$path-wal', '$path-shm', '$path-journal', path];
  }

  static Future<void> _deleteDatabaseArtifacts(String path) async {
    for (final artifact in _databaseArtifactPaths(path)) {
      final type = await FileSystemEntity.type(artifact, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.link) {
        throw FileSystemException(
          'Database artifact is not a regular file.',
          artifact,
        );
      }
      await File(artifact).delete();
    }
  }

  static Future<void> _verifyDatabaseArtifactsDeleted(String path) async {
    final remaining = <String>[];
    for (final artifact in _databaseArtifactPaths(path)) {
      final type = await FileSystemEntity.type(artifact, followLinks: false);
      if (type != FileSystemEntityType.notFound) remaining.add(artifact);
    }
    if (remaining.isNotEmpty) {
      throw FileSystemException(
        'Database reset left local data behind: ${remaining.join(', ')}',
        path,
      );
    }
  }
}
