import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/models/learner_profile.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => LocalDatabase.resetForTesting());

  test('builds a bounded tutor snapshot from saved learning data', () async {
    const learners = SqliteLearnerRepository();
    const repository = SqliteTutorContextRepository();
    final now = DateTime.utc(2026, 9, 13, 12);
    await learners.save(
      const LearnerProfile(
        name: 'Private Name',
        hskLevel: 3,
        dailyWordTarget: 10,
      ),
    );
    final db = await LocalDatabase.ensureInitialized();

    final lessonId = await db.insert('lessons', {
      'lesson_title': 'Opinions and feelings',
      'theme': 'Conversation',
      'hsk_level': 3,
      'is_listed': 1,
    });
    final juedeId = await _insertCard(
      db,
      lessonId: lessonId,
      chinese: '觉得',
      pinyin: 'juéde',
      english: 'to feel; to think',
    );
    final renweiId = await _insertCard(
      db,
      lessonId: lessonId,
      chinese: '认为',
      pinyin: 'rènwéi',
      english: 'to believe',
    );
    await _insertProgress(
      db,
      cardId: juedeId,
      mastery: .4,
      incorrectAnswers: 3,
      dueAt: now.subtract(const Duration(days: 1)),
    );
    await _insertProgress(
      db,
      cardId: renweiId,
      mastery: .5,
      incorrectAnswers: 2,
      dueAt: now.add(const Duration(days: 1)),
    );
    for (var index = 0; index < 2; index++) {
      await db.insert('review_history', {
        'learner_id': 1,
        'card_id': renweiId,
        'reviewed_at': now
            .subtract(Duration(minutes: index + 1))
            .toIso8601String(),
        'rating': 0,
        'was_correct': 0,
      });
    }
    await db.insert('lesson_sessions', {
      'learner_id': 1,
      'lesson_id': lessonId,
      'started_at': now.subtract(const Duration(days: 2)).toIso8601String(),
      'completed_at': now
          .subtract(const Duration(days: 1, hours: 23))
          .toIso8601String(),
      'current_card_index': 2,
      'cards_reviewed': 2,
      'correct_answers': 1,
    });

    final snapshot = await repository.load(asOf: now);
    final promptData =
        jsonDecode(snapshot.toPromptJson()) as Map<String, dynamic>;

    expect(snapshot.hskLevel, 3);
    expect(snapshot.weakWords.map((word) => word.chinese), ['觉得', '认为']);
    expect(snapshot.dueCards.map((word) => word.chinese), ['觉得']);
    expect(snapshot.recentMistakes, hasLength(1));
    expect(snapshot.recentMistakes.single.chinese, '认为');
    expect(snapshot.recentMistakes.single.mistakeCount, 2);
    expect(snapshot.lessonHistory.single.title, 'Opinions and feelings');
    expect(snapshot.lessonHistory.single.cardsReviewed, 2);
    expect(promptData, isNot(contains('name')));
    expect(snapshot.toPromptJson(), isNot(contains('Private Name')));
  });

  test('caps every repeated snapshot section', () async {
    const learners = SqliteLearnerRepository();
    const repository = SqliteTutorContextRepository();
    final now = DateTime.utc(2026, 9, 13, 12);
    await learners.save(
      const LearnerProfile(name: 'Learner', hskLevel: 4, dailyWordTarget: 10),
    );
    final db = await LocalDatabase.ensureInitialized();

    for (var index = 0; index < 10; index++) {
      final lessonId = await db.insert('lessons', {
        'lesson_title': 'Recent lesson $index',
        'theme': 'Theme',
        'hsk_level': 4,
        'is_listed': 1,
      });
      final cardId = await _insertCard(
        db,
        lessonId: lessonId,
        chinese: '词$index',
        pinyin: 'cí $index',
        english: 'word $index',
      );
      await _insertProgress(
        db,
        cardId: cardId,
        mastery: .2,
        incorrectAnswers: 1,
        dueAt: now.subtract(Duration(days: index + 1)),
      );
      await db.insert('review_history', {
        'learner_id': 1,
        'card_id': cardId,
        'reviewed_at': now.subtract(Duration(minutes: index)).toIso8601String(),
        'rating': 0,
        'was_correct': 0,
      });
      await db.insert('lesson_sessions', {
        'learner_id': 1,
        'lesson_id': lessonId,
        'started_at': now.subtract(Duration(days: index)).toIso8601String(),
        'completed_at': now.subtract(Duration(days: index)).toIso8601String(),
        'current_card_index': 1,
        'cards_reviewed': 1,
        'correct_answers': 0,
      });
    }

    final snapshot = await repository.load(asOf: now);

    expect(snapshot.weakWords, hasLength(8));
    expect(snapshot.dueCards, hasLength(8));
    expect(snapshot.recentMistakes, hasLength(8));
    expect(snapshot.lessonHistory, hasLength(5));
  });
}

Future<int> _insertCard(
  Database db, {
  required int lessonId,
  required String chinese,
  required String pinyin,
  required String english,
}) => db.insert('cards', {
  'lesson_id': lessonId,
  'chinese': chinese,
  'pinyin': pinyin,
  'english_meaning': english,
  'part_of_speech': 'verb',
  'hsk_level': 3,
  'example_sentence_chinese': '',
  'example_sentence_pinyin': '',
  'example_sentence_english': '',
  'quiz_options': jsonEncode([english]),
  'correct_answer': english,
});

Future<void> _insertProgress(
  Database db, {
  required int cardId,
  required double mastery,
  required int incorrectAnswers,
  required DateTime dueAt,
}) => db.insert('card_progress', {
  'learner_id': 1,
  'card_id': cardId,
  'times_seen': incorrectAnswers + 1,
  'correct_answers': 1,
  'incorrect_answers': incorrectAnswers,
  'mastery': mastery,
  'repetitions': 1,
  'lapses': incorrectAnswers,
  'interval_days': 1,
  'ease_factor': 2.5,
  'due_at': dueAt.toIso8601String(),
  'last_reviewed_at': dueAt
      .subtract(const Duration(hours: 1))
      .toIso8601String(),
});
