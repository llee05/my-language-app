class LearnerSettings {
  const LearnerSettings({
    this.showPinyin = true,
    this.soundEnabled = true,
    this.reminderEnabled = false,
    this.reminderHour = 18,
  });

  final bool showPinyin;
  final bool soundEnabled;
  final bool reminderEnabled;
  final int reminderHour;
}

class LessonSession {
  const LessonSession({
    required this.id,
    required this.lessonId,
    required this.startedAt,
    this.completedAt,
    this.currentCardIndex = 0,
    this.cardsReviewed = 0,
    this.correctAnswers = 0,
  });

  final int id;
  final int lessonId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int currentCardIndex;
  final int cardsReviewed;
  final int correctAnswers;

  bool get isComplete => completedAt != null;
}

enum ReviewRating { again, hard, good, easy }

class ReviewRecord {
  const ReviewRecord({
    required this.id,
    required this.cardId,
    required this.reviewedAt,
    required this.rating,
    required this.wasCorrect,
    this.sessionId,
    this.responseTimeMs,
  });

  final int id;
  final int cardId;
  final int? sessionId;
  final DateTime reviewedAt;
  final ReviewRating rating;
  final bool wasCorrect;
  final int? responseTimeMs;
}

class CardProgress {
  const CardProgress({
    required this.cardId,
    required this.dueAt,
    this.repetitions = 0,
    this.lapses = 0,
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    this.lastReviewedAt,
  });

  final int cardId;
  final int repetitions;
  final int lapses;
  final int intervalDays;
  final double easeFactor;
  final DateTime dueAt;
  final DateTime? lastReviewedAt;
}
