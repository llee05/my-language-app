import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/database/vocabulary_content.dart';

void main() {
  test('study meaning takes precedence over raw dictionary senses', () {
    final entry = <String, dynamic>{
      'studyMeaning': 'three',
      'meanings': ['surname San'],
    };

    expect(vocabularyStudyMeaning(entry), 'three');
    expect(vocabularyDisplayMeanings(entry), ['three', 'surname San']);
  });

  test('legacy entries fall back to the first nonempty meaning', () {
    final entry = <String, dynamic>{
      'meanings': ['', '  to study  ', 'to learn'],
    };

    expect(vocabularyStudyMeaning(entry), 'to study');
    expect(vocabularyDisplayMeanings(entry), ['to study', 'to learn']);
  });

  test('invalid entries fail instead of creating unusable cards', () {
    expect(
      () => vocabularyStudyMeaning(<String, dynamic>{'meanings': const []}),
      throwsFormatException,
    );
  });
}
