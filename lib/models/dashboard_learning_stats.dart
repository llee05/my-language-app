import 'learning_progress.dart';
import '../services/study_streak_calculator.dart';
import 'weekly_progress_report.dart';

class DashboardLearningStats {
  const DashboardLearningStats({
    this.totalXp = 0,
    this.weeklyXp = const [0, 0, 0, 0, 0, 0, 0],
    this.streakDays = 0,
    this.wordsSeen = 0,
    this.wordsLearning = 0,
    this.wordsLearned = 0,
    this.reviewCount = 0,
    this.correctReviewCount = 0,
    this.activeStudyDays = 0,
    this.weeklyReviewCount = 0,
    this.weeklyReport = const WeeklyProgressReport(),
    this.hskWordsLearned = const [0, 0, 0, 0, 0, 0],
    this.vocabulary = const [],
  });

  static const hskVocabularyTotals = [150, 147, 298, 598, 1298, 2500];

  final int totalXp;
  final List<int> weeklyXp;
  final int streakDays;
  final int wordsSeen;
  final int wordsLearning;
  final int wordsLearned;
  final int reviewCount;
  final int correctReviewCount;
  final int activeStudyDays;
  final int weeklyReviewCount;
  final WeeklyProgressReport weeklyReport;
  final List<int> hskWordsLearned;
  final List<VocabularyCardProgress> vocabulary;

  double get accuracy =>
      reviewCount == 0 ? 0 : correctReviewCount / reviewCount;

  int get hskLevelReached {
    var reached = 0;
    for (var index = 0; index < hskVocabularyTotals.length; index++) {
      if (hskWordsLearned[index] < hskVocabularyTotals[index]) break;
      reached = index + 1;
    }
    return reached;
  }

  int? get nextHskLevel => hskLevelReached >= 6 ? null : hskLevelReached + 1;

  int get nextHskWordsLearned {
    final next = nextHskLevel;
    return next == null ? hskVocabularyTotals.last : hskWordsLearned[next - 1];
  }

  int get nextHskWordTarget {
    final next = nextHskLevel;
    return next == null
        ? hskVocabularyTotals.last
        : hskVocabularyTotals[next - 1];
  }

  double get nextHskProgress =>
      (nextHskWordsLearned / nextHskWordTarget).clamp(0, 1);

  factory DashboardLearningStats.fromSavedData({
    required List<ReviewRecord> reviews,
    required List<VocabularyCardProgress> vocabulary,
    required DateTime now,
  }) {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weeklyXp = List<int>.filled(7, 0);
    final weeklyReviews = List<int>.filled(7, 0);
    final weeklyCorrect = List<int>.filled(7, 0);
    var totalXp = 0;
    var correctReviewCount = 0;
    var weeklyReviewCount = 0;
    final activeDays = <(int, int, int)>{};

    for (final review in reviews) {
      final xp = review.wasCorrect ? 10 : 5;
      totalXp += xp;
      if (review.wasCorrect) correctReviewCount++;
      final reviewed = review.reviewedAt.toLocal();
      final day = DateTime(reviewed.year, reviewed.month, reviewed.day);
      activeDays.add((day.year, day.month, day.day));
      final offset = day.difference(weekStart).inDays;
      if (offset >= 0 && offset < 7) {
        weeklyXp[offset] += xp;
        weeklyReviews[offset]++;
        weeklyReviewCount++;
        if (review.wasCorrect) weeklyCorrect[offset]++;
      }
    }

    final seenVocabulary = vocabulary
        .where((word) => word.progress.timesSeen > 0)
        .toList(growable: false);
    final wordsLearned = seenVocabulary
        .where((word) => word.progress.mastery >= .8)
        .length;
    final learnedWordsByLevel = [
      for (var level = 0; level < 6; level++) <String>{},
    ];
    for (final word in seenVocabulary) {
      if (word.progress.mastery < .8) continue;
      learnedWordsByLevel[word.hskLevel - 1].add(word.chinese);
    }

    return DashboardLearningStats(
      totalXp: totalXp,
      weeklyXp: List.unmodifiable(weeklyXp),
      streakDays: calculateCurrentStudyStreak(
        studiedAt: reviews.map((review) => review.reviewedAt),
        now: now,
      ),
      wordsSeen: seenVocabulary.length,
      wordsLearning: seenVocabulary.length - wordsLearned,
      wordsLearned: wordsLearned,
      reviewCount: reviews.length,
      correctReviewCount: correctReviewCount,
      activeStudyDays: activeDays.length,
      weeklyReviewCount: weeklyReviewCount,
      weeklyReport: WeeklyProgressReport(
        weekStart: weekStart,
        xpByDay: List.unmodifiable(weeklyXp),
        reviewsByDay: List.unmodifiable(weeklyReviews),
        correctByDay: List.unmodifiable(weeklyCorrect),
      ),
      hskWordsLearned: List.unmodifiable(
        learnedWordsByLevel.map((words) => words.length),
      ),
      vocabulary: List.unmodifiable(seenVocabulary.take(6)),
    );
  }
}
