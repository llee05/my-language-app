import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/repositories/bundled_vocabulary_repository.dart';
import 'package:mylanguageapp/repositories/lesson_repository.dart';
import 'package:mylanguageapp/repositories/progress_repository.dart';
import 'package:mylanguageapp/services/mandarin_sentence_reading.dart';
import 'package:mylanguageapp/services/vocabulary_study_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses source spellings, joined syllables, umlaut and erhua', () {
    for (final reading in [
      'Nǐ hǎo, lǜ sè, huār.',
      'Ni3 hao3, lv4 se4, hua1r5.',
      'Ni3 hao3, lu:4 se4, hua1 r5.',
      'Ni\u030c ha\u030co, lu\u0308\u0300 se\u0300, hua\u0304r.',
    ]) {
      final parsed = parseMandarinSentenceReading(reading)!;
      expect(parsed.map((s) => (s.base, s.tone)), [
        ('ni', 3),
        ('hao', 3),
        ('lü', 4),
        ('se', 4),
        ('hua', 1),
        ('r', 5),
      ], reason: reading);
    }
    expect(parseMandarinSentenceReading("Xī'ān xuéxí.")!.map((s) => s.base), [
      'xi',
      'an',
      'xue',
      'xi',
    ]);
    expect(
      parseMandarinSentenceReading('Wǒ jiào Tāngmǔ.')![2].capitalized,
      isTrue,
    );
    expect(
      parseMandarinSentenceReading('Wǒ jiào Tāngmǔ.')![2].sentenceInitial,
      isFalse,
    );
  });

  test('rejects incomplete or invalid transcripts', () {
    for (final reading in [
      '你好',
      'ni6 hao3',
      'hello world',
      'nǐ3',
      'ñ',
      'a' * 8193,
    ]) {
      expect(parseMandarinSentenceReading(reading), isNull, reason: reading);
    }
  });

  test('every displayed bundled sentence has one reading per Hanzi', () async {
    final examples =
        jsonDecode(
              await rootBundle.loadString(
                'assets/data/vocabulary_examples.json',
              ),
            )
            as Map<String, dynamic>;
    final sentences =
        jsonDecode(
              await rootBundle.loadString('assets/data/sentence_practice.json'),
            )
            as List;
    final rows = <Map<String, dynamic>>[
      for (final row in examples['entries'] as List)
        for (final example in row['examples'] as List)
          Map<String, dynamic>.from(example as Map),
      for (final deck in sentences)
        for (final sentence in deck['sentences'] as List)
          Map<String, dynamic>.from(sentence as Map),
    ];
    for (final example in rows) {
      final chinese = example['chinese'] as String;
      expect(
        parseMandarinSentenceReading(example['pinyin'] as String),
        hasLength(RegExp(r'[\u3400-\u9fff]').allMatches(chinese).length),
        reason: '$chinese: ${example['pinyin']}',
      );
    }
  });

  final service = VocabularyStudyService(
    lessons: _NoLessons(),
    progress: _NoProgress(),
  );
  Future<List<String>> words(
    String text,
    String? pinyin, {
    List<String> excluded = const [],
    List<String>? allowed,
  }) async => (await service.wordsInText(
    text,
    pinyin: pinyin,
    excludedWords: excluded,
    allowedWordIds: allowed,
  )).map((word) => word['simplified'] as String).toList();

  test(
    'source pronunciation filters polyphonic senses using local entries',
    () async {
      expect(
        await words('你得努力学习。', 'Nǐ děi nǔlì xuéxí.'),
        isNot(contains('得')),
      );
      expect(await words('他说得很好。', 'Tā shuō de hěn hǎo.'), contains('得'));
      expect(await words('我还了书。', 'Wǒ huán le shū.'), isNot(contains('还')));
      expect(await words('我还在学习。', 'Wǒ hái zài xuéxí.'), contains('还'));
      expect(
        await words('孩子长高了。', 'Háizi zhǎng gāo le.'),
        isNot(contains('长')),
      );
      expect(await words('这条路很长。', 'Zhè tiáo lù hěn cháng.'), contains('长'));
      expect(await words('他很大意。', 'Tā hěn dàyi.'), contains('大意'));
      expect(await words('文章的大意。', 'Wénzhāng de dàyì.'), isNot(contains('大意')));
      expect(
        await words('还是很长。', null),
        isNot(anyOf(contains('还'), contains('长'))),
      );
      expect(await words('我喝茶。', 'wrong reading'), isEmpty);
    },
  );

  test('does not match unrelated word boundaries or names', () async {
    expect(await words('他是运动员。', 'Tā shì yùndòngyuán.'), isNot(contains('动员')));
    expect(
      await words('请把收音机关掉。', 'Qǐng bǎ shōuyīnjī guāndiào.'),
      isNot(contains('机关')),
    );
    expect(await words('他是书记。', 'Tā shì shūjì.'), contains('书记'));
    expect(await words('秘书记录会议。', 'Mìshū jìlù huìyì.'), isNot(contains('书记')));
    expect(
      await words('汤姆和玛丽来了。', 'Tāngmǔ hé Mǎlì lái le.'),
      isNot(anyOf(contains('汤'), contains('克'))),
    );
    expect(
      await words('这是自发的运动。', 'Zhè shì zìfā de yùndòng.', excluded: ['自发']),
      isNot(contains('自发')),
    );
  });

  test(
    'accepts third-tone and common yi/bu sandhi and reviewed owner IDs',
    () async {
      expect(await words('你好。', 'Ní hǎo.'), contains('你'));
      expect(await words('不是。', 'Bú shì.'), contains('不'));
      expect(await words('一杯茶。', 'Yì bēi chá.'), contains('一'));
      final entries = await const BundledVocabularyRepository().load();
      final tea = entries.singleWhere((w) => w['simplified'] == '茶');
      expect(
        await words('我喝茶。', 'Wǒ hē chá.', allowed: [tea['id'] as String]),
        ['茶'],
      );
      expect(await words('我喝茶。', 'Wǒ hē chá.', allowed: []), isEmpty);
      expect(
        (await service.wordsInText('我喝茶。', pinyin: 'Wǒ hē chá.')),
        everyElement(isIn(entries)),
      );
    },
  );
}

class _NoLessons implements LessonRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Matching must not write lessons.');
}

class _NoProgress implements ProgressRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Matching must not award progress.');
}
