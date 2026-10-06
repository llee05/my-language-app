# Google Play internal testing

This guide covers TingShuo beta 7. Console instructions were checked against
Google's documentation on 6 October 2026.

| Field | Beta 7 value |
| --- | --- |
| App name | TingShuo |
| Application/package ID | `io.github.llee05.tingshuo` |
| Flutter version | `1.0.0-beta.7+7` |
| Android version name | `1.0.0-beta.7` |
| Android version code | `7` |
| Local upload file | `build/app/outputs/bundle/release/app-release.aab` |
| GitHub release upload file | `tingshuo-1.0.0-beta.7-android.aab` |

## 1. Select or create the app

Open [Google Play Console](https://play.google.com/console/) and select the
existing TingShuo app. If this is its first upload, select **Create app**, enter
TingShuo, choose the default listing language, select **App**, choose the intended
free/paid setting, add a support email, and complete the declarations shown by
Console. See [Google's app setup guide](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en).

Complete any developer-account verification requested by Console. This build
uses `io.github.llee05.tingshuo`; an existing Play app must have that same package
ID. Google fixes the package ID after the first artifact upload.

Check **Test and release → Latest releases and bundles** for previously uploaded
version codes. Code `7` must be unused and higher than the version testers already
have. If `7` was already uploaded, increase the `+BUILD` number in `pubspec.yaml`,
align the current-version documentation, and rebuild before uploading.

## 2. Use the upload key

For an existing app, reuse its registered upload keystore and alias. The
repository's [Android signing instructions](../README.md#android-signing)
explain `android/key.properties` and key generation for a first release.
If the file is already configured, keep it. If it is missing, copy
`android/key.properties.example` and enter the existing keystore's absolute path,
alias, and passwords locally. Keep the keystore and credentials out of Git.

For a first upload, follow Console's **Play App Signing** setup. Google can
generate and manage the app-signing key; the local keystore signs uploads.
The app-signing certificate and upload certificate can therefore differ.
See [Google's Play App Signing guide](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en).

If you are unsure which existing keystore to use, compare its SHA-256 certificate
fingerprint with Console's **Upload key certificate** under **Protected with
Play → Play Store distribution → Go to Play app signing** (older Console
layouts use **App integrity**). Run this locally, substituting the path and
alias; `keytool` prompts for the password:

```sh
keytool -list -v -keystore /secure/path/tingshuo-upload-keystore.jks -alias upload
```

## 3. Build the signed bundle

From the repository root, using Flutter **3.44.4** and Java **17**:

```sh
flutter --version
flutter pub get --enforce-lockfile
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab`. Release signing must
be configured; the build fails if signing credentials are missing. Build without
developer AI-key Dart defines, so each user supplies their own optional AI key.

Alternatively, download `tingshuo-1.0.0-beta.7-android.aab` from the verified
GitHub release described in [Beta release workflow](beta-releases.md).
A local signed build does not require a GitHub tag. Ordinary branch CI produces
a debug APK; Play Console needs the signed release bundle.

Flutter derives Android version metadata from `pubspec.yaml`; see
[Flutter's Android release guide](https://docs.flutter.dev/deployment/android).

## 4. Add testers

Select **Test and release → Testing → Internal testing → Testers**.
Create an email list, add your own Google Play account and the other testers'
Google Account addresses, save it, then select the list for this track.
Add a feedback email or URL and save the track changes.

Internal testing supports up to **100 testers**. Each person must both belong
to the selected list and opt in using the test link. See
[Google's testing setup guide](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en).

## 5. Upload and roll out beta 7

1. On **Internal testing → Releases**, choose **Create new release**.
2. Complete Play App Signing setup if requested, then upload the `.aab` from
   step 3. Confirm package ID `io.github.llee05.tingshuo`, version name
   `1.0.0-beta.7`, and version code `7` in the processed bundle details.
3. Name the release `TingShuo 1.0.0 beta 7 (7)` and add the notes below. Use the
   language tag Console provides if your listing language differs from `en-US`.
4. Save the draft and choose **Next** / **Preview and confirm**. Resolve blocking
   errors and review warnings. If release creation is disabled, complete the
   outstanding Dashboard tasks identified by Console.
5. Confirm the destination is **Internal testing**, then choose **Start rollout
   to internal testing** or the equivalent **Publish** action shown. If Console
   instead saves changes for review, open **Publishing overview** and send those
   changes for review; follow the displayed status until the test is available.

```text
<en-US>
Beta 7 adds Dictionary and Doom Scrolling with saved vocabulary progress across study modes. Flashcards and Listening Practice share a searchable deck library. Includes numbered-pinyin search, example-sentence playback, improved layouts and lesson summaries, safer account reset, and fixes for Vocab Rush, appearance settings, and dictation. Core study works offline; AI features use your own API key.
</en-US>
```

The notes fit Google's 500-character limit per language. The internal release
name is only for Console. See
[Google's release instructions](https://support.google.com/googleplay/android-developer/answer/9859348?hl=en)
for current button labels and review states.

## 6. Install through Google Play

Return to the **Testers** tab and copy the opt-in link under **How testers join
your test**. Share it with your selected testers. On the Android phone, open it
with the Google Account on the tester list, join the test, then follow the
Google Play installation link. The app is not discoverable through public
search during an internal-only test.

The first test link can take several hours to become available. Console can
also show a temporary app name before its first review. If the link says the
app is unavailable, check the rollout status, selected email list, Google
Account, and opt-in status before retrying. These details are covered in
[Google's testing setup guide](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en).

A debug or directly installed APK may have a different signing certificate from
the Play build. If an update is rejected, export a study backup before removing
the old installation, install through Play, then restore the backup. Test Play
upgrades using an earlier Play-installed version when available.

Check offline startup, a saved card rating after restarting, deck resumption,
Mandarin system speech, backup export/import, and denied microphone access on
a test device. Use a disposable profile for reset checks.

## Later updates and production

Every changed bundle upload needs a new, unused version code. Reuse the upload
key, rebuild, and create another internal release; existing opted-in testers
receive the update through Google Play.

Internal testing is available before completing all app setup. Production has
additional requirements. For personal developer accounts created after
13 November 2023, Google currently requires a **closed test with at least
12 testers opted in continuously for 14 days** before applying for production
access. Internal testing does not satisfy that closed-test requirement. See
[Google's personal-account testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).
