# Beta release checks

Checked on 2026-09-07 against commit `baca981` plus the local formatting,
release-workflow, and README corrections described below. These results support
an invited beta after production signing and target-device checks; they do not
constitute approval of a production-signed artifact.

## Results

| Check | Result |
| --- | --- |
| Flutter / Dart | 3.44.4 stable / 3.12.2, matching CI |
| Formatting | Passed for `lib` and `test` after formatting two files |
| `flutter analyze` | Passed, no issues |
| `flutter test --coverage` | All 203 tests passed; 4,398 / 4,946 measured lines covered (88.9%) |
| Android debug APK | Built and installed successfully |
| Linux release bundle | Built successfully; native dependency compiler warnings remain |
| Android release app bundle | Blocked: `android/key.properties` is absent; `verifyAndroidSigning` correctly fails |
| Release workflow | YAML parsed, build shell syntax checked, seven endpoint-validation cases passed using a stubbed Flutter command |
| Android runtime smoke check | Passed the flows below on a disposable API 36 x86_64 emulator |
| Windows / Apple platforms | Not built or run on this Linux machine |
| Remote CI status | Not verified: GitHub CLI is not authenticated |

The Android build reports plugin migration warnings about built-in Kotlin.
The debug build succeeds; compatibility with a future toolchain is not implied.

## Offline Android smoke check

The emulator used a fresh, temporary data directory. Wi-Fi and mobile data were
disabled before the first app launch. Existing learner databases and the user's
normal emulator were not used. The test emulator was shut down afterward.

- Completed onboarding as `BetaTester`, HSK 1, five words per day.
- Opened daily review, revealed a meaning, and saved a confident rating.
- Force-stopped and relaunched the app. The profile, 10 XP, and four remaining
  review cards persisted; resuming opened the next unreviewed word.
- Rated the remaining four cards, finished the session, and restarted again.
  The dashboard retained 50 XP and showed daily review as complete.
- Opened the bundled HSK 1 lesson through the lesson library, revealed its
  answer and attributed example, and marked the first word familiar.
- Restarted and resumed the lesson at card 2, with one of 20 words completed
  and 60 total XP retained.
- Pressed the pronunciation button; the app remained responsive. Audible output
  was not verified, and the production Kokoro pack was not downloaded.
- No `flutter:E` or `AndroidRuntime:E` log entries were captured during these
  checks. This is a limited smoke check, not a guarantee against runtime errors.

## Corrections made

- Formatted `settings_page.dart` and `kokoro_voice_pack.dart` to clear CI's
  formatting gate; no Dart behavior was changed.
- Made `OLLAMA_URL` optional in the Android release workflow. When supplied,
  it must still use HTTPS and contain no credentials, query, or fragment.
  Verified absent and valid HTTPS values pass, while HTTP, credentials, query,
  fragment, and malformed values fail. The actual CI job was not executed.
- Corrected README claims about dashboard statistics and web support, and
  documented Android releases with the optional AI tutor unconfigured.

## Remaining release checks and findings

1. Configure the real upload key through the documented signing process, build
   the signed artifact, verify its signature, and test installation/update
   through the intended beta distribution channel. No substitute key was
   generated and no release was published.
2. Run the same offline and persistence flows on physical target devices.
   Check actual Mandarin audio, voice selection, background/resume behavior,
   and a real interrupted voice-pack installation. Download integrity, resume,
   and audio failure handling currently have automated fixture coverage.
3. Confirm Windows CI and any other advertised platform builds. A successful
   Linux compile does not establish Windows, iOS, or macOS readiness.
4. Database initialization still runs before `runApp` in `lib/main.dart`.
   Initialization failures can bypass the existing startup error UI. This
   code-review finding was not repaired or fault-injected during these checks.
5. After restarting a partially completed daily review, its final summary
   reported only the resumed segment (four cards / 40 XP), while the dashboard
   correctly retained the day's five ratings / 50 XP. Consider clarifying or
   reconciling the summary before public distribution; no loss of saved XP was
   observed.

Local build and validation logs are under `/tmp/tingshuo-release-*.log` and may
be removed by system cleanup. Coverage is in `coverage/lcov.info`; generated
artifacts and learner data are not included in source changes.
