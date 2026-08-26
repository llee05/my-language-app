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
