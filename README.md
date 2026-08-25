# 听说 TingShuo

**TingShuo v1.0.0 Beta 1** is a local-first Flutter app for building a
consistent Mandarin study habit. It combines HSK-aligned flashcard lessons,
spaced daily review, a searchable vocabulary library, Vocab Rush, and an
optional local AI tutor named Long Laoshi.

> [!IMPORTANT]
> This is a beta release. Learning data is stored only on the device, and the
> dashboard's XP, streak, mastery, lesson recommendations, and weekly activity
> are still presentation data. See [Beta limitations](#beta-limitations).

## Beta Highlights

- First-run setup for the learner's name, HSK level, and daily word target.
- More than 4,000 bundled vocabulary entries across HSK levels 1–6.
- Seeded and AI-assisted flashcard lessons with an offline vocabulary fallback.
- Hanzi, pinyin, English meanings, example sentences, and on-device Mandarin
  pronunciation.
- Immediate card ratings, persisted lesson position, completion summaries, and
  the ability to resume an unfinished lesson after restarting the app.
- A daily review queue that prioritises due and weak cards before new words.
- Spaced-review scheduling, resumable daily sessions, and a daily completion
  summary.
- Vocabulary search by Hanzi, pinyin, or English, with HSK and learning-state
  filters plus word detail views.
- Vocab Rush timed and survival modes; incorrect answers are added to the
  learner's review data.
- Long Laoshi, an optional local AI tutor powered by Ollama.
- Responsive desktop and mobile layouts, local settings, and versioned SQLite
  migrations.

The core study and review flow works without an account, internet connection,
or Ollama.

## Getting Started

### Requirements

- A Flutter SDK compatible with Dart `^3.12.2`
- A supported Flutter desktop, mobile, or web toolchain for the target platform
- Linux builds: ALSA development headers (`sudo apt install libasound2-dev` on
  Ubuntu/Debian)
- Optional: [Ollama](https://ollama.com/) for Long Laoshi and AI-assisted
  lesson content

Install dependencies:

```sh
flutter pub get
```

Run TingShuo:

```sh
flutter run
```

On first launch, choose a name, current HSK level, and daily word target. These
settings and subsequent learning history are saved in a local SQLite database.

## Using the Beta

### Lessons

Open **Lessons** to start a bundled lesson or revisit a locally generated one.
Reveal each answer and rate the word; TingShuo saves every rating immediately
and schedules the card's next review. An unfinished lesson can be resumed from
the dashboard or Lessons page.

### Daily review

Open **Daily Review** or use the dashboard prompt to review today's queue. Due and
weak vocabulary is shown first, followed by new words up to the configured
daily target. Session position and answers are persisted, so a review can be
continued later the same day.

### Vocabulary and Vocab Rush

The **Vocabulary** page supports Hanzi, pinyin, and English search, HSK 1–6
filters, and unseen, learning, learned, and due states. **Vocab Rush** provides
timed and survival challenges; missed vocabulary is recorded as weak and can
return in daily review.

### Pronunciation audio

The speaker button on lesson cards does not require Ollama. Sound can be
enabled or disabled under **Settings → Sound**.

For consistent mobile and desktop pronunciation, open **Settings → Offline
Mandarin voices**. TingShuo can download and verify either of these packs into
the app's private support directory; no manual model-file setup is needed:

- **MeloTTS:** an approximately 61 MB download with one compact, fast voice.
- **Kokoro int8 v1.1:** a 147 MB download (about 215 MB installed) with 100
  selectable Mandarin voices. Extraction needs about 600 MB of temporary free
  space.

Choose the speech engine and Kokoro voice after installation, then save the
preference for future launches. Synthesis runs locally through sherpa-onnx,
including on Linux. Until the selected pack is ready, the app falls back to a
compatible Simplified Chinese (`zh-CN`) system voice where one is available.
Melo uses the MIT-licensed
[MeloTTS Chinese/English model](https://huggingface.co/csukuangfj/vits-melo-tts-zh_en);
Kokoro uses the Apache-2.0-licensed
[Kokoro int8 multilingual v1.1 model](https://huggingface.co/csukuangfj/kokoro-int8-multi-lang-v1_1).

### Optional AI tutor

Install Ollama and make at least one model available:

```sh
ollama list
```

On Linux, macOS, and Windows, TingShuo attempts to start `ollama serve` when
needed. Ollama must be installed and available on `PATH`. The first installed
model is used by default; select another model at launch with:

```sh
flutter run --dart-define=OLLAMA_MODEL=model-name
```

If Ollama is missing or unavailable, the rest of the app remains usable.

## Beta Limitations

- Dashboard recommended lessons and recent activity are not yet personalized
  from stored learning history.
- A dedicated progress analytics view is planned.
- The daily reminder preference is saved locally but does not yet schedule a
  system notification.
- There are no accounts, cloud sync, or cross-device backup. Resetting all
  local data is permanent.
- AI responses require a locally running Ollama model and may vary in quality.
- Speech recognition, pronunciation grading, and handwriting recognition are
  outside this beta's scope.

Please treat beta learning data as non-critical until export and backup tools
are available.

## Development

Run static analysis and the test suite:

```sh
flutter analyze
flutter test
```

The suite covers startup and onboarding, database migrations and persistence,
lesson and daily-review flows, spaced scheduling, vocabulary data and search,
and Vocab Rush review integration.

### Technical snapshot

- **Framework:** Flutter
- **Language:** Dart
- **Storage:** SQLite via `sqflite_common_ffi`
- **AI:** Ollama's local chat API through a lightweight HTTP client
- **Audio:** selectable offline MeloTTS or Kokoro via `sherpa_onnx` and
  `flutter_soloud`, with a `flutter_tts` system-voice fallback
- **Content:** bundled HSK 1–6 JSON vocabulary and seeded lessons

### Project structure

```text
lib/
├── ai/                 # Ollama integration and AI lesson support
├── core/               # Theme and shared navigation/widgets
├── database/           # Migrations and seeded lessons
├── features/           # Dashboard, lessons, review, vocabulary, game, tutor
├── models/             # Learner, lesson, and progress models
├── repositories/       # Persistence interfaces and SQLite implementations
└── services/           # Spaced-review scheduler
```

## Release

Current version: **1.0.0-beta.1+1**

The beta milestone delivers a complete local loop:

`Learn → Rate → Save → Schedule review → Return tomorrow`

Work after Beta 1 is focused on live progress analytics, release reliability,
accessibility, learner-data export, and notification support.
