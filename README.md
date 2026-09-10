# 听说 TingShuo

**TingShuo v1.0.0 Beta 1** is a local-first Flutter app for building a
consistent Mandarin study habit. It combines HSK-aligned flashcard lessons,
spaced daily review, a searchable vocabulary library, Vocab Rush, and an
optional Gemini AI tutor named Long Laoshi.

> [!IMPORTANT]
> This is a beta release. Learning data is stored only on the device. Dashboard
> XP, streaks, vocabulary statistics, and weekly XP derive from saved learning
> data. See [Beta limitations](#beta-limitations) for remaining gaps.

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
- Long Laoshi, an optional AI tutor powered by the Gemini API scaffold.
- Responsive desktop and mobile layouts, local settings, and versioned SQLite
  migrations.

The core study and review flow works without an account, internet connection,
or a Gemini API key.

## Getting Started

### Requirements

- A Flutter SDK compatible with Dart `^3.12.2`
- A Flutter desktop or mobile toolchain for the target platform; web is not supported
- Linux builds: ALSA development headers (`sudo apt install libasound2-dev` on
  Ubuntu/Debian)
- Optional: a [Gemini API key](https://aistudio.google.com/apikey) for local
  development of Long Laoshi and AI-assisted lesson content

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

The speaker button on lesson cards does not require Gemini. Sound can be
enabled or disabled under **Settings → Sound**.

For consistent mobile and desktop pronunciation, open **Settings → Offline
Mandarin voices**. TingShuo can download and verify this pack into the app's
private support directory; no manual model-file setup is needed:

- **Kokoro int8 v1.1:** a 147 MB download (about 215 MB installed) with 100
  Mandarin voices. Extraction needs about 600 MB of temporary free space.

The download is resilient on mobile networks: if the connection drops, the
partial archive is kept and the next attempt resumes where it stopped instead
of restarting the 147 MB (via HTTP Range requests). Settings surfaces the
progress with a **Resume download** button and shows how much is already on
the device after an interruption.

Kokoro is the default pronunciation engine. After installing it, the default
voice pool includes all 100 voices and chooses one randomly for each phrase
without immediately repeating a voice. The searchable voice picker can limit
that pool to any subset; selecting one voice keeps pronunciation consistent.
Save settings to keep the voice pool for future launches. Synthesis runs
locally through sherpa-onnx, including on Linux. Until the pack is ready, the
app falls back to a compatible Simplified Chinese (`zh-CN`) system voice where
one is available. Kokoro uses the Apache-2.0-licensed
[Kokoro int8 multilingual v1.1 model](https://huggingface.co/csukuangfj/kokoro-int8-multi-lang-v1_1).

### Optional AI tutor

The Gemini scaffold calls Google's HTTPS
[`generateContent` API](https://ai.google.dev/api/generate-content) for tutor
replies and lesson examples using the existing `http` dependency. No AI service
is contacted during startup. Without a key, the tutor explains that it is
unconfigured and lesson generation falls back to bundled vocabulary.

For local development, create an ignored `.env.gemini.json` file:

```json
{
  "GEMINI_API_KEY": "your-development-key",
  "GEMINI_MODEL": "gemini-2.5-flash"
}
```

Run on your chosen desktop or mobile device:

```sh
flutter run --dart-define-from-file=.env.gemini.json
```

`GEMINI_MODEL` is optional and defaults to `gemini-2.5-flash`. Model values use
bare model IDs, without a `models/` prefix. Requests use JSON responses and
include conversation history for the tutor; lesson requests send the topic,
HSK level, and candidate vocabulary. This content goes to Google when AI is
configured and used. Chat history remains in memory until reset or navigation.

This is a development scaffold, not production key management. Dart defines
are compiled into the app even when read from an ignored file. Do not commit
keys or distribute builds containing a shared key. Before enabling AI in a
published app, add a backend that holds the key and authenticates client
requests, following Google's [API key guidance](https://ai.google.dev/gemini-api/docs/api-key).
The release workflow leaves Gemini unconfigured.

## Beta Limitations

- Dashboard recommended lessons and recent activity are not yet personalized
  from stored learning history.
- A dedicated progress analytics view is planned.
- The daily reminder preference is saved locally but does not yet schedule a
  system notification.
- There are no accounts, cloud sync, or cross-device backup. Resetting all
  local data is permanent.
- AI responses require internet access and a valid Gemini API configuration,
  are subject to API usage limits, and may vary in quality. Production backend
  integration is not included in this scaffold.
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

### Platform builds

Android development requires Android SDK 36, Java 17, and the SDK tools shown
by `flutter doctor -v`. Windows x64 builds must run on Windows with Visual
Studio's **Desktop development with C++** workload. Keep `nuget.exe` on
`PATH`; the Windows text-to-speech plugin downloads its C++/WinRT dependency
during the first build.

Pull requests compile an Android debug APK and a Windows x64 release bundle in
GitHub Actions, in addition to running the analyzer and tests.

### Technical snapshot

- **Framework:** Flutter
- **Language:** Dart
- **Storage:** SQLite via `sqflite_common_ffi`
- **AI:** Gemini REST API scaffold through a lightweight HTTP client
- **Audio:** offline Kokoro via `sherpa_onnx` and `flutter_soloud`, with a
  `flutter_tts` system-voice fallback. Android uses the system `zh-CN` voice
  only and ships without Kokoro, onnxruntime, and soloud native libraries.
- **Content:** bundled HSK 1–6 JSON vocabulary and seeded lessons

### Project structure

```text
lib/
├── ai/                 # Gemini API scaffold and AI lesson support
├── core/               # Theme and shared navigation/widgets
├── database/           # Migrations and seeded lessons
├── features/           # Dashboard, lessons, review, vocabulary, game, tutor
├── models/             # Learner, lesson, and progress models
├── repositories/       # Persistence interfaces and SQLite implementations
└── services/           # Spaced-review scheduler
```

## Release

Current version: **1.0.0-beta.1+1**

### Android signing

Android release builds must be signed with the project's upload key. Generate
the key once and keep both the keystore and its passwords in a secure backup:

```sh
keytool -genkeypair -v \
  -keystore /secure/path/tingshuo-upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Copy the versioned template, then replace all four placeholder values:

```sh
cp android/key.properties.example android/key.properties
```

`storeFile` must be the absolute path to the keystore. On Windows, use `/` as
the path separator. Both `android/key.properties` and keystore files are
ignored by Git; never commit either one. A release build fails with a clear
error when the file, a property, or the configured keystore is missing.

Build the Play Store artifact with:

```sh
flutter build appbundle --release
```

The signed bundle is written to
`build/app/outputs/bundle/release/app-release.aab`.

Version tags matching `v*` use the same signing configuration in GitHub
Actions. The Gemini scaffold stays unconfigured in release artifacts; core
study features remain available offline. Do not add a Gemini key to release
Dart defines. Configure these repository secrets before creating a release tag:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The complete upload keystore, base64-encoded as one line |
| `ANDROID_KEYSTORE_PASSWORD` | The keystore password |
| `ANDROID_KEY_ALIAS` | The upload-key alias, normally `upload` |
| `ANDROID_KEY_PASSWORD` | The upload-key password |

The workflow fails rather than publishing an unsigned or debug-signed bundle
when any signing secret is missing.

The beta milestone delivers a complete local loop:

`Learn → Rate → Save → Schedule review → Return tomorrow`

Work after Beta 1 is focused on expanded progress analytics, release reliability,
accessibility, learner-data export, and notification support.
