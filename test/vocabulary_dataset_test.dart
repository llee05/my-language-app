import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Map<String, dynamic>> vocabulary;

  setUpAll(() {
    vocabulary =
        (jsonDecode(File('assets/data/hsk_vocabulary.json').readAsStringSync())
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
  });

  test('bundled HSK dataset has substantial coverage across levels 1–6', () {
    expect(vocabulary.length, greaterThan(4000));
    expect(
      vocabulary.map((entry) => entry['hskLevel']).toSet(),
      equals({1, 2, 3, 4, 5, 6}),
    );
    for (var level = 1; level <= 6; level++) {
      expect(
        vocabulary.where((entry) => entry['hskLevel'] == level),
        isNotEmpty,
        reason: 'HSK level $level should contain vocabulary',
      );
    }
  });

  test('every vocabulary entry satisfies the game data contract', () {
    final ids = <String>{};

    for (final entry in vocabulary) {
      expect(entry['id'], isA<String>());
      expect(entry['simplified'], isA<String>());
      expect(entry['traditional'], isA<String>());
      expect(entry['pinyin'], isA<String>());
      expect(entry['hskLevel'], inInclusiveRange(1, 6));
      expect(entry['partOfSpeech'], isA<List<dynamic>>());
      expect(entry['meanings'], isA<List<dynamic>>());
      expect(entry['meanings'], isNotEmpty);
      expect((entry['meanings'] as List<dynamic>).first, isA<String>());
      expect(
        ids.add(entry['id'] as String),
        isTrue,
        reason: 'Vocabulary IDs must be unique',
      );
    }
  });

  test('dataset is ordered by HSK level', () {
    final levels = vocabulary.map((entry) => entry['hskLevel'] as int).toList();
    expect(levels, orderedEquals([...levels]..sort()));
  });
}
