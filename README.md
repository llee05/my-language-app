# HanziPath Project Brief

HanziPath is a local-first Flutter app that helps beginner Mandarin learners build a consistent study habit with HSK-aligned vocabulary, short flashcard lessons, vocabulary games, and an optional AI tutor named Long Laoshi.

The project is currently an early-stage prototype. It has a polished learner-facing shell and several working study activities, but its progress indicators are not yet connected to persistent learning history. The MVP milestone is to turn those activities into one complete daily learning loop:

`Learn → Answer → Save result → Schedule review → Return tomorrow`

## Product Goals

- Help beginner Mandarin learners practise in short, repeatable daily sessions.
- Present HSK vocabulary, pinyin, meanings, and examples in a focused lesson flow.
- Retain learner progress locally and work without an account or internet connection.
- Bring weak vocabulary back at useful intervals through spaced review.
- Offer an optional AI tutor for corrections, sentence practice, and explanations.
- Keep the interface calm, approachable, and suitable for repeated use.

## Current Features

- Responsive dashboard and sidebar navigation across desktop and mobile layouts.
- A bundled dataset of more than 4,000 vocabulary entries across HSK levels 1–6.
- Seeded and AI-assisted flashcard lessons with an offline vocabulary fallback.
- Reusable generated lessons stored in a local SQLite database.
- Flashcards containing Hanzi, pinyin, English meanings, and example sentences.
- On-device Mandarin pronunciation audio on lesson flashcards, controlled by
  the saved sound preference.
- Vocab Rush, with HSK difficulty ranges, timed and survival modes, streaks, and three-strike scoring.
- Long Laoshi, a local AI tutor powered by Ollama.
- Dashboard surfaces for lessons, vocabulary mastery, XP, streaks, and weekly activity.
- Flutter widget, startup, database, game, and vocabulary dataset tests.

> [!NOTE]
> Dashboard XP, streak, mastery, lesson progress, and weekly activity are currently presentation data. Connecting them to real study history is part of the MVP roadmap.

## MVP Definition

The MVP is complete when a learner can:

1. ~~Choose an HSK level and daily study target.~~
2. ~~Complete a short vocabulary lesson.~~
3. Rate words as needing more or less practice.
4. ~~Close the app and later resume an unfinished lesson.~~
5. Review weak or due vocabulary in a daily review queue.
6. See XP, streak, mastery, and activity values based on real study sessions.
7. Use every core learning feature without Ollama or an internet connection.

## MVP Roadmap

### 1. Persistent learning foundation

- ~~Add first-run learner setup for name, HSK level, and daily word target.~~
- ~~Introduce typed models and repositories between the UI and SQLite.~~
- ~~Add versioned database migrations.~~
- ~~Store learner profiles, settings, lesson sessions, review history, and
  per-card progress.~~
- ~~Track times seen, correct and incorrect answers, mastery, last review,
  next review, and review interval.~~

**Milestone:** ~~restarting the app preserves learner settings, lesson
position, and card results.~~

### 2. Complete lesson loop

- ~~Mark a revealed flashcard as already familiar with a single button.~~
- ~~Save every rating immediately and update the card's review schedule.~~
- ~~Lesson progress and a completion summary show accuracy, learned words,
  review words, and XP earned.~~
- ~~The dashboard's Resume action opens the latest unfinished lesson session.~~
- Let learners browse and start seeded or previously generated lessons directly.

**Milestone:** ~~a learner can finish or resume a lesson and see the correct
result after reopening the app.~~

### 3. Daily review and vocabulary library

- ~~Implement a simple, explainable spaced-repetition scheduler.~~
- Create a daily queue of cards that are new, weak, or due for review.
- Build the Vocabulary page with Hanzi, pinyin, and English search.
- Add filters for HSK level and unseen, learning, learned, and due states.
- Add word detail views with meanings and example sentences.
- Feed incorrect Vocab Rush answers into the learner's review queue.

**Milestone:** the app automatically offers a useful review session each day.

### 4. Live dashboard and progress

