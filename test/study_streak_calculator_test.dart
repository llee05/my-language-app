import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/services/study_streak_calculator.dart';

void main() {
  final now = DateTime(2026, 8, 14, 12);

  test('counts consecutive local study days including today', () {
    final streak = calculateCurrentStudyStreak(
      now: now,
      studiedAt: [
        DateTime(2026, 8, 14, 8),
        DateTime(2026, 8, 14, 10),
        DateTime(2026, 8, 13, 18),
        DateTime(2026, 8, 12, 9),
      ],
    );

    expect(streak, 3);
  });

  test('keeps yesterday streak current until learner studies today', () {
    final streak = calculateCurrentStudyStreak(
      now: now,
      studiedAt: [DateTime(2026, 8, 13), DateTime(2026, 8, 12)],
    );

    expect(streak, 2);
  });

  test('returns zero after a missed day', () {
    final streak = calculateCurrentStudyStreak(
      now: now,
      studiedAt: [DateTime(2026, 8, 12), DateTime(2026, 8, 11)],
    );

    expect(streak, 0);
  });

  test('ignores future activity timestamps', () {
    final streak = calculateCurrentStudyStreak(
      now: now,
      studiedAt: [DateTime(2026, 8, 15)],
    );

    expect(streak, 0);
  });
}
