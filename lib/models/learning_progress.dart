import 'lesson.dart';

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
  CardProgress({
    required this.cardId,
    DateTime? nextReview,
    DateTime? dueAt,
    this.repetitions = 0,
    this.lapses = 0,
    int? reviewInterval,
    int? intervalDays,
    this.easeFactor = 2.5,
    DateTime? lastReview,
    DateTime? lastReviewedAt,
    this.timesSeen = 0,
    this.correctAnswers = 0,
    this.incorrectAnswers = 0,
    this.mastery = 0,
  }) : assert(nextReview != null || dueAt != null),
       nextReview = nextReview ?? dueAt!,
       reviewInterval = reviewInterval ?? intervalDays ?? 0,
       lastReview = lastReview ?? lastReviewedAt;

  final int cardId;
  final int timesSeen;
  final int correctAnswers;
  final int incorrectAnswers;

  /// Correct answers divided by times seen, from 0.0 to 1.0.
  final double mastery;
  final int repetitions;
  final int lapses;
  final int reviewInterval;
  final double easeFactor;
  final DateTime nextReview;
  final DateTime? lastReview;

  // Compatibility aliases for the original scheduling terminology.
  int get intervalDays => reviewInterval;
  DateTime get dueAt => nextReview;
  DateTime? get lastReviewedAt => lastReview;
}

enum DailyQueueReason { due, weak, newWord }

class DailyQueueCard {
  const DailyQueueCard({
    required this.card,
    required this.reason,
    this.progress,
  });

  final Flashcard card;
  final DailyQueueReason reason;
  final CardProgress? progress;
}

class VocabularyCardProgress {
  const VocabularyCardProgress({
    required this.chinese,
    required this.pinyin,
    required this.progress,
  });

  final String chinese;
  final String pinyin;
  final CardProgress progress;
}