- Replace the hard-coded greeting date and study target with current data.
- Calculate XP, current streak, due reviews, learned words, and mastery from stored activity.
- ~~Resume the latest incomplete lesson from the dashboard.~~
- Populate the seven-day activity chart from completed sessions.
- Recommend the next appropriate lesson.
- Build the Progress page already represented in navigation.

**Milestone:** every displayed metric is based on actual learner activity.

### 5. Reliability and release readiness

- Keep startup and core study flows independent of Ollama availability.
- Detect AI availability only when an AI-powered feature is opened.
- Show the actual local Ollama model instead of a hard-coded model label.
- Add consistent loading, empty, error, offline, and retry states.
- Improve keyboard navigation, semantics, and screen-reader support.
- Add tests for migrations, review scheduling, card ratings, lesson resume, streaks, offline fallback, and malformed AI responses.
- Add learner-data reset and export options.
- Validate and polish one primary release target before expanding platform-specific work.

**Milestone:** a new learner can complete the full offline learning loop and safely retain progress between launches.

## Deferred Until After MVP

- Accounts and cloud synchronization
- Social features and leaderboards
- Subscriptions and payments
- Speech recognition and pronunciation grading
- Handwriting recognition
- Push notifications
- Large achievement systems
- Additional game modes
- AI-generated content as a requirement for core study

## Technical Snapshot

- Framework: Flutter
- Language: Dart
- Local storage: SQLite via `sqflite_common_ffi`
- AI integration: Ollama local chat API through a lightweight HTTP client
- Audio: on-device Mandarin text-to-speech via `flutter_tts`
- Content: bundled HSK 1–6 JSON vocabulary dataset and seeded lessons
- Tests: Flutter widget, startup, database, Vocab Rush, and dataset tests

## Current Architecture

- `lib/main.dart` initializes local services, configures the app theme, and assembles feature files.
- `lib/core/widgets/app_sidebar.dart` defines the responsive application navigation.
- `lib/features/dashboard/` contains the main shell, learning dashboard, and progress rail.
- `lib/features/lessons/lessons_page.dart` builds, caches, and displays flashcard lessons.
- `lib/features/vocab_rush/vocab_rush_page.dart` implements the vocabulary game.
- `lib/features/ai_tutor/ai_tutor_page.dart` implements Long Laoshi's chat interface and response formatting.
- `lib/ai/ollama_service.dart` manages communication with the local Ollama server.
- `lib/local_database.dart` creates, seeds, and queries the SQLite database.
- `lib/database/flashcard_seed.dart` contains the initial flashcard lessons.
- `assets/data/hsk_vocabulary.json` contains the bundled HSK vocabulary dataset.

## Local Setup

Install dependencies:

```sh
flutter pub get
```

Run the app:

```sh
flutter run
```

Run static analysis and tests:

```sh
flutter analyze
flutter test
```

### Pronunciation audio

Lesson flashcards include a speaker button that reads the displayed Mandarin
word aloud using the device's text-to-speech engine. Audio is generated on the
device and does not require Ollama. It can be enabled or disabled under
**Settings → Sound**.

Mandarin pronunciation is supported on Android, iOS, macOS, Windows, and the
web when a compatible Chinese voice is installed. Linux is not currently
supported by the selected text-to-speech plugin. If playback is unavailable,
install a Simplified Chinese (`zh-CN`) system voice and restart the app.

### Optional AI tutor setup

The core MVP is intended to work without AI. To use Long Laoshi and AI-assisted lesson examples, install Ollama and ensure at least one model is available:

```sh
ollama list
```

On Linux, macOS, and Windows, the current prototype attempts to start `ollama serve` when needed. Ollama must be installed and available on `PATH`. The first installed model is used by default; override it with:

```sh
flutter run --dart-define=OLLAMA_MODEL=model-name
```

## Project Status

HanziPath has the content, visual foundation, and initial activities needed for an MVP. Development is now focused on persistent learner state, assessed lesson sessions, spaced review, and truthful progress reporting. New modes and broader platform features should follow only after that core learning loop is reliable.
