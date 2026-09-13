import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/models/listening_dialogue.dart';

void main() {
  const knownWords = ['你', '好', '我', '要', '谢谢'];

  test('parses a bounded dialogue made only from known and new words', () {
    final dialogue = ListeningDialogue.fromAiResponse(
      '```json\n${jsonEncode(_validDialogue())}\n```',
      knownWords: knownWords,
    );

    expect(dialogue.title, 'At the café');
    expect(dialogue.lines, hasLength(4));
    expect(dialogue.lines.map((line) => line.speaker).toSet(), {'A', 'B'});
    expect(dialogue.newWords.single.chinese, '咖啡');
    expect(dialogue.questions, hasLength(2));
    expect(dialogue.questions.first.correctIndex, 0);
  });

  test('rejects vocabulary outside the approved word set', () {
    final json = _validDialogue();
    final lines = json['lines']! as List<Map<String, Object>>;
    lines[2] = {
      ...lines[2],
      'chinese': '我要咖啡和茶。',
      'tokens': ['我', '要', '咖啡', '和', '茶'],
    };

    expect(
      () => ListeningDialogue.fromAiResponse(
        jsonEncode(json),
        knownWords: knownWords,
      ),
      throwsFormatException,
    );
  });

  test('rejects token lists that do not cover the spoken line', () {
    final json = _validDialogue();
    final lines = json['lines']! as List<Map<String, Object>>;
    lines[2] = {...lines[2], 'chinese': '我真的要咖啡。'};

    expect(
      () => ListeningDialogue.fromAiResponse(
        jsonEncode(json),
        knownWords: knownWords,
      ),
      throwsFormatException,
    );
  });

  test('requires one or two genuinely new words', () {
    final json = _validDialogue();
    json['new_words'] = <Map<String, Object>>[];

    expect(
      () => ListeningDialogue.fromAiResponse(
        jsonEncode(json),
        knownWords: knownWords,
      ),
      throwsFormatException,
    );
  });
}

Map<String, Object> _validDialogue() => {
  'title': 'At the café',
  'setting': 'Two friends order a drink.',
  'lines': <Map<String, Object>>[
    {
      'speaker': 'A',
      'chinese': '你好！',
      'tokens': ['你', '好'],
      'pinyin': 'Nǐ hǎo!',
      'english': 'Hello!',
    },
    {
      'speaker': 'B',
      'chinese': '你好！',
      'tokens': ['你', '好'],
      'pinyin': 'Nǐ hǎo!',
      'english': 'Hello!',
    },
    {
      'speaker': 'A',
      'chinese': '我要咖啡。',
      'tokens': ['我', '要', '咖啡'],
      'pinyin': 'Wǒ yào kāfēi.',
      'english': 'I want coffee.',
    },
    {
      'speaker': 'B',
      'chinese': '好，谢谢。',
      'tokens': ['好', '谢谢'],
      'pinyin': 'Hǎo, xièxie.',
      'english': 'Okay, thank you.',
    },
  ],
  'new_words': <Map<String, Object>>[
    {'chinese': '咖啡', 'pinyin': 'kāfēi', 'english': 'coffee'},
  ],
  'questions': <Map<String, Object>>[
    {
      'prompt': 'What does Speaker A want?',
      'options': ['Coffee', 'Tea'],
      'correct_index': 0,
      'explanation': 'Speaker A says they want coffee.',
    },
    {
      'prompt': 'What does Speaker B say at the end?',
      'options': ['Goodbye', 'Okay, thank you'],
      'correct_index': 1,
      'explanation': 'Speaker B agrees and says thank you.',
    },
  ],
};
