import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/services/review_scheduler.dart';

void main() {
  final reviewedAt = DateTime.utc(2026, 8, 6, 10);

  test('new-card ratings produce the expected first review schedule', () {
    final again = scheduleCardReview(
      cardId: 1,
      rating: ReviewRating.again,
      reviewedAt: reviewedAt,
    );
    final hard = scheduleCardReview(
      cardId: 1,
      rating: ReviewRating.hard,
      reviewedAt: reviewedAt,
    );
    final good = scheduleCardReview(
      cardId: 1,
      rating: ReviewRating.good,
      reviewedAt: reviewedAt,
    );
    final easy = scheduleCardReview(
      cardId: 1,
      rating: ReviewRating.easy,
      reviewedAt: reviewedAt,
    );

    expect(again.intervalDays, 1);
    expect(again.repetitions, 0);
    expect(again.lapses, 1);
    expect(again.easeFactor, closeTo(2.3, .0001));
    expect(hard.intervalDays, 1);
    expect(hard.easeFactor, closeTo(2.35, .0001));
    expect(good.intervalDays, 1);
    expect(good.repetitions, 1);
    expect(easy.intervalDays, 4);
    expect(easy.easeFactor, closeTo(2.65, .0001));
    expect(easy.nextReview, reviewedAt.add(const Duration(days: 4)));
  });

  test('established-card ratings reuse interval and ease history', () {
    final previous = CardProgress(
      cardId: 1,
      repetitions: 3,
      lapses: 2,
      intervalDays: 10,
      easeFactor: 2.5,
      dueAt: reviewedAt,
    );

    CardProgress schedule(ReviewRating rating) => scheduleCardReview(
      cardId: 1,
      rating: rating,
      reviewedAt: reviewedAt,
      previous: previous,
    );

    expect(schedule(ReviewRating.again).intervalDays, 1);
    expect(schedule(ReviewRating.again).repetitions, 0);
    expect(schedule(ReviewRating.again).lapses, 3);
    expect(schedule(ReviewRating.hard).intervalDays, 12);
    expect(schedule(ReviewRating.good).intervalDays, 25);
    expect(schedule(ReviewRating.good).repetitions, 4);
    expect(schedule(ReviewRating.easy).intervalDays, 33);
    expect(schedule(ReviewRating.easy).easeFactor, closeTo(2.65, .0001));
  });
}
