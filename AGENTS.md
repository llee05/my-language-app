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
`HanziPathApp`. Core lessons, vocabulary, ratings, and daily review must remain
usable without an account, network access, or Ollama.

| Location | Responsibility |
| --- | --- |
| `lib/main.dart` | Entry point, optional Ollama startup, database initialization, app theme, onboarding, navigation, and shared UI library. |
| `lib/features/` | Dashboard, lessons, daily review, vocabulary, Vocab Rush, settings, onboarding, and Long Laoshi AI tutor screens. |
| `lib/core/` | Shared colors, sidebar, and reusable widgets. |
| `lib/models/` | Learner, lesson, settings, review, and progress data types. |
| `lib/repositories/` | Persistence interfaces, `AppDependencies` constructor injection, and SQLite implementations. |
| `lib/local_database.dart` | SQLite lifecycle, application-support database path, legacy path migration, seeding, content updates, and coordinated close/reset operations. |
| `lib/database/` | Ordered schema migrations, bundled flashcard seeds, and vocabulary helpers. |
| `lib/services/` | Review scheduling, study streak calculation, pronunciation abstractions, native/system speech, and Kokoro installation/configuration. |
| `lib/ai/` | Ollama HTTP integration and HSK flashcard generation support. |
| `assets/data/` | Bundled HSK vocabulary and Tatoeba sentence candidates, with provenance and regeneration instructions. |
| `test/` | Unit, widget, persistence, dataset, and service tests. |
| `tool/` | Vocabulary import and sentence-candidate generation scripts. |
| `.github/workflows/flutter.yml` | Validation, Android/Windows compile checks, and tagged Android releases. |

### UI library and dependency boundaries

- The current feature screens and core UI files use `part of` and belong to the
  `main.dart` library. They are not standalone importable libraries. Add imports
  to `main.dart` when needed by those parts; register new parts there. Do not
  convert them to independent libraries incidentally during a feature change.
- State is managed with Flutter stateful widgets, callbacks, and futures.
  Follow existing patterns rather than introducing a state-management framework
  for a small change.
- `AppDependencies` supplies repository interfaces and a pronunciation factory,
  with SQLite defaults. Use these seams for test doubles and feature dependencies.
  Keep SQL in persistence code and scheduling logic in services.
- Ratings feed saved review history and card progress; lesson and daily-review
  sessions persist position for resumption. Vocab Rush mistakes also enter review
  data. Preserve this flow across UI changes.
- Pronunciation uses a platform-selecting factory: native Kokoro synthesis through
  `sherpa_onnx`, playback through `flutter_soloud`, and `flutter_tts` system fallback.
  Keep optional audio failures from preventing study.

## Development workflow

Run commands from the repository root. `pubspec.yaml` requires Dart `^3.12.2`;
CI currently pins Flutter **3.44.4 stable**. Use the workflow and pubspec as the
source of truth when these versions change.

```sh
flutter --version
flutter doctor -v
flutter pub get
flutter run
```

For a desktop target, select the installed device explicitly, for example
`flutter run -d linux`. Linux native audio builds need ALSA development headers
(`libasound2-dev` on Ubuntu/Debian). Android development needs SDK 36 and Java 17.
Windows builds run on Windows with Visual Studio's Desktop development with C++
workload and `nuget.exe` on `PATH`.

Before editing, inspect `git status --short` and the relevant implementation and
tests. Preserve unrelated changes and keep edits within the requested scope.
Format changed Dart files with `dart format path/to/file.dart`; avoid unrelated
repository-wide formatting. Run relevant tests while iterating, then the checks
below for code changes. Report what changed, checks actually run, and any checks
blocked by the environment. Documentation-only edits normally need diff and
content review rather than rebuilding the app.

### Optional Ollama development

Desktop startup can launch `ollama serve` if Ollama is installed on `PATH`.
Use `ollama list` to inspect installed models. The first available model is the
default unless overridden:

```sh
flutter run --dart-define=OLLAMA_MODEL=model-name
flutter run --dart-define=OLLAMA_URL=http://10.0.2.2:11434
```

The second command targets an Android emulator reaching a host Ollama server.
Mobile requires an explicit reachable endpoint. Android release endpoints must
use HTTPS; debug/profile cleartext allowances are limited to emulator/loopback
addresses. `OLLAMA_URL` must not contain credentials, a query, or a fragment.
Dart defines are embedded in the app, so never use them to hide secrets.

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
flutter test test/startup_test.dart test/widget_test.dart
flutter test test/ollama_service_test.dart test/ai_tutor_page_test.dart
flutter test test/vocabulary_content_test.dart test/vocabulary_dataset_test.dart test/vocabulary_page_test.dart test/vocab_rush_test.dart test/dashboard_learning_stats_test.dart
```

- `test/flutter_test_config.dart` defaults the database to in-memory SQLite.
  Persistence/path tests use temporary directories and explicit overrides.
  Never run reset tests against a real learner database; close test databases,
  restore overrides, and clean temporary resources in teardown.
- Use injected repositories, HTTP clients, pronunciation doubles, and explicit
  times where existing tests provide those seams. Tests should not require a
  running Ollama server, actual speech playback, or a full voice-pack download.
- Add regression coverage for changed behavior, especially migrations, resume
  state, ratings, failed downloads, and asynchronous failures. Follow existing
  `flutter_test` patterns and restore widget surface sizes after layout tests.

Platform compile checks, when the appropriate toolchain is available:

```sh
flutter build apk --debug
flutter build windows --release
```

CI runs validation on main-branch pushes and pull requests, and on `v*` tags.
Tags also trigger signed Android release publication. Do not create a release
tag as a routine verification step. See `README.md` for signing and release
setup; release builds must not fall back to debug signing.

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
version 11): each map entry upgrades from the previous version. Add a new ordered
migration and increment the version for schema changes instead of rewriting an
already-applied migration. Test upgrades as well as fresh initialization.

Preserve foreign keys, transactions, content migration markers, and database
operation coordination during close/reset. Content changes must retain learner
history and be safe on repeated startup. Onboarding reset and full data reset
have different semantics; do not conflate them. There is no cloud backup, and
full reset permanently removes local learning data.

### Voice packs and native platforms

Kokoro downloads are large and stored in the app's private support directory,
not bundled into the repository. Preserve HTTP Range resume behavior, archive
SHA-256 verification, required-file checks, staged installation, completion
markers, and extraction outside the UI isolate. Keep voice-selection settings
and the Simplified Chinese system fallback working. Use test fixtures rather
than downloading the production model for automated tests.

The repository has Android, iOS, Linux, macOS, and Windows runners. Do not assume
web support: core database and Ollama code imports `dart:io`, and there is no web
runner in this checkout. Changes involving native plugins need platform-aware
verification beyond widget tests.

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
- The README contains some outdated beta descriptions: dashboard XP, weekly XP,
  streaks, and vocabulary statistics already derive from saved data in
  `DashboardLearningStats.fromSavedData`. Check code and tests before treating
  a feature as a placeholder. Reminder settings are saved, but system notification
  scheduling is still outside the implemented workflow.
