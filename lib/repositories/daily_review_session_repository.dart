import '../models/learning_progress.dart';

abstract interface class DailyReviewSessionRepository {
  Future<DailyReviewSession> create({
    required DateTime date,
    required List<int> queuedCardIds,
  });

  Future<DailyReviewSession?> load(DateTime date);
  Future<void> update(DailyReviewSession session);
  Future<void> complete({
    required int sessionId,
    required DateTime completedAt,
  });
  Future<void> enqueueCard({required DateTime date, required int cardId});
}
