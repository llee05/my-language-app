# HSK vocabulary data

`hsk_vocabulary.json` is generated from the `complete.json` file in
[`drkameleon/complete-hsk-vocabulary`](https://github.com/drkameleon/complete-hsk-vocabulary).
It contains the HSK 2.0 levels 1–6 used by Vocab Rush.

Regenerate it with:

```sh
dart run tool/import_hsk_vocabulary.dart path/to/complete.json assets/data/hsk_vocabulary.json
```

The upstream dataset is MIT licensed. Copyright (c) 2026 Yanis Zafirópulos.

## Tatoeba sentence pairs

`tatoeba/` contains the Mandarin–English sentence-pairs export used as a
curation source for bundled flashcard examples. It is intentionally not listed
in `pubspec.yaml`, so the source corpus and generated candidate list are not
packaged in the application.

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
