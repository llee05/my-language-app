import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/models/hsk_exam.dart';

void main() {
  final entries =
      (jsonDecode(File('assets/data/hsk_vocabulary.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();

  for (var level = 1; level <= 6; level++) {
    for (final listening in [true, false]) {
      test('HSK $level builds a balanced full exam, listening=$listening', () {
        for (var seed = 0; seed < 3; seed++) {
          final exam = HskExamGenerator(
            random: Random(seed),
          ).generate(entries, level: level, includeListening: listening);
          final perSection = HskExam.questionsPerSection(level);
          expect(exam.questions.length, perSection * (listening ? 4 : 3));
          expect(
            exam.questions.map((q) => q.word.id).toSet().length,
            exam.questions.length,
          );
          expect(
            exam.questions.map((q) => q.word.hanzi).toSet().length,
            exam.questions.length,
          );
          expect(exam.timeLimit, Duration(minutes: 20 + level * 5));
          for (final section in ExamSection.values) {
            expect(
              exam.questions.where((q) => q.section == section).length,
              section == ExamSection.listening && !listening ? 0 : perSection,
            );
          }
          for (final q in exam.questions) {
            expect(
              entries.singleWhere(
                (entry) => entry['id'] == q.word.id,
              )['hskLevel'],
              level,
            );
            expect(q.isCorrect(q.answer), isTrue);
            expect(q.isCorrect(null), isFalse);
            expect(q.isCorrect(''), isFalse);
            if (q.section == ExamSection.writing) {
              expect(q.options, isEmpty);
              expect(q.isCorrect(' ${q.word.traditional} '), isTrue);
            } else {
              expect(q.options, hasLength(4));
              expect(
                q.options.map((option) => option.toLowerCase()).toSet(),
                hasLength(4),
              );
              expect(q.options.where(q.isCorrect), [q.answer]);
            }
            if (q.section == ExamSection.listening) {
              expect(q.prompt, isNot(contains(q.word.hanzi)));
              expect(q.prompt, isNot(contains(q.word.pinyin)));
            }
          }
          final result = ExamResult(
            exam: exam,
            responses: exam.questions.map((q) => q.answer).toList(),
            timedOut: false,
          );
          expect(result.percentage, 100);
          expect(result.unanswered, 0);
        }
      });
    }
  }

  test('seeds reproduce exams while fresh seeds vary the questions', () {
    List<String> ids(int seed) => HskExamGenerator(
      random: Random(seed),
    ).generate(entries, level: 3).questions.map((q) => q.word.id).toList();
    expect(ids(12), ids(12));
    expect(ids(12), isNot(ids(13)));
  });

  test(
    'invalid levels, missing content, and malformed vocabulary fail explicitly',
    () {
      final generator = HskExamGenerator();
      for (final level in [0, 7]) {
        expect(
          () => generator.generate(entries, level: level),
          throwsRangeError,
        );
      }
      expect(() => generator.generate([], level: 1), throwsStateError);
      expect(
        () => generator.generate([
          {'hskLevel': 1},
        ], level: 1),
        throwsFormatException,
      );
      expect(
        () => generator.generate(List.filled(100, entries.first), level: 1),
        throwsStateError,
      );
    },
  );

  test(
    'scores include unanswered, omit unavailable audio, and freeze responses',
    () {
      final exam = HskExamGenerator(
        random: Random(3),
      ).generate(entries, level: 1);
      final responses = List<String?>.filled(exam.questions.length, null);
      responses[0] = exam.questions.first.answer;
      responses[1] = 'wrong';
      final excluded = {exam.questions.length - 1};
      final result = ExamResult(
        exam: exam,
        responses: responses,
        excluded: excluded,
        timedOut: true,
      );
      responses[0] = null;
      excluded.clear();
      expect(result.correct, 1);
      expect(result.total, 39);
      expect(result.unanswered, 37);
      expect(result.percentage, 3);
      expect(result.scoreFor(ExamSection.reading), (1, 10));
      expect(result.scoreFor(ExamSection.listening), (0, 9));
      expect(result.timedOut, isTrue);
      expect(() => result.responses[0] = 'changed', throwsUnsupportedError);
      expect(
        () => ExamResult(exam: exam, responses: [], timedOut: false),
        throwsArgumentError,
      );
      expect(
        () => ExamResult(
          exam: exam,
          responses: responses,
          excluded: {-1},
          timedOut: false,
        ),
        throwsArgumentError,
      );
    },
  );
}
