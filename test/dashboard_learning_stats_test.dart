import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';

void main() {
  group('DashboardLearningStats', () {
    final now = DateTime(2026, 8, 14, 12); // Friday.

    test('calculates total XP, current-week XP, and study streak', () {
      final stats = DashboardLearningStats.fromSavedData(
        now: now,
        reviews: [
          _review(1, DateTime(2026, 8, 14, 9), correct: true),
          _review(2, DateTime(2026, 8, 13, 9), correct: false),
          _review(3, DateTime(2026, 8, 9, 9), correct: true),
        ],
        vocabulary: const [],
      );

      expect(stats.totalXp, 25);
      expect(stats.weeklyXp, [0, 0, 0, 5, 10, 0, 0]);
      expect(stats.streakDays, 2);
      expect(stats.reviewCount, 3);
      expect(stats.correctReviewCount, 2);
      expect(stats.accuracy, closeTo(2 / 3, .0001));
      expect(stats.activeStudyDays, 3);
      expect(stats.weeklyReviewCount, 2);
    });

    test('returns zeroed progress for a learner without saved data', () {
      final stats = DashboardLearningStats.fromSavedData(
        now: now,
        reviews: const [],
        vocabulary: const [],
      );

      expect(stats.totalXp, 0);
      expect(stats.weeklyXp, everyElement(0));
      expect(stats.streakDays, 0);
      expect(stats.wordsSeen, 0);
      expect(stats.wordsLearning, 0);
      expect(stats.wordsLearned, 0);
      expect(stats.reviewCount, 0);
      expect(stats.accuracy, 0);
      expect(stats.activeStudyDays, 0);
      expect(stats.vocabulary, isEmpty);
    });

    test('calculates vocabulary totals from seen words and mastery', () {
      final stats = DashboardLearningStats.fromSavedData(
        now: now,
        reviews: const [],
        vocabulary: [
          _word(1, timesSeen: 0, mastery: 1),
          _word(2, timesSeen: 1, mastery: .79),
          _word(3, timesSeen: 2, mastery: .8),
          _word(4, timesSeen: 3, mastery: 1),
        ],
      );

      expect(stats.wordsSeen, 3);
      expect(stats.wordsLearning, 1);
      expect(stats.wordsLearned, 2);
      expect(stats.vocabulary.map((word) => word.progress.cardId), [2, 3, 4]);
    });

    test('limits dashboard vocabulary cards without reducing totals', () {
      final vocabulary = [
        for (var id = 1; id <= 8; id++)
          _word(id, timesSeen: 1, mastery: id.isEven ? .8 : .4),
      ];

      final stats = DashboardLearningStats.fromSavedData(
        now: now,
        reviews: const [],
        vocabulary: vocabulary,
      );

      expect(stats.wordsSeen, 8);
      expect(stats.wordsLearning, 4);
      expect(stats.wordsLearned, 4);
      expect(stats.vocabulary, hasLength(6));
      expect(stats.vocabulary.map((word) => word.progress.cardId), [
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
    });

    test('reaches HSK levels only after mastering each level vocabulary', () {
      final vocabulary = [
        for (var id = 1; id <= 150; id++)
          _word(id, timesSeen: 2, mastery: .8, hskLevel: 1),
        for (var id = 1; id <= 146; id++)
          _word(1000 + id, timesSeen: 2, mastery: 1, hskLevel: 2),
        _word(3000, timesSeen: 2, mastery: .79, hskLevel: 2),
      ];

      final stats = DashboardLearningStats.fromSavedData(
        now: now,
        reviews: const [],
        vocabulary: vocabulary,
      );

      expect(stats.hskWordsLearned, [150, 146, 0, 0, 0, 0]);
      expect(stats.hskLevelReached, 1);
      expect(stats.nextHskLevel, 2);
      expect(stats.nextHskWordsLearned, 146);
      expect(stats.nextHskWordTarget, 147);
      expect(stats.nextHskProgress, closeTo(146 / 147, .0001));
    });

    test('does not skip an incomplete lower HSK level', () {
      final stats = DashboardLearningStats.fromSavedData(
        now: now,
        reviews: const [],
        vocabulary: [
          for (var id = 1; id <= 147; id++)
            _word(id, timesSeen: 1, mastery: 1, hskLevel: 2),
        ],
      );

      expect(stats.hskLevelReached, 0);
      expect(stats.nextHskLevel, 1);
      expect(stats.nextHskWordsLearned, 0);
    });

    test('counts repeated lesson cards once toward an HSK milestone', () {
      final stats = DashboardLearningStats.fromSavedData(
        now: now,
        reviews: const [],
        vocabulary: [
          _word(1, timesSeen: 2, mastery: 1, chinese: '学习'),
          _word(2, timesSeen: 3, mastery: 1, chinese: '学习'),
        ],
      );

      expect(stats.hskWordsLearned.first, 1);
    });
  });
}

ReviewRecord _review(int id, DateTime reviewedAt, {required bool correct}) =>
    ReviewRecord(
      id: id,
      cardId: id,
      reviewedAt: reviewedAt,
      rating: correct ? ReviewRating.good : ReviewRating.again,
      wasCorrect: correct,
    );

VocabularyCardProgress _word(
  int id, {
  required int timesSeen,
  required double mastery,
  int hskLevel = 1,
  String? chinese,
}) => VocabularyCardProgress(
  chinese: chinese ?? '词$id',
  pinyin: 'cí',
  hskLevel: hskLevel,
  progress: CardProgress(
    cardId: id,
    dueAt: DateTime(2026, 8, 15),
    timesSeen: timesSeen,
    mastery: mastery,
  ),
);
