import 'package:mylanguageapp/models/lesson_guide.dart';

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
