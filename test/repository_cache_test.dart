import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/local_database.dart';
import 'package:mylanguageapp/models/learner_profile.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/models/lesson.dart';
import 'package:mylanguageapp/repositories/backup_repository.dart';
import 'package:mylanguageapp/repositories/progress_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const lessons = SqliteLessonRepository();
  const progress = SqliteProgressRepository();
  const learners = SqliteLearnerRepository();
  final sunday = DateTime(2026, 9, 27, 12);

  setUp(() async {
    await LocalDatabase.resetForTesting();
    await learners.save(
      const LearnerProfile(name: 'Test', hskLevel: 1, dailyWordTarget: 10),
    );
  });
  tearDown(LocalDatabase.close);

  Future<Lesson> firstLesson() async =>
      (await lessons.findById((await lessons.topics()).first.id))!;

  Future<void> review(int cardId) => progress.recordReview(
    review: ReviewRecord(
      id: 0,
      cardId: cardId,
      reviewedAt: sunday,
      rating: ReviewRating.good,
      wasCorrect: true,
    ),
    progress: CardProgress(
      cardId: cardId,
      dueAt: sunday.add(const Duration(days: 1)),
      lastReviewedAt: sunday,
    ),
  );

  test(
    'lesson results are shared, immutable, and invalidated by new content',
    () async {
      final topics = await lessons.topics();
      expect(await const SqliteLessonRepository().topics(), same(topics));
      final reads = await Future.wait([
        lessons.findById(topics.first.id),
        lessons.findById(topics.first.id),
      ]);
      expect(reads[0], same(reads[1]));
      expect(() => topics.clear(), throwsUnsupportedError);
      expect(() => reads[0]!.cards.clear(), throwsUnsupportedError);
      expect(
        () => reads[0]!.cards.first.quizOptions.clear(),
        throwsUnsupportedError,
      );
      await lessons.saveGenerated(_newLesson);
      final updated = await lessons.topics();
      expect(updated.length, topics.length + 1);
      expect(updated.first.title, 'New cached lesson');
    },
  );

  test(
    'reviews refresh statistics without discarding lesson content',
    () async {
      final lesson = await firstLesson();
      final before = await progress.loadLearningStats(sunday);
      expect(await progress.loadLearningStats(sunday), same(before));
      await review(lesson.cards.first.id);
      final after = await progress.loadLearningStats(sunday);
      expect(after.totalXp, 10);
      expect(after.wordsSeen, 1);
      expect(after.weeklyReviewCount, 1);
      expect(after, isNot(same(before)));
      expect(await lessons.findById(lesson.summary.id), same(lesson));
      expect(() => after.weeklyXp.clear(), throwsUnsupportedError);
    },
  );

  test('statistics expire on a new local day and week', () async {
    await review((await firstLesson()).cards.first.id);
    final today = await progress.loadLearningStats(sunday);
    expect(today.weeklyReviewCount, 1);
    expect(
      await progress.loadLearningStats(sunday.add(const Duration(hours: 1))),
      same(today),
    );
    final monday = await progress.loadLearningStats(
      sunday.add(const Duration(days: 1)),
    );
    expect(monday.totalXp, 10);
    expect(monday.weeklyReviewCount, 0);
    final tuesday = await progress.loadLearningStats(
      sunday.add(const Duration(days: 2)),
    );
    expect(tuesday.streakDays, 0);
  });

  test(
    'failed transactions retain previously committed cache values',
    () async {
      final topics = await lessons.topics();
      await expectLater(
        LocalDatabase.write(
          (db) => db.transaction((txn) async {
            await txn.delete('lessons');
            throw StateError('rollback');
          }),
        ),
        throwsStateError,
      );
      expect(await lessons.topics(), same(topics));
      expect(await lessons.findById(topics.first.id), isNotNull);
    },
  );

  test(
    'backup restore removes cached content and statistics from later writes',
    () async {
      const backups = SqliteBackupRepository();
      final originalTopics = await lessons.topics();
      final original = await backups.exportBackup();
      await lessons.saveGenerated(_newLesson);
      final topics = await lessons.topics();
      final newId = topics.first.id;
      await review((await lessons.findById(newId))!.cards.first.id);
      expect((await progress.loadLearningStats(sunday)).totalXp, 10);
      await backups.restoreBackup(original);
      expect((await lessons.topics()).length, originalTopics.length);
      expect(await lessons.findById(newId), isNull);
      expect((await progress.loadLearningStats(sunday)).totalXp, 0);
    },
  );

  test('onboarding and full reset invalidate cached learner data', () async {
    await lessons.saveGenerated(_newLesson);
    final topics = await lessons.topics();
    await review((await firstLesson()).cards.first.id);
    final stats = await progress.loadLearningStats(sunday);
    await learners.resetOnboarding();
    expect(await lessons.topics(), isNot(same(topics)));
    final preserved = await progress.loadLearningStats(sunday);
    expect(preserved, isNot(same(stats)));
    expect(preserved.totalXp, 10);
    await LocalDatabase.resetAllData();
    expect(
      (await lessons.topics()).any(
        (topic) => topic.title == _newLesson.summary.title,
      ),
      isFalse,
    );
    expect((await progress.loadLearningStats(sunday)).totalXp, 0);
  });

  test(
    'cache hits cannot bypass close while operations are draining',
    () async {
      await lessons.topics();
      final pending = Completer<void>();
      final entered = Completer<void>();
      final operation = LocalDatabase.use((_) {
        entered.complete();
        return pending.future;
      });
      await entered.future;
      final closing = LocalDatabase.close();
      try {
        await expectLater(
          lessons.topics(),
          throwsA(isA<DatabaseResetInProgressException>()),
        );
      } finally {
        pending.complete();
        await operation;
        await closing;
      }
    },
  );

  test(
    'bulk sessions reflect position updates and exclude completed sessions',
    () async {
      final topics = await lessons.topics();
      const bulk = _BulkOnlyProgress();
      final session = await bulk.startSession(topics.first.id);
      final other = await bulk.startSession(topics[1].id);
      var active = await bulk.activeSessionsForLessons(
        topics.map((topic) => topic.id),
      );
      expect(active.keys, unorderedEquals([session.lessonId, other.lessonId]));
      await bulk.updateSessionPosition(
        sessionId: session.id,
        currentCardIndex: 1,
        expectedCardsReviewed: 0,
      );
      await bulk.updateSession(
        LessonSession(
          id: other.id,
          lessonId: other.lessonId,
          startedAt: other.startedAt,
          completedAt: sunday,
        ),
      );
      active = await bulk.activeSessionsForLessons(
        topics.map((topic) => topic.id),
      );
      expect(active.keys, [session.lessonId]);
      expect(active[session.lessonId]!.currentCardIndex, 1);
      expect(await bulk.activeSessionsForLessons([other.lessonId]), isEmpty);
    },
  );
}

class _BulkOnlyProgress extends SqliteProgressRepository {
  const _BulkOnlyProgress();

  @override
  Future<LessonSession?> activeSessionForLesson(int lessonId) =>
      throw StateError('The library must use the bulk query.');
}

const _newLesson = Lesson(
  summary: LessonSummary(
    id: 0,
    title: 'New cached lesson',
    theme: 'Cache',
    hskLevel: 1,
  ),
  cards: [Flashcard(chinese: '学', pinyin: 'xué', englishMeaning: 'study')],
);
