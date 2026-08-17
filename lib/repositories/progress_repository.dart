import '../models/learning_progress.dart';

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
