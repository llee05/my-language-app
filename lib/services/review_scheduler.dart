import 'dart:math';

import '../models/learning_progress.dart';

CardProgress scheduleCardReview({
  required int cardId,
  required ReviewRating rating,
  required DateTime reviewedAt,
  CardProgress? previous,
}) {
  final previousInterval = previous?.reviewInterval ?? 0;
  final previousEase = previous?.easeFactor ?? 2.5;
  final correct = rating != ReviewRating.again;
  final interval = switch (rating) {
    ReviewRating.again => 1,
    ReviewRating.hard => max(1, (previousInterval * 1.2).round()),
    ReviewRating.good =>
      previousInterval == 0
          ? 1
          : max(1, (previousInterval * previousEase).round()),
    ReviewRating.easy =>
      previousInterval == 0
          ? 4
          : max(2, (previousInterval * previousEase * 1.3).round()),
  };
  final ease = switch (rating) {
    ReviewRating.again => max(1.3, previousEase - .2),
    ReviewRating.hard => max(1.3, previousEase - .15),
    ReviewRating.good => previousEase,
    ReviewRating.easy => previousEase + .15,
  };
  return CardProgress(
    cardId: cardId,
    repetitions: correct ? (previous?.repetitions ?? 0) + 1 : 0,
    lapses: (previous?.lapses ?? 0) + (correct ? 0 : 1),
    reviewInterval: interval,
    easeFactor: ease,
    nextReview: reviewedAt.add(Duration(days: interval)),
    lastReview: reviewedAt,
  );
}
