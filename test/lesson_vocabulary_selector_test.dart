import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/services/lesson_vocabulary_selector.dart';

void main() {
  final vocabulary =
      (jsonDecode(File('assets/data/hsk_vocabulary.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> select(
    String topic,
    int level, {
    Set<String> studied = const {},
    Set<String> previous = const {},
    bool randomMix = false,
  }) => const LessonVocabularySelector().select(
    vocabulary: vocabulary,
    topic: topic,
    hskLevel: level,
    studiedWords: studied,
    previousWords: previous,
    randomMix: randomMix,
    random: Random(42),
  );
  Set<String> words(List<Map<String, dynamic>> entries) =>
      entries.map((word) => word['simplified'] as String).toSet();

  test('Family includes core family words', () {
    expect(words(select('Family', 1)), containsAll(['妈妈', '爸爸', '儿子', '女儿']));
  });
  test('Greetings and Daily Life have distinct topic vocabulary', () {
    final greetings = words(select('Greetings', 1).take(10).toList());
    expect(greetings, containsAll(['谢谢', '再见']));
    expect(greetings, isNot(words(select('Daily Life', 1).take(10).toList())));
  });
  test('common words in a custom scenario do not distort matching', () {
    expect(
      words(select('ordering breakfast in Beijing', 1).take(20).toList()),
      containsAll(['吃', '喝', '米饭']),
    );
    expect(
      words(select('Food and Drinks', 1).take(10).toList()),
      isNot(contains('的')),
    );
  });
  for (final topic in [
    'Politics',
    'Economics',
    'History and Philosophy',
    'a previously unknown topic',
  ]) {
    test('$topic reserves current-level vocabulary', () {
      final selected = select(topic, 6);
      expect(selected, hasLength(60));
      expect(
        selected.where((word) => word['hskLevel'] == 6).length,
        greaterThanOrEqualTo(40),
      );
      expect(
        selected.take(10).where((word) => word['hskLevel'] == 6).length,
        greaterThanOrEqualTo(6),
      );
    });
  }
  test(
    'studied and previous words are deprioritized within equal relevance',
    () {
      final first = select('unknown', 1);
      final previous = words(first.take(10).toList());
      final next = select('unknown', 1, studied: previous, previous: previous);
      expect(words(next.take(10).toList()).intersection(previous), isEmpty);
    },
  );
  test('all modes stay within level and deduplicate words', () {
    for (var level = 1; level <= 6; level++) {
      final selected = select('Random mix', level, randomMix: true);
      expect(
        selected.every((word) => (word['hskLevel'] as int) <= level),
        isTrue,
      );
      expect(words(selected), hasLength(selected.length));
    }
  });
}
