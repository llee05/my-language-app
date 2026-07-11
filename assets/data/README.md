# HSK vocabulary data

`hsk_vocabulary.json` is generated from the `complete.json` file in
[`drkameleon/complete-hsk-vocabulary`](https://github.com/drkameleon/complete-hsk-vocabulary).
It contains the HSK 2.0 levels 1–6 used by Vocab Rush.

Regenerate it with:

```sh
dart run tool/import_hsk_vocabulary.dart path/to/complete.json assets/data/hsk_vocabulary.json
```

The upstream dataset is MIT licensed. Copyright (c) 2026 Yanis Zafirópulos.
