import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../local_database.dart';
import '../models/learner_profile.dart';
import '../models/learning_progress.dart';
import '../models/lesson.dart';
import 'development_repository.dart';
import 'learner_repository.dart';
import 'lesson_repository.dart';
import 'progress_repository.dart';
import 'settings_repository.dart';

class SqliteLearnerRepository implements LearnerRepository {
  const SqliteLearnerRepository();

  @override
  Future<LearnerProfile?> load() async {
    final db = await LocalDatabase.ensureInitialized();
    final rows = await db.query(
      'learner_profiles',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return LearnerProfile(
      name: row['name'] as String,
      hskLevel: row['hsk_level'] as int,
      dailyWordTarget: row['daily_word_target'] as int,
    );
  }

  @override
  Future<void> save(LearnerProfile profile) async {
    final db = await LocalDatabase.ensureInitialized();
    final now = DateTime.now().toUtc().toIso8601String();
    final values = {
      'name': profile.name.trim(),
      'hsk_level': profile.hskLevel,
      'daily_word_target': profile.dailyWordTarget,
      'updated_at': now,
    };
    final updated = await db.update(
      'learner_profiles',
      values,
      where: 'id = ?',
      whereArgs: [1],
    );
    if (updated == 0) {
      await db.insert('learner_profiles', {
        'id': 1,
        ...values,
        'created_at': now,
      });
    }
  }

  @override
  Future<void> clear() async {
    final db = await LocalDatabase.ensureInitialized();
    await db.delete('learner_profiles', where: 'id = ?', whereArgs: [1]);
  }
}

class SqliteSettingsRepository implements SettingsRepository {
  const SqliteSettingsRepository();

