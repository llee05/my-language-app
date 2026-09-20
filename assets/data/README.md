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

`tatoeba/` contains the Mandarin–English sentence-pairs export used for bundled
flashcard examples. The compact generated candidate list is packaged with the
application; the full source corpus is not.

Generate a ranked, reviewable shortlist for every bundled flashcard with:

```sh
dart run tool/build_tatoeba_candidates.dart \
  "assets/data/tatoeba/Sentence pairs in Mandarin Chinese-English - 2026-08-08.tsv" \
  lib/database/flashcard_seed.dart \
  assets/data/tatoeba/flashcard_candidates.json
```

The export is provided by [Tatoeba](https://tatoeba.org/) under CC BY 2.0 FR.
Candidate records retain both sentence IDs so adopted examples can be traced
and attributed. Generated candidates still require human review for natural
Mandarin, translation accuracy, level suitability, and sentence-level pinyin.

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

Topic titles identify the installed decks. Keep existing topic titles stable:
new installations seed these cards, and later startups preserve installed card
IDs, ratings, and session progress. Future corrections to installed content need
an explicit content migration rather than deleting and reseeding decks.
