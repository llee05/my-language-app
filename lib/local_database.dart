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

  static Future<String> databasePath() async {
    Directory documentsDirectory;
    try {
      documentsDirectory = await getApplicationDocumentsDirectory();
    } catch (_) {
      documentsDirectory = Directory.current;
    }
    return p.join(documentsDirectory.path, _dbName);
  }

  static Future<Database> ensureInitialized() async {
    if (_database != null) {
      return _database!;
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    _database = await openDatabase(
      await databasePath(),
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

  static Future<List<Map<String, dynamic>>> lessonTopics() async {
    final db = await ensureInitialized();
    return db.query(
      _lessonTable,
      columns: ['id', 'lesson_title', 'theme', 'hsk_level'],
      orderBy: 'id DESC',
    );
  }

  /// Returns the newest matching lesson, avoiding another AI request.
  static Future<Map<String, dynamic>?> generatedLesson({
    required String theme,
    required int hskLevel,
  }) async {
    final db = await ensureInitialized();
    final lessons = await db.query(
      _lessonTable,
      columns: ['id', 'lesson_title'],
      where: 'LOWER(theme) = LOWER(?) AND hsk_level = ?',
      whereArgs: [theme.trim(), hskLevel],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (lessons.isEmpty) return null;

    final lesson = lessons.single;
    final rows = await db.query(
      _cardTable,
      where: 'lesson_id = ?',
      whereArgs: [lesson['id']],
      orderBy: 'id ASC',
    );
    if (rows.isEmpty) return null;

    return {
      'title': lesson['lesson_title'],
      'cards': [
        for (final row in rows)
          {...row, 'quiz_options': jsonDecode(row['quiz_options'] as String)},
      ],
    };
  }

  static Future<void> saveGeneratedLesson({
    required String title,
    required String theme,
    required int hskLevel,
    required List<Map<String, dynamic>> cards,
  }) async {
    final db = await ensureInitialized();
    await db.transaction((txn) async {
      final lessonId = await txn.insert(_lessonTable, {
        'lesson_title': title,
        'theme': theme,
        'hsk_level': hskLevel,
      });
      for (final card in cards) {
        await txn.insert(_cardTable, {
          'lesson_id': lessonId,
          'chinese': card['chinese'],
          'pinyin': card['pinyin'],
          'english_meaning': card['english_meaning'],
          'part_of_speech': card['part_of_speech'] ?? '',
          'hsk_level': hskLevel,
          'example_sentence_chinese': card['example_sentence_chinese'] ?? '',
          'example_sentence_pinyin': card['example_sentence_pinyin'] ?? '',
          'example_sentence_english': card['example_sentence_english'] ?? '',
          'quiz_options': jsonEncode(card['quiz_options'] ?? const []),
          'correct_answer': card['english_meaning'],
        });
      }
    });
  }

  static Future<Map<String, dynamic>?> learnerProfile() async {
    final db = await ensureInitialized();
    final rows = await db.query(
      _tableName,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['learner_profile'],
      limit: 1,
    );
    if (rows.isEmpty || rows.single['value'] == null) return null;

    try {
      return Map<String, dynamic>.from(
        jsonDecode(rows.single['value'] as String) as Map,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static Future<void> saveLearnerProfile(Map<String, dynamic> profile) async {
    final db = await ensureInitialized();
    await db.insert(_tableName, {
      'key': 'learner_profile',
      'value': jsonEncode(profile),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> clearLearnerProfile() async {
    final db = await ensureInitialized();
    await db.delete(
      _tableName,
      where: 'key = ?',
      whereArgs: ['learner_profile'],
    );
  }

  static Future<void> resetAllData() async {
    final database = _database;
    _database = null;
    await database?.close();
    await databaseFactory.deleteDatabase(await databasePath());
  }

  static Future<void> resetForTesting() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final database = _database;
    if (database != null) {
      await database.close();
      _database = null;
    }

    await databaseFactory.deleteDatabase(await databasePath());
  }

  static Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}
