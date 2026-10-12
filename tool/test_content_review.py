import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from build_vocabulary_examples import build
from content_review import excluded_pair, has_hidden_formatting
from original_lesson_examples import pinyin_for
import test_vocabulary_examples as examples_fixture
from test_vocabulary_examples import word


class ContentReviewTest(unittest.TestCase):
    def test_exclusions_distinguish_bad_reading_from_bad_translation(self):
        review = {'excludedSentenceIds': {'1': 'wrong reading'},
                  'excludedPairs': {'2:3': 'wrong translation'}}
        self.assertTrue(excluded_pair('1', '9', review))
        self.assertTrue(excluded_pair('2', '3', review))
        self.assertFalse(excluded_pair('2', '4', review))
        self.assertTrue(has_hidden_formatting('词\u200b语'))
        self.assertFalse(has_hidden_formatting('词语', 'cí yǔ'))

    def test_reviewed_primary_pins_allow_valid_alternates(self):
        fixture = examples_fixture.VocabularyExamplesTest()
        fixture.setUp()
        result = build(fixture.words, fixture.curriculum, fixture.scripts,
                       {'茶': {'reviewedPrimary': True, 'chineseId': '1'}})
        self.assertEqual(len(result['entries'][0]['examples']), 2)
        review = {'wordPracticeExclusions': {'2': ['茶']}}
        result = build(fixture.words, fixture.curriculum, fixture.scripts, {}, review=review)
        self.assertEqual(len(result['entries'][0]['examples']), 1)
        with self.assertRaises(ValueError):
            build(fixture.words, fixture.curriculum, fixture.scripts, {},
                  review={'excludedPairs': {'2:102': 'bad translation'}})

    def test_contextual_original_readings_do_not_follow_cross_word_tokens(self):
        vocabulary = json.loads(Path('assets/data/hsk_vocabulary.json').read_text())
        by_text = {w['simplified']: w for w in vocabulary}
        cases = {
            '棉花': ('这块地里种的是棉花。', 'dì lǐ zhòng de'),
            '宣布': ('老师宣布明天放假。', 'fàng jià'),
            '被动': ('他不想一直处于被动的位置。', 'chǔ yú'),
            '变迁': ('这本书记录了城市的变迁。', 'shū jì lù'),
            '夫人': ('李夫人，欢迎您来参加会议。', 'Lǐ fū ren'),
            '锲而不舍': ('学习需要锲而不舍的精神。', 'jīng shén'),
        }
        for target, (sentence, expected) in cases.items():
            self.assertIn(expected, pinyin_for(sentence, by_text[target], vocabulary))

    def test_curriculum_rejects_cross_boundary_and_excluded_pairs(self):
        # A higher-rated sentence containing 收音机+关 must not teach 机关.
        vocabulary = [word('收音机', 'shōu yīn jī', 'radio'),
                      word('关', 'guān', 'close'), word('机关', 'jī guān', 'agency')]
        pairs = '1\t请把收音机关掉。\t101\tPlease turn off the radio at the agency.\n2\t他在机关工作。\t102\tHe works at the agency.\n'
        scripts = '1\tcmn\tLatn\tReviewer\tQing3 ba3 shou1yin1ji1 guan1 diao4.\n2\tcmn\tLatn\tReviewer\tTa1 zai4 ji1guan1 gong1zuo4.\n'
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            for name, content in {'v.json': json.dumps(vocabulary), 'pairs.tsv': pairs,
                                  'scripts.tsv': scripts, 'originals.json': '{}',
                                  'overrides.json': '{}', 'review.json': json.dumps({
                                      'version': 1, 'excludedSentenceIds': {},
                                      'excludedPairs': {}, 'wordPracticeExclusions': {},
                                  })}.items():
                (base / name).write_text(content)
            command = [sys.executable, 'tool/build_vocabulary_lessons.py',
                       str(base/'v.json'), str(base/'pairs.tsv'), str(base/'scripts.tsv'),
                       str(base/'output.json'), '--overrides', str(base/'overrides.json'),
                       '--original-examples', str(base/'originals.json'), '--review', str(base/'review.json'),
                       '--allow-missing']
            subprocess.run(command, check=True, capture_output=True)
            result = json.loads((base/'output.json').read_text())
            entry = next(e for d in result['lessons'] for e in d['entries'] if e['vocabularyId'] == '机关')
            self.assertEqual(entry['example']['chineseId'], '2')
            review = json.loads((base/'review.json').read_text())
            review['excludedPairs']['2:102'] = 'bad translation'
            (base/'review.json').write_text(json.dumps(review))
            subprocess.run(command, check=True, capture_output=True)
            result = json.loads((base/'output.json').read_text())
            self.assertIn('机关', [e['vocabularyId'] for e in result['missingExamples']])


if __name__ == '__main__':
    unittest.main()
