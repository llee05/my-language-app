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

  test('ease bottoms out at 1.3 after repeated lapses', () {
    final lapsing = scheduleCardReview(
      cardId: 2,
      rating: ReviewRating.again,
      reviewedAt: reviewedAt,
      previous: CardProgress(
        cardId: 2,
        repetitions: 1,
        lapses: 4,
        intervalDays: 10,
        easeFactor: 1.4,
        dueAt: reviewedAt,
      ),
    );
    expect(lapsing.easeFactor, 1.3);
    expect(lapsing.repetitions, 0);
    expect(lapsing.lapses, 5);
    expect(lapsing.intervalDays, 1);

    final recovering = scheduleCardReview(
      cardId: 2,
      rating: ReviewRating.good,
      reviewedAt: reviewedAt,
      previous: CardProgress(
        cardId: 2,
        repetitions: 1,
        lapses: 5,
        intervalDays: 10,
        easeFactor: 1.3,
        dueAt: reviewedAt,
      ),
    );
    expect(recovering.easeFactor, 1.3);
    expect(recovering.intervalDays, 13);
    expect(recovering.repetitions, 2);
  });

  test('hard reviews keep at least a one-day interval', () {
    final hard = scheduleCardReview(
      cardId: 3,
      rating: ReviewRating.hard,
      reviewedAt: reviewedAt,
      previous: CardProgress(
        cardId: 3,
        repetitions: 1,
        intervalDays: 1,
        easeFactor: 2.5,
        dueAt: reviewedAt,
      ),
    );

    expect(hard.intervalDays, 1);
    expect(hard.easeFactor, closeTo(2.35, .0001));
  });

  test('easy reviews grow at least two days after a lapse', () {
    final easy = scheduleCardReview(
      cardId: 4,
      rating: ReviewRating.easy,
      reviewedAt: reviewedAt,
      previous: CardProgress(
        cardId: 4,
        repetitions: 1,
        lapses: 1,
        intervalDays: 1,
        easeFactor: 1.3,
        dueAt: reviewedAt,
      ),
    );

    expect(easy.intervalDays, 2);
    expect(easy.easeFactor, closeTo(1.45, .0001));
  });
}
