#!/usr/bin/env python3
"""Validate every bundled word/example and optionally inspect SQLite read-only.

This checks consistency and source provenance. Editorial judgement remains in
the reviewed overrides and sentence exclusions; it is not inferred from a
successful automated check. CSV exports contain bundled content only.
"""
import argparse
import collections
import csv
import json
import sqlite3
from pathlib import Path

from build_vocabulary_examples import matching_reading
from build_vocabulary_lessons import HANZI, reading, transcriptions
from content_review import (MAX_EXAMPLE_CHARACTERS, excluded_pair,
                            has_hidden_formatting, load_review,
                            practice_exclusions)


def load(path):
    return json.loads(path.read_text())


def audit(data=Path('assets/data'), database=None, csv_directory=None):
    vocabulary = load(data / 'hsk_vocabulary.json')
    curriculum = load(data / 'vocabulary_lessons.json')
    examples = load(data / 'vocabulary_examples.json')
    originals = load(data / 'lesson_original_examples.json')
    sentences = load(data / 'sentence_practice.json')
    review = load_review(data / 'tatoeba/sentence_review_exclusions.json')
    scripts = transcriptions(data / 'tatoeba/lesson_transcriptions.tsv')
    by_id = {word['id']: word for word in vocabulary}
    problems = []

    def require(condition, message):
        if not condition:
            problems.append(message)

    require(len(vocabulary) == len(by_id) == 4991, 'Vocabulary IDs/count changed.')
    levels = dict(sorted(collections.Counter(w['hskLevel'] for w in vocabulary).items()))
    require(levels == {1: 150, 2: 147, 3: 298, 4: 598, 5: 1298, 6: 2500},
            'HSK level coverage changed.')
    for word in vocabulary:
        for field in ('id', 'simplified', 'traditional', 'pinyin', 'studyMeaning'):
            value = word.get(field)
            require(isinstance(value, str) and bool(value.strip()),
                    f"{word['id']}: missing {field}")
        require(isinstance(word.get('hasMultipleReadings'), bool),
                f"{word['id']}: missing reading-ambiguity metadata")
        for value in [word['studyMeaning'], *word['meanings']]:
            require(value.count('(') == value.count(')') and
                    value.count('[') == value.count(']'),
                    f"{word['id']}: unbalanced meaning annotation")

    primary = {}
    memberships = []
    for lesson in curriculum['lessons']:
        ids = [entry['vocabularyId'] for entry in lesson['entries']]
        require(len(ids) == len(set(ids)) == 20, f"Invalid deck: {lesson['title']}")
        memberships.extend(ids)
        for entry in lesson['entries']:
            wid = entry['vocabularyId']
            require(wid in by_id, f'Unknown deck word: {wid}')
            require(by_id[wid]['hskLevel'] == lesson['hskLevel'], f'Wrong deck level: {wid}')
            if wid in primary:
                require(primary[wid] == entry['example'], f'Inconsistent shared example: {wid}')
            primary[wid] = entry['example']
    require(len(curriculum['lessons']) == 251 and len(memberships) == 5020,
            'Curriculum deck membership count changed.')
    require(set(primary) == set(by_id), 'Curriculum does not cover every word.')
    require(not curriculum['missingExamples'], 'Missing curriculum examples.')
    require(set(originals) <= set(by_id), 'Unknown original-example word.')

    pairs = {}
    for line in (data / 'tatoeba/Sentence pairs in Mandarin Chinese-English - 2026-08-08.tsv').read_text(encoding='utf-8-sig').splitlines():
        sid, chinese, eid, english = line.split('\t')
        pairs[(sid, eid)] = (chinese, english)
    unique = {}
    associations = 0
    alternate_words = 0
    require({row['vocabularyId'] for row in examples['entries']} == set(by_id),
            'Example library does not cover every word.')
    for row in examples['entries']:
        wid = row['vocabularyId']
        word = by_id[wid]
        require(1 <= len(row['examples']) <= 5, f'Invalid example count: {wid}')
        require(row['examples'][0] == primary[wid], f'Primary example changed in library: {wid}')
        alternate_words += len(row['examples']) > 1
        seen = set()
        for example in row['examples']:
            associations += 1
            text = example['chinese']
            key = (text, example['pinyin'], example['english'])
            require(key not in seen, f'Duplicate example: {wid}')
            seen.add(key)
            unique.setdefault(key, {'example': example, 'words': set()})['words'].add(wid)
            require(word['simplified'] in text, f'Target absent: {wid}: {text}')
            require(not has_hidden_formatting(*key), f'Hidden formatting: {wid}: {text}')
            require(len(HANZI.findall(text)) <= MAX_EXAMPLE_CHARACTERS,
                    f'Example exceeds study length: {wid}: {text}')
            if example['source'] == 'Original':
                require(example == originals.get(wid), f'Unknown original: {wid}')
                continue
            require(example['source'] == 'Tatoeba', f'Unknown source: {wid}')
            sid, eid = example['chineseId'], example['englishId']
            require(not excluded_pair(sid, eid, review), f'Excluded source pair: {wid}: {sid}:{eid}')
            source = scripts.get(sid, {})
            pair = pairs.get((sid, eid))
            require(pair is not None and pair[1] == example['english'],
                    f'Translation provenance mismatch: {wid}: {sid}:{eid}')
            if pair:
                require(source.get('Hans', (pair[0],))[0] == text,
                        f'Hanzi provenance mismatch: {wid}: {sid}')
            raw = source.get('Latn')
            parsed = reading(raw[0], text) if raw else None
            require(parsed is not None and parsed[1] == example['pinyin'] and
                    raw[1] == example['pinyinContributor'],
                    f'Reading provenance mismatch: {wid}: {sid}')
            excluded = practice_exclusions(sid, review)
            require(word['simplified'] not in excluded, f'Excluded word context: {wid}: {sid}')
            require(example.get('excludedVocabulary', []) == excluded,
                    f'Missing context exclusions: {wid}: {sid}')
            if parsed:
                starts = [i for i in range(len(text)) if text.startswith(word['simplified'], i)]
                require(any(matching_reading(word, text, parsed[0], i) for i in starts),
                        f'Target reading mismatch: {wid}: {sid}')
    sentence_count = sum(len(deck['sentences']) for deck in sentences)
    require(len(sentences) == 10 and sentence_count == 100, 'Sentence-practice coverage changed.')
    for deck in sentences:
        for sentence in deck['sentences']:
            require(all(isinstance(sentence.get(field), str) and sentence[field].strip()
                        for field in ('chinese', 'pinyin', 'english')),
                    f"Missing sentence-practice field: {deck['topic']}")
            require(not has_hidden_formatting(*sentence.values()),
                    f"Hidden sentence-practice formatting: {deck['topic']}")

    stats = {
        'vocabulary': len(vocabulary), 'levels': levels,
        'decks': len(curriculum['lessons']), 'memberships': len(memberships),
        'primaryTatoeba': sum(x['source'] == 'Tatoeba' for x in primary.values()),
        'primaryOriginal': sum(x['source'] == 'Original' for x in primary.values()),
        'uniqueListeningSentences': len({x['chinese'] for x in primary.values() if x['source'] == 'Tatoeba'}),
        'exampleAssociations': associations, 'distinctExamples': len(unique),
        'alternates': associations - len(vocabulary), 'wordsWithAlternates': alternate_words,
        'sentencePractice': sentence_count,
    }
    if database:
        db = sqlite3.connect(f'{database.resolve().as_uri()}?mode=ro', uri=True)
        try:
            require(db.execute('PRAGMA integrity_check').fetchall() == [('ok',)], 'SQLite integrity failure.')
            require(not db.execute('PRAGMA foreign_key_check').fetchall(), 'SQLite foreign-key failure.')
            titles = [lesson['title'] for lesson in curriculum['lessons']]
            rows = db.execute('''SELECT DISTINCT c.id,c.chinese,c.pinyin,c.english_meaning,
                c.example_sentence_chinese,c.example_sentence_pinyin,c.example_sentence_english
                FROM cards c JOIN lessons owner ON owner.id=c.lesson_id
                JOIN lesson_cards lc ON lc.card_id=c.id JOIN lessons deck ON deck.id=lc.lesson_id
                WHERE owner.is_user_generated=0 AND owner.is_sentence_practice=0
                AND deck.is_user_generated=0 AND deck.lesson_title IN (%s)'''
                % ','.join('?' for _ in titles), titles).fetchall()
            by_text = {w['simplified']: w for w in vocabulary}
            stale = []
            for row in rows:
                word = by_text.get(row[1])
                example = primary[word['id']] if word else {}
                expected = (word['pinyin'], word['studyMeaning'], example['chinese'],
                            example['pinyin'], example['english']) if word else None
                if tuple(row[2:]) != expected:
                    stale.append(row[0])
            stats['database'] = {'curriculumCards': len(rows), 'staleCurriculumCards': len(stale)}
            require(not stale, f'{len(stale)} SQLite curriculum cards need the content update.')
        finally:
            db.close()
    if csv_directory:
        csv_directory.mkdir(parents=True, exist_ok=True)
        with (csv_directory / 'vocabulary.csv').open('w', newline='') as output:
            writer = csv.writer(output, lineterminator='\n')
            writer.writerow(['id', 'hskLevel', 'simplified', 'traditional', 'pinyin', 'studyMeaning',
                             'primaryChinese', 'primaryPinyin', 'primaryEnglish', 'source', 'chineseId', 'englishId', 'pinyinContributor'])
            for word in vocabulary:
                x = primary[word['id']]
                writer.writerow([word[k] for k in ('id','hskLevel','simplified','traditional','pinyin','studyMeaning')] +
                                [x.get(k, '') for k in ('chinese','pinyin','english','source','chineseId','englishId','pinyinContributor')])
        with (csv_directory / 'sentences.csv').open('w', newline='') as output:
            writer = csv.writer(output, lineterminator='\n')
            writer.writerow(['chinese','pinyin','english','source','chineseId','englishId','pinyinContributor','vocabularyIds'])
            for row in unique.values():
                x = row['example']
                writer.writerow([x.get(k, '') for k in ('chinese','pinyin','english','source','chineseId','englishId','pinyinContributor')] +
                                [';'.join(sorted(row['words']))])
            for deck in sentences:
                for x in deck['sentences']:
                    writer.writerow([x[k] for k in ('chinese','pinyin','english')] + ['Sentence practice','','','',''])
    return stats, problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database', type=Path)
    parser.add_argument('--csv-directory', type=Path)
    args = parser.parse_args()
    stats, problems = audit(database=args.database, csv_directory=args.csv_directory)
    print(json.dumps(stats, ensure_ascii=False, indent=2))
    for problem in problems:
        print(problem)
    if problems:
        raise SystemExit(1)
    print('All bundled content consistency and provenance checks passed.')


if __name__ == '__main__':
    main()
