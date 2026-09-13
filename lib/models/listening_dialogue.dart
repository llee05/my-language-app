import 'dart:convert';

/// A short, locally validated listening exercise returned by an AI provider.
class ListeningDialogue {
  const ListeningDialogue({
    required this.title,
    required this.setting,
    required this.lines,
    required this.newWords,
    required this.questions,
  });

  final String title;
  final String setting;
  final List<ListeningDialogueLine> lines;
  final List<ListeningDialogueWord> newWords;
  final List<ListeningDialogueQuestion> questions;

  static ListeningDialogue fromAiResponse(
    String response, {
    required Iterable<String> knownWords,
  }) {
    final normalized = response
        .trim()
        .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
        .replaceAll(RegExp(r'\s*```$'), '');
    final decoded = jsonDecode(normalized);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The dialogue must be a JSON object.');
    }

    final known = {
      for (final word in knownWords)
        if (word.trim().isNotEmpty) word.trim(),
    };
    final newWordsJson = _objectList(decoded['new_words'], 'new_words');
    if (newWordsJson.isEmpty || newWordsJson.length > 2) {
      throw const FormatException(
        'A dialogue must introduce one or two new words.',
      );
    }
    final newWords = newWordsJson
        .map(ListeningDialogueWord.fromJson)
        .toList(growable: false);
    final newWordText = newWords.map((word) => word.chinese).toSet();
    if (newWordText.length != newWords.length ||
        newWordText.any(known.contains)) {
      throw const FormatException('New words must be unique and unstudied.');
    }

    final linesJson = _objectList(decoded['lines'], 'lines');
    if (linesJson.length < 2 || linesJson.length > 8) {
      throw const FormatException('A dialogue must contain 2–8 lines.');
    }
    final allowedWords = {...known, ...newWordText};
    final lines = linesJson
        .map(
          (line) =>
              ListeningDialogueLine.fromJson(line, allowedWords: allowedWords),
        )
        .toList(growable: false);
    if (!lines.map((line) => line.speaker).toSet().containsAll({'A', 'B'})) {
      throw const FormatException('Both dialogue speakers must have a line.');
    }
    final usedWords = lines.expand((line) => line.tokens).toSet();
    if (!usedWords.containsAll(newWordText)) {
      throw const FormatException(
        'Every new word must appear in the dialogue.',
      );
    }

    final questionsJson = _objectList(decoded['questions'], 'questions');
    if (questionsJson.length < 2 || questionsJson.length > 3) {
      throw const FormatException(
        'A dialogue must contain two or three questions.',
      );
    }

    return ListeningDialogue(
      title: _requiredText(decoded, 'title', maxLength: 80),
      setting: _requiredText(decoded, 'setting', maxLength: 120),
      lines: lines,
      newWords: newWords,
      questions: questionsJson
          .map(ListeningDialogueQuestion.fromJson)
          .toList(growable: false),
    );
  }
}

class ListeningDialogueLine {
  const ListeningDialogueLine({
    required this.speaker,
    required this.chinese,
    required this.tokens,
    required this.pinyin,
    required this.english,
  });

  final String speaker;
  final String chinese;
  final List<String> tokens;
  final String pinyin;
  final String english;

  static ListeningDialogueLine fromJson(
    Map<String, dynamic> json, {
    required Set<String> allowedWords,
  }) {
    final speaker = _requiredText(json, 'speaker', maxLength: 1);
    if (speaker != 'A' && speaker != 'B') {
      throw const FormatException('Dialogue speakers must be A or B.');
    }
    final tokens = _stringList(json['tokens'], 'tokens', maxItems: 24);
    if (tokens.isEmpty ||
        tokens.any((token) => !allowedWords.contains(token))) {
      throw const FormatException(
        'The dialogue used vocabulary outside the approved word list.',
      );
    }
    final chinese = _requiredText(json, 'chinese', maxLength: 120);
    if (_lexicalText(chinese) != _lexicalText(tokens.join())) {
      throw const FormatException(
        'Dialogue tokens must account for the complete Chinese line.',
      );
    }
    return ListeningDialogueLine(
      speaker: speaker,
      chinese: chinese,
      tokens: tokens,
      pinyin: _requiredText(json, 'pinyin', maxLength: 180),
      english: _requiredText(json, 'english', maxLength: 180),
    );
  }
}

class ListeningDialogueWord {
  const ListeningDialogueWord({
    required this.chinese,
    required this.pinyin,
    required this.english,
  });

  final String chinese;
  final String pinyin;
  final String english;

  static ListeningDialogueWord fromJson(Map<String, dynamic> json) =>
      ListeningDialogueWord(
        chinese: _requiredText(json, 'chinese', maxLength: 16),
        pinyin: _requiredText(json, 'pinyin', maxLength: 40),
        english: _requiredText(json, 'english', maxLength: 80),
      );
}

class ListeningDialogueQuestion {
  const ListeningDialogueQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  static ListeningDialogueQuestion fromJson(Map<String, dynamic> json) {
    final options = _stringList(json['options'], 'options', maxItems: 4);
    if (options.length < 2 || options.toSet().length != options.length) {
      throw const FormatException(
        'Each question needs two to four unique options.',
      );
    }
    final correctIndex = json['correct_index'];
    if (correctIndex is! int ||
        correctIndex < 0 ||
        correctIndex >= options.length) {
      throw const FormatException('A question has an invalid correct answer.');
    }
    return ListeningDialogueQuestion(
      prompt: _requiredText(json, 'prompt', maxLength: 180),
      options: options,
      correctIndex: correctIndex,
      explanation: _requiredText(json, 'explanation', maxLength: 240),
    );
  }
}

List<Map<String, dynamic>> _objectList(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be a list.');
  final result = <Map<String, dynamic>>[];
  for (final item in value) {
    if (item is! Map<String, dynamic>) {
      throw FormatException('$field contains an invalid item.');
    }
    result.add(item);
  }
  return result;
}

List<String> _stringList(Object? value, String field, {required int maxItems}) {
  if (value is! List || value.length > maxItems) {
    throw FormatException('$field must be a short list.');
  }
  final result = <String>[];
  for (final item in value) {
    if (item is! String || item.trim().isEmpty || item.length > 80) {
      throw FormatException('$field contains invalid text.');
    }
    result.add(item.trim());
  }
  return List.unmodifiable(result);
}

String _requiredText(
  Map<String, dynamic> json,
  String field, {
  required int maxLength,
}) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty || value.length > maxLength) {
    throw FormatException('$field is missing or too long.');
  }
  return value.trim();
}

String _lexicalText(String text) =>
    text.replaceAll(RegExp(r'''[\s，。！？、,.!?；;：:“”'"（）()…—-]'''), '');
