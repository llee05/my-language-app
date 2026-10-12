/// A bundled Tatoeba pair with its source sentence transcription.
class ListeningSentence {
  const ListeningSentence({
    required this.chinese,
    required this.pinyin,
    required this.english,
    required this.chineseId,
    required this.englishId,
    required this.pinyinContributor,
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
    );
  }

  final String chinese;
  final String pinyin;
  final String english;
  final int chineseId;
  final int englishId;
  final String pinyinContributor;

  Uri get chineseSource =>
      Uri.https('tatoeba.org', '/en/sentences/show/$chineseId');
  Uri get englishSource =>
      Uri.https('tatoeba.org', '/en/sentences/show/$englishId');
}
