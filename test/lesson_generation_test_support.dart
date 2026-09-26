import 'dart:convert';

import 'package:mylanguageapp/models/lesson_guide.dart';

/// Synthetic, target-aware protocol fixtures; linguistic quality is not
/// inferred from these adapter tests.
Map<String, dynamic> lessonResponseFor(List<dynamic> vocabulary) {
  Map<String, String> line(int index) => {
    'chinese': '请说“${vocabulary[index]['hanzi']}”。',
    'pinyin': 'Qǐng shuō “${vocabulary[index]['pinyin']}”.',
    'english': 'Please say “${vocabulary[index]['meaning']}”.',
  };
  return {
    'cards': [
      for (var index = 0; index < 10; index++)
        {
          'index': index,
          'exampleChinese': line(index)['chinese'],
          'examplePinyin': line(index)['pinyin'],
          'exampleEnglish': line(index)['english'],
        },
    ],
    'guide': {
      'objective': 'Use these words in a short conversation.',
      'explanation': 'Use 请 before a request: 请说。Qǐng shuō. Please speak.',
      'dialogue': [line(0), line(1), line(2)],
      'exercises': [
        {'question': 'Ask someone to say the first word.', 'answer': line(0)},
        {'question': 'Now ask for the second word.', 'answer': line(1)},
      ],
    },
  };
}

List<dynamic> vocabularyFromLessonRequest(Map<String, dynamic> body) {
  final messages = body['messages'] as List;
  final prompt =
      messages.firstWhere((message) => message['role'] == 'user')['content']
          as String;
  return jsonDecode(prompt.split('Vocabulary: ').last) as List;
}

const savedLessonGuide = LessonGuide(
  objective: 'Ask for tea politely.',
  explanation: 'Use 请 to make a polite request: 请坐。Qǐng zuò. Please sit.',
  dialogue: [
    LessonSentence(
      chinese: '你喝茶吗？',
      pinyin: 'Nǐ hē chá ma?',
      english: 'Do you drink tea?',
    ),
    LessonSentence(
      chinese: '我喝茶。',
      pinyin: 'Wǒ hē chá.',
      english: 'I drink tea.',
    ),
    LessonSentence(
      chinese: '请喝茶。',
      pinyin: 'Qǐng hē chá.',
      english: 'Please have some tea.',
    ),
  ],
  exercises: [
    LessonExercise(
      question: 'Ask whether someone drinks tea.',
      answer: LessonSentence(
        chinese: '你喝茶吗？',
        pinyin: 'Nǐ hē chá ma?',
        english: 'Do you drink tea?',
      ),
    ),
    LessonExercise(
      question: 'Offer someone tea politely.',
      answer: LessonSentence(
        chinese: '请喝茶。',
        pinyin: 'Qǐng hē chá.',
        english: 'Please have some tea.',
      ),
    ),
  ],
);
