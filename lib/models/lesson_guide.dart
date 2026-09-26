/// Optional teaching content accompanying a generated vocabulary deck.
class LessonGuide {
  const LessonGuide({
    required this.objective,
    required this.explanation,
    required this.dialogue,
    required this.exercises,
  });

  final String objective;
  final String explanation;
  final List<LessonSentence> dialogue;
  final List<LessonExercise> exercises;

  factory LessonGuide.fromJson(Object? value) {
    final map = lessonObject(value);
    final dialogue = map['dialogue'];
    final exercises = map['exercises'];
    if (dialogue is! List ||
        dialogue.length < 3 ||
        dialogue.length > 6 ||
        exercises is! List ||
        exercises.length != 2) {
      throw const FormatException(
        'Include 3–6 dialogue lines and two exercises.',
      );
    }
    return LessonGuide(
      objective: lessonText(map, 'objective', maxLength: 200),
      explanation: lessonText(map, 'explanation', maxLength: 1200),
      dialogue: dialogue.map(LessonSentence.fromJson).toList(growable: false),
      exercises: exercises.map(LessonExercise.fromJson).toList(growable: false),
    );
  }

  Map<String, Object> toJson() => {
    'objective': objective,
    'explanation': explanation,
    'dialogue': dialogue.map((line) => line.toJson()).toList(),
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };
}

class LessonSentence {
  const LessonSentence({
    required this.chinese,
    required this.pinyin,
    required this.english,
  });
  final String chinese;
  final String pinyin;
  final String english;

  factory LessonSentence.fromJson(Object? value) {
    final map = lessonObject(value);
    final chinese = lessonText(map, 'chinese', maxLength: 160);
    final pinyin = lessonText(map, 'pinyin', maxLength: 500);
    final english = lessonText(map, 'english', maxLength: 500);
    if (!RegExp(r'[\u3400-\u9fff]').hasMatch(chinese) ||
        !RegExp(
          r'[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜńňǹḿ]',
          caseSensitive: false,
        ).hasMatch(pinyin) ||
        RegExp(r'[\u3400-\u9fff0-9]').hasMatch(pinyin) ||
        !RegExp(r'[a-zA-Z]').hasMatch(english)) {
      throw const FormatException(
        'Include Chinese, tone-marked sentence pinyin, and English.',
      );
    }
    return LessonSentence(chinese: chinese, pinyin: pinyin, english: english);
  }

  Map<String, Object> toJson() => {
    'chinese': chinese,
    'pinyin': pinyin,
    'english': english,
  };
}

class LessonExercise {
  const LessonExercise({required this.question, required this.answer});
  final String question;
  final LessonSentence answer;
  factory LessonExercise.fromJson(Object? value) {
    final map = lessonObject(value);
    return LessonExercise(
      question: lessonText(map, 'question', maxLength: 400),
      answer: LessonSentence.fromJson(map['answer']),
    );
  }
  Map<String, Object> toJson() => {
    'question': question,
    'answer': answer.toJson(),
  };
}

Map<String, dynamic> lessonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a lesson object.');
  }
  return value;
}

String lessonText(
  Map<String, dynamic> map,
  String key, {
  required int maxLength,
}) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty || value.length > maxLength) {
    throw FormatException('Provide $key with 1–$maxLength characters.');
  }
  return value.trim();
}
