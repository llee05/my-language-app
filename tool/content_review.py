"""Shared, explicit editorial decisions for the bundled learning content."""
import json
import unicodedata
from pathlib import Path


REVIEW_PATH = Path('assets/data/tatoeba/sentence_review_exclusions.json')
MAX_EXAMPLE_CHARACTERS = 45


def load_review(path=REVIEW_PATH):
    document = json.loads(path.read_text())
    if document.get('version') != 1:
        raise ValueError('Unsupported content review version.')
    for field in ('excludedSentenceIds', 'excludedPairs', 'wordPracticeExclusions'):
        if not isinstance(document.get(field), dict):
            raise ValueError(f'Invalid content review {field}.')
    return document


def excluded_pair(chinese_id, english_id, review):
    return (str(chinese_id) in review.get('excludedSentenceIds', {}) or
            f'{chinese_id}:{english_id}' in review.get('excludedPairs', {}))


def has_hidden_formatting(*texts):
    return any(unicodedata.category(character) == 'Cf'
               for text in texts for character in text)


def practice_exclusions(chinese_id, review):
    return list(review.get('wordPracticeExclusions', {}).get(str(chinese_id), []))
