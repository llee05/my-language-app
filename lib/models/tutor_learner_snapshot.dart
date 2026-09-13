import 'dart:convert';

/// A deliberately small, read-only view of learning data for the AI tutor.
class TutorLearnerSnapshot {
  const TutorLearnerSnapshot({
    required this.asOf,
    this.hskLevel,
    this.weakWords = const [],
    this.dueCards = const [],
    this.recentMistakes = const [],
    this.lessonHistory = const [],
  });

  final DateTime asOf;
  final int? hskLevel;
  final List<TutorWordSnapshot> weakWords;
  final List<TutorWordSnapshot> dueCards;
  final List<TutorMistakeSnapshot> recentMistakes;
  final List<TutorLessonSnapshot> lessonHistory;

  String toPromptJson() => jsonEncode({
    'schema_version': 1,
    'as_of': asOf.toUtc().toIso8601String(),
    'hsk_level': hskLevel,
    'weak_words': weakWords.map((word) => word.toJson()).toList(),
    'due_cards': dueCards.map((word) => word.toJson()).toList(),
    'recent_mistakes': recentMistakes
        .map((mistake) => mistake.toJson())
        .toList(),
    'lesson_history': lessonHistory.map((lesson) => lesson.toJson()).toList(),
  });
}

class TutorWordSnapshot {
  const TutorWordSnapshot({
    required this.chinese,
    required this.pinyin,
    required this.englishMeaning,
    required this.mastery,
    required this.incorrectAnswers,
    this.dueAt,
  });

  final String chinese;
  final String pinyin;
  final String englishMeaning;
  final double mastery;
  final int incorrectAnswers;
  final DateTime? dueAt;

  Map<String, Object?> toJson() => {
    'chinese': chinese,
    'pinyin': pinyin,
    'english': englishMeaning,
    'mastery_percent': (mastery.clamp(0, 1) * 100).round(),
    'incorrect_answers': incorrectAnswers,
    if (dueAt != null) 'due_at': dueAt!.toUtc().toIso8601String(),
  };
}

class TutorMistakeSnapshot {
  const TutorMistakeSnapshot({
    required this.chinese,
    required this.pinyin,
    required this.englishMeaning,
    required this.mistakeCount,
    required this.lastMistakeAt,
  });

  final String chinese;
  final String pinyin;
  final String englishMeaning;
  final int mistakeCount;
  final DateTime lastMistakeAt;

  Map<String, Object?> toJson() => {
    'chinese': chinese,
    'pinyin': pinyin,
    'english': englishMeaning,
    'mistake_count': mistakeCount,
    'last_mistake_at': lastMistakeAt.toUtc().toIso8601String(),
  };
}

class TutorLessonSnapshot {
  const TutorLessonSnapshot({
    required this.title,
    required this.theme,
    required this.hskLevel,
    required this.startedAt,
    required this.completedAt,
    required this.cardsReviewed,
    required this.correctAnswers,
  });

  final String title;
  final String theme;
  final int hskLevel;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int cardsReviewed;
  final int correctAnswers;

  Map<String, Object?> toJson() => {
    'title': title,
    'theme': theme,
    'hsk_level': hskLevel,
    'status': completedAt == null ? 'in_progress' : 'completed',
    'started_at': startedAt.toUtc().toIso8601String(),
    if (completedAt != null)
      'completed_at': completedAt!.toUtc().toIso8601String(),
    'cards_reviewed': cardsReviewed,
    'correct_answers': correctAnswers,
  };
}
