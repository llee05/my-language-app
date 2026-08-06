import '../models/learning_progress.dart';

abstract interface class ProgressRepository {
  Future<LessonSession> startSession(int lessonId);
  Future<void> updateSession(LessonSession session);
  Future<LessonSession?> activeSessionForLesson(int lessonId);
  Future<LessonSession?> latestActiveSession();
  Future<DailyReviewSession?> dailyReviewSession(DateTime forDay);
  Future<void> updateDailyReviewSession(DailyReviewSession session);

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
