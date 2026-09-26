import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/ai/ai_errors.dart';
import 'package:mylanguageapp/ai/ai_service.dart';
import 'package:mylanguageapp/ai/lesson_generator.dart';

import 'lesson_generation_test_support.dart';

void main() {
  final candidates = [
    for (final (index, word) in [
      '妈妈',
      '爸爸',
      '儿子',
      '女儿',
      '家',
      '哥哥',
      '姐姐',
      '弟弟',
      '妹妹',
      '孩子',
    ].indexed)
      {
        'simplified': word,
        'pinyin': 'jiā',
        'studyMeaning': 'family word $index',
        'meanings': ['family'],
        'partOfSpeech': ['noun'],
        'hskLevel': 1,
      },
  ];
  Map<String, dynamic> valid() => lessonResponseFor([
    for (final word in candidates)
      {
        'hanzi': word['simplified'],
        'pinyin': word['pinyin'],
        'meaning': word['studyMeaning'],
      },
  ]);
  GeneratedLessonContent parse(Map<String, dynamic> data, {int level = 1}) =>
      LessonGenerator.parse(
        jsonEncode(data),
        candidates: candidates,
        hskLevel: level,
      );

  test('parses examples and teaching guide, including fenced JSON', () {
    final lesson = LessonGenerator.parse(
      '```json\n${jsonEncode(valid())}\n```',
      candidates: candidates,
      hskLevel: 1,
    );
    expect(lesson.cards, hasLength(10));
    expect(lesson.cards.first.exampleChinese, contains('妈妈'));
    expect(lesson.guide.dialogue, hasLength(3));
    expect(lesson.guide.exercises, hasLength(2));
  });

  final mutations = <String, void Function(Map<String, dynamic>)>{
    'unrelated example': (data) =>
        data['cards'][0]['exampleChinese'] = '我学习中文。',
    'word alone': (data) => data['cards'][0]['exampleChinese'] = '妈妈。',
    'repeated example': (data) {
      data['cards'][0]['exampleChinese'] = '妈妈和爸爸都在家。';
      data['cards'][1]['exampleChinese'] = '妈妈和爸爸，都在家！';
    },
    'missing tones': (data) =>
        data['cards'][0]['examplePinyin'] = 'Qing shuo mama.',
    'numbered pinyin': (data) =>
        data['cards'][0]['examplePinyin'] = 'Qǐng shuo1 ma1ma.',
    'missing translation': (data) => data['cards'][0]['exampleEnglish'] = '',
    'duplicate index': (data) => data['cards'][1]['index'] = 0,
    'invalid index': (data) => data['cards'][0]['index'] = 999,
    'missing guide': (data) => data.remove('guide'),
    'unconnected dialogue': (data) =>
        data['guide']['dialogue'][0]['chinese'] = '今天很好。',
    'duplicate question': (data) => data['guide']['exercises'][1]['question'] =
        data['guide']['exercises'][0]['question'],
    'unrelated answer': (data) =>
        data['guide']['exercises'][0]['answer']['chinese'] = '今天很好。',
    'oversized content': (data) => data['guide']['objective'] = 'x' * 201,
  };
  for (final entry in mutations.entries) {
    test('rejects ${entry.key}', () {
      final data = valid();
      entry.value(data);
      expect(() => parse(data), throwsFormatException);
    });
  }

  test('rejects a deck that avoids available requested-level words', () {
    final levelCandidates = [
      ...candidates,
      for (var i = 0; i < 4; i++)
        {...candidates[i], 'simplified': '词$i', 'hskLevel': 6},
    ];
    expect(
      () => LessonGenerator.parse(
        jsonEncode(valid()),
        candidates: levelCandidates,
        hskLevel: 6,
      ),
      throwsFormatException,
    );
  });

  test('repairs once with validation feedback and learner context', () async {
    final bad = valid();
    mutations['unrelated example']!(bad);
    final ai = _Replies([jsonEncode(bad), jsonEncode(valid())]);
    final result = await LessonGenerator(ai).generate(
      topic: 'Family',
      hskLevel: 1,
      candidates: candidates,
      studiedWords: {'妈妈'},
      previousWords: {'爸爸'},
    );
    expect(result.cards, hasLength(10));
    expect(ai.requests, hasLength(2));
    expect(ai.requests.last.last['content'], contains('target word'));
    expect(ai.requests.last[2]['role'], 'assistant');
    final supplied = vocabularyFromLessonRequest({
      'messages': ai.requests.first,
    });
    expect(supplied[0]['studied'], isTrue);
    expect(supplied[1]['inPreviousLesson'], isTrue);
  });

  test('stops after two invalid responses', () async {
    final ai = _Replies(['invalid', '{}']);
    await expectLater(
      LessonGenerator(
        ai,
      ).generate(topic: 'Family', hskLevel: 1, candidates: candidates),
      throwsFormatException,
    );
    expect(ai.requests, hasLength(2));
  });

  for (final error in [
    const AiConfigurationException('Missing key'),
    const AiRequestException('Quota reached'),
  ]) {
    test('does not retry provider error: $error', () async {
      final ai = _Replies([error]);
      await expectLater(
        LessonGenerator(
          ai,
        ).generate(topic: 'Family', hskLevel: 1, candidates: candidates),
        throwsA(same(error)),
      );
      expect(ai.requests, hasLength(1));
    });
  }

  test('does not repair when the caller has left', () async {
    final ai = _Replies(['invalid']);
    await expectLater(
      LessonGenerator(ai).generate(
        topic: 'Family',
        hskLevel: 1,
        candidates: candidates,
        shouldContinue: () => false,
      ),
      throwsFormatException,
    );
    expect(ai.requests, hasLength(1));
  });
}

class _Replies extends AiService {
  _Replies(this.replies);
  final List<Object> replies;
  final requests = <List<Map<String, String>>>[];
  @override
  Future<String> chatText({
    required List<Map<String, String>> messages,
    int maxTokens = 2048,
    double temperature = .7,
    bool jsonResponse = false,
  }) async {
    requests.add([
      for (final message in messages) {...message},
    ]);
    final response = replies[requests.length - 1];
    if (response is! String) throw response;
    return response;
  }
}