  @override
  Future<LearnerSettings> load() async {
    final db = await LocalDatabase.ensureInitialized();
    final rows = await db.query(
      'learner_settings',
      where: 'learner_id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return const LearnerSettings();
    final row = rows.single;
    return LearnerSettings(
      showPinyin: row['show_pinyin'] == 1,
      soundEnabled: row['sound_enabled'] == 1,
      reminderEnabled: row['reminder_enabled'] == 1,
      reminderHour: row['reminder_hour'] as int,
    );
  }

  @override
  Future<void> save(LearnerSettings settings) async {
    final db = await LocalDatabase.ensureInitialized();
    await db.insert('learner_settings', {
      'learner_id': 1,
      'show_pinyin': settings.showPinyin ? 1 : 0,
      'sound_enabled': settings.soundEnabled ? 1 : 0,
      'reminder_enabled': settings.reminderEnabled ? 1 : 0,
      'reminder_hour': settings.reminderHour,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
  Future<Lesson?> findById(int id) async {
    final db = await LocalDatabase.ensureInitialized();
    final lessons = await db.query(
      'lessons',
      columns: ['id', 'lesson_title', 'theme', 'hsk_level'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (lessons.isEmpty) return null;
    return _lessonFromSummary(db, _summaryFromRow(lessons.single));
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

    return _lessonFromSummary(db, _summaryFromRow(lessons.single));
  }

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async {
    final db = await LocalDatabase.ensureInitialized();
    return db.transaction((txn) async {
      final existing = await txn.query(
        'cards',
        where: 'chinese = ? AND pinyin = ? COLLATE NOCASE',
        whereArgs: [card.chinese, card.pinyin],
        orderBy: 'id ASC',
        limit: 1,
      );
      if (existing.isNotEmpty) return _cardFromRow(existing.single);

      final lessons = await txn.query(
        'lessons',
        columns: ['id'],
        where: 'theme = ? AND hsk_level = ?',
        whereArgs: ['Vocab Rush', hskLevel],
        limit: 1,
      );
      final lessonId = lessons.isEmpty
          ? await txn.insert('lessons', {
              'lesson_title': 'Vocab Rush · HSK $hskLevel',
              'theme': 'Vocab Rush',
              'hsk_level': hskLevel,
            })
          : lessons.single['id'] as int;
      final cardId = await txn.insert('cards', {
        'lesson_id': lessonId,
        'chinese': card.chinese,
        'pinyin': card.pinyin,
        'english_meaning': card.englishMeaning,
        'part_of_speech': card.partOfSpeech,
        'hsk_level': hskLevel,
        'example_sentence_chinese': card.exampleChinese,
        'example_sentence_pinyin': card.examplePinyin,
        'example_sentence_english': card.exampleEnglish,
        'quiz_options': jsonEncode(card.quizOptions),
        'correct_answer': card.englishMeaning,
      });
      return Flashcard(
        id: cardId,
        chinese: card.chinese,
        pinyin: card.pinyin,
        englishMeaning: card.englishMeaning,
        partOfSpeech: card.partOfSpeech,
        exampleChinese: card.exampleChinese,
        examplePinyin: card.examplePinyin,
        exampleEnglish: card.exampleEnglish,
        quizOptions: card.quizOptions,
      );
    });
  }

  Future<Lesson?> _lessonFromSummary(Database db, LessonSummary summary) async {
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
    id: row['id'] as int,
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

class SqliteProgressRepository implements ProgressRepository {
  const SqliteProgressRepository();

  @override
  Future<LessonSession> startSession(int lessonId) async {
    final db = await LocalDatabase.ensureInitialized();
    final startedAt = DateTime.now().toUtc();
    final id = await db.insert('lesson_sessions', {
      'learner_id': 1,
      'lesson_id': lessonId,
      'started_at': startedAt.toIso8601String(),
    });
    return LessonSession(id: id, lessonId: lessonId, startedAt: startedAt);
  }

  @override
  Future<void> updateSession(LessonSession session) async {
    final db = await LocalDatabase.ensureInitialized();
    await db.update(
      'lesson_sessions',
      {
        'completed_at': session.completedAt?.toUtc().toIso8601String(),
        'current_card_index': session.currentCardIndex,
        'cards_reviewed': session.cardsReviewed,
        'correct_answers': session.correctAnswers,
      },
      where: 'id = ? AND learner_id = ?',
      whereArgs: [session.id, 1],
    );
  }

  @override
  Future<LessonSession?> activeSessionForLesson(int lessonId) async {
    final db = await LocalDatabase.ensureInitialized();
    final rows = await db.query(
      'lesson_sessions',
      where: 'learner_id = ? AND lesson_id = ? AND completed_at IS NULL',
      whereArgs: [1, lessonId],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _sessionFromRow(rows.single);
  }

  @override
  Future<LessonSession?> latestActiveSession() async {
    final db = await LocalDatabase.ensureInitialized();
    final rows = await db.query(
      'lesson_sessions',
      where: 'learner_id = ? AND completed_at IS NULL',
      whereArgs: [1],
      orderBy: 'started_at DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _sessionFromRow(rows.single);
  }

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    if (review.cardId != progress.cardId) {
      throw ArgumentError('Review and progress must refer to the same card.');
    }
    final db = await LocalDatabase.ensureInitialized();
    await db.transaction((txn) async {
      await txn.insert('review_history', {
        'learner_id': 1,
        'card_id': review.cardId,
        'session_id': review.sessionId,
        'reviewed_at': review.reviewedAt.toUtc().toIso8601String(),
        'rating': review.rating.index,
        'was_correct': review.wasCorrect ? 1 : 0,
        'response_time_ms': review.responseTimeMs,
      });
      final totals = (await txn.rawQuery(
        '''
        SELECT
          COUNT(*) AS times_seen,
          COALESCE(SUM(CASE WHEN was_correct = 1 THEN 1 ELSE 0 END), 0)
            AS correct_answers,
          COALESCE(SUM(CASE WHEN was_correct = 0 THEN 1 ELSE 0 END), 0)
            AS incorrect_answers
        FROM review_history
        WHERE learner_id = ? AND card_id = ?
        ''',
        [1, review.cardId],
      )).single;
      final timesSeen = totals['times_seen'] as int;
      final correctAnswers = totals['correct_answers'] as int;
      final incorrectAnswers = totals['incorrect_answers'] as int;
      await txn.insert('card_progress', {
        'learner_id': 1,
        'card_id': progress.cardId,
        'times_seen': timesSeen,
        'correct_answers': correctAnswers,
        'incorrect_answers': incorrectAnswers,
        'mastery': timesSeen == 0 ? 0.0 : correctAnswers / timesSeen,
        'repetitions': progress.repetitions,
        'lapses': progress.lapses,
        'interval_days': progress.intervalDays,
        'ease_factor': progress.easeFactor,
        'due_at': progress.dueAt.toUtc().toIso8601String(),
        'last_reviewed_at': progress.lastReviewedAt?.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<List<ReviewRecord>> reviewHistory({int? cardId, int? limit}) async {
    final db = await LocalDatabase.ensureInitialized();
    final rows = await db.query(
      'review_history',
      where: cardId == null
          ? 'learner_id = ?'
          : 'learner_id = ? AND card_id = ?',
      whereArgs: cardId == null ? [1] : [1, cardId],
      orderBy: 'reviewed_at DESC',
      limit: limit,
    );
    return rows.map(_reviewFromRow).toList(growable: false);
  }

  @override
  Future<CardProgress?> progressForCard(int cardId) async {
    final db = await LocalDatabase.ensureInitialized();
    final rows = await db.query(
      'card_progress',
      where: 'learner_id = ? AND card_id = ?',
      whereArgs: [1, cardId],
      limit: 1,
    );
    return rows.isEmpty ? null : _progressFromRow(rows.single);
  }

  @override
  Future<List<CardProgress>> dueCards(DateTime through) async {
    final db = await LocalDatabase.ensureInitialized();
    final rows = await db.query(
      'card_progress',
      where: 'learner_id = ? AND due_at <= ?',
      whereArgs: [1, through.toUtc().toIso8601String()],
      orderBy: 'due_at ASC',
    );
    return rows.map(_progressFromRow).toList(growable: false);
  }

  @override
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  }) async {
    if (limit <= 0) return const [];
    final db = await LocalDatabase.ensureInitialized();
    final rows = await db.rawQuery(
      '''
      SELECT
        cards.*,
        card_progress.times_seen AS progress_times_seen,
        card_progress.correct_answers AS progress_correct_answers,
        card_progress.incorrect_answers AS progress_incorrect_answers,
        card_progress.mastery AS progress_mastery,
        card_progress.repetitions AS progress_repetitions,
        card_progress.lapses AS progress_lapses,
        card_progress.interval_days AS progress_interval_days,
        card_progress.ease_factor AS progress_ease_factor,
        card_progress.due_at AS progress_due_at,
        card_progress.last_reviewed_at AS progress_last_reviewed_at
      FROM cards
      LEFT JOIN card_progress
        ON card_progress.card_id = cards.id
        AND card_progress.learner_id = ?
      WHERE cards.hsk_level <= ?
      ORDER BY cards.id ASC
    ''',
      [1, maxHskLevel],
    );

    final endOfDay = forDay.isUtc
        ? DateTime.utc(forDay.year, forDay.month, forDay.day + 1)
        : DateTime(forDay.year, forDay.month, forDay.day + 1).toUtc();
    final due = <DailyQueueCard>[];
    final weak = <DailyQueueCard>[];
    final newCards = <DailyQueueCard>[];

    for (final row in rows) {
      final card = _queueCardFromRow(row);
      final dueAt = row['progress_due_at'] as String?;
      if (dueAt == null) {
        newCards.add(
          DailyQueueCard(card: card, reason: DailyQueueReason.newWord),
        );
        continue;
      }
      final progress = CardProgress(
        cardId: card.id,
        timesSeen: row['progress_times_seen'] as int,
        correctAnswers: row['progress_correct_answers'] as int,
        incorrectAnswers: row['progress_incorrect_answers'] as int,
        mastery: (row['progress_mastery'] as num).toDouble(),
        repetitions: row['progress_repetitions'] as int,
        lapses: row['progress_lapses'] as int,
        intervalDays: row['progress_interval_days'] as int,
        easeFactor: (row['progress_ease_factor'] as num).toDouble(),
        dueAt: DateTime.parse(dueAt),
        lastReviewedAt: row['progress_last_reviewed_at'] == null
            ? null
            : DateTime.parse(row['progress_last_reviewed_at'] as String),
      );
      if (progress.dueAt.isBefore(endOfDay)) {
        due.add(
          DailyQueueCard(
            card: card,
            reason: DailyQueueReason.due,
            progress: progress,
          ),
        );
      } else if (progress.mastery < weakThreshold) {
        weak.add(
          DailyQueueCard(
            card: card,
            reason: DailyQueueReason.weak,
            progress: progress,
          ),
        );
      }
    }

    due.sort((a, b) => a.progress!.dueAt.compareTo(b.progress!.dueAt));
    weak.sort((a, b) {
      final mastery = a.progress!.mastery.compareTo(b.progress!.mastery);
      if (mastery != 0) return mastery;
      return (a.progress!.lastReview ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(
            b.progress!.lastReview ?? DateTime.fromMillisecondsSinceEpoch(0),
          );
    });

    return [...due, ...weak, ...newCards].take(limit).toList(growable: false);
  }

  Flashcard _queueCardFromRow(Map<String, Object?> row) => Flashcard(
    id: row['id'] as int,
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

  LessonSession _sessionFromRow(Map<String, Object?> row) => LessonSession(
    id: row['id'] as int,
    lessonId: row['lesson_id'] as int,
    startedAt: DateTime.parse(row['started_at'] as String),
    completedAt: row['completed_at'] == null
        ? null
        : DateTime.parse(row['completed_at'] as String),
    currentCardIndex: row['current_card_index'] as int,
    cardsReviewed: row['cards_reviewed'] as int,
    correctAnswers: row['correct_answers'] as int,
  );

  ReviewRecord _reviewFromRow(Map<String, Object?> row) => ReviewRecord(
    id: row['id'] as int,
    cardId: row['card_id'] as int,
    sessionId: row['session_id'] as int?,
    reviewedAt: DateTime.parse(row['reviewed_at'] as String),
    rating: ReviewRating.values[row['rating'] as int],
    wasCorrect: row['was_correct'] == 1,
    responseTimeMs: row['response_time_ms'] as int?,
  );

  CardProgress _progressFromRow(Map<String, Object?> row) => CardProgress(
    cardId: row['card_id'] as int,
    timesSeen: row['times_seen'] as int,
    correctAnswers: row['correct_answers'] as int,
    incorrectAnswers: row['incorrect_answers'] as int,
    mastery: (row['mastery'] as num).toDouble(),
    repetitions: row['repetitions'] as int,
    lapses: row['lapses'] as int,
    intervalDays: row['interval_days'] as int,
    easeFactor: (row['ease_factor'] as num).toDouble(),
    dueAt: DateTime.parse(row['due_at'] as String),
    lastReviewedAt: row['last_reviewed_at'] == null
        ? null
        : DateTime.parse(row['last_reviewed_at'] as String),
  );
}

class SqliteDevelopmentRepository implements DevelopmentRepository {
  const SqliteDevelopmentRepository();

  @override
  Future<String> databasePath() => LocalDatabase.databasePath();

  @override
  Future<void> resetAllData() => LocalDatabase.resetAllData();
}
