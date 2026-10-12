/// A bundled Tatoeba pair with its source sentence transcription.
class ListeningSentence {
  const ListeningSentence({
    required this.chinese,
    required this.pinyin,
    required this.english,
    required this.chineseId,
    required this.englishId,
    required this.pinyinContributor,
    this.excludedVocabulary = const [],
    this.practiceVocabularyIds,
  });

  factory ListeningSentence.fromTatoeba(Map<String, dynamic> example) {
    String text(String field) {
      final value = example[field];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing Tatoeba sentence $field.');
      }
      return value.trim();
    }

    int sentenceId(String field) {
      final id = int.tryParse(text(field));
      if (id == null || id <= 0) {
        throw FormatException('Invalid Tatoeba sentence $field.');
      }
      return id;
    }

    if (example['source'] != 'Tatoeba') {
      throw const FormatException('Expected a Tatoeba sentence.');
    }
    return ListeningSentence(
      chinese: text('chinese'),
      pinyin: text('pinyin'),
      english: text('english'),
      chineseId: sentenceId('chineseId'),
      englishId: sentenceId('englishId'),
      pinyinContributor: example['pinyinContributor'] as String? ?? '',
      excludedVocabulary: _excludedVocabulary(example),
    );
  }

  final String chinese;
  final String pinyin;
  final String english;
  final int chineseId;
  final int englishId;
  final String pinyinContributor;
  final List<String> excludedVocabulary;
  final List<String>? practiceVocabularyIds;

  ListeningSentence withPracticeVocabulary(Iterable<String> ids) =>
      ListeningSentence(
        chinese: chinese,
        pinyin: pinyin,
        english: english,
        chineseId: chineseId,
        englishId: englishId,
        pinyinContributor: pinyinContributor,
        excludedVocabulary: excludedVocabulary,
        practiceVocabularyIds: List.unmodifiable(ids),
      );

  static List<String> _excludedVocabulary(Map<String, dynamic> example) {
    final values = example['excludedVocabulary'] ?? const <String>[];
    if (values is! List ||
        values.any((value) => value is! String || value.trim().isEmpty)) {
      throw const FormatException('Invalid sentence vocabulary exclusions.');
    }
    return List<String>.unmodifiable(values.cast<String>());
  }

  Uri get chineseSource =>
      Uri.https('tatoeba.org', '/en/sentences/show/$chineseId');
  Uri get englishSource =>
      Uri.https('tatoeba.org', '/en/sentences/show/$englishId');
}
