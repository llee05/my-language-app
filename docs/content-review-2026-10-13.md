# Full learning-content review — 13 October 2026

Reviewed every bundled headword and every distinct displayed vocabulary example,
all 100 sentence-practice cards, and the additional historical cards in the
installed database. Fixed confirmed definition, pronunciation, translation,
word-boundary, and sentence-quality issues through the source overrides and
generators, then regenerated the runtime assets.

The review updates 197 primary study definitions and one headword reading
(利害, lì hài, interests/advantages and disadvantages). Many definition changes
add common senses or improve wording; they are not all factual errors. There
are 357 changed primary example records: 322 change the Chinese sentence,
341 change its pinyin, and 325 change its translation. These counts overlap.

The [complete vocabulary table](content-review-2026-10-13/vocabulary.csv) contains
all 4,991 current words and their primary examples. The
[complete sentence table](content-review-2026-10-13/sentences.csv) contains all
4,658 distinct vocabulary-example records and all 100 sentence-practice cards.
The [editorial exclusion file](../assets/data/tatoeba/sentence_review_exclusions.json)
records the reasons for excluding 142 Chinese sentence IDs, 74 translation
pairs, and inappropriate inferred words in 80 source sentences. Some exclusions
overlap; these are decisions, not a count of distinct defective sentences.

## Scope and resulting coverage

The editorial pass read all 4,991 headwords, their displayed pinyin and study
definitions, all 4,657 distinct vocabulary-example records in the starting
library (797 Original and 3,860 Tatoeba), and every sentence-practice sentence.
New and changed original examples and newly selected alternate associations
received another reading and translation pass. Additional dictionary senses,
reference spellings, source readings, attribution, field consistency, and target
pronunciations were cross-checked against the existing reference datasets and
CC-CEDICT. Legitimate dialect, neutral-tone, sandhi, and erhua variants were
retained where appropriate.

| Content | Before | After |
| --- | ---: | ---: |
| Unique vocabulary words | 4,991 | 4,991 |
| Twenty-word decks / memberships | 251 / 5,020 | 251 / 5,020 |
| Primary Tatoeba examples | 4,191 | 3,905 |
| Primary Original examples | 800 | 1,086 |
| Unique sentence-listening transcripts | 3,851 | 3,567 |
| Alternate examples / words with alternates | 1,717 / 883 | 1,611 / 833 |
| Sentence-practice cards / decks | 100 / 10 | 100 / 10 |

HSK word counts remain 150, 147, 298, 598, 1,298, and 2,500 across levels 1–6.
Every vocabulary ID, deck title, level, and ordered membership is unchanged.
The target remains the pinned import source's old-HSK list, rather than every
headword in every historical HSK reference. Only adopted corpus examples
received the full editorial pass; the entire 77,669-pair source export and
unused historical candidate shortlists did not receive that certification.

## Corrections and protections

| Issue | Examples of the correction |
| --- | --- |
| Incorrect translations | Two yuan rendered as one dollar; deficit as surplus; agile as fat; lion as tiger; president as prime minister. Replaced the selected pairs with reviewed alternatives or originals. |
| Wrong target context | 动员 inside 运动员, 机关 across 收音机 + 关, 天生 across 昨天 + 生, 学问 across 数学 + 问题, and 青 inside the place name 青森. |
| Wrong contextual readings | 地里 dì, 长发 fà, 系好 jì, 有空 kòng, 取得/得到 dé, 放假 jià, 处于 chǔ, and 种的是 zhòng. Corpus records with incorrect readings such as 不禁 jìn or 监狱长 cháng are excluded without altering their source transcription. |
| Unsuitable study examples | Broken Mandarin/English, editorial brackets, invisible formatting, stale undated claims, and long paragraphs. Examples now have a hard 45-Hanzi maximum. |
| Historical pronunciation | The exact archived 下载 seed changes xiàzài to xiàzǎi, including its example reading. |

Reviewed primary choices are pinned so regeneration cannot silently replace them
with unreviewed corpus examples. The exclusion manifest is shared by primary and
alternate generators. Adopted Tatoeba text, translations, IDs, and contributor
credit remain source-derived; no replacement pinyin is invented for a defective
corpus record. Original examples use explicit contextual dictionary readings.

