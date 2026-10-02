import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('curriculum examples retain their actual source text and attribution', () {
    final document =
        jsonDecode(
              File('assets/data/vocabulary_lessons.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final originals =
        jsonDecode(
              File(
                'assets/data/lesson_original_examples.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final pairs = <String, List<String>>{};
    for (final line in File(
      'assets/data/tatoeba/Sentence pairs in Mandarin Chinese-English - 2026-08-08.tsv',
    ).readAsLinesSync()) {
      final fields = line.replaceFirst('\ufeff', '').split('\t');
      pairs['${fields[0]}|${fields[2]}'] = fields;
    }
    final scripts = <String, Map<String, List<String>>>{};
    for (final line in File(
      'assets/data/tatoeba/lesson_transcriptions.tsv',
    ).readAsLinesSync()) {
      final fields = line.split('\t');
      (scripts[fields[0]] ??= {})[fields[2]] = fields;
    }
    final examples = <String, Map<String, dynamic>>{};
    for (final lesson in document['lessons'] as List) {
      for (final entry in lesson['entries'] as List) {
        final id = entry['vocabularyId'] as String;
        final example = entry['example'] as Map<String, dynamic>;
        if (examples.containsKey(id)) expect(example, examples[id]);
        examples[id] = example;
      }
    }
    var tatoebaCount = 0;
    var originalCount = 0;
    for (final entry in examples.entries) {
      final example = entry.value;
      expect(example['pinyin'], isNot(matches(RegExp(r'\d'))));
      if (example['source'] == 'Original') {
        originalCount++;
        expect(example, originals[entry.key]);
        expect(example.containsKey('chineseId'), isFalse);
        expect(example.containsKey('englishId'), isFalse);
        continue;
      }
      tatoebaCount++;
      expect(example['source'], 'Tatoeba');
      final pair = pairs['${example['chineseId']}|${example['englishId']}'];
      expect(pair, isNotNull, reason: entry.key);
      final readings = scripts[example['chineseId']];
      expect(readings?['Latn'], isNotNull, reason: entry.key);
      expect(example['chinese'], readings?['Hans']?[4] ?? pair![1]);
      expect(example['english'], pair![3]);
      expect(example['pinyinContributor'], readings!['Latn']![3]);
    }
    expect(tatoebaCount, document['tatoebaExampleCount']);
    expect(originalCount, document['originalExampleCount']);
    expect(tatoebaCount + originalCount, document['vocabularyCount']);
    expect(document['missingExamples'], isEmpty);
    expect(document['source']['license'], 'CC BY 2.0 FR');
  });
}
