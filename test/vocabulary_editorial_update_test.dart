import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/database/vocabulary_lesson_content.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/models/learner_profile.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/repositories/backup_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:mylanguageapp/services/review_scheduler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const lessons = SqliteLessonRepository();
  const progress = SqliteProgressRepository();
  const backups = SqliteBackupRepository();
  late Directory directory;
  late String path;

  setUp(() async {
    await LocalDatabase.close();
    directory = await Directory.systemTemp.createTemp('vocabulary_editorial_');
    path = '${directory.path}/test.db';
    LocalDatabase.useDatabasePathForTesting(path);
    await LocalDatabase.initialize();
    await const SqliteLearnerRepository().save(
      const LearnerProfile(name: 'Mei', hskLevel: 4, dailyWordTarget: 10),
    );
  });

  tearDown(() async {
    await LocalDatabase.close();
    LocalDatabase.useDatabasePathForTesting(inMemoryDatabasePath);
    await directory.delete(recursive: true);
  });

  Future<({int cardId, int lessonId, int customId})> legacyFixture() async {
    final db = await LocalDatabase.ensureInitialized();
    final card = (await db.query(
      'cards',
      where: 'chinese = ?',
      whereArgs: ['俩'],
    )).single;
    final cardId = card['id'] as int;
    await db.update(
      'cards',
      {
        'pinyin': 'liǎng',
        'english_meaning': '(colloquial) two (people)',
        'correct_answer': '(colloquial) two (people)',
        'example_sentence_pinyin': 'Wǒ men liǎng shì péng you.',
        'quiz_options': jsonEncode([
          '(colloquial) two (people)',
          'both',
          'water',
          'table',
        ]),
      },
      where: 'id = ?',
      whereArgs: [cardId],
    );
    final member = (await db.query(
      'lesson_cards',
      where: 'card_id = ?',
      whereArgs: [cardId],
    )).first;
    final lessonId = member['lesson_id'] as int;
    final lesson = (await lessons.findById(lessonId))!;
    await lessons.saveGenerated(lesson);
    final customId = (await lessons.topics())
        .firstWhere((topic) => topic.isUserGenerated)
        .id;
    final session = await progress.startSession(lessonId);
    final now = DateTime.utc(2026, 10, 10, 2);
    await progress.recordReview(
      review: ReviewRecord(
        id: 0,
        cardId: cardId,
        sessionId: session.id,
        reviewedAt: now,
        rating: ReviewRating.hard,
        wasCorrect: true,
      ),
      progress: scheduleCardReview(
        cardId: cardId,
        reviewedAt: now,
        rating: ReviewRating.hard,
      ),
    );
    await progress.updateSession(
      LessonSession(
        id: session.id,
        lessonId: lessonId,
        startedAt: session.startedAt,
        currentCardIndex: 1,
        cardsReviewed: 1,
        correctAnswers: 1,
      ),
    );
    return (cardId: cardId, lessonId: lessonId, customId: customId);
  }

  Future<Map<String, List<Map<String, Object?>>>> savedTables(
    Database db,
  ) async => {
    for (final table in [
      'lessons',
      'lesson_cards',
      'card_progress',
      'review_history',
      'lesson_sessions',
    ])
      table: await db.query(table, orderBy: 'rowid'),
  };

  test(
    'startup correction preserves shared IDs, sessions, history and custom copies',
    () async {
      final fixture = await legacyFixture();
      final db = await LocalDatabase.ensureInitialized();
      final customCards = await db.query(
        'cards',
        where: 'lesson_id = ?',
        whereArgs: [fixture.customId],
        orderBy: 'id',
      );
      final historicalId = await db.insert('lessons', {
        'lesson_title': 'Archived words',
        'theme': 'Historical',
        'hsk_level': 4,
        'is_archived': 1,
        'is_listed': 0,
        'is_user_generated': 0,
      });
      final historical = Map<String, Object?>.of(
        (await db.query(
          'cards',
          where: 'id = ?',
          whereArgs: [fixture.cardId],
        )).single,
      )..remove('id');
      historical['lesson_id'] = historicalId;
      final historicalCardId = await db.insert('cards', historical);
      final saved = await savedTables(db);
      await db.delete(
        'content_migrations',
        where: 'key = ?',
        whereArgs: [vocabularyEditorialCorrectionsMarker],
      );
      await LocalDatabase.close();
      final upgraded = await LocalDatabase.ensureInitialized();
      expect(await savedTables(upgraded), saved);
      final corrected = (await upgraded.query(
        'cards',
        where: 'id = ?',
        whereArgs: [fixture.cardId],
      )).single;
      expect(corrected['pinyin'], 'liǎ');
      expect(corrected['english_meaning'], 'two; both');
      expect(corrected['correct_answer'], 'two; both');
      expect(corrected['example_sentence_pinyin'], contains('liǎ '));
      expect(
        jsonDecode(corrected['quiz_options'] as String),
        isNot(contains('both')),
      );
      expect(
        await upgraded.query(
          'cards',
          where: 'lesson_id = ?',
          whereArgs: [fixture.customId],
          orderBy: 'id',
        ),
        customCards,
      );
      expect(
        (await upgraded.query(
          'cards',
          where: 'id = ?',
          whereArgs: [historicalCardId],
        )).single['pinyin'],
        'liǎng',
      );
      final cardsAfter = await upgraded.query('cards', orderBy: 'id');
      await LocalDatabase.close();
      final reopened = await LocalDatabase.ensureInitialized();
      expect(await reopened.query('cards', orderBy: 'id'), cardsAfter);
      expect(await savedTables(reopened), saved);
      expect(await reopened.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test('a failed content update rolls back and succeeds on retry', () async {
    final fixture = await legacyFixture();
    final db = await LocalDatabase.ensureInitialized();
    final before = await db.query('cards', orderBy: 'id');
    await db.delete(
      'content_migrations',
      where: 'key = ?',
      whereArgs: [vocabularyEditorialCorrectionsMarker],
    );
    await db.execute(
      "CREATE TRIGGER reject_editorial BEFORE UPDATE ON cards WHEN NEW.chinese = '背' BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END",
    );
    await LocalDatabase.close();
    await expectLater(
      LocalDatabase.initialize(),
      throwsA(isA<DatabaseException>()),
    );
    final probe = await openDatabase(path, singleInstance: false);
    expect(await probe.query('cards', orderBy: 'id'), before);
    expect(
      await probe.query(
        'content_migrations',
        where: 'key = ?',
        whereArgs: [vocabularyEditorialCorrectionsMarker],
      ),
      isEmpty,
    );
    await probe.execute('DROP TRIGGER reject_editorial');
    await probe.close();
    final retried = await LocalDatabase.ensureInitialized();
    expect(
      (await retried.query(
        'cards',
        where: 'id = ?',
        whereArgs: [fixture.cardId],
      )).single['pinyin'],
      'liǎ',
    );
  });

  for (final legacyProvenance in [false, true]) {
    test(
      'old backup retains corrected card identity with legacy provenance $legacyProvenance',
      () async {
        final fixture = await legacyFixture();
        final db = await LocalDatabase.ensureInitialized();
        final saved = await savedTables(db);
        final customCards = await db.query(
          'cards',
          where: 'lesson_id = ?',
          whereArgs: [fixture.customId],
          orderBy: 'id',
        );
        final document =
            jsonDecode(utf8.decode(await backups.exportBackup()))
                as Map<String, dynamic>;
        if (legacyProvenance) {
          for (final row in document['data']['lessons'] as List) {
            (row as Map).remove('is_user_generated');
          }
        }
        // The correction marker is already present on this installation. Restore
        // must still upgrade the older text before reusing the shared cards.
        await backups.restoreBackup(
          Uint8List.fromList(utf8.encode(jsonEncode(document))),
        );
        final restored = await LocalDatabase.ensureInitialized();
        final corrected = (await restored.query(
          'cards',
          where: 'id = ?',
          whereArgs: [fixture.cardId],
        )).single;
        expect(corrected['pinyin'], 'liǎ');
        expect(await savedTables(restored), saved);
        expect(
          await restored.query(
            'cards',
            where: 'lesson_id = ?',
            whereArgs: [fixture.customId],
            orderBy: 'id',
          ),
          customCards,
        );
        expect(await restored.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      },
    );
  }
}
