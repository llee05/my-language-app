# 听说 TingShuo

**TingShuo v1.0.0 Beta 7** is a local-first Flutter app for building a
consistent Mandarin study habit. It combines HSK-aligned flashcard decks,
sentence and listening practice, a swipe-based word feed, a searchable
dictionary, Vocab Rush, offline vocabulary exams, and saved progress analytics.
An optional AI tutor offers chat, listening dialogues, roleplay missions, and
custom teaching personalities using your own provider and API key.

> [!IMPORTANT]
> This is a beta release. Learning data is stored only on the device. Dashboard
> XP, streaks, vocabulary statistics, and weekly XP derive from saved learning
> data. See [Beta limitations](#beta-limitations) for remaining gaps.

## Beta Highlights

- First-run setup for the learner's name, HSK level, and daily word target.
- All 4,991 bundled HSK 2.0 vocabulary entries across levels 1–6, arranged in
  251 twenty-word decks, plus previously saved custom decks.
- Ten offline sentence-practice decks with 100 everyday expressions.
- Hanzi, pinyin, English meanings, example sentences, and on-device Mandarin
  pronunciation.
- Listening practice with hidden Hanzi and pinyin, meaning choices, answer
  reveal, replay, and slower playback.
- Immediate card ratings, persisted deck position, completion summaries, and
  the ability to resume an unfinished deck after restarting the app.
- Doom Scrolling: a vertical, random feed of vocabulary below 80% mastery,
  with pronunciation, examples, and explicit word ratings.
- Spaced-review scheduling and saved progress shared across study modes.
- Dictionary search by Hanzi, pinyin, or English, with HSK and learning-state
  filters, word details, and word-rating controls.
- Vocab Rush timed and survival modes; correct and incorrect answers contribute
  to vocabulary statistics.
- Offline Exam Mode with reading, pinyin, written recall, optional listening,
  section scores, and answer review.
- Dashboard and Profile analytics from saved reviews, including XP, streaks,
  vocabulary mastery, HSK vocabulary progress, and a weekly report.
- Seven built-in AI tutor personalities, including Long Laoshi, plus custom
  profiles, generated listening dialogues, and goal-oriented roleplay missions.
- Five colour themes, local settings, manual JSON backup/restore, safeguarded
  data reset, and responsive desktop and mobile layouts.

The core study and review flow works without an account, internet connection,
or an AI API key.

## Getting Started

### Requirements

- Flutter **3.44.4** (Dart **3.12.2**), matching CI and the committed lockfile
- A Flutter desktop or mobile toolchain for the target platform; web is not supported
- Linux builds: ALSA and libsecret development headers
  (`sudo apt install libasound2-dev libsecret-1-dev` on Ubuntu/Debian).
  Saving AI keys also requires a running, unlocked Secret Service keyring, such
  as GNOME Keyring, in the desktop session.
- Optional: a personal API key for one of the supported AI providers below

If you use mise, the repository's `mise.toml` selects Flutter 3.44.4:

```sh
mise trust
mise install
```

Otherwise, select Flutter 3.44.4 from the
[Flutter SDK archive](https://docs.flutter.dev/install/archive), including in
your IDE's Flutter SDK setting. Confirm `flutter --version` before resolving
dependencies: a newer SDK can select different Flutter-pinned dependencies
and make the lockfile incompatible with CI.

Install the committed dependencies:

```sh
flutter --version
flutter doctor -v
flutter pub get --enforce-lockfile
```

Run TingShuo:

```sh
flutter run
```

On first launch, choose a name, current HSK level, and daily word target. These
settings and subsequent learning history are saved in a local SQLite database.

## Using the Beta

### Flashcards

Open **Flashcards** to start a bundled deck or revisit a previously saved custom deck.
The default vocabulary library contains 251 decks covering all 4,991 bundled
HSK 1–6 entries. Each deck contains 20 distinct words from one HSK level;
the final deck in each level repeats a few words to keep its size at 20.
Examples use attributed Tatoeba Mandarin–English pairs with source pinyin,
and original study sentences fill gaps. Everything is bundled for offline use.

Reveal each answer and rate the word; TingShuo saves every rating immediately
and schedules the card's next review. Completing a deck shows a short
celebration, the XP earned from saved ratings, accuracy, and new/revisited word
counts. Expand the recap to revisit cards rated Again or Hard, or start the next
deck at the same HSK level. Sentence practice offers the next sentence deck.
An unfinished deck can be resumed from the dashboard or Flashcards page.
The library opens at **All levels** and shows
the total number of decks. Filtering by HSK 6 shows 125 of the 251 vocabulary
decks; **Show all decks** clears the level filter and search. Custom deck
creation has been removed; previously saved decks and their progress remain available.

Previously saved decks with a **Study guide** still show their objective,
grammar explanation, dialogue, and practice questions. Guides remain available
with the deck and are included in exported backups.

Upgrading replaces the old default library while retaining saved reviews,
schedules, custom decks, and unfinished sessions. Historical decks remain
available when resuming a session. Shared cards keep the same progress across
the new decks.

Open **Flashcards → Sentence practice** for ten themed decks of ten everyday
sentences and short expressions. Each includes Hanzi, sentence pinyin, English,
and pronunciation. These original study sentences follow the same rating and
review flow as vocabulary cards; they are an everyday-language selection rather
than an HSK-aligned sentence curriculum. See [Content provenance](assets/data/README.md)
for dataset sources, attribution, and regeneration instructions.

### Home and Profile

**Home** shows the unlearned-word discovery prompt, the latest unfinished
deck, and weekly XP. Vocabulary statistics also appear on wider layouts; on
mobile, open Profile for vocabulary mastery. **Available HSK flashcards** samples
up to six decks across HSK levels; use **Refresh decks** for another selection.

Open **Profile** through the user icon in the dashboard header to see total XP,
current streak, answer accuracy, review counts, active study days, and vocabulary
mastery. The weekly report covers Monday through Sunday in local time and shows
XP, reviews, accuracy, days studied, and the most productive day. Saved correct
reviews earn 10 XP and incorrect reviews earn 5 XP.

Words count as learned at 80% mastery. Mastery is lifetime recorded answer
accuracy, so a single correct answer can count as learned. Hard ratings count
as correct; the score does not measure long-term retention. HSK vocabulary
progress counts distinct
learned words in each level and marks a level reached when that level and all
lower levels are complete. This progress is separate from the HSK level you
choose in learner settings and is not an official proficiency score. Analytics
refresh after saved reviews, at local midnight, and when the app resumes.

Flashcards, Dictionary, Doom Scrolling, Listening Practice, Vocab Rush, and Exam
Mode share the same saved word progress. Sentence recaps, AI chat, generated
dialogues, and roleplay turns offer **Practise these words** controls for locally
matched bundled vocabulary. Only explicit ratings and assessed answers update
statistics; browsing, listening to audio, and generating AI content do not.
Whole sentence cards earn study XP but are excluded from HSK word totals.

### Doom Scrolling

Open **Doom Scrolling** or select **Start scrolling** on Home for a vertical feed
of random HSK 1–6 words you have not learned yet. Words at 80% mastery or above
are excluded, including learned words whose spaced review is due. Each card
shows Hanzi, optional pinyin, a study meaning, and an example where one is
available. Each word plays automatically when its card appears, if Sound is
enabled in Settings. **Word details** shows the full readings, meanings, and
examples, with controls to replay the word or hear its example sentence.

Swipe up, scroll with the mouse wheel, use the arrow keys, or select **Swipe up
for another word**. Browsing and skipping do not change progress. **Got it**
saves a correct rating; **Still learning** saves an incorrect rating. Saving
finishes before the feed advances, and failed saves can be retried. At the end
of a mix, **Refresh word feed** reshuffles the remaining unlearned vocabulary.

With enlarged text or a short window, scroll within the word card to reach its
content and ratings, then select **Next word** to advance.

Legacy daily-review sessions remain in local storage and backups; navigation
now opens the word feed. Spaced-review dates and the Dictionary's **To review**
filter remain available.

### Listening practice

Open **Listening Practice** to use the same vocabulary, sentence-practice,
and previously saved custom decks as **Flashcards**. The library opens at
**All levels**; search decks, Hanzi, pinyin, or English, or use HSK chips to
filter vocabulary. Select **Listen** on a deck to start directly, with all 20
words in each default vocabulary deck and all ten prompts in each sentence deck.
**Random deck** chooses one of the visible decks; **Random mix** shuffles cards
from the visible decks. Both follow the current mode, level filter, and search.
Deck cards show learned counts using saved progress with at least 80% mastery.
Each prompt plays before its Hanzi and pinyin are shown. Choose the English
meaning or reveal the answer, and use **Replay** or **Slower** to hear it again.

Listening scores last for the current session only. Choosing a meaning saves
a correct or incorrect card rating; revealing an answer saves an incorrect
rating. Vocabulary responses update mastery, XP, streaks, and review schedules.
Sentence-card responses retain their own review history and XP and do not count
as HSK vocabulary mastery.

### Exam Mode

Open **Exam Mode** in the navigation to take an offline vocabulary assessment
for any HSK level from 1 to 6. Exams sample distinct words from the selected
level across reading, pinyin, written recall, and optional listening. With all
four sections enabled, levels 1–6 contain 40, 48, 56, 64, 72, and 80 questions.
Choose a timed session (25–50 minutes, depending on level) or an untimed exam.
Answers can be revisited before submission; the results show section scores and
a full answer review. Written recall accepts simplified or traditional Chinese.

These are TingShuo practice assessments, not official HSK papers or certification
scores. Listening requires a working Mandarin voice and enabled sound; failed
audio questions can be excluded and the result is marked as partial. Unanswered
questions count as incorrect. Attempts and results stay in memory only and are
lost when leaving the exam or closing the app. On submission or timeout,
answered, scored questions save correct or incorrect vocabulary ratings.
Unanswered and excluded audio questions do not change vocabulary progress.
Failed progress saves can be retried without counting answers twice.

### Dictionary and Vocab Rush

The **Dictionary** page supports Hanzi, pinyin, and English search, HSK 1–6
filters, and unseen, learning, learned, and due states. Pinyin search accepts
tone marks, plain letters, or tone numbers such as `xue2xi2`; `ü`, `v`, and `u:`
spellings are supported. The search bar stays at the top while you scroll the
word list. Open word details and expand **Practise these words**
to save a **Got it** or **Still learning** rating.
Looking up a word or playing its pronunciation does not award mastery.
**Vocab Rush** provides timed and survival challenges; every answer contributes
to shared vocabulary statistics, with mistakes recorded as weak words.

Three mistakes end a Vocab Rush game. Timed games keep counting while the app
is in the background; Survival has no time limit. **Show pinyin** in Settings
also controls the pronunciation hint during a game.

### Appearance and preferences

Open **Settings → Appearance** to choose Classic Ember, Ocean, Forest, Violet,
or Midnight. Colour changes apply immediately and save automatically. The
experimental **Press feedback** selector includes a preview button; select
**Save settings** to keep that choice.

Use **Save settings** after editing your name, HSK level, daily word target,
Show pinyin, Sound, or Kokoro voice selection on iOS/macOS. These preferences are stored
locally and restored on the next launch. The save action stays visible at the
bottom while you scroll through Settings.

### Pronunciation audio

Use **Listen to example** on the back of a deck card, or the speaker beside an
example in Dictionary or Doom Scrolling word details, or a saved deck guide, to
hear the full Mandarin sentence. Playback does not require an AI provider or
award mastery. Sound can be enabled or disabled under **Settings → Sound**.

On **Android**, pronunciation uses the device's Simplified Chinese (`zh-CN`)
speech engine. Open **Settings → Mandarin voice → Install Mandarin voice**,
or **Install voice** after a missing-voice error, and select Chinese
(Mandarin / China) in the speech engine's installer. The app checks again when
you return; use **Check again** if the download finishes later. Voice downloads
are managed by the device's speech engine and may require internet access.
Android does not offer Kokoro and ships without its native libraries.

On **Linux and Windows**, 4,379 human-recorded vocabulary words are included
with the app (87.7% of the vocabulary, about 47 MB). Matching words play offline
immediately, including in Flashcards and Listening Practice. **Settings →
Recorded Mandarin audio** shows the pack status and credits. No Kokoro download
is needed. The recordings are by Yue Tan (Shtooka / University of Caen),
converted to MP3 by [audio-cmn](https://github.com/hugolpz/audio-cmn), under
[CC BY-SA 3.0 US](https://creativecommons.org/licenses/by-sa/3.0/us/).

Missing words and full sentences, including examples and AI dialogue, use
system speech. Open **Settings → Recorded Mandarin audio → System Mandarin
fallback** to check availability. **Install Mandarin voice** installs **eSpeak
NG** on Linux through the system package manager, or Chinese (Simplified)
text-to-speech on Windows through Windows Update. Installation needs internet
access and system administrator approval. The app verifies availability after
installation and when it resumes; **Check again** refreshes the status manually.
If Windows requests a restart, restart and check again before using sentence
audio. Installing speech does not change your display language.

Linux automatic installation supports apt, dnf, pacman, zypper, and apk and
requires PolicyKit (`pkexec`). For other setups, install `espeak-ng` manually
(for example, `sudo apt install espeak-ng` on Debian/Ubuntu or
`sudo pacman -S espeak-ng` on Arch), then select **Check again**. Legacy eSpeak
is also supported. The recordings work without a fallback engine; sentence
audio needs it. Generated desktop dialogue uses one system voice.
Potentially ambiguous single-character recordings are excluded pending reading
review. See [recording provenance and regeneration](assets/audio/mandarin/README.md).

On **iOS and macOS**, open **Settings → Offline Mandarin voices**. TingShuo
downloads and verifies this pack into the app's private support directory;
no manual model-file setup is needed:

- **Kokoro int8 v1.1:** a 147 MB download (about 215 MB installed) with 100
  Mandarin voices. Extraction needs about 600 MB of temporary free space.

The download is resilient on mobile networks: if the connection drops, the
partial archive is kept and the next attempt resumes where it stopped instead
of restarting the 147 MB (via HTTP Range requests). Settings surfaces the
progress with a **Resume download** button and shows how much is already on
the device after an interruption.

Kokoro is the default engine on these platforms. After installing it, the default
voice pool includes all 100 voices and chooses one randomly for each phrase
without immediately repeating a voice. The searchable voice picker can limit
that pool to any subset; selecting one voice keeps pronunciation consistent.
Save settings to keep the voice pool for future launches. Synthesis runs
locally through sherpa-onnx. Until the pack is ready, the
app falls back to a compatible Simplified Chinese (`zh-CN`) system voice where
one is available. Kokoro uses the Apache-2.0-licensed
[Kokoro int8 multilingual v1.1 model](https://huggingface.co/csukuangfj/kokoro-int8-multi-lang-v1_1).

### Speech input

Hold the microphone button to dictate a tutor message, a listening-dialogue
topic, or a roleplay reply; release it to stop. The transcript stays in the text
field for review before sending or generating an exercise. Dictation uses the
platform's speech recognition, requires microphone and speech permissions where
applicable, and may need network access. Typing remains available when
recognition is unsupported or unavailable.

### Optional AI tutor

In **Tutor chat → Choose personality**, pick Long Laoshi, Chatty Friend,
Precision Coach, Travel Guide, Storyteller, Culture Companion, or Quiz Master.
Each card explains its teaching style. Switching tutors starts a fresh chat;
the selected style is remembered on this device. Listening dialogues and
roleplay missions keep their own exercise formats.

Select **Create a personality** to describe your ideal tutor, then **Create with
AI** to draft a profile using the current connection in Settings. Review or edit
the name, short description, and teaching style before selecting **Save and
chat**. You can also fill in the profile manually without making an AI request.
Custom tutors can be edited or deleted from the picker. Profiles are stored
locally, survive onboarding reset, and are removed by full data reset. They are
not included in study-data backup exports.

Open **Settings → AI provider** to configure AI without rebuilding the app:

1. Choose a provider. Gemini is suggested for new users; Gemini, OpenAI, and
   Claude have preset text models.
2. Select **Get an API key** to open the provider's official key page in your
   browser. Follow the on-screen instructions, then return to TingShuo.
3. Select **Paste key**, or paste/type into the masked API key field. The app
   reads the clipboard only when you select **Paste key**.
4. Select **Test and save**. This sends a small request using your API allowance
   (charges may apply), then saves the key securely only if the test succeeds.
   Failed tests keep your draft and leave previously saved settings unchanged.

**Advanced** contains the editable model ID and custom HTTPS endpoint, along
with **Save without testing** (local storage only) and **Test connection**
(a request without saving). Custom providers need both an endpoint and model ID.
**Skip — continue without AI** dismisses setup and discards the unsaved key;
decks and review remain available. You can reopen setup from Settings.

The setup pages are [Google AI Studio](https://aistudio.google.com/apikey),
[OpenAI API keys](https://platform.openai.com/api-keys), and
[Claude Console API keys](https://platform.claude.com/settings/keys). Review the
provider's billing and quota information before making requests. Gemini's free
access applies to selected models and has usage limits. Claude defaults to
`claude-haiku-4-5-20251001`; existing saved model choices are preserved.

When you send a tutor message, the request also includes a bounded snapshot of
your locally saved HSK level, studied vocabulary, weak and due words, recent
mistakes, and recent deck sessions so the tutor can personalize practice. The
snapshot excludes your name and is limited to 80 studied words, 8 targeted
words per category, and 5 deck sessions. If the snapshot cannot be read,
tutor chat continues without personalization.

Choose **Listening dialogue** inside AI Tutor to generate a short conversation
from up to 80 recently studied words. The response is locally checked so every
spoken token comes from that list apart from one or two highlighted new words.
Listen without the transcript, answer the comprehension questions, then reveal
the pinyin and translation. New words are tappable for their reading, meaning,
and pronunciation. Linux/Windows play generated dialogues through one system
Mandarin voice. On iOS/macOS, when the Kokoro pack is installed, the two speakers use two
different voices from the learner's selected voice pool where possible.

Choose **Roleplay Missions** from the sidebar for a short goal-driven exchange
such as ordering food, visiting a pharmacist, meeting a language partner,
correcting an order, or handling a station announcement. Each turn is locally
checked against the learner's studied words plus a small mission-specific
vocabulary set. Hints stay hidden until requested, and every completed mission
ends with tailored feedback and a short list of words to review.

| Provider option | API used |
| --- | --- |
| Google Gemini | Google's [`generateContent`](https://ai.google.dev/api/generate-content) API |
| OpenAI | [Chat Completions](https://developers.openai.com/api/reference/resources/chat) |
| Anthropic / Claude | [Messages](https://platform.claude.com/docs/en/api/messages/create) |
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

Previously saved OpenRouter, DeepSeek, Groq, Mistral, and xAI configurations
appear under **Other / OpenAI-compatible**, retaining their endpoint, model,
and key.

Keys are stored through the platform's secure storage using
[`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage),
separately from the learner SQLite database. A saved key is never redisplayed
in the form. If secure storage is unavailable, Settings reports the failure
instead of saving a key in ordinary preferences.

Your key and tutor conversation history go directly to the selected provider
when you use AI. Your provider's usage limits, charges, and data policies apply.
Only enter a custom endpoint you trust. Chat history stays in memory until reset
or navigation; bundled vocabulary decks are available offline.

No AI service is contacted during startup. Without a configured key, the tutor
directs you to Settings. Flashcards and review work offline.

#### Developer Gemini fallback

For local development, an ignored `.env.gemini.json` file is still supported
when no personal configuration is saved:

```json
{
  "GEMINI_API_KEY": "your-development-key",
  "GEMINI_MODEL": "gemini-3.6-flash"
}
```

Run on your chosen desktop or mobile device:

```sh
flutter run --dart-define-from-file=.env.gemini.json
```

`GEMINI_MODEL` is optional and defaults to `gemini-3.6-flash`. Gemini model values
use bare model IDs, without a `models/` prefix. Removing a personal configuration
in a development build restores this fallback, if one was compiled in.

Dart defines are compiled into the app even when read from an ignored file.
Never commit keys or distribute a build containing a shared key. If the app
will pay for AI using a shared developer key, a backend must hold that key and
authenticate requests; that backend is outside this implementation. See Google's
[API key guidance](https://ai.google.dev/gemini-api/docs/api-key). Release artifacts
contain no shared AI key; users can add their own through Settings.

### Backup, restore, and reset

Open **Settings → Backup and restore → Export backup** to save a JSON snapshot
of your learner profile, learning and appearance settings, decks and guides,
cards, deck memberships, review history, mastery/schedules, and resumable deck
and daily-review sessions. Keep a copy outside the app's data directory before
upgrading, moving to another device, or resetting.

Select **Restore backup** to choose a file and review its learner name, HSK
level, export date, and deck/card/review/session counts. Confirming replaces
the local study data and settings with the snapshot. Restore validates linked
records and applies the replacement in one database transaction, so an invalid
backup leaves existing study data intact. Older backups receive the current
bundled curriculum while retaining learning history.

Backups exclude API keys, tutor personalities and the selected tutor, chat and
AI exercise history, exam/listening results, and downloaded voice files. Restore
preserves the installation's saved AI configuration; configure it separately
when moving to another device. Tutor profiles and installed voices stay local
to each installation.

To start over, open **Settings → Reset account**. Read the deletion warning,
select **Continue**, then type `RESET` and select **Reset account permanently**.
You can cancel either confirmation without changing your data. Reset removes
the local learner profile, study progress, review history, custom decks and
tutors, settings, and saved AI configuration, including API keys, then returns
to learner setup with the default appearance. Bundled decks are recreated;
downloaded voices remain available. Deleted study data can only be recovered
from a previously exported backup, which does not restore keys or tutor profiles.

Debug builds also expose **Reset onboarding only** in the Development section.
This returns to learner setup while preserving learning data, settings, tutor
profiles, and AI configuration.

## Beta Limitations

- Home's available lesson selection is randomized across HSK levels; it is not
  personalized from learning history.
- Reminder preferences are stored, but Settings currently has no reminder
  controls and system notifications are not scheduled.
- Button press animations remain experimental, as indicated in Settings.
- There are no accounts, cloud sync, or automatic cloud backups. Manual backup
  export and restore are available in Settings. Resetting all local data is
  permanent unless you restore a previously exported backup.
- Exam attempts, listening scores, tutor chats, and AI exercises are not saved
  between visits or launches.
- AI responses require internet access and a valid provider, key, and model,
  are subject to API usage limits and charges, and may vary in quality. Provider
  contracts and failures are tested with mocked HTTP responses; live access
  depends on the user's account and selected model. A backend for a shared
  app-owned key is not included.
- Pronunciation grading and handwriting recognition are outside this beta's
  scope. Dictation depends on platform support and speech permissions.

## Development

Run formatting validation, static analysis, and the test suite from the
repository root:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

CI runs `flutter test --coverage` and uploads `coverage/lcov.info`. Release
tooling has a separate offline suite:

```sh
python3 -m unittest discover -s tool/ci -p 'test_*.py' -v
```

The suite covers startup and onboarding, database migrations and persistence,
curriculum upgrades, lesson and daily-review resumption, spaced scheduling,
dictionary search, unlearned-word discovery, cross-mode vocabulary statistics,
exam generation/results, Profile analytics, AI contracts and tutor profiles,
personal-key settings, voice installation/fallback, backup/reset, appearance,
and cache invalidation. Tests use in-memory or temporary SQLite databases,
mock secure storage and provider responses, and injected audio/file services.
They require no provider API keys or production voice-pack downloads.

Read [AGENTS.md](AGENTS.md) for architecture boundaries, data-preservation rules,
and focused checks before changing the app.

### Platform builds

Android development requires Android SDK 36, Java 17, and the SDK tools shown
by `flutter doctor -v`. Windows x64 builds must run on Windows with Visual
Studio's **Desktop development with C++** workload and the **C++ ATL** component
for the selected MSVC toolset (required by secure storage). Keep `nuget.exe` on
`PATH`; the Windows text-to-speech plugin downloads its C++/WinRT dependency
during the first build.

Pull requests, main-branch pushes, and manual GitHub Actions runs validate the
workflow, formatting, analyzer, and tests, then build Linux x64, universal macOS
(Intel and Apple Silicon), Windows x64, and an Android debug APK. Desktop
packages and the debug APK are downloadable from each run's artifacts.

Linux CI builds on Ubuntu 22.04 with GTK, ALSA, and libsecret headers. The macOS
app targets macOS 11 or later and builds on macOS 15 with Xcode, CocoaPods, and
CMake. Windows builds use the Windows 2022 runner. CI pins Flutter 3.44.4 and
installs dependencies from the committed lockfile.

Matching version tags produce signed Android APK/AAB downloads and all three
desktop packages in one GitHub Release, only after every platform succeeds.
See [Beta release workflow](docs/beta-releases.md) for preparation, installation,
platform testing, signing requirements, and failed-run recovery.
The [October 4 stability report](docs/stability-check-2026-10-04.md) records the
automated checks, fixes, and remaining device checks for the next beta.
The [app runthrough](docs/app-runthrough.md) records the subsequent Linux
screen review, usability improvements, and full validation pass.
The [interface review](docs/ui-runthrough.md) records the visual refinements,
desktop and narrow-layout checks, and persistent Settings save action.

### Technical snapshot

- **Framework:** Flutter
- **Language:** Dart
- **Storage:** SQLite via `sqflite_common_ffi`; personal AI keys via `flutter_secure_storage`
- **Schema:** version 17, with ordered migrations and separate bundled-content
  updates that preserve learner history
- **AI:** Gemini, Anthropic, and OpenAI-compatible REST APIs through an HTTP client
- **Audio:** Linux/Windows use bundled human MP3 recordings via `flutter_soloud`,
  with Linux eSpeak and Windows system speech for missing clips and sentences.
  iOS/macOS use Kokoro via `sherpa_onnx` with `flutter_tts` fallback.
  Android uses the system `zh-CN` voice
  only and ships without Kokoro, onnxruntime, and soloud native libraries.
- **Speech input:** platform recognition via `speech_to_text`
- **Backups:** validated local JSON snapshots through `file_picker`
- **UI:** a shared `main.dart` library with feature/core `part` files, stateful
  widgets, callbacks, futures, and dependencies supplied by `AppDependencies`
- **Content:** bundled HSK 2.0 levels 1–6 vocabulary, twenty-word decks, and
  original sentence practice

Native dependency overrides keep Android's sherpa-onnx plugins empty and vendor
Linux secure storage with schema-lifetime and write/readback fixes. Linux keys
saved by older builds under the broken schema need to be entered again once.
See [Native dependency notes](third_party/README.md) before updating these plugins.
Android, iOS, Linux, macOS, and Windows runners are present; CI currently builds
Android and the three desktop platforms. There is no web runner.

### In-memory caching

Bundled vocabulary is parsed once per asset bundle and shared as immutable data
by Flashcards, Dictionary, Doom Scrolling, Vocab Rush, and Exam Mode. The database
retains up to 32 recent lesson reads (including the library summary) and one daily statistics
result. Lesson sessions are loaded in one bulk query and remain fresh on each load.
Statistics refresh after saved reviews, at local midnight, and when the app
resumes. Kokoro retains up to 64 synthesized clips within a 16 MiB sample-data
budget, keyed by text, speaker, model directory, and model archive version.
Oversized clips can play without being retained in that cache. Desktop word
recordings retain up to 64 compressed clips within a separate 4 MiB budget.

Database cache hits still participate in close/reset coordination. Content
writes and backup restores invalidate both database caches; saved reviews only
invalidate statistics. Onboarding reset, full reset, and database close clear
the database caches. New repository operations that change lessons or progress
must wrap their transaction in `LocalDatabase.write`, choosing the appropriate
`DatabaseCacheScope` so invalidation follows a successful commit. These caches
never replace SQLite persistence or secure storage. Concurrent reads share
pending work, and failed loads can retry.

### Project structure

```text
lib/
├── main.dart           # Entry point, shared UI library, theme, navigation
├── local_database.dart # SQLite lifecycle, content installation, caches/reset
├── ai/                 # Provider routing and REST adapters
├── core/               # Theme and shared navigation/widgets
├── database/           # Schema/content migrations and bundled curriculum
├── features/           # Home/profile, study, review, games, exams, AI, settings
├── models/             # Learner, lessons, analytics, exams, AI exercises
├── repositories/       # Persistence, bundled vocabulary, AI keys, backups
└── services/           # Review/streak logic, pronunciation, dictation, caches
```

Bundled runtime content and provenance live in `assets/data/`; regeneration and
release tools live in `tool/`; automated coverage lives in `test/`.

## Release

Current version: **1.0.0-beta.7+7**

### Beta 7

- Added Dictionary, Doom Scrolling, and vocabulary progress shared across study
  modes, with saved XP, streaks, HSK mastery, and weekly analytics.
- Gave Flashcards and Listening Practice one searchable deck library with HSK
  filters and direct deck selection.
- Added example-sentence playback, numbered-pinyin dictionary searches, and
  improved lesson completion summaries.
- Refreshed navigation and study layouts, kept Settings save controls visible,
  and improved controls for enlarged text.
- Fixed Vocab Rush timing and answer feedback, rapid appearance selections,
  stale dictation callbacks, and reviewed curriculum examples.
- Added a two-step account reset confirmation and expanded offline persistence
  and backup failure-recovery coverage.
- Bundled 4,379 human Mandarin word recordings for Linux and Windows, with
  system speech fallback and explicit fallback-voice installation in Settings.
  Android continues to use its system Mandarin voice.
- Updated Android to version code **7** and documented the Google Play internal
  testing upload process.

### Beta 6

- Renamed Lessons to Flashcards and gave Listening Practice the same deck library,
  with direct deck selection, search, and HSK filters in place of dropdowns.
- Replaced AI lesson creation with 251 bundled twenty-word vocabulary decks
  covering all 4,991 HSK 1–6 entries, available offline.
- Added attributed Tatoeba examples and original study sentences, and refreshed
  sentence-practice content.
- Preserved saved custom decks, review history, and unfinished sessions during
  the curriculum upgrade; shared words retain their progress across decks.
- Added learned-word counts to decks and expanded listening practice to use
  the new curriculum decks.
- Improved Android back navigation across study screens.
- Added coordinated Linux x64, universal macOS, Windows x64, and signed Android
  APK/AAB release packages with checksums. macOS beta packages use ad-hoc signing
  and are labeled unsigned; Windows packages are unsigned portable bundles.

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

For Google Play, follow [Google Play internal testing](docs/google-play-internal-testing.md).
Beta 7 uses package ID `io.github.llee05.tingshuo`, version name
`1.0.0-beta.7`, and version code `7`. Reuse the existing upload key and check
that Play Console has not already used version code `7` before uploading.

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

The workflow fails rather than publishing an unsigned or debug-signed Android
artifact when any signing secret is missing. It also verifies APK and AAB
signatures before uploading them. Beta tags are marked as GitHub prereleases;
macOS downloads are explicitly labeled unsigned and Windows downloads are
unsigned portable bundles. See [Beta release workflow](docs/beta-releases.md)
before tagging the next beta.

The beta milestone delivers a complete local loop:

`Learn → Rate → Save → Schedule review → Return tomorrow`

Further work focuses on release reliability, accessibility, and reminder
notification support.

## Copyright and usage

**Copyright © 2026 Leon Lee. All rights reserved.**

This repository is publicly available for portfolio and demonstration purposes.
No permission is granted to copy, modify, distribute, sublicense, or use this
source code in other projects without prior written permission.
