import '../database/vocabulary_content.dart';
import '../models/lesson.dart';

/// Compare complete senses, including ordinary English articles and annotations.
/// This is a conservative dictionary check, not a general synonym detector.
Set<String> quizMeaningKeys(Iterable<String> meanings) => {
  for (final meaning in meanings)
    for (final sense
        in meaning
            .replaceAll(RegExp(r'\([^)]*\)|（[^）]*）'), '')
            .split(RegExp(r'[;,；，]')))
      if (_meaningKey(sense).isNotEmpty) _meaningKey(sense),
};

String _meaningKey(String meaning) => meaning
    .toLowerCase()
    .trim()
    .replaceFirst(RegExp(r'^(?:to|a|an|the)\s+'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'[.!?]+$'), '')
    .trim();

class QuizMeaning {
  QuizMeaning(this.answer, {Iterable<String> meanings = const [], this.pinyin})
    : keys = Set.unmodifiable(quizMeaningKeys([answer, ...meanings]));

  final String answer;
  final String? pinyin;
  final Set<String> keys;

  bool overlaps(QuizMeaning other) => keys.intersection(other.keys).isNotEmpty;
}

/// Returns the designated answer first, followed only by distinct alternatives.
/// Callers control candidate order and shuffle the final choices. Fewer choices
/// are preferable to presenting another valid meaning as an incorrect answer.
List<String> buildMeaningOptions({
  required QuizMeaning answer,
  required Iterable<QuizMeaning> candidates,
  int limit = 4,
}) {
  if (limit < 1) throw ArgumentError.value(limit, 'limit');
  final options = <String>[answer.answer.trim()];
  final seen = quizMeaningKeys(options);
  final pronunciation = answer.pinyin == null
      ? null
      : vocabularyWordKey('', answer.pinyin!);
  for (final candidate in candidates) {
    if (options.length >= limit) break;
    final value = candidate.answer.trim();
    if (value.isEmpty ||
        answer.overlaps(candidate) ||
        quizMeaningKeys([value]).intersection(seen).isNotEmpty ||
        (pronunciation != null &&
            candidate.pinyin != null &&
            vocabularyWordKey('', candidate.pinyin!) == pronunciation)) {
      continue;
    }
    options.add(value);
    seen.addAll(quizMeaningKeys([value]));
  }
  return options;
}

/// Shares the same known senses for bundled cards and every assessment mode.
/// Custom words and sentence cards fall back to their own supplied meaning.
class VocabularyQuizIndex {
  VocabularyQuizIndex(Iterable<Map<String, dynamic>> entries)
    : _entries = {
        for (final entry in entries)
          vocabularyWordKey(
            entry['simplified'] as String,
            entry['pinyin'] as String,
          ): entry,
      };

  final Map<String, Map<String, dynamic>> _entries;

  QuizMeaning forWord({
    required String chinese,
    required String pinyin,
    required String meaning,
  }) {
    final entry = _entries[vocabularyWordKey(chinese, pinyin)];
    return QuizMeaning(
      meaning,
      pinyin: pinyin,
      meanings: entry == null ? const [] : vocabularyDisplayMeanings(entry),
    );
  }

  QuizMeaning forCard(Flashcard card) => forWord(
    chinese: card.chinese,
    pinyin: card.pinyin,
    meaning: card.englishMeaning,
  );

  QuizMeaning forEntry(Map<String, dynamic> entry) => forWord(
    chinese: entry['simplified'] as String,
    pinyin: entry['pinyin'] as String,
    meaning: vocabularyStudyMeaning(entry),
  );
}