Sentence practice no longer infers the bundled 得 de from a děi sentence, 还 hái
from huán, or 长 cháng from zhǎng. A parser handles joined and numbered pinyin,
tone marks, umlauts, apostrophes, and erhua. Readings filter local entries only;
they never supply new word definitions. Conservative overlap/name exclusions
can omit valid practice opportunities. Sentence listening additionally offers
only reviewed curriculum owner words, addressing senses that share a reading.
Generic AI sentence matching remains a conservative dictionary match rather
than a complete semantic analysis. Ratings still require an explicit action.

## Database upgrade and verification

The new `bundled_hsk_editorial_v4` content marker applies corrections on the next
startup of the updated app, including installations that already applied v3.
Schema version stays 17. Current shared cards update in place, including quiz
answers and safe alternatives. Learner-created copies and unrelated archived
content retain their text. The precise historical 下载 seed is the sole extra
archived-card correction. Backup restore applies the current editorial update
before selecting shared cards, including older display readings.

The installed database was inspected read-only: 5,184 cards, comprising 5,084
vocabulary cards and 100 sentence cards. Ninety-three vocabulary cards are
outside the current curriculum; their displayed content was reviewed too.
The database passed integrity and foreign-key checks. A SQLite backup copy in
a temporary directory was upgraded through the actual startup code. All 4,991
current cards then matched the corrected assets. All other learner tables,
card IDs/owners, memberships, reviews, progress, and sessions were unchanged;
only the known historical download reading changed outside the curriculum.
Reopening was idempotent. The original installed database was not edited by
this review; it receives the migration when the updated app starts.

Regression tests cover upgrades with v3/v4 markers, custom and archived copies,
older backups, preserved identities/history, rollback/retry, historical-seed
failure after the shared-card batch, polyphonic matching, and corpus-wide
sentence/pinyin alignment. The standalone audit checks every runtime word and
example against the retained source files and verifies optional SQLite input
read-only. All 4,379 cached MP3 files passed checksum verification; this was not
a listening review of every recording.

Validation used Flutter 3.44.4 and Dart 3.12.2:

- Required Dart format check: 173 files checked, no changes needed.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --coverage`: all 680 tests passed. Ten focused dataset,
  reading, and provenance tests also passed after the final wording refinements.
- Python content/audio tooling: all 11 tests passed; release tooling: all 10
  tests passed.
- All four runtime JSON assets regenerated byte-for-byte from the pinned local
  inputs, reviewed overrides, and original-example generator.
- Complete content/provenance audit and two isolated installed-database upgrade
  probes passed. The final copy had zero stale curriculum cards, with identical
  hashes for all learner tables and card identities before and after the update.
- `flutter build linux --release --no-pub` and
  `flutter build apk --debug --no-pub` succeeded with the final assets.
- `git diff --check` passed; recording metadata refresh verified 4,379 MP3 files
  without changing any audio or the existing catalog.

macOS, iOS, and Windows builds were not run in this Linux environment. Android
reported existing plugin Kotlin-migration and SDK XML warnings but built
successfully. No package or native-plugin dependency changed.

## References and limits

The vocabulary import remains pinned to
[complete-hsk-vocabulary revision 7ac65bf](https://github.com/drkameleon/complete-hsk-vocabulary/tree/7ac65bf1a6387d35f1ade478906172a19311c7f9)
and the
[2012 HSK glossary](https://github.com/glxxyz/hskhsk.com/tree/8a6f229c699e2fd7ac8708156c55c3afb2be7e1f).
The additional dictionary check used the
[CC-CEDICT export](https://www.mdbg.net/chinese/dictionary?page=cc-cedict)
downloaded on 12 October 2026 (125,263 entries; compressed SHA-256
`a04c03deb9aab384df952d99194099a17d628ff57d11c8b132fe0519e691a247`).
Source sentences retain the attribution and licensing described in
[Tatoeba's download documentation](https://tatoeba.org/en/downloads) and
[the asset README](../assets/data/README.md).

This is a complete editorial pass over displayed bundled content and a
reproducible consistency/provenance audit. It is not native-lexicographer
certification or a claim that every possible synonym, regional reading, or
meaning is covered. Several references share dictionary ancestry. Custom
learner-written sentences and runtime-generated AI responses are not rewritten
as bundled content. No learner database, private record, API key, or raw external
dictionary export is included in these review artifacts.
