# Repository guide for agents

## Scope and shared access

This root file is the shared, tool-independent guide for the entire repository,
including Codex and the Clide extension using the GLM 5.3 Flash API. Open the
repository root as the workspace and read this file before making changes.
Keep shared instructions here rather than maintaining separate tool-specific
copies. Model choice does not change these repository conventions.

If an extension does not automatically include `AGENTS.md`, explicitly attach
this file to its task context or begin the task with: **Read ./AGENTS.md before
working on this repository.** Clide's automatic discovery has not been verified;
this explicit file reference is the fallback. No extension configuration is
required by this document or supplied alongside it.

## Product and architecture

TingShuo is a local-first Mandarin learning app built with Flutter and Dart.
The Dart package is `mylanguageapp`; the root widget retains the historical name
`HanziPathApp`. Core flashcards, dictionary, word discovery, and ratings must remain
usable without an account, network access, or an AI provider.

The package version is `1.0.0-beta.7+7` in `pubspec.yaml`. The current app includes
251 twenty-word vocabulary decks covering 4,991 HSK 2.0 entries across levels
1–6, ten sentence-practice decks, Dictionary, Doom Scrolling, Listening Practice,
Vocab Rush, offline Exam Mode, Profile analytics, appearance settings, manual
backup/restore, and optional AI chat, listening dialogues, roleplay missions,
and custom tutor personalities.
Check implementation and tests before describing an existing feature as planned.

| Location | Responsibility |
| --- | --- |
| `lib/main.dart` | Entry point, startup/profile loading, app theme, onboarding, navigation, and shared UI library; repositories initialize SQLite while the loading screen is visible. |
| `lib/features/` | Dashboard, Profile analytics, lessons, listening, word discovery, dictionary, Vocab Rush, exams, settings, onboarding, and AI tutor screens. |
| `lib/core/` | Shared colors, sidebar, and reusable widgets. |
| `lib/models/` | Learner, lesson, settings, review, progress/weekly analytics, exam, and AI exercise/personality data types. |
| `lib/repositories/` | Persistence interfaces, `AppDependencies` constructor injection, immutable bundled vocabulary, SQLite implementations, secure AI configuration, and backup validation/restore. |
| `lib/local_database.dart` | SQLite lifecycle, application-support database path, legacy path migration, seeding, content updates, and coordinated close/reset operations. |
| `lib/database/` | Ordered schema migrations, bundled curriculum installation, historical flashcard seeds, and vocabulary helpers. |
| `lib/services/` | Review scheduling, study streak calculation, pronunciation, speech input, Kokoro installation/configuration, memory caches, and backup file selection. |
| `lib/ai/` | Gemini, Anthropic, and OpenAI-compatible REST adapters for the optional AI tutor. |
| `assets/data/` | Bundled HSK vocabulary and Tatoeba sentence candidates, with provenance and regeneration instructions. |
| `test/` | Unit, widget, persistence, dataset, and service tests. |
| `tool/` | Vocabulary import, Tatoeba candidate selection, original-example generation, and vocabulary curriculum generation scripts. |
| `.github/workflows/flutter.yml` | Validation, four-platform builds, and coordinated tagged releases. |
| `tool/ci/` | Offline release metadata validation, asset checks, checksums, and regression tests. |

### UI library and dependency boundaries

- The current feature screens and core UI files use `part of` and belong to the
  `main.dart` library. They are not standalone importable libraries. Add imports
  to `main.dart` when needed by those parts; register new parts there. Do not
  convert them to independent libraries incidentally during a feature change.
- State is managed with Flutter stateful widgets, callbacks, and futures.
  Follow existing patterns rather than introducing a state-management framework
  for a small change.
- `AppDependencies` supplies repositories, pronunciation and speech-input
  factories, and backup file access, with SQLite and secure-storage defaults.
  Use these seams for test doubles and feature dependencies.
  Keep SQL in persistence code and scheduling logic in services.
