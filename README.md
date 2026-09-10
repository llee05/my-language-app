# 听说 TingShuo

**TingShuo v1.0.0 Beta 1** is a local-first Flutter app for building a
consistent Mandarin study habit. It combines HSK-aligned flashcard lessons,
spaced daily review, a searchable vocabulary library, Vocab Rush, and an
optional AI tutor named Long Laoshi, using your own provider and API key.

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
- Long Laoshi, an optional AI tutor with personal API keys configured in Settings.
- Responsive desktop and mobile layouts, local settings, and versioned SQLite
  migrations.

The core study and review flow works without an account, internet connection,
or an AI API key.

## Getting Started

### Requirements

- A Flutter SDK compatible with Dart `^3.12.2`
- A Flutter desktop or mobile toolchain for the target platform; web is not supported
- Linux builds: ALSA and libsecret development headers
  (`sudo apt install libasound2-dev libsecret-1-dev` on Ubuntu/Debian).
  Saving AI keys also requires a running, unlocked Secret Service keyring, such
  as GNOME Keyring, in the desktop session.
- Optional: a personal API key for one of the supported AI providers below

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

The speaker button on lesson cards does not require an AI provider. Sound can be
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

Open **Settings → AI provider** to configure AI without rebuilding the app:

1. Select your provider and paste your personal API key.
2. Enter a text/chat model ID available to your provider account. Gemini and
   OpenAI have editable defaults; other providers require a model ID.
3. Select **Save AI settings**. The next tutor or lesson-generation request uses
   the saved configuration. Saving itself does not contact the provider.
4. Optionally select **Test connection** to make a small request with the values
   in the form. This uses your API allowance and does not save changes.

| Provider option | API used |
| --- | --- |
| Google Gemini | Google's [`generateContent`](https://ai.google.dev/api/generate-content) API |
| OpenAI | [Chat Completions](https://developers.openai.com/api/reference/resources/chat) |
| Anthropic / Claude | [Messages](https://platform.claude.com/docs/en/api/messages/create) |
| OpenRouter, DeepSeek, Groq, Mistral, xAI / Grok | Each provider's OpenAI-compatible Chat Completions endpoint |
| Other / OpenAI-compatible | Your full HTTPS Chat Completions URL, for example `https://provider.example/v1/chat/completions` |

The custom option requires an OpenAI-compatible JSON API with Bearer API-key
authentication. It does not support every proprietary protocol, extra custom
headers, or cloud IAM authentication. Use a text/chat model; models with special
request requirements may not work. The API key alone cannot identify a provider
or model. Use **Test connection** to check your particular configuration.

One provider configuration is saved at a time. Switching providers requires a
key for the new provider; saving replaces the previous configuration. To replace
a key, enter a new one and save. Leave the key field blank to retain a saved key
for the same provider and endpoint. **Remove key** deletes the saved configuration
from this device. Resetting all local data also removes it; resetting learner
setup preserves it. Removal does not revoke the key at the provider or cancel
requests already sent.

Keys are stored through the platform's secure storage using
[`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage),
separately from the learner SQLite database. A saved key is never redisplayed
in the form. If secure storage is unavailable, Settings reports the failure
instead of saving a key in ordinary preferences.

Your key, tutor conversation history, and lesson prompts go directly to the
selected provider when you use AI. Lesson prompts include the topic, HSK level,
and candidate vocabulary. Your provider's usage limits, charges, and data
policies apply. Only enter a custom endpoint you trust. Chat history stays in
memory until reset or navigation; generated lessons are saved locally.

No AI service is contacted during startup. Without a configured key, the tutor
directs you to Settings and lesson generation falls back to bundled vocabulary.

#### Developer Gemini fallback

For local development, an ignored `.env.gemini.json` file is still supported
when no personal configuration is saved:

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

`GEMINI_MODEL` is optional and defaults to `gemini-2.5-flash`. Gemini model values
use bare model IDs, without a `models/` prefix. Removing a personal configuration
in a development build restores this fallback, if one was compiled in.

Dart defines are compiled into the app even when read from an ignored file.
Never commit keys or distribute a build containing a shared key. If the app
will pay for AI using a shared developer key, a backend must hold that key and
authenticate requests; that backend is outside this implementation. See Google's
[API key guidance](https://ai.google.dev/gemini-api/docs/api-key). Release artifacts
contain no shared AI key; users can add their own through Settings.

## Beta Limitations

- Dashboard recommended lessons and recent activity are not yet personalized
  from stored learning history.
- A dedicated progress analytics view is planned.
- The daily reminder preference is saved locally but does not yet schedule a
  system notification.
- There are no accounts, cloud sync, or cross-device backup. Resetting all
  local data is permanent.
- AI responses require internet access and a valid provider, key, and model,
  are subject to API usage limits and charges, and may vary in quality. Provider
  contracts and failures are tested with mocked HTTP responses; live access
  depends on the user's account and selected model. A backend for a shared
  app-owned key is not included.
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
Vocab Rush review integration, AI request contracts, and personal-key settings.

### Platform builds

Android development requires Android SDK 36, Java 17, and the SDK tools shown
by `flutter doctor -v`. Windows x64 builds must run on Windows with Visual
Studio's **Desktop development with C++** workload and the **C++ ATL** component
for the selected MSVC toolset (required by secure storage). Keep `nuget.exe` on
`PATH`; the Windows text-to-speech plugin downloads its C++/WinRT dependency
during the first build.

Pull requests compile an Android debug APK and a Windows x64 release bundle in
GitHub Actions, in addition to running the analyzer and tests.

### Technical snapshot

- **Framework:** Flutter
- **Language:** Dart
- **Storage:** SQLite via `sqflite_common_ffi`; personal AI keys via `flutter_secure_storage`
- **AI:** Gemini, Anthropic, and OpenAI-compatible REST APIs through an HTTP client
- **Audio:** offline Kokoro via `sherpa_onnx` and `flutter_soloud`, with a
  `flutter_tts` system-voice fallback. Android uses the system `zh-CN` voice
  only and ships without Kokoro, onnxruntime, and soloud native libraries.
- **Content:** bundled HSK 1–6 JSON vocabulary and seeded lessons

### Project structure

```text
lib/
├── ai/                 # Provider routing, REST adapters, and AI lesson support
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
Actions. Release artifacts contain no shared AI key; users configure their own
in Settings, and core study features remain available offline. Do not add AI
keys to release Dart defines. Configure these repository secrets before creating
a release tag:

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
