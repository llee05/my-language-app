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
      '台': ('tái', 'classifier for machines; platform'),
      '钟': ('zhōng', 'clock'),
      '方言': ('fāng yán', 'dialect'),
      '联想': ('lián xiǎng', 'to associate (cognitively)'),
      '恶心': ('ě xīn', 'disgusting'),
      '俩': ('liǎ', 'two; both'),
      '干': ('gàn', 'to do; to work'),
      '丙': ('bǐng', 'third; label C; third Heavenly Stem'),
      '乙': ('yǐ', 'second; label B; second Heavenly Stem'),
      '甲': ('jiǎ', 'first; label A; first Heavenly Stem'),
      '背': ('bèi', 'back; to memorize'),
      '哇': ('wā', 'wow'),
      '大意': ('dà yi', 'careless'),
      '拄': ('zhǔ', 'to lean on a walking stick; to support oneself with'),
      '挨': ('ái', 'to suffer; to endure'),
      '条理': ('tiáo lǐ', 'logical order; organization'),
      '欧洲': ('Ōu zhōu', 'Europe'),
      '淋': ('lín', 'to drench; to sprinkle'),
      '澄清': ('chéng qīng', 'to clarify; clear'),
      '生态': ('shēng tài', 'ecology; ecological conditions'),
      '粉碎': ('fěn suì', 'to smash; to crush'),
      '起哄': ('qǐ hòng', 'to make a noisy disturbance; to heckle'),
      '领先': ('lǐng xiān', 'to be ahead; to lead'),
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

  test('dictionary references retain their complete Chinese headwords', () {
    const references = {
      '甲': ['十天干', '保甲'],
      '乙': ['十天干', '乙方', '甲方'],
      '丙': ['十天干'],
      '丁': ['天干'],
      '哈': ['哈士奇'],
      '高速': ['高速公路'],
      '立方': ['立方米'],
      '泰斗': ['泰山北斗'],
      '法人': ['自然人'],
      '得罪': ['得罪'],
      '淡季': ['旺季'],
      '嫌': ['嫌犯'],
    };
    for (final MapEntry(key: word, value: expected) in references.entries) {
      final entry = vocabulary.singleWhere(
        (entry) => entry['simplified'] == word,
      );
      final text = (entry['meanings'] as List).join(' ');
      for (final reference in expected) {
        expect(text, contains(reference), reason: word);
      }
    }
  });

  test('modern display variants and common-word grammar tags are reviewed', () {
    final entries = {
      for (final entry in vocabulary) entry['simplified']: entry,
    };
    expect(entries['嘱咐']!['pinyin'], 'zhǔ fu');
    expect(entries['泄露']!['pinyin'], 'xiè lòu');
    expect(entries['泄露']!['meanings'], contains('also pr. [xiè lù]'));
    expect(entries['小伙子']!['traditional'], '小夥子');
    expect(entries['事迹']!['traditional'], '事蹟');
    expect(entries['合伙']!['traditional'], '合夥');
    expect(entries['生锈']!['traditional'], '生鏽');
    expect(entries['蒙']!['traditional'], '蒙');
    for (final word in ['东西', '钱', '一起', '夏', '马']) {
      expect(
        entries[word]!['partOfSpeech'],
        isNot(contains('nr')),
        reason: word,
      );
    }
  });
}
