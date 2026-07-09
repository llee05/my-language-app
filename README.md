# HanziPath Project Brief

HanziPath is a Flutter-based Mandarin learning app for beginner learners. It combines a structured lesson dashboard, HSK-aligned flashcard content, progress-oriented UI patterns, and an AI tutor named Long Laoshi to help learners practice Chinese in a low-pressure, conversational way.

The app is currently focused on the learner experience: continuing lessons, browsing suggested study material, tracking light progress signals, and asking the AI tutor for compact explanations with Chinese, pinyin, English, and practical tips.

## Product Goals

- Help beginner Mandarin learners build consistent daily practice habits.
- Present HSK vocabulary and example sentences in a clean lesson flow.
- Offer an always-available AI tutor for corrections, sentence practice, and quick explanations.
- Keep the interface calm, focused, and suitable for repeated study sessions.
- Support local-first learning data so the app can initialize with seeded content.

## Core Features

- Responsive Flutter dashboard with sidebar navigation for Home, Lessons, Vocabulary, Progress, and AI Tutor.
- HSK flashcard lesson seed data with Chinese terms, pinyin, English meanings, examples, quiz options, and answer keys.
- Local SQLite database initialization using `sqflite_common_ffi`.
- AI tutor chat powered by OpenAI Chat Completions.
- Optional `.env` support for local OpenAI API key configuration.
- Dark Mandarin study interface with XP, streak, lesson progress, and suggested lesson surfaces.

## Technical Snapshot

- Framework: Flutter
- Language: Dart
- Local storage: SQLite via `sqflite_common_ffi`
- AI integration: OpenAI Chat Completions through a lightweight HTTP client
- Environment config: `flutter_dotenv`, platform environment variables, or local `.env`
- Tests: Flutter widget and database startup tests

## Local Setup

Install dependencies:

```sh
flutter pub get
```

To enable the AI tutor locally, create a `.env` file in the project root:

```sh
OPENAI_API_KEY=your_api_key_here
```

Run the app:

```sh
flutter run
```

Run tests:

```sh
flutter test
```

## Current Architecture

- `lib/main.dart` wires app startup, environment loading, local database initialization, and the root `HanziPathApp`.
- `lib/dashboard_page.dart` defines the responsive shell and switches to the AI tutor view from the sidebar.
- `lib/learning_panel.dart` renders the main lesson dashboard and suggested lesson cards.
- `lib/ai_tutor_page.dart` implements the Long Laoshi chat interface and response formatting.
- `lib/ai/openai_service.dart` provides the OpenAI API client and API key loading.
- `lib/local_database.dart` creates and seeds the local SQLite schema.
- `lib/database/flashcard_seed.dart` contains the current flashcard lesson content.

## Near-Term Opportunities

- Connect lesson cards to a full flashcard review flow.
- Persist user progress, streaks, XP, completed cards, and tutor conversation history.
- Add vocabulary search and review modes.
- Expand HSK lesson coverage beyond the current seed set.
- Improve secure API key handling for packaged builds.
- Add integration tests around tutor failure states and database seeding.

## Project Status

HanziPath is an early-stage learning app prototype with a functioning dashboard, seeded Mandarin lesson data, local database setup, and AI tutor integration. The next major milestone is turning the dashboard lesson surfaces into complete study and review workflows.
