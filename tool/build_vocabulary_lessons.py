#!/usr/bin/env python3
"""Build 20-word HSK decks from vocabulary and source-provided Tatoeba readings.

Only Python's standard library is needed. Tatoeba examples require source
transcriptions; explicitly authored examples fill gaps. Use overrides for
editorial choices. Uncovered entries fail unless --allow-missing is requested.
"""
import argparse
import collections
import hashlib
import json
import re
import tarfile
import unicodedata
from pathlib import Path

HANZI = re.compile(r'[\u3400-\u9fff]')
SYLLABLE = re.compile(r'(?:[a-züv]|u:)+[1-5]', re.I)
MARKS = {'a': 'āáǎà', 'e': 'ēéěè', 'i': 'īíǐì', 'o': 'ōóǒò',
         'u': 'ūúǔù', 'ü': 'ǖǘǚǜ', 'n': 'ńňǹ', 'm': 'ḿ'}


def plain(text):
    return ''.join(c for c in unicodedata.normalize('NFD', text.lower())
                   if unicodedata.category(c) != 'Mn').replace('u:', 'u').replace('v', 'u')


def tone_mark(match):
    token = match.group()
    tone = int(token[-1])
    body = token[:-1].replace('u:', 'ü').replace('U:', 'Ü').replace('v', 'ü')
    if tone == 5:
        return body
    lower = body.lower()
    if 'a' in lower:
        index = lower.index('a')
    elif 'e' in lower:
        index = lower.index('e')
    elif 'ou' in lower:
        index = lower.index('o')
    else:
        vowels = [i for i, c in enumerate(lower) if c in 'iouü']
        if not vowels:
            # Syllabic nasals are rare. Keep only source spellings we can convert.
            raise ValueError(f'Unsupported pinyin syllable: {token}')
        index = vowels[-1]
    marked = MARKS[lower[index]][tone - 1]
    if body[index].isupper():
        marked = marked.upper()
    return body[:index] + marked + body[index + 1:]


def reading(text, chinese):
    tokens = SYLLABLE.findall(text)
    remaining = SYLLABLE.sub('', text)
    if re.search(r'[A-Za-z0-9\u3400-\u9fff]', remaining):
        return None
    if len(tokens) != len(HANZI.findall(chinese)):
        return None
    try:
        converted = SYLLABLE.sub(tone_mark, text)
    except ValueError:
        return None
    converted = re.sub(r'\s+([,.!?;:])', r'\1', converted)
    converted = re.sub(r'\s+', ' ', converted).strip()
    return tokens, converted


