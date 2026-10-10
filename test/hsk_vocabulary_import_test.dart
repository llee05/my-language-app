import 'package:flutter_test/flutter_test.dart';

import '../tool/import_hsk_vocabulary.dart';

void main() {
  test('a glossary meaning from a different reading cannot win', () {
    expect(
      studyMeaningForForm(
        simplified: 'test-word',
        selectedPinyin: 'bèi',
        meanings: ['see another entry', 'the back', 'to memorize'],
        glossary: (
          traditional: 'test-word',
          pinyin: ['bēi'],
          meaning: 'to carry',
        ),
      ),
      'the back',
    );
  });

  test('the matching reading selects its own glossary branch', () {
    expect(
      studyMeaningForForm(
        simplified: 'test-word',
        selectedPinyin: 'á',
        meanings: ['fallback'],
        glossary: (
          traditional: 'test-word',
          pinyin: ['ā', 'á'],
          meaning: 'first | second; other sense',
        ),
      ),
      'second',
    );
  });

  test('ambiguous branch counts use the selected form instead', () {
    expect(
      studyMeaningForForm(
        simplified: 'test-word',
        selectedPinyin: 'á',
        meanings: ['selected sense'],
        glossary: (
          traditional: 'test-word',
          pinyin: ['ā', 'á'],
          meaning: 'first | second | third',
        ),
      ),
      'selected sense',
    );
  });

  test(
    'gloss truncation preserves parentheses and recognizes both semicolons',
    () {
      expect(
        conciseStudyGloss('inspect and accept (goods; completed work); check'),
        'inspect and accept (goods; completed work)',
      );
      expect(conciseStudyGloss('benefit；results'), 'benefit');
    },
  );
}
