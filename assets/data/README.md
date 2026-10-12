# HSK vocabulary data

`hsk_vocabulary.json` is generated from the `complete.json` file in
[`drkameleon/complete-hsk-vocabulary`](https://github.com/drkameleon/complete-hsk-vocabulary).
It contains the HSK 2.0 levels 1–6 used by lessons, Vocab Rush, and the
vocabulary browser.

The target list is the `old-1`–`old-6` labels in the pinned import source
(commit `7ac65bf1a6387d35f1ade478906172a19311c7f9`). This is 4,991
unique headwords, not an assertion of complete coverage of every HSK reference.
The original `clem109` reference also includes 称 and 志愿者, which have no
old-HSK labels in that import source; the curriculum retains its existing scope.

The importer cross-checks ambiguous readings against the original HSK 2.0
lists from [`clem109/hsk-vocabulary`](https://github.com/clem109/hsk-vocabulary)
and builds concise `studyMeaning` values from the "HSK Official With
Definitions 2012" files in
[`glxxyz/hskhsk.com`](https://github.com/glxxyz/hskhsk.com). This avoids
selecting surnames, archaic readings, variants, and other dictionary senses
that are not the intended HSK vocabulary. Glossary branches must match the
selected reading; unmatched or ambiguous branches fall back to that form’s
substantive dictionary senses. Reviewed definitions, reference repairs, modern
display variants, and source-tag exclusions live in
`tool/hsk_vocabulary_overrides.dart`. Explicit compatibility glosses preserve
established study senses when the older glossary contains branch-count, spelling,
or sandhi inconsistencies. Semicolons inside parentheses do not truncate a gloss.

Regenerate it with:

```sh
dart run tool/import_hsk_vocabulary.dart \
  path/to/complete.json \
  path/to/hskhsk.com/data/lists \
  assets/data/hsk_vocabulary.json
```

Both upstream datasets are MIT licensed. The complete vocabulary dataset is
copyright (c) 2026 Yanis Zafirópulos.

## Tatoeba sentence pairs

`tatoeba/` contains the Mandarin–English sentence-pairs export used to build
vocabulary lesson examples. The full corpus is not packaged with the app.
`lesson_transcriptions.tsv` retains the selected sentences' original Tatoeba
transcription records: sentence ID, language, script, contributor, and text.
`Hans` supplies Simplified Chinese when available; `Latn` supplies sentence pinyin.
The generator converts numeric tones to tone marks, retains source readings,
and rejects missing readings or incompatible target-word pronunciations.

The export is provided by [Tatoeba](https://tatoeba.org/en/downloads) under
[CC BY 2.0 FR](https://creativecommons.org/licenses/by/2.0/fr/).
Each adopted example retains both sentence IDs, its source label, and its pinyin
contributor when available. Sentence pages are `https://tatoeba.org/en/sentences/show/ID`.
Review source examples for Mandarin naturalness, translation accuracy, level
suitability, intended word sense, and contextual pinyin. Record corrections in
`lesson_example_overrides.json`; use an original example when no suitable source
pair with a correct reading is available.

`sentence_review_exclusions.json` records unsuitable sentences, incorrect
translation pairs, and words whose apparent occurrence has the wrong sense or
crosses a word boundary. Both generators enforce these decisions, reject hidden
formatting, and cap vocabulary examples at 45 Hanzi. Reviewed primary choices
are pinned in `lesson_example_overrides.json`; pins permit reviewed alternate
contexts unless `excludeAlternates` is set. Raw corpus records remain unchanged.

## Twenty-word vocabulary curriculum

`vocabulary_lessons.json` contains 251 lessons covering all 4,991 vocabulary
entries: 8 / 8 / 15 / 30 / 65 / 125 lessons for HSK levels 1–6. Every deck has
20 distinct entries from its level, ordered by the vocabulary dataset. Final
decks overlap slightly with the preceding deck to stay at 20 words; there are
5,020 memberships but only 4,991 vocabulary cards on a fresh installation.

There are 3,905 Tatoeba-backed examples and 1,086 original examples. All entries
include Hanzi, sentence pinyin, and English. `lesson_original_examples.json`
records originals with the source label `Original` and no Tatoeba IDs.
`tool/original_lesson_examples.py` contains the authored examples, semantic frames,
translation edits, and explicit supporting-word readings. Its pinyin assembler
uses bundled dictionary readings plus that lexicon and fails on unknown words;
polyphonic words and particles require contextual readings in the lexicon.

The Doom Scrolling sentence-listening feed reuses the Tatoeba entries in
`vocabulary_lessons.json`, deduplicating repeated Chinese sentences across
headwords and overlapping decks into 3,567 sentences. It keeps source pinyin,
both sentence IDs, and pinyin contributors, and excludes original examples.
The app's speech engine reads the sentences; no Tatoeba audio is bundled or
downloaded. No new corpus asset or content migration is needed for this feed.

Sentence word practice uses the reviewed curriculum associations and source
pinyin to filter the bundled word readings. Unsupported transcripts, ambiguous
crossing matches, proper names, and incompatible polyphonic readings do not
offer inferred word ratings. Generic sentence practice also checks available
pinyin; explicit standalone dictionary ratings retain their selected word.

`vocabulary_examples.json` preserves all 4,991 primary examples and adds 1,611
alternate examples for 833 words, with at most five examples per word. Alternates
reuse the existing curriculum's Tatoeba selection; they do not introduce new
corpus sentences, translations, or authored pinyin. The generator checks the
source transcription against the target reading (including ü and tones),
matches the longest bundled words, requires an English study-meaning anchor,
and excludes contexts containing bundled words more than two HSK levels above
the target. These filters are conservative selection rules, not a complete
semantic or sentence-difficulty model. Words with explicit editorial exceptions
keep their primary example until their alternate contexts are reviewed.

Flashcards, Dictionary, and Doom Scrolling load this immutable asset without
writing to SQLite. Ratings, card IDs, sessions, custom decks, and backups retain
their existing behavior. Example browsing cycles in memory and does not award
mastery. Regenerate offline after updating the vocabulary or curriculum:

```sh
python3 tool/build_vocabulary_examples.py
python3 -m unittest discover -s tool -p 'test_vocabulary_examples.py' -v
flutter test test/bundled_vocabulary_example_repository_test.dart test/vocabulary_examples_test.dart
```

The output records its source curriculum checksum and actual coverage. English
anchors can miss valid synonyms; absence of an alternate does not establish
that Tatoeba has no suitable sentence. Expanding coverage requires additional
context review, rather than weakening pronunciation or editorial protections.

Regenerate the originals and final runtime asset without downloading data:

```sh
python3 tool/original_lesson_examples.py
python3 tool/build_vocabulary_lessons.py \
  assets/data/hsk_vocabulary.json \
  "assets/data/tatoeba/Sentence pairs in Mandarin Chinese-English - 2026-08-08.tsv" \
  assets/data/tatoeba/lesson_transcriptions.tsv \
  assets/data/vocabulary_lessons.json
```

For a complete reselection, download `transcriptions.tar.bz2` from
[Tatoeba's exports](https://downloads.tatoeba.org/exports/transcriptions.tar.bz2),
pass that archive instead of the transcription subset, and add
`--source-subset assets/data/tatoeba/lesson_transcriptions.tsv`. Keep the full
archive outside the repository. `--allow-missing` produces a gap report while
editing; add missing original examples, regenerate them, and run the final
generator without that flag to enforce complete coverage. The original-example
generator preserves existing originals when adding newly reported gaps.

Schema 17 and `bundled_hsk_curriculum_v1` install this library transactionally.
Ordered memberships reuse existing non-custom card IDs and their saved progress.
Historical default decks are archived so their unfinished sessions and card order
remain available; learner-created lessons and the sentence decks are preserved.
Backups include memberships and archive flags, and older backups acquire the
curriculum during restore. Repeated startup does not reinstall content.
`bundled_hsk_examples_v2` applies the reviewed 最 and 一会儿 example corrections
once to installed curriculum cards. It changes only example text and attribution,
preserving card IDs, memberships, learner history, sessions, and custom copies.
The replacements are recorded in `lesson_example_overrides.json`; their source
transcriptions remain in the bundled subset for offline regeneration.

`bundled_hsk_editorial_v3` applies the vocabulary review in place, including
readings, meanings, grammatical tags, examples, designated answers, and safe
quiz alternatives. It preserves current memberships, card IDs, reviews, and
sessions; learner-created copies and archived cards outside the current
curriculum keep their text. Older backups are corrected before shared-card
selection, including decks with the legacy display readings.

`bundled_hsk_editorial_v4` applies the full word and sentence review even when v3
has already run. It corrects current shared cards transactionally and repairs
the exact historical 下载 seed's reading, preserving learner records and custom
copies. Older backups also receive the update before shared-card selection.
See [the completed review](../../docs/content-review-2026-10-13.md) and its
full word/sentence CSVs. Validate every bundled association and source record
offline with:

```sh
python3 tool/audit_learning_content.py
python3 tool/audit_learning_content.py --database path/to/copied/local_app.db
python3 -m unittest discover -s tool -p 'test_*.py' -v
flutter test test/mandarin_sentence_reading_test.dart test/vocabulary_editorial_update_test.dart
```

The database audit opens SQLite read-only. Use `--csv-directory path/to/output`
to export bundled review tables; it never exports learner records. These checks
verify consistency and provenance, not naturalness or translation quality.

Quiz alternatives use the target’s known dictionary senses, ordinary English
articles, and parenthetical annotations to reject equivalent meanings. Matching
pronunciations are also excluded. The same rule serves installed cards, Listening
Practice, Vocab Rush, and Exam Mode. This is a conservative check of supplied
senses, not a complete English synonym model.

When vocabulary display readings change, refresh the recording catalog’s
curriculum metadata without downloading or modifying audio:

```sh
python3 tool/import_mandarin_audio.py --refresh-metadata
python3 tool/import_mandarin_audio.py --verify
```

Both operations verify the pinned cached audio; metadata refresh fails before
writing if any recording is damaged. Catalog pinyin remains curriculum metadata
rather than a verified transcript of the recordings.

The historical flashcard seeds in `lib/database/flashcard_seed.dart` remain as
migration definitions. They no longer seed the default vocabulary library.

Generate a ranked, reviewable shortlist for the historical flashcards with:

```sh
dart run tool/build_tatoeba_candidates.dart \
  "assets/data/tatoeba/Sentence pairs in Mandarin Chinese-English - 2026-08-08.tsv" \
  lib/database/flashcard_seed.dart \
  assets/data/tatoeba/flashcard_candidates.json
```

This older shortlist targets the historical seeds rather than the new curriculum.

## Everyday sentence practice

`sentence_practice.json` contains 100 original, AI-assisted Mandarin study
sentences and short conversational expressions, grouped into ten topics of ten.
They are bundled for offline practice under Lessons → Sentence practice. This is
an editorial selection of common everyday language, not a corpus-ranked top 100
or an HSK-aligned curriculum. No external sentence corpus was copied.

Each entry includes Simplified Chinese, full sentence pinyin with tone marks,
and an English translation. Pinyin shows common pronunciation changes for 一
and 不; third-tone sandhi retains the dictionary tone marks. Neutral-tone
syllables have no tone mark. Keep these conventions consistent when editing.

Sentence deck topics and word order remain stable. The historical
`bundled_lessons_rewrite_v1` content update preserves their lesson/card IDs,
ratings, schedules, and session positions. Origin tracking protects custom decks
even when they share a bundled title. Bundled lessons are protected from deletion;
custom lesson deletion also removes that lesson's cards, progress, and reviews.
Future content corrections need an explicit content migration rather than
deleting and reseeding decks.
