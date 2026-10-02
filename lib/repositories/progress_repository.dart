import '../models/learning_progress.dart';
import '../models/dashboard_learning_stats.dart';
import '../models/lesson.dart';
import 'lesson_repository.dart';

abstract interface class ProgressRepository {
  Future<LessonSession> startSession(int lessonId);
  Future<void> updateSessionPosition({
    required int sessionId,
    required int currentCardIndex,
    required int expectedCardsReviewed,
  });
  Future<void> updateSession(
    LessonSession session, {
    bool reconcileFromHistory = false,
    int? expectedCardsReviewed,
    int? expectedCorrectAnswers,
  });
  Future<LessonSession?> activeSessionForLesson(int lessonId);
  Future<LessonSession?> latestActiveSession();

  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  });
  Future<List<ReviewRecord>> reviewHistory({int? cardId, int? limit});
  Future<CardProgress?> progressForCard(int cardId);
  Future<List<CardProgress>> dueCards(DateTime through);
  Future<List<VocabularyCardProgress>> vocabularyProgress();
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  });
}

/// Optional aggregate queries for stores that can avoid per-lesson queries and
/// cache calculated statistics. Other implementations retain the same behavior.
abstract interface class ProgressSummaryRepository {
  Future<Map<int, LessonSession>> activeLessonSessions();
  Future<DashboardLearningStats> learningStats(DateTime now);
}

/// Counts learned cards across ordered curriculum memberships and legacy decks.
abstract interface class LessonProgressSummaryRepository {
  Future<Map<int, LessonLearningProgress>> lessonLearningProgress();
}

extension ProgressRepositoryQueries on ProgressRepository {
  Future<Map<int, LessonLearningProgress>> learningProgressForLessons(
    LessonRepository lessons,
    Iterable<int> lessonIds,
  ) async {
    final ids = lessonIds.toSet();
    if (ids.isEmpty) return const {};
    final repository = this;
    if (repository is LessonProgressSummaryRepository) {
      final progress = await (repository as LessonProgressSummaryRepository)
          .lessonLearningProgress();
      return Map.unmodifiable({for (final id in ids) id: ?progress[id]});
    }
    final vocabulary = await vocabularyProgress();
    final learnedIds = {
      for (final word in vocabulary)
        if (word.progress.timesSeen > 0 && word.progress.mastery >= .8)
          word.progress.cardId,
    };
    final decks = await Future.wait(ids.map(lessons.findById));
    return Map.unmodifiable({
      for (final deck in decks.whereType<Lesson>())
        deck.summary.id: LessonLearningProgress(
          totalCards: deck.cards.length,
          learnedCards: deck.cards
              .where((card) => learnedIds.contains(card.id))
              .length,
        ),
    });
  }

  Future<Map<int, LessonSession>> activeSessionsForLessons(
    Iterable<int> lessonIds,
  ) async {
    final ids = lessonIds.toSet();
    if (ids.isEmpty) return const {};
    final repository = this;
    if (repository is ProgressSummaryRepository) {
      final sessions = await (repository as ProgressSummaryRepository)
          .activeLessonSessions();
      return Map.unmodifiable({for (final id in ids) id: ?sessions[id]});
    }
    final sessions = await Future.wait([
      for (final id in ids) activeSessionForLesson(id),
    ]);
    return Map.unmodifiable({
      for (final session in sessions.whereType<LessonSession>())
        session.lessonId: session,
    });
  }

  Future<DashboardLearningStats> loadLearningStats(DateTime now) async {
    final repository = this;
    if (repository is ProgressSummaryRepository) {
      return (repository as ProgressSummaryRepository).learningStats(now);
    }
    final results = await Future.wait([reviewHistory(), vocabularyProgress()]);
    return DashboardLearningStats.fromSavedData(
      reviews: results[0] as List<ReviewRecord>,
      vocabulary: results[1] as List<VocabularyCardProgress>,
      now: now,
    );
  }
}
