class LessonSummary {
  const LessonSummary({
    required this.id,
    required this.title,
    required this.theme,
    required this.hskLevel,
  });

  final int id;
  final String title;
  final String theme;
  final int hskLevel;
}

class Flashcard {
  const Flashcard({
    this.id = 0,
    required this.chinese,
    required this.pinyin,
    required this.englishMeaning,
    this.partOfSpeech = '',
    this.exampleChinese = '',
    this.examplePinyin = '',
    this.exampleEnglish = '',
    this.exampleSource = '',
    this.exampleSourceId = '',
    this.exampleTranslationId = '',
    this.quizOptions = const [],
  });

  final int id;
  final String chinese;
  final String pinyin;
  final String englishMeaning;
  final String partOfSpeech;
  final String exampleChinese;
  final String examplePinyin;
  final String exampleEnglish;
  final String exampleSource;
  final String exampleSourceId;
  final String exampleTranslationId;
  final List<String> quizOptions;

  Flashcard copyWith({
    String? exampleChinese,
    String? examplePinyin,
    String? exampleEnglish,
  }) {
    return Flashcard(
      id: id,
      chinese: chinese,
      pinyin: pinyin,
      englishMeaning: englishMeaning,
      partOfSpeech: partOfSpeech,
      exampleChinese: exampleChinese ?? this.exampleChinese,
      examplePinyin: examplePinyin ?? this.examplePinyin,
      exampleEnglish: exampleEnglish ?? this.exampleEnglish,
      exampleSource: exampleSource,
      exampleSourceId: exampleSourceId,
      exampleTranslationId: exampleTranslationId,
      quizOptions: quizOptions,
    );
  }
}

class Lesson {
  const Lesson({required this.summary, required this.cards});

  final LessonSummary summary;
  final List<Flashcard> cards;
}
