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
      for (final key in [
        'id',
        'simplified',
        'traditional',
        'pinyin',
        'studyMeaning',
      ]) {
        expect(entry[key], isA<String>(), reason: '$key must be text');
        final value = entry[key] as String;
        expect(value, isNotEmpty, reason: '$key must not be empty');
        expect(value, value.trim(), reason: '$key must be trimmed');
      }
      expect(entry['hskLevel'], inInclusiveRange(1, 6));
      expect(entry['frequency'], isA<int>());
      expect(entry['partOfSpeech'], isA<List<dynamic>>());
      expect(entry['meanings'], isA<List<dynamic>>());
      expect(entry['meanings'], isNotEmpty);
      for (final meaning in entry['meanings'] as List<dynamic>) {
        expect(meaning, isA<String>());
        expect((meaning as String).trim(), isNotEmpty);
      }
      for (final partOfSpeech in entry['partOfSpeech'] as List<dynamic>) {
        expect(partOfSpeech, isA<String>());
        expect((partOfSpeech as String).trim(), isNotEmpty);
      }
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

  test('study meanings exclude dictionary metadata and proper surnames', () {
    final unsuitable = RegExp(
      r'^(?:surname\b|(?:old |erhua )?variant of\b|used in\b|'
      r'see(?: also)?\s+[\u3400-\u9fff]|abbr\. for\b)',
      caseSensitive: false,
    );

    for (final entry in vocabulary) {
      final word = entry['simplified'] as String;
      final meaning = entry['studyMeaning'] as String;
      if (word != '姓') {
        expect(
          unsuitable.hasMatch(meaning),
          isFalse,
          reason: '$word must have a learner-facing study meaning: $meaning',
        );
      }
      expect(meaning, isNot(contains(r'$')));
    }

    final familyName = vocabulary.singleWhere(
      (entry) => entry['simplified'] == '姓',
    );
    expect(familyName['studyMeaning'], 'surname');
  });

  test('ambiguous words use the intended HSK forms and meanings', () {
    const expected = <String, (String, String)>{
      '三': ('sān', 'three'),
      '东西': ('dōng xi', 'things'),
      '个': ('gè', 'general measure word'),
      '冷': ('lěng', 'cold'),
      '几': ('jǐ', 'how many'),
      '听': ('tīng', 'listen'),
      '读': ('dú', 'to read'),
      '便宜': ('pián yi', 'cheap'),
      '告诉': ('gào su', 'to tell'),
      '鸟': ('niǎo', 'bird'),
      '孙子': ('sūn zi', 'grandson'),
      '成功': ('chéng gōng', 'success'),
      '台': ('tái', 'platform'),
      '钟': ('zhōng', 'clock'),
      '方言': ('fāng yán', 'dialect'),
      '联想': ('lián xiǎng', 'to associate (cognitively)'),
      '恶心': ('ě xīn', 'disgusting'),
    };

    for (final MapEntry(key: word, value: expectedValue) in expected.entries) {
      final entry = vocabulary.singleWhere(
        (candidate) => candidate['simplified'] == word,
      );
      expect(entry['pinyin'], expectedValue.$1, reason: word);
      expect(entry['studyMeaning'], expectedValue.$2, reason: word);
    }
  });

  test('pinyin uses learner-friendly spelling', () {
    for (final entry in vocabulary) {
      final pinyin = entry['pinyin'] as String;
      expect(
        pinyin,
        isNot(contains('u:')),
        reason: entry['simplified'] as String,
      );
    }

    final entriesByWord = {
      for (final entry in vocabulary) entry['simplified'] as String: entry,
    };
    expect(entriesByWord['系领带']!['pinyin'], 'jì lǐng dài');
    expect(entriesByWord['纽扣儿']!['pinyin'], 'niǔ kòu r');
    expect(entriesByWord['致力于']!['pinyin'], 'zhì lì yú');
  });
}
