import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/models/learning_progress.dart';

void main() {
  test(
    'learned status preserves the existing one-answer and 80% boundary rules',
    () {
      final now = DateTime.utc(2026, 10, 10);
      CardProgress progress(int seen, double accuracy, DateTime due) =>
          CardProgress(
            cardId: 1,
            timesSeen: seen,
            mastery: accuracy,
            nextReview: due,
          );
      final tomorrow = now.add(const Duration(days: 1));
      expect(progress(0, 1, tomorrow).isLearned, isFalse);
      expect(progress(1, 1, tomorrow).isLearned, isTrue);
      expect(progress(5, .8, tomorrow).isLearned, isTrue);
      expect(progress(5, .79, tomorrow).isLearned, isFalse);
      expect(
        progress(1, 1, now).learningStateAt(now),
        VocabularyLearningState.due,
      );
      expect(progress(1, 1, now).isLearned, isTrue);
      expect(
        progress(0, 0, now).learningStateAt(now),
        VocabularyLearningState.unseen,
      );
    },
  );
}
