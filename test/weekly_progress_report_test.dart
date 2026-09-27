import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/models/dashboard_learning_stats.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/models/weekly_progress_report.dart';

void main() {
  group('WeeklyProgressReport', () {
    // Wednesday, September 23, 2026. Its week runs Monday, September 21
    // through Sunday, September 27.
    final now = DateTime(2026, 9, 23, 15);

    ReviewRecord review(int id, DateTime reviewedAt, {required bool correct}) =>
        ReviewRecord(
          id: id,
          cardId: id,
          reviewedAt: reviewedAt,
          rating: correct ? ReviewRating.good : ReviewRating.again,
          wasCorrect: correct,
        );

    test('covers Monday through Sunday of the current week', () {
      final stats = DashboardLearningStats.fromSavedData(
        now: now,
        reviews: [
          review(1, DateTime(2026, 9, 20, 9), correct: true), // Last Sunday.
          review(2, DateTime(2026, 9, 21, 9), correct: true), // Monday.
          review(3, DateTime(2026, 9, 23, 9), correct: true), // Wednesday.
          review(4, DateTime(2026, 9, 27, 22), correct: true), // Sunday.
          review(5, DateTime(2026, 9, 28, 9), correct: true), // Next Monday.
        ],
        vocabulary: const [],
      );

      final report = stats.weeklyReport;
      expect(report.weekStart, DateTime(2026, 9, 21));
      expect(report.weekStart!.weekday, DateTime.monday);
      expect(report.weekEnd, DateTime(2026, 9, 27));
      expect(report.weekEnd!.weekday, DateTime.sunday);
      expect(report.xpByDay, [10, 0, 10, 0, 0, 0, 10]);
      expect(report.reviewsByDay, [1, 0, 1, 0, 0, 0, 1]);
      expect(report.correctByDay, [1, 0, 1, 0, 0, 0, 1]);
      expect(report.totalXp, 30);
      expect(report.reviewCount, 3);
      expect(report.correctReviewCount, 3);
      expect(report.accuracy, 1);
      expect(report.activeDays, 3);
      expect(report.bestDayIndex, 0);
      expect(stats.weeklyXp, report.xpByDay);
      expect(stats.weeklyReviewCount, report.reviewCount);
    });

    test('aggregates reviews per day and finds the best day', () {
      final stats = DashboardLearningStats.fromSavedData(
        now: now,
        reviews: [
          review(1, DateTime(2026, 9, 21, 9), correct: false),
          review(2, DateTime(2026, 9, 21, 10), correct: true),
          review(3, DateTime(2026, 9, 22, 9), correct: true),
          review(4, DateTime(2026, 9, 22, 10), correct: true),
        ],
        vocabulary: const [],
      );

      final report = stats.weeklyReport;
      expect(report.xpByDay, [15, 20, 0, 0, 0, 0, 0]);
      expect(report.reviewsByDay, [2, 2, 0, 0, 0, 0, 0]);
      expect(report.correctByDay, [1, 2, 0, 0, 0, 0, 0]);
      expect(report.totalXp, 35);
      expect(report.accuracy, closeTo(3 / 4, .0001));
      expect(report.activeDays, 2);
      expect(report.bestDayIndex, 1); // Tuesday outranks Monday.
    });

    test('returns zeroed totals without saved reviews', () {
      final stats = DashboardLearningStats.fromSavedData(
        now: now,
        reviews: const [],
        vocabulary: const [],
      );

      final report = stats.weeklyReport;
      expect(report.weekStart, DateTime(2026, 9, 21));
      expect(report.xpByDay, everyElement(0));
      expect(report.reviewsByDay, everyElement(0));
      expect(report.correctByDay, everyElement(0));
      expect(report.totalXp, 0);
      expect(report.reviewCount, 0);
      expect(report.accuracy, 0);
      expect(report.activeDays, 0);
      expect(report.bestDayIndex, isNull);
    });

    test('defaults to an empty report without a week range', () {
      const report = WeeklyProgressReport();

      expect(report.weekStart, isNull);
      expect(report.weekEnd, isNull);
      expect(report.totalXp, 0);
      expect(report.reviewCount, 0);
      expect(report.accuracy, 0);
      expect(report.activeDays, 0);
      expect(report.bestDayIndex, isNull);
    });
  });
}
