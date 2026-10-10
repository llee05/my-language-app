# App improvements — 11 October 2026

TingShuo `1.0.0-beta.7+7` received content, assessment, explanation, interaction,
and maintenance improvements within its existing feature set. The 80% learned
rule and existing scores remain unchanged, as requested. Schema 17, curriculum
membership/order, dependencies, platform overrides, and the package version are
unchanged.

## Vocabulary and examples

The [10 October review](vocabulary-review-2026-10-10.md) and its CSV remain a
historical snapshot. All 212 flagged entries now have a correction or an explicit
reviewed reading/traditional-form choice. Across 243 changed vocabulary entries:

- 197 primary study meanings changed. All 18 high-priority findings are
  corrected across meaning and reading fields.
- Nine display readings and five traditional forms changed.
- Twelve words have repaired complete dictionary references. Other raw-sense
  changes follow the selected form or the retained alternate reading of 泄露.
- The source's unrelated personal-name tags were removed from 34 common words.
  Dictionary grammar chips now display readable labels.

The importer associates glossary branches with the selected reading and uses
that form's substantive senses when branches cannot be matched. Reviewed
compatibility glosses retain useful established meanings where the older glossary
contains spelling, sandhi, or branch-count inconsistencies. Both semicolon forms
are recognized, and parenthetical explanations remain intact.

The source scope is explicitly documented: the 4,991 `old-1`–`old-6` headwords in
pinned `drkameleon/complete-hsk-vocabulary` commit
`7ac65bf1a6387d35f1ade478906172a19311c7f9`. 称 and 志愿者 are absent from those
labels even though another original HSK reference includes them. The app does not
claim complete coverage relative to every HSK reference, and deck membership was
not expanded or reordered.

Fifty-four curriculum examples changed. Fifty-three explicit sense-specific
originals replace unsuitable matches or retain a simple example with a corrected
reading; the other change updates an existing original's neutral-tone display.
Corpus examples that remain suitable are pinned to their existing attributed
pairs. The runtime curriculum contains 4,191 Tatoeba examples and 800 originals,
with no missing examples. This is not a new editorial audit of all 4,991 examples.

The recording catalog's seven affected pinyin labels were regenerated through
the importer. All 4,379 MP3s retain their bytes, pinned hashes, and attribution.
`--refresh-metadata` verifies every cached recording before changing labels and
requires no download. Catalog pinyin remains curriculum metadata rather than a
verified transcript of the speaker's recording.

## Persistence and quiz fairness

`bundled_hsk_editorial_v3` updates current bundled cards transactionally in place:
readings, meanings, grammar tags, examples, correct answers, and quiz choices.
Current card IDs and membership order are retained. Saved reviews, progress,
sessions, custom copies, and archived cards outside the current curriculum are
preserved. A failed update rolls back and remains retryable.

Backup restore corrects older bundled readings before choosing shared cards.
Regression tests cover restores after the marker is already present, backups
without lesson provenance, custom copies, repeated startup, and forced write
failure/rollback.

`VocabularyQuizIndex`, `QuizMeaning`, and `buildMeaningOptions` share known-sense
filtering across installed cards, Listening Practice, Vocab Rush, and Exam Mode.
They reject equivalent article/parenthetical forms, supplied alternate senses,
and matching pronunciations. Examples include practice/to practice,
man-made/artificial, interfere/meddle, and annotated/unannotated standard.
Fewer choices are allowed for small custom pools rather than introducing a valid
alternative as a wrong answer. All bundled words still support four choices.
This is a conservative dictionary-sense check, not a complete synonym model.

## Progress and interactions

- Profile explains that mastery is recorded answer accuracy, that one correct
  answer can meet the learned threshold, and that Hard counts as correct. The
  explanation distinguishes the score from long-term retention.
- `CardProgress.isLearned` and `learningStateAt` share the existing learned/due
  rules across statistics, discovery, lesson counts, and Dictionary. The SQL
  aggregate uses the same 80% threshold. Existing counts are unchanged.
- Settings states which choices save automatically and which require Save
  settings. Existing save behavior and the persistent save footer are retained.
