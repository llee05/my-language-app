import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../local_database.dart';
import '../models/learner_profile.dart';
import '../models/lesson.dart';
import 'development_repository.dart';
import 'learner_repository.dart';
import 'lesson_repository.dart';

class SqliteLearnerRepository implements LearnerRepository {
  const SqliteLearnerRepository();

  static const _profileKey = 'learner_profile';

  @override
  Future<LearnerProfile?> load() async {
    final db = await LocalDatabase.ensureInitialized();
    final rows = await db.query(
      'app_data',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_profileKey],
      limit: 1,
    );
    if (rows.isEmpty || rows.single['value'] == null) return null;

    try {
      final json = jsonDecode(rows.single['value'] as String);
      if (json is! Map<String, dynamic>) return null;
      final name = json['name'];
      final hskLevel = json['hskLevel'];
      final dailyWordTarget = json['dailyWordTarget'];
      if (name is! String ||
          name.trim().isEmpty ||
          hskLevel is! int ||
          hskLevel < 1 ||
          hskLevel > 6 ||
          dailyWordTarget is! int ||
          dailyWordTarget < 1) {
        return null;
      }
      return LearnerProfile(
        name: name.trim(),
        hskLevel: hskLevel,
        dailyWordTarget: dailyWordTarget,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(LearnerProfile profile) async {
    final db = await LocalDatabase.ensureInitialized();
    await db.insert('app_data', {
      'key': _profileKey,
      'value': jsonEncode({
        'name': profile.name,
        'hskLevel': profile.hskLevel,
        'dailyWordTarget': profile.dailyWordTarget,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clear() async {
    final db = await LocalDatabase.ensureInitialized();
    await db.delete('app_data', where: 'key = ?', whereArgs: [_profileKey]);
  }
}

class SqliteLessonRepository implements LessonRepository {
  const SqliteLessonRepository();

  @override
  Future<List<LessonSummary>> topics() async {
    final db = await LocalDatabase.ensureInitialized();
    final rows = await db.query(
      'lessons',
      columns: ['id', 'lesson_title', 'theme', 'hsk_level'],
      orderBy: 'id DESC',
    );
    return rows.map(_summaryFromRow).toList(growable: false);
  }

  @override
  Future<Lesson?> findGenerated({
    required String theme,
    required int hskLevel,
  }) async {
    final db = await LocalDatabase.ensureInitialized();
    final lessons = await db.query(
      'lessons',
      columns: ['id', 'lesson_title', 'theme', 'hsk_level'],
      where: 'theme = ? COLLATE NOCASE AND hsk_level = ?',
      whereArgs: [theme.trim(), hskLevel],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (lessons.isEmpty) return null;

    final summary = _summaryFromRow(lessons.single);
    final rows = await db.query(
      'cards',
      where: 'lesson_id = ?',
      whereArgs: [summary.id],
      orderBy: 'id ASC',
    );
    if (rows.isEmpty) return null;
    return Lesson(
      summary: summary,
      cards: rows.map(_cardFromRow).toList(growable: false),
    );
  }

  @override
  Future<void> saveGenerated(Lesson lesson) async {
    final db = await LocalDatabase.ensureInitialized();
    await db.transaction((txn) async {
      final lessonId = await txn.insert('lessons', {
        'lesson_title': lesson.summary.title,
        'theme': lesson.summary.theme,
        'hsk_level': lesson.summary.hskLevel,
      });
      for (final card in lesson.cards) {
        await txn.insert('cards', {
          'lesson_id': lessonId,
          'chinese': card.chinese,
          'pinyin': card.pinyin,
          'english_meaning': card.englishMeaning,
          'part_of_speech': card.partOfSpeech,
          'hsk_level': lesson.summary.hskLevel,
          'example_sentence_chinese': card.exampleChinese,
          'example_sentence_pinyin': card.examplePinyin,
          'example_sentence_english': card.exampleEnglish,
          'quiz_options': jsonEncode(card.quizOptions),
          'correct_answer': card.englishMeaning,
        });
      }
    });
  }

  LessonSummary _summaryFromRow(Map<String, Object?> row) => LessonSummary(
    id: row['id'] as int,
    title: row['lesson_title'] as String,
    theme: row['theme'] as String,
    hskLevel: row['hsk_level'] as int,
  );

  Flashcard _cardFromRow(Map<String, Object?> row) => Flashcard(
    chinese: row['chinese'] as String,
    pinyin: row['pinyin'] as String,
    englishMeaning: row['english_meaning'] as String,
    partOfSpeech: row['part_of_speech'] as String,
    exampleChinese: row['example_sentence_chinese'] as String,
    examplePinyin: row['example_sentence_pinyin'] as String,
    exampleEnglish: row['example_sentence_english'] as String,
    quizOptions: (jsonDecode(row['quiz_options'] as String) as List)
        .cast<String>(),
  );
}

class SqliteDevelopmentRepository implements DevelopmentRepository {
  const SqliteDevelopmentRepository();

  @override
  Future<String> databasePath() => LocalDatabase.databasePath();

  @override
  Future<void> resetAllData() => LocalDatabase.resetAllData();
}
