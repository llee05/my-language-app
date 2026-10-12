import copy
import unittest

from build_vocabulary_examples import build, matching_reading


def word(text, pinyin, meaning, level=1):
    return {'id': text, 'simplified': text, 'pinyin': pinyin,
            'studyMeaning': meaning, 'hskLevel': level}


def example(chinese, pinyin, english, sid):
    return {'chinese': chinese, 'pinyin': pinyin, 'english': english,
            'source': 'Tatoeba', 'chineseId': str(sid),
            'englishId': str(sid + 100), 'pinyinContributor': 'Test author'}


class VocabularyExamplesTest(unittest.TestCase):
    def setUp(self):
        self.words = [word('茶', 'chá', 'tea'), word('书', 'shū', 'book'),
                      word('快乐', 'kuài lè', 'happy'), word('快', 'kuài', 'fast')]
        self.examples = [
            example('我喝茶。', 'Wǒ hē chá.', 'I drink tea.', 1),
            example('我买茶和书。', 'Wǒ mǎi chá hé shū.', 'I buy tea and a book.', 2),
            example('我们很快乐。', 'Wǒmen hěn kuàilè.', 'We are happy and fast.', 3),
            {'chinese': '他跑得快。', 'pinyin': 'Tā pǎo de kuài.',
             'english': 'He runs fast.', 'source': 'Original'},
        ]
        self.curriculum = {'source': {'name': 'Tatoeba'}, 'lessons': [
            {'entries': [{'vocabularyId': w['id'], 'example': e}
                         for w, e in zip(self.words, self.examples)]}]}
        self.scripts = {
            '1': {'Latn': ('Wo3 he1 cha2.', 'Test author', '')},
            '2': {'Latn': ('Wo3 mai3 cha2 he2 shu1.', 'Test author', '')},
            '3': {'Latn': ('Wo3men5 hen3 kuai4le4.', 'Test author', '')},
        }

    def test_preserves_primary_and_reuses_complete_attributed_examples(self):
        original = copy.deepcopy(self.curriculum)
        result = build(self.words, self.curriculum, self.scripts, {})
        for row, primary in zip(result['entries'], self.examples):
            self.assertEqual(row['examples'][0], primary)
        self.assertEqual(result['entries'][0]['examples'][1], self.examples[1])
        self.assertEqual(self.curriculum, original)

    def test_rejects_compound_substrings_and_missing_translation_anchor(self):
        result = build(self.words, self.curriculum, self.scripts, {})
        self.assertEqual(len(result['entries'][3]['examples']), 1)
        self.examples[1]['english'] = 'I buy coffee and a book.'
        result = build(self.words, self.curriculum, self.scripts, {})
        self.assertEqual(len(result['entries'][0]['examples']), 1)

    def test_editorial_exceptions_and_limit_keep_primary_only(self):
        result = build(self.words, self.curriculum, self.scripts, {'茶': {'omit': True}})
        self.assertEqual(len(result['entries'][0]['examples']), 1)
        result = build(self.words, self.curriculum, self.scripts, {}, limit=1)
        self.assertTrue(all(len(row['examples']) == 1 for row in result['entries']))

    def test_source_readings_are_required_and_never_invented(self):
        del self.scripts['2']
        with self.assertRaises(ValueError):
            build(self.words, self.curriculum, self.scripts, {})

    def test_level_filter_excludes_advanced_context(self):
        self.words[1]['hskLevel'] = 6
        result = build(self.words, self.curriculum, self.scripts, {})
        self.assertEqual(len(result['entries'][0]['examples']), 1)

    def test_target_readings_preserve_tones_and_umlaut(self):
        self.assertTrue(matching_reading(word('行', 'háng', 'row'), '行', ['hang2'], 0))
        self.assertFalse(matching_reading(word('行', 'háng', 'row'), '行', ['xing2'], 0))
        self.assertFalse(matching_reading(word('买', 'mǎi', 'buy'), '买', ['mai4'], 0))
        self.assertTrue(matching_reading(word('绿', 'lǜ', 'green'), '绿', ['lv4'], 0))
        self.assertFalse(matching_reading(word('绿', 'lǜ', 'green'), '绿', ['lu4'], 0))
        self.assertTrue(matching_reading(word('不', 'bù', 'not'), '不', ['bu2'], 0))


if __name__ == '__main__':
    unittest.main()
