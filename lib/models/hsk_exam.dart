import 'dart:math';

import '../database/vocabulary_content.dart';
import '../services/vocabulary_quiz_options.dart';

enum ExamSection {
  reading('Reading'),
  pinyin('Pinyin'),
  writing('Written recall'),
  listening('Listening');

  const ExamSection(this.label);
  final String label;
}

/// TingShuo's own vocabulary assessment, not an official HSK paper.
class HskExam {
  HskExam({required this.level, required List<ExamQuestion> questions})
    : questions = List.unmodifiable(questions);

  final int level;
  final List<ExamQuestion> questions;
  Duration get timeLimit => Duration(minutes: 20 + level * 5);
  static int questionsPerSection(int level) => 8 + level * 2;
}

class ExamWord {
  const ExamWord({
    required this.id,
    required this.hanzi,
    required this.traditional,
    required this.pinyin,
    required this.meaning,
    required this.meanings,
  });

  final String id;
  final String hanzi;
  final String traditional;
  final String pinyin;
  final String meaning;
  final Set<String> meanings;
}

class ExamQuestion {
  ExamQuestion({
    required this.section,
    required this.word,
    required List<String> options,
  }) : options = List.unmodifiable(options);

  final ExamSection section;
  final ExamWord word;
  final List<String> options;
  String get answer => section == ExamSection.pinyin
      ? word.pinyin
      : section == ExamSection.writing
      ? word.hanzi
      : word.meaning;

  String get prompt => switch (section) {
    ExamSection.reading => word.hanzi,
    ExamSection.pinyin => '${word.hanzi} · ${word.meaning}',
    ExamSection.writing => '${word.meaning}\n${word.pinyin}',
    ExamSection.listening => 'Listen and choose the meaning',
  };

  bool isCorrect(String? response) {
    if (response == null || response.trim().isEmpty) return false;
    final normalized = response.trim();
    return normalized == answer ||
        (section == ExamSection.writing && normalized == word.traditional);
  }
}

class HskExamGenerator {
  HskExamGenerator({Random? random}) : _random = random ?? Random();
  final Random _random;

  HskExam generate(
    List<Map<String, dynamic>> entries, {
    required int level,
    bool includeListening = true,
  }) {
    RangeError.checkValueInInterval(level, 1, 6, 'level');
    final words = <ExamWord>[];
    final seen = <String>{};
    for (final entry in entries.where((entry) => entry['hskLevel'] == level)) {
      final hanzi = entry['simplified'];
      final pinyin = entry['pinyin'];
      final id = entry['id'];
      if (hanzi is! String ||
          hanzi.trim().isEmpty ||
          pinyin is! String ||
          pinyin.trim().isEmpty ||
          id is! String ||
          id.isEmpty) {
        throw const FormatException('Incomplete exam vocabulary.');
      }
      if (!seen.add(hanzi.trim())) continue;
      final meaning = vocabularyStudyMeaning(entry);
      words.add(
        ExamWord(
          id: id,
          hanzi: hanzi.trim(),
          traditional:
              (entry['traditional'] as String?)?.trim() ?? hanzi.trim(),
          pinyin: pinyin.trim(),
          meaning: meaning,
          meanings: Set.unmodifiable(vocabularyDisplayMeanings(entry)),
        ),
      );
    }
    words.shuffle(_random);
    final meanings = {
      for (final word in words)
        word.id: QuizMeaning(word.meaning, meanings: word.meanings),
    };
    final sections = ExamSection.values.where(
      (section) => includeListening || section != ExamSection.listening,
    );
    final used = <String>{};
    final questions = <ExamQuestion>[];
    final count = HskExam.questionsPerSection(level);
    for (final section in sections) {
      var added = 0;
      for (final word in words) {
        if (used.contains(word.id)) continue;
        final options = <String>[];
        if (section != ExamSection.writing) {
          final answer = section == ExamSection.pinyin
              ? word.pinyin
              : word.meaning;
          final seenOptions = <String>{answer.toLowerCase()};
          final candidates = words.toList()..shuffle(_random);
          for (final other in candidates) {
            if (other.hanzi == word.hanzi ||
                other.pinyin == word.pinyin ||
                meanings[word.id]!.overlaps(meanings[other.id]!)) {
              continue;
            }
            final option = section == ExamSection.pinyin
                ? other.pinyin
                : other.meaning;
            if (seenOptions.add(option.toLowerCase())) options.add(option);
            if (options.length == 3) break;
          }
          if (options.length != 3) continue;
          options.add(answer);
          options.shuffle(_random);
        }
        questions.add(
          ExamQuestion(section: section, word: word, options: options),
        );
        used.add(word.id);
        if (++added == count) break;
      }
      if (added != count) {
        throw StateError(
          'Not enough distinct HSK $level vocabulary for a full exam.',
        );
      }
    }
    return HskExam(level: level, questions: questions);
  }
}

class ExamResult {
  ExamResult({
    required this.exam,
    required List<String?> responses,
    Set<int> excluded = const {},
    required this.timedOut,
  }) : responses = List.unmodifiable(responses),
       excluded = Set.unmodifiable(excluded) {
    if (responses.length != exam.questions.length ||
        excluded.any((index) => index < 0 || index >= responses.length)) {
      throw ArgumentError('Answers must match the exam.');
    }
  }

  final HskExam exam;
  final List<String?> responses;
  final Set<int> excluded;
  final bool timedOut;
  int get total => exam.questions.length - excluded.length;
  int get correct => scoreFor(null).$1;
  int get percentage => total == 0 ? 0 : (correct * 100 / total).round();
  int get unanswered => [
    for (var i = 0; i < responses.length; i++)
      if (!excluded.contains(i) && (responses[i]?.trim().isEmpty ?? true)) i,
  ].length;

  (int, int) scoreFor(ExamSection? section) {
    var correct = 0;
    var total = 0;
    for (var i = 0; i < exam.questions.length; i++) {
      final question = exam.questions[i];
      if (excluded.contains(i) ||
          (section != null && question.section != section)) {
        continue;
      }
      total++;
      if (question.isCorrect(responses[i])) correct++;
    }
    return (correct, total);
  }
}
