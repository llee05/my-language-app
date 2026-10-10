import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/services/vocabulary_quiz_options.dart';

void main() {
  test(
    'valid alternate senses and annotated equivalents are never distractors',
    () {
      final examples = [
        (QuizMeaning('practice', meanings: ['to practice']), 'to practice'),
        (
          QuizMeaning('man-made', meanings: ['artificial', 'manpower']),
          'artificial',
        ),
        (QuizMeaning('interfere', meanings: ['to meddle']), 'meddle'),
        (QuizMeaning('standard (design or model)'), 'the standard'),
      ];
      for (final (answer, alternative) in examples) {
        final options = buildMeaningOptions(
          answer: answer,
          candidates: [
            QuizMeaning(alternative),
            QuizMeaning('cat'),
            QuizMeaning('a cat'),
            QuizMeaning('table'),
            QuizMeaning('water'),
          ],
        );
        expect(options, [answer.answer, 'cat', 'table', 'water']);
      }
    },
  );

  test(
    'candidate senses and identical pronunciations also exclude ambiguity',
    () {
      final options = buildMeaningOptions(
        answer: QuizMeaning('he', pinyin: 'tā', meanings: ['him']),
        candidates: [
          QuizMeaning('she', pinyin: 'T Ā'),
          QuizMeaning('a male person', meanings: ['him']),
          QuizMeaning('book', pinyin: 'shū'),
        ],
      );
      expect(options, ['he', 'book']);
    },
  );

  test('partial text is not treated as an equivalent meaning', () {
    expect(
      buildMeaningOptions(
        answer: QuizMeaning('to work'),
        candidates: [QuizMeaning('workplace'), QuizMeaning('worker')],
      ),
      ['to work', 'workplace', 'worker'],
    );
  });

  test(
    'all bundled vocabulary supports four distinct dictionary-aware choices',
    () {
      final vocabulary =
          (jsonDecode(
                    File('assets/data/hsk_vocabulary.json').readAsStringSync(),
                  )
                  as List)
              .cast<Map<String, dynamic>>();
      final index = VocabularyQuizIndex(vocabulary);
      final byLevel = {
        for (var level = 1; level <= 6; level++)
          level: [
            for (final word in vocabulary)
              if (word['hskLevel'] == level) index.forEntry(word),
          ],
      };
      for (final word in vocabulary) {
        final answer = index.forEntry(word);
        final options = buildMeaningOptions(
          answer: answer,
          candidates: byLevel[word['hskLevel']]!,
        );
        expect(options, hasLength(4), reason: word['simplified'] as String);
        expect(options.first, answer.answer);
        for (final option in options.skip(1)) {
          expect(
            answer.overlaps(QuizMeaning(option)),
            isFalse,
            reason: '${word['simplified']}: $option',
          );
        }
      }
    },
  );
}
