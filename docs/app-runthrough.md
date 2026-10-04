# App runthrough and improvements

This pass reviewed TingShuo `1.0.0-beta.6+6` using Flutter 3.44.4 and Dart
3.12.2. It combined a native Linux session, implementation review, the complete
automated suite, and Linux/Android compile checks. The native session used a
disposable profile and database outside the learner's application data.

## Coverage

| Area | Checks completed |
| --- | --- |
| Startup, onboarding and Home | Native startup/navigation and saved-profile restoration; automated first-run, failure recovery, resume and empty-state checks. |
| Lessons | Native card reveal, rating and return to the library; automated completion, vocabulary/sentence content, saved positions and curriculum upgrades. |
| Dictionary and Doom Scrolling | Native numbered-pinyin search, bundled word details and feed rating; automated filters, save retries, shared progress, feed navigation and end states. |
| Listening Practice and Vocab Rush | Native answer assessment, advance and results; automated audio failure handling, persistence, timing, feedback and settings. |
| Exam Mode | Native answer, confirmation and results with unanswered questions; automated section scoring, timeouts, audio exclusions and idempotent progress saves. |
| Profile | Native progress refresh after practice and restoration after restart; automated XP, streaks, mastery and weekly analytics. |
| Settings, backup and reset | Native appearance selection/restoration; automated preference failures, backup validation/restore and coordinated reset semantics. |
| Optional AI and native services | Native tutor/roleplay screens; automated provider contracts, missing configuration, learner context, tutor personalities, dialogues, roleplay, dictation and voice fallback. |

Native navigation and practice actions were driven through the local Flutter
debug service, with rendered screens captured and inspected. Sound was disabled
for the native study session. Automated service checks used injected doubles;
this pass did not contact an AI provider or download a production voice pack.
Exam summaries and listening scores remain temporary; their assessed vocabulary
answers persist as designed.

## Improvements

- **Vocab Rush timing:** a deadline now measures elapsed time, including time in
  the background. Expired games reject answers before the next timer tick.
  Delayed feedback from an earlier game cannot advance a new game. End messages
  distinguish timeout, three mistakes and manual exit, and games respect the
  saved Show pinyin preference.
- **Appearance persistence:** rapid theme choices save in selection order,
  including after leaving Settings. A failed earlier choice cannot obscure a
  successful later choice. Theme selection waits while a full settings save is
  in progress, and disabled/selected swatches expose those states to assistive
  technology. Button animation is clearly labeled experimental.
- **Dictionary input:** search accepts tone-number pinyin such as `xue2xi2`,
  uppercase input, and `ü`, `v`, `u:` or decomposed umlaut spellings. A tone
  number by itself does not match the entire vocabulary.
- **Small screens and enlarged text:** onboarding labels wrap; Home lesson tiles
  and the first-lesson prompt give text more room; lesson-library actions move
  below the details. Doom Scrolling makes the complete word card scrollable in
  short windows or with enlarged text, with reachable ratings and a Next word
  action. Its end screen also scrolls.
- **Onboarding copy:** the visible legacy HANZIPATH subtitle now reads
  MANDARIN PRACTICE beneath the TingShuo name.

Regression checks reproduced timer/save races, numbered-pinyin misses and
enlarged-text overflows before their fixes. The final suite adds 24 cases,
including navigation at 320 × 640 with doubled text and word-feed practice at
640 × 360. Content counts, schema, dependencies and learner data are unchanged.

## Validation

| Check | Result |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Passed |
| Baseline `flutter test` | 536 tests passed |
| `dart format --output=none --set-exit-if-changed lib test` | Passed; 137 files, no formatting changes needed |
| `flutter analyze --no-pub` | Passed; no issues |
| `flutter test --no-pub --coverage` | 560 tests passed |
| `python3 -m unittest discover -s tool/ci -p 'test_*.py' -v` | 10 tests passed |
| `flutter build linux --release --no-pub` | Passed |
| `flutter build apk --debug --no-pub` | Passed |
| Native Linux practice and restart | Saved reviews, XP and appearance restored |

## Remaining device checks

Only Linux was connected. The Android APK compiled but was not exercised on a
phone; macOS, Windows and iOS were not built in this environment. Real Mandarin
playback, microphone/voice-install permissions, desktop keyring behavior,
interactive backup file selection and live AI connection tests still need their
respective devices or services. The full suite covers their application logic
and expected failures without external accounts or destructive learner actions.
