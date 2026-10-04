# Interface review

This UI pass reviewed TingShuo `1.0.0-beta.6+6` on Linux with Flutter 3.44.4
and Dart 3.12.2. Native screens were inspected at desktop and 390-pixel widths
using a disposable learner profile. Automated checks also covered 320-pixel
layouts with normal, enlarged and doubled text, desktop layouts, landscape,
keyboard-open search, and Android/iOS navigation gestures.

## Design changes

The interface keeps the five existing palettes and Mandarin content, with a
clearer hierarchy between page titles, study content, controls and metadata.

| Area | Improvement |
| --- | --- |
| Shared styling | Larger body text and line spacing; consistent English headings with Mandarin accents; quieter card outlines and separators; palette-based Material cards and inputs. |
| Controls | Visible hover/keyboard-focus feedback, clearer selected chips, 44-pixel minimum sizes for shared text/icon buttons, and selected-state semantics on Vocab Rush difficulty choices and the Profile button. |
| Navigation | Groups for Study, Practice & Reference, and AI Conversation; wider desktop sidebar; wrapping navigation labels; a useful prompt before the first study streak. |
| Home | A clear daily-practice heading; the first lesson or resumable lesson appears before word discovery; readable lesson metadata; palette-aware highlighted cards. |
| Lesson library | Consistent title, quieter lesson icons, and subdued progress tracks that distinguish unlearned words from learned progress. |
| Dictionary | Concise study meanings in results, full definitions in details, and denser narrow-screen cards that keep Hanzi, pinyin and meaning together. Search still includes every definition. |
| Listening and exams | Consistent headings and Material surfaces with clearer separation between setup controls and background. |
| Vocab Rush | More readable difficulty labels, palette-aware selection surfaces, and a shorter introduction that also fits Survival mode. |
| Tutor, dialogues and roleplay | Larger tutor Hanzi, pinyin and translation text; quieter conversation separators; palette-aware messages and tips; consistent mission headings and card outlines. |
| Profile | A clear progress heading, quieter analytics panels, and correct singular/plural streak labels. |
| Settings | A bounded desktop reading width and persistent save/retry footer. Saving, backup and reset coordination remains in place. |
| Onboarding and word discovery | Softer card outlines, shared type/control improvements, and the previously validated scrolling behavior for enlarged text. |

Home's daily word target is labeled as a goal rather than words already studied.
Resumable lesson cards show the actual completion percentage and maximum XP
based on their card count; the hardcoded Lesson 1 label and 60 XP claim are gone.
The available-lesson loading text now correctly describes selection across HSK
levels.

## Validation

- Complete Flutter suite with coverage: **563 tests passed**, including new
  checks for the persistent save action at desktop and doubled-text phone sizes,
  concise Dictionary results with full-definition search/details, and immediate
  heading colour updates when changing palettes.
- Formatting: **137 files checked; no changes needed**.
- Static analysis: **no issues**.
- Linux release build: **passed**.
- Android debug APK build: **passed**.
- Native visual checks: Home, Lessons, Roleplay Missions, Listening Practice,
  Vocab Rush, Dictionary, Doom Scrolling, AI Tutor, Exam Mode, Settings and
  Profile at desktop and narrow widths. Classic Ember, Forest and a live switch
  to Ocean were inspected natively; the suite covers theme restoration and
  primary-button contrast in all five palettes.

Native navigation and captures used the local Flutter debug service. No
production learner data was edited, no reset was performed, and no AI provider
was contacted. Content, persistence schemas, dependencies and platform plugins
are unchanged.

Physical Android/iOS devices, macOS/Windows builds, real audio/microphone
permissions and live AI responses were not exercised. The narrow native review
checks Linux rendering; mobile behavior is additionally covered by widget tests.
