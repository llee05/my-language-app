#!/usr/bin/env python3
"""Reuse attributed curriculum sentences as conservative word alternatives.

Primary examples stay unchanged. Alternates come only from the existing Tatoeba
selection, retain its translation and transcription, and require a standalone
target with the intended reading and an English study-meaning anchor.
"""
import argparse
import collections
import hashlib
import json
import re
import unicodedata
from pathlib import Path

from build_vocabulary_lessons import HANZI, plain, reading, transcriptions

STOP_WORDS = set('a an the to of in on at for with and or as by from be is are '
                 'was were being been someone something person people thing '
                 'used use form bound noun verb adjective adverb particle '
                 'measure word classifier suffix prefix also especially'.split())
IRREGULAR = {
    'learn': 'study', 'learns': 'study', 'learning': 'study',
    'drank': 'drink', 'drunk': 'drink', 'ate': 'eat', 'eaten': 'eat',
    'went': 'go', 'gone': 'go', 'came': 'come', 'bought': 'buy', 'sold': 'sell',
    'taught': 'teach', 'learnt': 'study', 'learned': 'study', 'thought': 'think',
    'said': 'say', 'spoke': 'speak', 'spoken': 'speak', 'wrote': 'write',
    'written': 'write', 'took': 'take', 'taken': 'take', 'gave': 'give',
    'given': 'give', 'saw': 'see', 'seen': 'see', 'felt': 'feel', 'made': 'make',
    'knew': 'know', 'known': 'know', 'studies': 'study', 'studied': 'study',
    'studying': 'study', 'children': 'child', 'men': 'man', 'women': 'woman',
}


def terms(text):
    return {IRREGULAR.get(token, token) for token in re.findall(r'[a-z]+', text.lower())
            if len(token) >= 3 and token not in STOP_WORDS}


def matching_reading(word, chinese, tokens, start):
    target = word['simplified']
    offset = len(HANZI.findall(chinese[:start]))
    actual = tokens[offset:offset + len(target)]
    expected = word['pinyin'].split()
    if len(actual) != len(expected):
        return False
    for token, syllable in zip(actual, expected):
        def syllable_base(value):
            value = value.lower().replace('u:', 'ü').replace('v', 'ü')
            return unicodedata.normalize('NFC', ''.join(
                c for c in unicodedata.normalize('NFD', value)
                if c not in '\u0304\u0301\u030c\u0300'))
        if syllable_base(token[:-1]) != syllable_base(syllable):
            return False
        marks = [c for c in unicodedata.normalize('NFD', syllable)
                 if c in '\u0304\u0301\u030c\u0300']
        tone = '\u0304\u0301\u030c\u0300'.index(marks[0]) + 1 if marks else 5
        # Source sandhi for 一/不 and neutral-tone variants are retained.
        if (int(token[-1]) != tone and tone != 5 and
                not (plain(token[:-1]) in ('yi', 'bu') and int(token[-1]) in (1, 2, 4))):
            return False
    return True


def build(vocabulary, curriculum, scripts, overrides, limit=5):
    if not 1 <= limit <= 5:
        raise ValueError('Example limit must be between 1 and 5.')
    primary = {}
    pool = {}
    for lesson in curriculum['lessons']:
        for entry in lesson['entries']:
            example = entry['example']
            primary[entry['vocabularyId']] = example
            if example['source'] == 'Tatoeba':
                pool.setdefault(example['chinese'], example)
    if set(primary) != {word['id'] for word in vocabulary}:
        raise ValueError('Curriculum and vocabulary IDs must match.')
    by_text = {word['simplified']: word for word in vocabulary}
    maximum = max(map(len, by_text))
    candidates = collections.defaultdict(list)
    for chinese, example in pool.items():
        metadata = scripts.get(example['chineseId'], {})
        source = metadata.get('Latn')
        parsed = reading(source[0], chinese) if source else None
        if parsed is None or parsed[1] != example['pinyin']:
            raise ValueError(f'Example lacks its source reading: {example["chineseId"]}')
        tokens = parsed[0]
        if not 4 <= len(tokens) <= 30:
            continue
        # Longest vocabulary words protect against e.g. 快 inside 快乐.
        spans = []
        cursor = 0
        while cursor < len(chinese):
            match = next((chinese[cursor:cursor + size] for size in
                          range(min(maximum, len(chinese) - cursor), 0, -1)
                          if chinese[cursor:cursor + size] in by_text), None)
            if match:
                spans.append((cursor, cursor + len(match), by_text[match]['hskLevel']))
                cursor += len(match)
            else:
                cursor += 1
        english_terms = terms(example['english'])
        for start, end, _ in spans:
            word = by_text[chinese[start:end]]
            if word['id'] in overrides:
                # Reviewed exceptions retain their designated context until
                # alternate contexts receive an explicit editorial review.
                continue
            if chinese == primary[word['id']]['chinese']:
                continue
            if not matching_reading(word, chinese, tokens, start):
                continue
            anchors = terms(word['studyMeaning'])
            relevance = len(anchors & english_terms)
            if not relevance:
                continue
            if any(level > min(6, word['hskLevel'] + 2) for _, _, level in spans):
                continue
            complexity = sum(max(0, level - word['hskLevel']) for _, _, level in spans)
            ideal = 6 + word['hskLevel'] * 2
            score = relevance * 12 - abs(len(tokens) - ideal) * 2 - complexity * 8
            candidates[word['id']].append(((-score, int(example['chineseId']),
                                            int(example['englishId'])), example))
    entries = []
    for word in vocabulary:
        examples = [primary[word['id']]]
        seen = {examples[0]['chinese']}
        for _, example in sorted(candidates[word['id']], key=lambda item: item[0]):
            if len(examples) >= limit:
                break
            if example['chinese'] not in seen:
                seen.add(example['chinese'])
                examples.append(example)
        entries.append({'vocabularyId': word['id'], 'chinese': word['simplified'],
                        'pinyin': word['pinyin'], 'examples': examples})
    return {'version': 1, 'source': curriculum['source'], 'maxExamplesPerWord': limit,
            'vocabularyCount': len(entries),
            'wordsWithAlternates': sum(len(entry['examples']) > 1 for entry in entries),
            'alternateExampleCount': sum(len(entry['examples']) - 1 for entry in entries),
            'entries': entries}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vocabulary', type=Path, default=Path('assets/data/hsk_vocabulary.json'))
    parser.add_argument('--curriculum', type=Path, default=Path('assets/data/vocabulary_lessons.json'))
    parser.add_argument('--transcriptions', type=Path, default=Path('assets/data/tatoeba/lesson_transcriptions.tsv'))
    parser.add_argument('--overrides', type=Path, default=Path('assets/data/tatoeba/lesson_example_overrides.json'))
    parser.add_argument('--output', type=Path, default=Path('assets/data/vocabulary_examples.json'))
    args = parser.parse_args()
    document = build(json.loads(args.vocabulary.read_text()),
                     json.loads(args.curriculum.read_text()),
                     transcriptions(args.transcriptions),
                     json.loads(args.overrides.read_text()))
    document['curriculumSha256'] = hashlib.sha256(args.curriculum.read_bytes()).hexdigest()
    args.output.write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n')
    print(f'{document["wordsWithAlternates"]} words with {document["alternateExampleCount"]} '
          f'alternates; {document["vocabularyCount"]} primary examples preserved.')


if __name__ == '__main__':
    main()