- Ratings feed saved review history and card progress; lesson sessions persist
  position for resumption. `VocabularyStudyService` records explicit word ratings
  and assessed answers from Dictionary, Doom Scrolling, Listening Practice,
  Vocab Rush, and Exam Mode against shared vocabulary cards. Sentence recaps,
  AI chat, dialogues, and roleplay expose explicit practice controls for locally
  matched bundled words. Browsing, skipping, pronunciation, and AI generation
  do not award mastery. Preserve stable submission keys on retries and refresh
  statistics after saves. Listening scores and exam results remain in memory,
  while their answered vocabulary assessments persist. Excluded and unanswered
  exam questions do not change vocabulary progress. Whole sentence cards are
  excluded from HSK vocabulary totals but retain review history and XP.
- Doom Scrolling replaces the Daily Review navigation entry and Home prompt.
  Its vertical feed shuffles vocabulary below 80% mastery across HSK 1–6;
  learned words stay excluded even when due. Save ratings before advancing;
  support swipes, mouse-wheel scrolling, keyboard navigation, and save retries.
  Preserve legacy daily-review sessions and backup compatibility.
- Dashboard and Profile use `DashboardLearningStats.fromSavedData`, including
  XP, streaks, accuracy, HSK vocabulary mastery, and `WeeklyProgressReport`.
  Learned words require at least 80% mastery; HSK progress is independent of the
  learner's selected HSK level. Refresh statistics after reviews, at local
  midnight, and when the app resumes. Home samples available lessons across
  HSK levels rather than generating personalized recommendations.
- Appearance uses five `AppThemes` palettes and shared `AppColors`. Theme
  choices apply immediately and persist automatically; button-animation choices
  require Save settings and remain experimental. Preserve appearance restoration,
  backup support, and the default appearance after full reset.
- Pronunciation uses a platform-selecting factory. Linux and Windows play bundled
  human word recordings through `flutter_soloud`, with eSpeak NG / legacy eSpeak
  on Linux and `flutter_tts` on Windows for missing words and sentences.
  Settings checks fallback availability and installs missing system speech on
  an explicit button action: Linux uses PolicyKit and the package manager;
  Windows installs Simplified Chinese Basic and TextToSpeech capabilities
  through Windows Update with UAC. Recheck the playback engine after installation
  and on resume; installer completion alone is not proof of a usable voice.
  The 4,379 MP3s in `assets/audio/mandarin/` are installed only by desktop CMake
  into `data/mandarin_audio`; keep them out of pubspec assets and Android builds.
  iOS/macOS retain Kokoro through `sherpa_onnx` with system speech fallback.
  Android always uses the system `zh-CN` voice instead: its APK ships no Kokoro,
  onnxruntime, or soloud native libraries (see `third_party/README.md`).
  Android's voice installer opens the speech engine's installer/settings and
  rechecks availability on resume or Check again; opening it is not installation
  success. Keep optional audio and dictation failures from preventing study.

## Development workflow

Run commands from the repository root. `pubspec.yaml` requires Dart `^3.12.2`;
CI currently pins Flutter **3.44.4 stable**. Use the workflow and pubspec as the
source of truth when these versions change. `mise.toml` pins the same SDK for
local development; use Flutter 3.44.4 when regenerating `pubspec.lock` and update
the local pin together with intentional CI SDK upgrades.

```sh
flutter --version
flutter doctor -v
flutter pub get --enforce-lockfile
flutter run
```

For a desktop target, select the installed device explicitly, for example
`flutter run -d linux`. Linux native audio builds need ALSA development headers
(`libasound2-dev` on Ubuntu/Debian). Secure storage also needs `libsecret-1-dev`,
plus an unlocked Secret Service keyring at runtime.
Android development needs SDK 36 and Java 17. Windows builds run on Windows with
Visual Studio's Desktop development with C++ workload, its C++ ATL component,
and `nuget.exe` on `PATH`.

Before editing, inspect `git status --short` and the relevant implementation and
tests. Preserve unrelated changes and keep edits within the requested scope.
Format changed Dart files with `dart format path/to/file.dart`; avoid unrelated
repository-wide formatting. Run relevant tests while iterating, then the checks
below for code changes. Report what changed, checks actually run, and any checks
blocked by the environment. Documentation-only edits normally need diff and
content review rather than rebuilding the app.

Make sure to split jobs into reasonably sized commits with a commit message of the form "job type: message", and never add your agent name as co-author.

### Optional AI development

