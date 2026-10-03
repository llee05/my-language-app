import '../database/vocabulary_content.dart';
import '../models/learning_progress.dart';
import '../models/lesson.dart';
import '../repositories/bundled_vocabulary_repository.dart';
import '../repositories/lesson_repository.dart';
import '../repositories/progress_repository.dart';
import 'review_scheduler.dart';

/// Saves practice from every study mode against the same vocabulary cards.
class VocabularyStudyService {
  VocabularyStudyService({
    required this.lessons,
    required this.progress,
    this.vocabulary = const BundledVocabularyRepository(),
    this.clock,
  });

  final LessonRepository lessons;
  final ProgressRepository progress;
  final BundledVocabularyRepository vocabulary;
  final DateTime Function()? clock;
  Future<void> _pending = Future.value();

  Future<Flashcard> recordWord(
    Map<String, dynamic> word, {
    required ReviewRating rating,
    required String submissionKey,
  }) => recordCard(
    Flashcard(
      chinese: word['simplified'] as String,
      pinyin: word['pinyin'] as String,
      englishMeaning: vocabularyStudyMeaning(word),
      partOfSpeech: (word['partOfSpeech'] as List<dynamic>? ?? []).join(', '),
    ),
    hskLevel: word['hskLevel'] as int,
    rating: rating,
    submissionKey: submissionKey,
  );

  Future<Flashcard> recordCard(
    Flashcard word, {
    required int hskLevel,
    required ReviewRating rating,
    required String submissionKey,
  }) {
    final result = _pending.then((_) async {
      final card = word.id != 0
          ? word
          : await lessons.findOrCreateVocabularyCard(
              card: word,
              hskLevel: hskLevel,
            );
      final previous = await progress.progressForCard(card.id);
      final now = (clock?.call() ?? DateTime.now()).toUtc();
      await progress.recordReview(
        review: ReviewRecord(
          id: 0,
          cardId: card.id,
          reviewedAt: now,
          rating: rating,
          wasCorrect: rating != ReviewRating.again,
          submissionKey: submissionKey,
        ),
        progress: scheduleCardReview(
          cardId: card.id,
          rating: rating,
          reviewedAt: now,
          previous: previous,
        ),
      );
      return card;
    });
    // A failed save must remain retryable without blocking subsequent saves.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// Longest matching bundled words; never trusts provider-supplied readings.
  Future<List<Map<String, dynamic>>> wordsInText(String text) async {
    final entries = await vocabulary.load();
    final byFirst = <String, List<Map<String, dynamic>>>{};
    for (final word in entries) {
      final chinese = word['simplified'] as String;
      if (chinese.isEmpty) continue;
      byFirst.putIfAbsent(chinese[0], () => []).add(word);
    }
    for (final words in byFirst.values) {
      words.sort(
        (a, b) => (b['simplified'] as String).length.compareTo(
          (a['simplified'] as String).length,
        ),
      );
    }
    final found = <String, Map<String, dynamic>>{};
    var offset = 0;
    while (offset < text.length) {
      Map<String, dynamic>? match;
      for (final word in byFirst[text[offset]] ?? const []) {
        if (text.startsWith(word['simplified'] as String, offset)) {
          match = word;
          break;
        }
      }
      if (match == null) {
        offset++;
      } else {
        final chinese = match['simplified'] as String;
        found.putIfAbsent(
          vocabularyWordKey(chinese, match['pinyin'] as String),
          () => match!,
        );
        offset += chinese.length;
      }
    }
    return found.values.toList(growable: false);
  }
}

String vocabularyWordKey(String chinese, String pinyin) =>
    '${chinese.trim()}\u0000${pinyin.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';

List<Map<String, dynamic>> unlearnedVocabulary(
  List<Map<String, dynamic>> words,
  List<VocabularyCardProgress> progress,
) {
  final learned = {
    for (final word in progress)
      if (word.progress.timesSeen > 0 && word.progress.mastery >= .8)
        vocabularyWordKey(word.chinese, word.pinyin),
  };
  return [
    for (final word in words)
      if (!learned.contains(
        vocabularyWordKey(
          word['simplified'] as String,
          word['pinyin'] as String,
        ),
      ))
        word,
  ];
}
