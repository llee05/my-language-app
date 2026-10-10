String vocabularyStudyMeaning(Map<String, dynamic> entry) {
  final studyMeaning = entry['studyMeaning'];
  if (studyMeaning is String && studyMeaning.trim().isNotEmpty) {
    return studyMeaning.trim();
  }

  final meanings = entry['meanings'];
  if (meanings is List<dynamic>) {
    for (final meaning in meanings) {
      if (meaning is String && meaning.trim().isNotEmpty) {
        return meaning.trim();
      }
    }
  }
  throw const FormatException('Vocabulary entry has no study meaning.');
}

List<String> vocabularyDisplayMeanings(Map<String, dynamic> entry) {
  final studyMeaning = vocabularyStudyMeaning(entry);
  final meanings = <String>[studyMeaning];
  final seen = <String>{studyMeaning.toLowerCase()};

  for (final raw in entry['meanings'] as List<dynamic>? ?? const []) {
    if (raw is! String) continue;
    final meaning = raw.trim();
    if (meaning.isNotEmpty && seen.add(meaning.toLowerCase())) {
      meanings.add(meaning);
    }
  }
  return List.unmodifiable(meanings);
}

String vocabularyPartOfSpeechLabel(String code) =>
    const <String, String>{
      'n': 'Noun',
      'v': 'Verb',
      'a': 'Adjective',
      'd': 'Adverb',
      'p': 'Preposition',
      'c': 'Conjunction',
      'cc': 'Coordinating conjunction',
      'r': 'Pronoun',
      'u': 'Particle',
      'y': 'Sentence particle',
      'e': 'Interjection',
      'o': 'Sound word',
      'q': 'Classifier',
      'qv': 'Action classifier',
      'qt': 'Time classifier',
      'm': 'Number',
      'mq': 'Number and classifier',
      'Mg': 'Number element',
      'b': 'Attributive',
      'vn': 'Verb or noun',
      'an': 'Adjective or noun',
      'ad': 'Adjective or adverb',
      'g': 'Bound form',
      't': 'Time word',
      'tg': 'Time element',
      'f': 'Position word',
      's': 'Place word',
      'l': 'Fixed expression',
      'z': 'Descriptive expression',
      'k': 'Suffix',
      'nr': 'Personal name',
      'ns': 'Place name',
      'nt': 'Organization name',
      'nz': 'Other proper noun',
    }[code] ??
    code;

String vocabularyWordKey(String chinese, String pinyin) =>
    '${chinese.trim()}\u0000${pinyin.toLowerCase().replaceAll(RegExp(r"[\s']"), '')}';

// Accept the old display readings when identifying a bundled deck in a backup.
// Editorial upgrades then replace the text in place, retaining its shared IDs.
const legacyEditorialPinyin = <String, String>{
  '俩': 'liǎng',
  '哇': 'wa',
  '欧洲': 'Oū zhōu',
  '嘱咐': 'zhǔ fù',
  '吩咐': 'fēn fù',
  '大不了': 'dà bù liǎo',
  '码头': 'mǎ tóu',
  '泄露': 'xiè lù',
  '得罪': 'dé zuì',
};

bool matchesBundledVocabularyReading(
  Map<String, dynamic> entry,
  String pinyin,
) {
  final chinese = entry['simplified'] as String;
  final key = vocabularyWordKey(chinese, pinyin);
  final legacy = legacyEditorialPinyin[chinese];
  return key == vocabularyWordKey(chinese, entry['pinyin'] as String) ||
      (legacy != null && key == vocabularyWordKey(chinese, legacy));
}