def transcriptions(path):
    if path.name.endswith('.tar.bz2'):
        with tarfile.open(path) as archive:
            lines = archive.extractfile('transcriptions.csv').read().decode().splitlines()
    else:
        lines = path.read_text().splitlines()
    result = collections.defaultdict(dict)
    for line in lines:
        fields = line.split('\t')
        if len(fields) == 5 and fields[1] == 'cmn':
            result[fields[0]][fields[2]] = (fields[4], fields[3], line)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('vocabulary', type=Path)
    parser.add_argument('pairs', type=Path)
    parser.add_argument('transcriptions', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--overrides', type=Path,
                        default=Path('assets/data/tatoeba/lesson_example_overrides.json'))
    parser.add_argument('--source-subset', type=Path)
    parser.add_argument('--original-examples', type=Path,
                        default=Path('assets/data/lesson_original_examples.json'))
    parser.add_argument('--allow-missing', action='store_true')
    args = parser.parse_args()
    vocabulary = json.loads(args.vocabulary.read_text())
    overrides = json.loads(args.overrides.read_text()) if args.overrides.exists() else {}
    unknown = set(overrides) - {word['id'] for word in vocabulary}
    if unknown:
        raise ValueError(f'Unknown vocabulary override IDs: {sorted(unknown)}')
    scripts = transcriptions(args.transcriptions)
    by_text = collections.defaultdict(list)
    for word in vocabulary:
        by_text[word['simplified']].append(word)
    maximum_word_length = max(map(len, by_text))
    levels = {text: min(w['hskLevel'] for w in words) for text, words in by_text.items()}
    character_levels = {}
    for text, level in levels.items():
        for char in text:
            character_levels[char] = min(level, character_levels.get(char, 7))
    best = {}
    used_source = set()
    pairs_count = 0
    candidates_count = collections.Counter()
    for line in args.pairs.read_text(encoding='utf-8-sig').splitlines():
        fields = line.split('\t')
        if len(fields) != 4:
            raise ValueError('Sentence pairs must contain four TSV fields.')
        sid, original, eid, english = fields
        if not sid.isdigit() or not eid.isdigit():
            raise ValueError('Tatoeba IDs must be positive integers.')
        pairs_count += 1
        metadata = scripts.get(sid, {})
        chinese = metadata.get('Hans', (original, '', ''))[0]
        source_reading = metadata.get('Latn')
        if not source_reading or re.search(r'[A-Za-z0-9]', chinese):
            continue
        parsed = reading(source_reading[0], chinese)
        if parsed is None:
            continue
        tokens, pinyin = parsed
        chars = HANZI.findall(chinese)
        found = set()
        complex_words = []
        cursor = 0
        while cursor < len(chinese):
            match = next((chinese[cursor:cursor + length] for length in
                          range(min(maximum_word_length, len(chinese) - cursor), 0, -1)
                          if chinese[cursor:cursor + length] in levels), None)
            if match:
                complex_words.append((cursor, cursor + len(match), levels[match]))
                cursor += len(match)
            else:
                if HANZI.fullmatch(chinese[cursor]):
                    complex_words.append((cursor, cursor + 1, character_levels.get(chinese[cursor], 7)))
                cursor += 1
        # Index all vocabulary substrings in one pass rather than scanning 5k
        # words for every sentence. Reading alignment rejects e.g. 行 háng in 行 xíng.
        for start in range(len(chinese)):
            for length in range(1, min(maximum_word_length, len(chinese) - start) + 1):
                target = chinese[start:start + length]
                for word in by_text.get(target, ()):
                    offset = len(HANZI.findall(chinese[:start]))
                    actual = ''.join(plain(t[:-1]) for t in tokens[offset:offset + length])
                    expected = plain(word['pinyin']).replace(' ', '').replace("'", '')
                    target_tones = []
                    for syllable in word['pinyin'].split():
                        tone = 5
                        for character in unicodedata.normalize('NFD', syllable):
                            if character in '\u0304\u0301\u030c\u0300':
                                tone = '\u0304\u0301\u030c\u0300'.index(character) + 1
                        target_tones.append(tone)
                    actual_tokens = tokens[offset:offset + length]
                    tones_match = len(target_tones) == len(actual_tokens) and all(
                        int(token[-1]) == tone or tone == 5 or
                        (plain(token[:-1]) in ('yi', 'bu') and int(token[-1]) in (1, 2, 4))
                        for token, tone in zip(actual_tokens, target_tones))
                    if actual != expected or not tones_match or word['id'] in found:
                        continue
                    # Avoid teaching the target as a substring of a different
                    # dictionary word (e.g. 快 in 快乐 or 做主 in 做主角).
                    if any(a <= start and b >= start + length and b - a > length
                           for a, b, _ in complex_words):
                        continue
                    if length == 1 and re.match(r'(迈克|迈阿密|爱丽丝|汤姆|玛丽|杰克)', chinese[start:]):
                        continue
                    found.add(word['id'])
                    override = overrides.get(word['id'], {})
                    if override.get('omit'):
                        continue
                    if override.get('chineseId') and str(override['chineseId']) != sid:
                        continue
                    if override.get('englishId') and str(override['englishId']) != eid:
                        continue
                    candidates_count[word['id']] += 1
                    ideal = 6 + word['hskLevel'] * 2
                    meaning_terms = set(re.findall(r'[a-z]{3,}', word['studyMeaning'].lower()))
                    english_terms = set(re.findall(r'[a-z]{3,}', english.lower()))
                    relevance = len(meaning_terms & english_terms)
                    complexity = sum(max(0, level - word['hskLevel'])
                                     for _, _, level in complex_words)
                    score = relevance * 12 - abs(len(chars) - ideal) * 2 - complexity * 8
                    if len(chars) < 4 or len(chars) > 45:
                        score -= 60
                    if re.search(r'\b(fuck|shit|bitch)\b', english, re.I):
                        continue
                    score += 2 if source_reading[1] not in ('', r'\N') else 0
                    rank = (-score, int(sid), int(eid))
                    example = {
                        'chinese': chinese, 'pinyin': pinyin, 'english': english,
                        'source': 'Tatoeba', 'chineseId': sid, 'englishId': eid,
                        'pinyinContributor': source_reading[1],
                    }
                    if word['id'] not in best or rank < best[word['id']][0]:
                        best[word['id']] = (rank, example)
    for entry_id, override in overrides.items():
        if override.get('chineseId') and entry_id not in best:
            raise ValueError(f'Override has no valid matching source reading: {entry_id}')
    originals = json.loads(args.original_examples.read_text()) if args.original_examples.exists() else {}
    examples = {entry_id: record[1] for entry_id, record in best.items()}
    original_count = 0
    for word in vocabulary:
        if word['id'] in examples:
            continue
        example = originals.get(word['id'])
        if example is not None:
            if example.get('source') != 'Original' or word['simplified'] not in example.get('chinese', '') or not all(
                    isinstance(example.get(field), str) and example[field].strip()
                    for field in ('chinese', 'pinyin', 'english')):
                raise ValueError(f'Invalid original example: {word["id"]}')
            examples[word['id']] = example
            original_count += 1
    decks = []
    missing = []
    for level in range(1, 7):
        words = [w for w in vocabulary if w['hskLevel'] == level]
        for start in range(0, len(words), 20):
            batch = words[start:start + 20]
            # Keep exactly 20 distinct words even at each level's end.
            if len(batch) < 20:
                batch = words[-20:]
            number = start // 20 + 1
            entries = []
            for word in batch:
                example = examples.get(word['id'])
                if example and example['source'] == 'Tatoeba':
                    used_source.add(example['chineseId'])
                entries.append({'vocabularyId': word['id'], 'example': example})
            decks.append({'key': f'hsk-{level}-{number:03d}',
                          'title': f'HSK {level} · Lesson {number:03d}',
                          'hskLevel': level, 'entries': entries})
    for word in vocabulary:
        if word['id'] not in examples:
            missing.append({'vocabularyId': word['id'], 'chinese': word['simplified'],
                            'hskLevel': word['hskLevel']})
    output = {'version': 1, 'wordsPerLesson': 20,
              'source': {'name': 'Tatoeba', 'license': 'CC BY 2.0 FR',
                         'url': 'https://tatoeba.org/en/downloads',
                         'pairsSha256': hashlib.sha256(args.pairs.read_bytes()).hexdigest()},
              'vocabularyCount': len(vocabulary), 'exampleCount': len(examples),
              'tatoebaExampleCount': len(best), 'originalExampleCount': original_count,
              'missingExamples': missing, 'lessons': decks}
    if missing and not args.allow_missing:
        raise ValueError(f'{len(missing)} words still require original examples.')
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
    if args.source_subset:
        args.source_subset.write_text(''.join(
            record[2] + '\n' for sid in sorted(used_source, key=int)
            for _, record in sorted(scripts[sid].items())))
    print(f'{len(vocabulary)} entries in {len(decks)} 20-word lessons; '
          f'{len(best)} Tatoeba examples, {original_count} original examples, {len(missing)} missing; '
          f'{pairs_count} sentence pairs inspected.')


if __name__ == '__main__':
    main()
