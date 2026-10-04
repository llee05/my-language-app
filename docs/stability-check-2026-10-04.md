# Beta 6 stability check — 4 October 2026

Scope: checklist steps 3–8, on `1.0.0-beta.6+6`, starting from commit
`a4bda87`, plus the fixes and regression tests accompanying this report.
Flutter 3.44.4 / Dart 3.12.2, matching the repository and CI pins.

## Results by checklist step

| Step | Verified here | Remaining device checks |
| --- | --- | --- |
| 3. Fresh installation and offline use | New widget test creates a temporary file-backed SQLite database, completes onboarding, opens Lessons, Dictionary, Doom Scrolling, Listening Practice and Exam Mode with HTTP client creation forbidden, then closes/reopens the database and reconstructs the app. Profile, settings and an explicit word rating survive. Audio and microphone are unavailable test doubles. | Fresh install in airplane mode on a phone; native file paths and actual process termination/relaunch. |
| 4. Accurate saved progress | Existing repository/service/widget tests cover shared cards, idempotent save retries, lesson completion/resumption, interrupted answer/session saves, statistics invalidation, local midnight and resume. Explicit assessments persist across study modes; browsing/skipping does not award mastery. | Force-close immediately after an answer on a device; check the next local day and background/resume during normal use. |
| 5. Backup restore | Existing tests cover real SQLite round trips, legacy backups, curriculum membership/archive preservation, malformed linked records and transactional rollback. Added UI tests for invalid previews, restore failure/retry, export cancellation and file-write failure/retry. Failed or cancelled operations never report success. | Export/import using actual Android/desktop file pickers and storage providers in a disposable installation. |
| 6. Study modes and content | Existing tests cover lessons, sentence practice, discovery, dictionary ratings, listening answers, Vocab Rush, exam scoring/review, timer expiry and excluded/unanswered exam questions. Dataset tests cover all 251 vocabulary decks, 4,991 entries and source attribution. Reviewed 18 example sentences across all six HSK levels; editorial follow-ups below. | Complete sessions in the installed release package; broader human review of Mandarin and level suitability. |
| 7. Navigation and layout | Existing widget tests cover mobile menu dragging, Android Back, small widths, enlarged text, dictionary keyboard visibility, statistics refresh on resume and exam background deadlines. Added regression coverage for leaving while push-to-talk is held; fixed a post-disposal button event error. | Real soft keyboards, OS back gestures, rotation, resizing, long background periods and audio interruptions. |
| 8. Audio and optional AI failures | Existing tests cover system-voice availability/installer checks, fallback, disabled sound, audio failures, denied dictation, missing/invalid AI configuration, HTTP failures/timeouts and secure-storage failures. New speech-service and tutor tests cover delayed permission/locale setup, cancellation, disposal, stale transcripts and retry. | Real permission dialogs, installed/missing Mandarin voices, actual playback, native secure storage and a user-initiated connection test with a personal provider account. |

Doom Scrolling is the current discovery workflow. Daily Review tests protect
legacy persistence/backup behavior; they do not imply a current navigation entry.
Exam result summaries, listening scores and AI chats remain in memory by design;
their explicit vocabulary assessments persist.

## Bugs reproduced and fixed

- A pending microphone start could continue after stop, cancellation or disposal,
  and old transcripts could reach a later dictation. Speech setup now invalidates
  pending requests and binds results to their session. Normal stop still permits
  the final transcript; cancellation discards it.
- Push-to-talk could start after the user released the button or left while audio
  shutdown was pending. It now checks its active session before starting and
  cancels immediately when released during speech setup. A late completion from
  a closed page no longer cancels a newer page’s dictation.
- Releasing a held animated button after its screen was disposed could call
  `setState` on a disposed widget. Pointer feedback now checks `mounted`.

New regression coverage lives in `test/speech_input_service_test.dart`,
`test/offline_stability_test.dart`, `test/ai_tutor_page_test.dart` and
`test/backup_settings_test.dart`. The new speech/button regression cases failed before their
associated fixes and passed afterward. The offline and backup tests add coverage
without changing their production behavior.

## Validation

- Locked dependency installation: passed (`flutter pub get --enforce-lockfile`).
- Formatting: passed (`dart format --output=none --set-exit-if-changed lib test`).
- Static analysis: passed (`flutter analyze --no-pub`).
- Baseline suite: all 511 existing tests passed.
- Final full suite: all 527 tests passed with coverage (`flutter test --no-pub --coverage`),
  including 16 new stability regression tests.
- Android debug compile: passed (`flutter build apk --debug --no-pub`).

Tests use in-memory/temporary SQLite databases, mocked secure storage and injected
native services. No real learner database was reset and no provider was contacted.
Only Linux was connected; this pass did not launch the native app or exercise a
physical phone. Automated success is not a substitute for the remaining checks.

## Curriculum sample follow-ups

The sample was the first entry in the first, middle and last vocabulary deck of
each HSK level. Coverage/provenance checks passed, but source attribution does
not guarantee suitable teaching examples. Two items merit editorial review:

- `hsk-old-3-一会儿`: “我休息了一会儿再要出去。” has awkward tense/word order for
  the English “I'll go out after I've rested for a while.” Select a more natural
  source sentence with verified pinyin through the generator overrides.
- `hsk-old-2-最`: “得不到的东西就最想得到。” is grammatical but relatively abstract
  for a beginner example. Consider a simpler example at this level.

These are sample findings, not a comprehensive linguistic audit. The generated
curriculum was not rewritten during this stability pass.
