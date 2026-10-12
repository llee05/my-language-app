import 'lesson.dart';

class VocabularyExample {
  const VocabularyExample({
    required this.chinese,
    required this.pinyin,
    required this.english,
    this.source = '',
    this.chineseId = '',
    this.englishId = '',
    this.pinyinContributor = '',
  });

  factory VocabularyExample.fromJson(Map<String, dynamic> json) {
    String text(String field) {
      final value = json[field];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing example $field.');
      }
      return value;
    }

    final source = text('source');
    if (source != 'Tatoeba' && source != 'Original') {
      throw const FormatException('Unknown bundled example source.');
    }
    final chineseId = json['chineseId'] as String? ?? '';
    final englishId = json['englishId'] as String? ?? '';
    if (source == 'Tatoeba' &&
        ((int.tryParse(chineseId) ?? 0) <= 0 ||
            (int.tryParse(englishId) ?? 0) <= 0)) {
      throw const FormatException('Invalid Tatoeba example IDs.');
    }
    return VocabularyExample(
      chinese: text('chinese'),
      pinyin: text('pinyin'),
      english: text('english'),
      source: source,
      chineseId: chineseId,
      englishId: englishId,
      pinyinContributor: json['pinyinContributor'] as String? ?? '',
    );
  }

  factory VocabularyExample.fromCard(Flashcard card) => VocabularyExample(
    chinese: card.exampleChinese,
    pinyin: card.examplePinyin,
    english: card.exampleEnglish,
    source: card.exampleSource,
    chineseId: card.exampleSourceId,
    englishId: card.exampleTranslationId,
  );

  final String chinese;
  final String pinyin;
  final String english;
  final String source;
  final String chineseId;
  final String englishId;
  final String pinyinContributor;
}