- The tutor personality selector has a labeled 48-pixel minimum-height target
  and supports keyboard activation. Its title and selector sit side by side
  when there is room; phone layouts stack them. This also fixes the short
  landscape overflow exposed by the larger control.
- The former 5,761-line widget test is split into eight feature case files and
  shared helpers in `test/widget_cases/`. The existing entry point and original
  registration order are preserved: 95 widget-test registrations and one unit
  registration, including their parameterized cases.

## Validation completed

Flutter 3.44.4 and Dart 3.12.2, matching local and CI pins.

| Check | Result |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Passed; lockfile unchanged |
| `dart format --output=none --set-exit-if-changed lib test` | Passed; 163 files, no formatting changes |
| `flutter analyze --no-pub` | Passed; no issues |
| `flutter test --no-pub --coverage` | All 640 tests passed; 17 added regressions |
| Release-tool Python suite | All 10 tests passed |
| Audio importer Python regression | Passed, including metadata refresh and refusal to overwrite a damaged pack |
| `python3 tool/import_mandarin_audio.py --verify` | All 4,379 pinned recordings verified |
| Vocabulary regeneration from pinned local sources | Byte-for-byte match with the committed asset |
| Curriculum regeneration | 251 decks, 4,991 words, 5,020 unchanged memberships, no missing examples |
| `flutter build linux --release --no-pub` | Passed |
| `flutter build apk --debug --no-pub` | Passed; existing Kotlin/plugin and SDK-metadata warnings remain |
| Native Linux smoke check | Completed as described below |

The native debug harness used an empty AI configuration, HTTP disabled inside
the app, and a disposable database under `/tmp`. It drove widget controls and
inspected rendered Home, Dictionary details, Profile, Settings, and reopened Home.
Offline onboarding, an explicit Dictionary rating, saved XP, automatic theme
saving/restoration, SQLite integrity/foreign keys, and a JSON backup round-trip
passed. Native recorded-word playback started successfully. No Flutter framework
errors were recorded. No learner database, real credentials, provider account,
or desktop configuration was changed.

The first launch detached before the harness completed and had no recorded
coredump. Running it with an interactive terminal kept the app attached. A later
harness timeout was resolved by expanding the existing vocabulary practice
controls before rating; it was not a production-app error.

The Linux sentence-speech probe reported no installed system Mandarin fallback.
The bundled recording engine remained ready and study/persistence continued.
No package or voice installer was run, and API success is not a human assessment
of the sound's pronunciation or quality.

## Remaining real-device checks

Only Linux is connected. These checks require their respective hardware or OS
interaction and remain outstanding; compilation and test doubles do not complete
them.

| Device or service | Concrete check |
| --- | --- |
| Physical Android | Fresh APK install in airplane mode; complete onboarding and each study mode; force-close immediately after a rating and verify the saved answer/position after relaunch. |
| Physical Android | Real Back gestures, soft keyboard, rotation, enlarged text, background/resume, and TalkBack navigation through study controls. |
| Android speech engine | Check installed and missing zh-CN voices; use the explicit installer button, return to the app, and recheck actual playback. |
| Linux system speech | Install eSpeak NG through the explicit Settings action, then recheck availability and listen to a missing word and full sentence. |
| Android and desktop storage | Export/import through actual native file pickers and storage providers in a disposable profile; verify preview, cancellation, failures, and restored data. The Linux JSON round-trip did not exercise a file picker. |
| Microphone and audio devices | Real permission denial/approval, held-button release, device interruptions, and audible pronunciation quality. |
| Windows and macOS | Build/run the packaged app on those operating systems; verify playback, system fallback, secure storage, file pickers, and restart/resume. Their toolchains are unavailable here. |
| iOS | Real system/Kokoro playback, microphone permissions, keyboard/back gestures, and native storage handling. No iOS device/toolchain is available here. |
| Optional AI configuration | User-initiated Test connection with a personal provider/key and native secure storage; confirm failure leaves the previous configuration intact. No provider was contacted in this pass. |