AI requests use `lib/ai/ai_service.dart`, which reads the current configuration
for every request and routes to Gemini, Anthropic, or an OpenAI-compatible API.
Users select Gemini, OpenAI, Claude, or Other / OpenAI-compatible, a personal
API key, and a model in Settings. Custom endpoints must be full HTTPS Chat
Completions URLs. Keys live in `SecureAiConfigurationRepository` through
platform secure storage, never SQLite or ordinary preferences. Test and save
makes a request and saves only after a successful test; Advanced → Save without
testing only stores configuration, and Test connection makes a request without
saving. Failed tests preserve the prior
configuration. Clipboard reads and provider key-page launches require the
corresponding explicit button action. Full data reset removes configuration,
while onboarding reset and backup restore preserve it. Missing keys and
secure-storage failures must fail without network requests.

Tutor chat includes a bounded, read-only learner snapshot: HSK level, up to
80 studied words, 8 words each for weak/due/recent-mistake categories, and
5 lesson sessions, excluding the learner's name. Snapshot failures allow chat
without personalization. Preserve local vocabulary validation for generated
listening dialogues and roleplay turns. Chat and AI exercise state are not
persisted. Built-in and custom tutor personalities are managed through
`TutorPersonalityRepository`; custom profiles and the selection live in
`app_data`, survive onboarding reset, and are excluded from study backups.
AI profile generation is optional; manual profile creation works without AI.

Flashcards and Listening Practice share one searchable deck browser and the same
vocabulary, sentence-practice, and saved custom deck pool across HSK 1–6.
Listening starts directly from a deck; random modes follow the visible filters.
Vocabulary decks use the bundled curriculum; deck creation has been removed.
Preserve previously saved custom lessons, lesson guides, and learning history.

Startup never contacts an AI service. When no personal configuration is saved,
configure a developer Gemini fallback using an ignored `.env.gemini.json` file:

```sh
flutter run --dart-define-from-file=.env.gemini.json
```

The file contains `GEMINI_API_KEY` and optionally `GEMINI_MODEL` (default:
`gemini-3.6-flash`). See README for an example. Dart defines are embedded in the
app, so never commit keys or distribute builds containing a shared key. A
production backend that holds a shared developer key and authenticates requests
is outside this implementation. CI release artifacts contain no shared AI key;
users may configure their own. Use injected configuration repositories and HTTP
clients to test API contracts and failures without contacting providers.

## Testing and build commands

