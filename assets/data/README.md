# HSK vocabulary data

`hsk_vocabulary.json` is generated from the `complete.json` file in
[`drkameleon/complete-hsk-vocabulary`](https://github.com/drkameleon/complete-hsk-vocabulary).
It contains the HSK 2.0 levels 1–6 used by lessons, Vocab Rush, and the
vocabulary browser.

The importer cross-checks ambiguous readings against the original HSK 2.0
lists from [`clem109/hsk-vocabulary`](https://github.com/clem109/hsk-vocabulary)
and builds concise `studyMeaning` values from the "HSK Official With
Definitions 2012" files in
[`glxxyz/hskhsk.com`](https://github.com/glxxyz/hskhsk.com). This avoids
selecting surnames, archaic readings, variants, and other dictionary senses
that are not the intended HSK vocabulary.

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

## Twenty-word vocabulary curriculum

`vocabulary_lessons.json` contains 251 lessons covering all 4,991 vocabulary
entries: 8 / 8 / 15 / 30 / 65 / 125 lessons for HSK levels 1–6. Every deck has
20 distinct entries from its level, ordered by the vocabulary dataset. Final
decks overlap slightly with the preceding deck to stay at 20 words; there are
5,020 memberships but only 4,991 vocabulary cards on a fresh installation.

There are 4,241 Tatoeba-backed examples and 750 original examples. All entries
include Hanzi, sentence pinyin, and English. `lesson_original_examples.json`
records originals with the source label `Original` and no Tatoeba IDs.
`tool/original_lesson_examples.py` contains the authored examples, semantic frames,
translation edits, and explicit supporting-word readings. Its pinyin assembler
uses bundled dictionary readings plus that lexicon and fails on unknown words;
polyphonic words and particles require contextual readings in the lexicon.

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
