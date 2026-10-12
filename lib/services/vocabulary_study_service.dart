import '../database/vocabulary_content.dart';
import '../models/learning_progress.dart';
import '../models/lesson.dart';
import '../repositories/bundled_vocabulary_repository.dart';
import '../repositories/bundled_vocabulary_example_repository.dart';
import '../repositories/lesson_repository.dart';
import '../repositories/progress_repository.dart';
import 'review_scheduler.dart';
import 'mandarin_sentence_reading.dart';

export '../database/vocabulary_content.dart' show vocabularyWordKey;

/// Saves practice from every study mode against the same vocabulary cards.
class VocabularyStudyService {
  VocabularyStudyService({
    required this.lessons,
    required this.progress,
    this.vocabulary = const BundledVocabularyRepository(),
    this.examples = const BundledVocabularyExampleRepository(),
    this.clock,
  });

  final LessonRepository lessons;
  final ProgressRepository progress;
  final BundledVocabularyRepository vocabulary;
  final BundledVocabularyExampleRepository examples;
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

  /// Source readings only filter local entries; they never create word readings.
  /// Ambiguous overlaps are omitted instead of joining unrelated word parts.
  Future<List<Map<String, dynamic>>> wordsInText(
    String text, {
    String? pinyin,
    List<String> excludedWords = const [],
    List<String>? allowedWordIds,
  }) async {
    final entries = await vocabulary.load();
    final offsets = RegExp(
      r'[\u3400-\u9fff]',
    ).allMatches(text).map((match) => match.start).toList(growable: false);
    final reading = pinyin == null || pinyin.trim().isEmpty
        ? null
        : parseMandarinSentenceReading(pinyin);
    if (pinyin != null &&
        pinyin.trim().isNotEmpty &&
        (reading == null || reading.length != offsets.length)) {
      return const [];
    }
    final syllableAt = {
      for (final (index, offset) in offsets.indexed) offset: index,
    };
    final excluded = excludedWords.toSet();
    final allowed = allowedWordIds?.toSet();
    const names = [
      '汤姆',
      '玛丽',
      '麦克',
      '迈克',
      '杰克',
      '爱丽丝',
      '安卡拉',
      '青森',
      '挪威',
      '柳霞',
      '克拉娃',
      '小明',
      '小林',
      '小李',
      '小王',
      '老王',
    ];
    final namesInText = <(int, int)>[];
    for (final name in names) {
      var start = text.indexOf(name);
      while (start >= 0) {
        namesInText.add((start, start + name.length));
        start = text.indexOf(name, start + name.length);
      }
    }
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
    final candidates = <_SentenceWordMatch>[];
    for (final offset in offsets) {
      for (final word in byFirst[text[offset]] ?? const []) {
        final chinese = word['simplified'] as String;
        if (excluded.contains(chinese) || !text.startsWith(chinese, offset)) {
          continue;
        }
        if ((allowed != null && !allowed.contains(word['id'])) ||
            namesInText.any(
              (name) => name.$1 < offset + chinese.length && name.$2 > offset,
            )) {
          continue;
        }
        if (reading == null) {
          if (word['hasMultipleReadings'] == true) continue;
        } else if (!_matchesSentenceReading(
          word,
          reading,
          syllableAt[offset]!,
          offsets,
        )) {
          continue;
        }
        candidates.add(
          _SentenceWordMatch(offset, offset + chinese.length, word),
        );
      }
    }
    final longest = candidates
        .where(
          (match) => !candidates.any(
            (other) =>
                other.start <= match.start &&
                other.end >= match.end &&
                other.end - other.start > match.end - match.start,
          ),
        )
        .toList(growable: false);
    final found = <String, Map<String, dynamic>>{};
    for (final match in longest) {
      if (longest.any(
        (other) =>
            other != match &&
            other.start < match.end &&
            other.end > match.start,
      )) {
        continue;
      }
      final word = match.word;
      found.putIfAbsent(
        vocabularyWordKey(
          word['simplified'] as String,
          word['pinyin'] as String,
        ),
        () => word,
      );
    }
    return found.values.toList(growable: false);
  }
}

class _SentenceWordMatch {
  const _SentenceWordMatch(this.start, this.end, this.word);

  final int start;
  final int end;
  final Map<String, dynamic> word;
}

bool _matchesSentenceReading(
  Map<String, dynamic> word,
  List<MandarinSyllable> actual,
  int start,
  List<int> offsets,
) {
  final pinyin = word['pinyin'] as String;
  final expected = parseMandarinSentenceReading(pinyin);
  if (expected == null ||
      expected.length != (word['simplified'] as String).length ||
      start + expected.length > actual.length) {
    return false;
  }
  final proper = pinyin[0] != pinyin[0].toLowerCase();
  const distinctNeutralSenses = {
    '东西',
    '大意',
    '地道',
    '精神',
    '孙子',
    '先生',
    '把手',
    '便宜',
    '的',
    '得',
    '地',
    '着',
    '了',
  };
  for (var index = 0; index < expected.length; index++) {
    final reference = expected[index];
    final source = actual[start + index];
    if (!proper && source.capitalized && !source.sentenceInitial) return false;
    if (reference.base != source.base) return false;
    if (reference.tone == source.tone) continue;
    if (reference.tone == 5 &&
        !distinctNeutralSenses.contains(word['simplified'])) {
      // Retain source-attested full-tone variants of otherwise identical words.
      continue;
    }
    final position = start + index;
    final adjacent =
        position + 1 < actual.length &&
        offsets[position + 1] == offsets[position] + 1;
    final nextTone = adjacent ? actual[position + 1].tone : null;
    if (reference.tone == 3 && source.tone == 2 && nextTone == 3) continue;
    if (reference.base == 'yi' &&
        reference.tone == 1 &&
        (source.tone == 2 || source.tone == 4)) {
      continue;
    }
    if (reference.base == 'bu' &&
        reference.tone == 4 &&
        (source.tone == 5 || (source.tone == 2 && nextTone == 4))) {
      continue;
    }
    return false;
  }
  return true;
}

List<Map<String, dynamic>> unlearnedVocabulary(
  List<Map<String, dynamic>> words,
  List<VocabularyCardProgress> progress,
) {
  final learned = {
    for (final word in progress)
      if (word.progress.isLearned) vocabularyWordKey(word.chinese, word.pinyin),
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