These are the validation commands used by CI after dependency installation:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
```

For a normal local suite run, `flutter test` is sufficient; coverage output is
`coverage/lcov.info`. Useful focused checks include:

```sh
flutter test test/review_scheduler_test.dart test/study_streak_calculator_test.dart
flutter test test/local_database_test.dart test/local_database_path_test.dart test/local_database_reset_test.dart test/sqlite_repository_validation_test.dart
flutter test test/kokoro_voice_pack_test.dart test/sherpa_voice_config_test.dart test/pronunciation_service_test.dart
flutter test test/startup_test.dart test/widget_test.dart test/lesson_completion_test.dart
flutter test test/gemini_service_test.dart test/ai_tutor_page_test.dart
flutter test test/ai_service_test.dart test/ai_settings_card_test.dart test/ai_configuration_repository_test.dart
flutter test test/vocabulary_content_test.dart test/vocabulary_dataset_test.dart test/vocabulary_page_test.dart test/vocab_rush_test.dart test/dashboard_learning_stats_test.dart test/vocabulary_study_test.dart
flutter test test/vocabulary_lesson_content_test.dart test/vocabulary_lesson_dataset_test.dart test/bundled_lesson_rewrite_test.dart test/sentence_practice_test.dart test/listening_practice_test.dart
flutter test test/hsk_exam_test.dart test/exam_mode_test.dart test/profile_progress_analytics_test.dart test/weekly_progress_report_test.dart
flutter test test/tutor_context_repository_test.dart test/tutor_personality_test.dart test/listening_dialogue_test.dart test/roleplay_mission_test.dart
flutter test test/backup_repository_test.dart test/backup_settings_test.dart test/appearance_theme_test.dart test/app_button_theme_test.dart
flutter test test/android_pronunciation_test.dart test/system_pronunciation_service_test.dart test/pronunciation_button_test.dart
flutter test test/recorded_pronunciation_service_test.dart test/linux_system_pronunciation_service_test.dart test/desktop_voice_installation_test.dart
flutter test test/async_lru_cache_test.dart test/bundled_vocabulary_repository_test.dart test/repository_cache_test.dart test/pronunciation_audio_cache_test.dart
```

- `test/flutter_test_config.dart` defaults the database to in-memory SQLite and
  mocks secure storage so tests never touch the desktop keyring.
  Persistence/path tests use temporary directories and explicit overrides.
  Never run reset tests against a real learner database; close test databases,
  restore overrides, and clean temporary resources in teardown.
- Use injected repositories, HTTP clients, pronunciation/speech-input doubles,
  backup file services, and explicit clocks/random sources where existing tests
  provide those seams. Tests should not require a provider API key or network
  access, actual speech playback/recognition, native file pickers, or a full
  voice-pack download.
- Add regression coverage for changed behavior, especially migrations, resume
  state, ratings, failed downloads, and asynchronous failures. Follow existing
  `flutter_test` patterns and restore widget surface sizes after layout tests.

Platform compile checks, when the appropriate toolchain is available:

```sh
flutter build apk --debug
flutter build linux --release
flutter build macos --release
flutter build windows --release
```

CI runs validation on main-branch pushes and pull requests, `v*` tags, and manual
workflow runs. Validation also checks release tooling, tag metadata, and workflow
syntax; platform jobs install dependencies with `--enforce-lockfile`.
Tags also trigger signed Android APK/AAB builds and one coordinated release
containing Linux x64, universal macOS, Windows x64, and Android packages. All
platforms must succeed before publication. Tags must match the pubspec version
without its `+BUILD` suffix. macOS beta downloads use ad-hoc signing and are
explicitly labeled unsigned; Windows packages are unsigned portable bundles.
Do not create a release tag as a routine verification step. See
`docs/beta-releases.md` and `README.md` for signing and release setup; Android
release builds must not fall back to debug signing. When changing release tools,
run `python3 -m unittest discover -s tool/ci -p 'test_*.py' -v` too.

## Coding conventions

- Follow `analysis_options.yaml` (`flutter_lints`) and the Dart formatter.
  Use `snake_case.dart` filenames, `UpperCamelCase` types, `lowerCamelCase`
  members, and underscore-prefixed library-private helpers.
- Match neighboring code: relative imports within `lib`, package imports in
  tests, `final` for values that do not change, and `const` constructors and
  widgets where possible. Keep public data models and repository contracts typed.
- Preserve null safety, validate external JSON and persistence inputs, and use
  parameterized SQL rather than interpolating user values.
- Await persistence before reporting success. Check `mounted` before updating
  widget state after awaits; dispose controllers, streams, audio, and other owned
  resources. Handle expected service failures without hiding persistence errors.
- Reuse `AppColors` and shared widgets. Preserve both narrow/mobile and desktop
  layouts, and keep Hanzi, pinyin, and English content intact.
- Keep new code focused on the requested behavior. Do not add packages, rename
  historical symbols, or restructure the shared UI library without a task-driven
  reason.

## Important constraints

### Learner data and migrations

SQLite uses `sqflite_common_ffi`; the database is `local_app.db` in the application
support directory. Existing code safely migrates the legacy documents-directory
database. Schema versioning lives in `lib/database/migrations.dart` (currently
version 17): each map entry upgrades from the previous version. Add a new ordered
migration and increment the version for schema changes instead of rewriting an
already-applied migration. Test upgrades as well as fresh initialization.

Preserve foreign keys, transactions, content migration markers, and database
operation coordination during close/reset. Content changes must retain learner
history and be safe on repeated startup. Onboarding reset and full data reset
have different semantics; do not conflate them. There is no cloud backup, and
full reset permanently removes local learning data.

Settings exposes manual JSON backup export/restore through `BackupRepository`
and `BackupFileService`. Validate the document and linked records, show the
preview before replacement, and restore transactionally. Backups contain learner
profiles/settings, lessons/guides/cards, memberships, progress, review history,
and resumable sessions; they exclude API keys, tutor personalities/selection,
in-memory chats/exams, and downloaded voices. Restore leaves secure AI
configuration intact and upgrades older bundled content.

Reset account requires a deletion warning followed by typing `RESET`. Await
secure AI configuration removal before deleting the learner database, and keep
reset/backup/settings operations coordinated. Full reset also removes custom
tutors and restores default appearance; bundled content is recreated and voice
files remain. Debug-only Reset onboarding only sets the setup-required marker,
preserving the profile row, learning history, settings, tutors, and API key.

The vocabulary curriculum uses ordered `lesson_cards` memberships to share card
IDs and progress between 20-word decks. Historical defaults are archived rather
than deleted so old sessions retain their card order and can resume. Preserve
memberships and archive flags in backup exports/restores; custom decks still use
their direct `cards.lesson_id` ownership.

### Memory caches

`BundledVocabularyRepository` shares immutable vocabulary through the asset
bundle's structured-data cache, including Exam Mode. Database reads use
`LocalDatabase.readCached`: up to 32 lesson/library entries and one statistics
result keyed by local day. Session reads remain fresh. New operations that
change lesson content or review progress must use `LocalDatabase.write` and
appropriate `DatabaseCacheScope` invalidation after a successful commit.
Reviews invalidate statistics; content writes and restores invalidate both
scopes. Cache hits must retain database leases for close/reset coordination.
Onboarding reset, full reset, and close clear both database caches.

Kokoro's `PronunciationAudioCache` holds up to 64 clips within a 16 MiB sample
budget, keyed by text, speaker, model directory, and archive version. Preserve
pending-work sharing, retry after failures, and playback of uncached oversized
clips. Caches supplement persistence rather than replacing it.

### Voice packs and native platforms

Linux/Windows recordings are pinned, checksum-verified, and credited under
CC BY-SA 3.0 US. Use `tool/import_mandarin_audio.py --verify` for offline asset
validation; regenerate with the importer rather than editing the catalog.
It matches whole Hanzi words and excludes ambiguous single characters; catalog
pinyin is curriculum metadata, not a source-verified transcript. Never splice
word clips to approximate whole sentences. Failed or missing recordings fall
back to system speech, and Linux needs a locally installed eSpeak engine for
that fallback. Playback must cancel superseded requests and release sources.

Kokoro downloads are large and stored in the app's private support directory,
not bundled into the repository. Preserve HTTP Range resume behavior, archive
SHA-256 verification, required-file checks, staged installation, completion
markers, and extraction outside the UI isolate. Keep voice-selection settings
and the Simplified Chinese system fallback working. Use test fixtures rather
than downloading the production model for automated tests.

The repository has Android, iOS, Linux, macOS, and Windows runners. Do not assume
web support: core database code imports `dart:io`, and there is no web
runner in this checkout. Changes involving native plugins need platform-aware
verification beyond widget tests.

`pubspec.yaml` intentionally overrides the four sherpa-onnx Android ABI packages
with empty plugins and vendors `flutter_secure_storage_linux` 3.0.2 with schema
lifetime and write/readback fixes. Android Gradle also excludes soloud libraries.
Preserve these changes during dependency upgrades unless their replacement has
been verified; see `third_party/README.md`. Older Linux keys saved under the
broken schema need to be re-entered once.

### Bundled content, secrets, and generated files

- `assets/data/README.md` documents HSK import and Tatoeba candidate-generation
  commands and licensing. Prefer updating the importer/overrides and regenerating
  data over mass-editing generated JSON. Preserve HSK levels 1–6, intended word
  readings, concise study meanings, and sentence IDs/source attribution.
- Review generated sentence candidates for natural Mandarin, translation accuracy,
  level suitability, and sentence-level pinyin. Do not invent missing pinyin or
  discard attribution. Ensure bundled asset paths remain registered in pubspec.
- Never commit learner databases, `.env` files, keystores, signing passwords,
  `android/key.properties`, downloaded models, or build/cache artifacts.
  Keep dependency changes intentional, including associated lockfile updates.
- Keep README feature descriptions, the package version, SDK pins, asset counts,
  and focused test commands aligned with the implementation. Reminder preferences
  are stored, but Settings currently has no reminder controls and system
  notification scheduling is not implemented. Exam results, chat history, and
  listening scores are not saved, but explicit vocabulary assessments are;
  button-animation settings remain experimental.
