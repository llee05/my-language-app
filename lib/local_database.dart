import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database/flashcard_seed.dart';

class LocalDatabase {
  LocalDatabase._();

  static Database? _database;
  static const String _dbName = 'local_app.db';
  static const String _tableName = 'app_data';
  static const String _lessonTable = 'lessons';
  static const String _cardTable = 'cards';

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
        await _createSchema(db);
        await _seedDefaultLessons(db);
      },
      onOpen: (db) async {
        await _createSchema(db);
      },
    );

    await _maybeSeedDefaultLessons(_database!);
    return _database!;
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
    final countRows = await db.rawQuery('SELECT COUNT(*) FROM $_lessonTable');
    final count = countRows.first.values.first as int? ?? 0;
    if (count == 0) {
      await _seedDefaultLessons(db);
    }
  }

  static Future<void> _seedDefaultLessons(Database db) async {
    await db.transaction((txn) async {
      for (final lesson in flashcardLessons) {
        final lessonId = await txn.insert(_lessonTable, {
          'lesson_title': lesson['lesson_title'],
          'theme': lesson['theme'],
          'hsk_level': lesson['hsk_level'],
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
