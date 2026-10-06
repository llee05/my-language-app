# Beta release workflow

`.github/workflows/flutter.yml` checks and packages TingShuo for Linux, macOS,
Windows, and Android. Changes to the workflow are made in the repository, then
committed and pushed like app code. No version tag is needed to test CI.

## What runs

Pull requests targeting `main`, pushes to `main`, and manual workflow runs:

1. Check the Python release tools and workflow syntax, read `pubspec.yaml`,
   and validate any release tag.
2. Install Flutter 3.44.4 and enforce the committed dependency lockfile.
3. Check Dart formatting, run analysis, and run the offline tests with coverage.
4. Build the four platforms in parallel after validation succeeds.
5. Upload portable desktop packages and the Android debug APK as workflow artifacts.

Tags matching `v*` replace the Android debug build with signed release APK/AAB
builds. The publishing job waits for validation and **every platform build**,
requires the exact five expected packages, generates checksums and a source
manifest, and publishes one GitHub Release. No shared AI key is embedded.

| Platform | Build host | Download | Signing / scope |
| --- | --- | --- | --- |
| Linux | Ubuntu 22.04 x64 | `tingshuo-VERSION-linux-x64.tar.gz` | Complete portable bundle; preserves executable modes |
| macOS | macOS 15 / Apple Silicon | `tingshuo-VERSION-macos-universal-unsigned.zip` | Intel and Apple Silicon; ad-hoc signed, no Developer ID or notarization |
| Windows | Windows 2022 x64 | `tingshuo-VERSION-windows-x64.zip` | Complete unsigned portable bundle |
| Android | Ubuntu 22.04 / Java 17 | `tingshuo-VERSION-android.apk` | Signed APK for direct installation |
| Android | Ubuntu 22.04 / Java 17 | `tingshuo-VERSION-android.aab` | Signed app bundle for Play Console |

`VERSION` excludes the `+BUILD` suffix. `release.json` records the full version,
build number, commit, Flutter version, platform files, and desktop signing status.
`SHA256SUMS` covers all five packages and `release.json`.

Linux CI checks linked native libraries for missing dependencies. macOS CI
checks the app and embedded Mach-O libraries for both architectures and verifies
the ad-hoc signature. Android CI verifies both signatures. These checks do not
replace launching the packages on their target systems.

Regular build artifacts expire after 14 days; signed Android artifacts and the
combined verified release set are retained for 30 days. Published GitHub Release
assets are separate from that workflow-artifact retention.

## Configure Android signing once

In GitHub, open **Settings → Secrets and variables → Actions → New repository
secret**, or use `gh secret set` from an authenticated GitHub CLI.

| Secret | Required value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded upload keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Signing key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

Use the existing upload key for subsequent betas. Back it up securely: replacing
the signing key can prevent existing direct APK installations from upgrading.
If Play App Signing uses a separate app-signing key, a GitHub APK signed with the
upload key cannot necessarily update a Play-installed app; test those channels
separately. This workflow does not upload to Play Console automatically.

The workflow creates `android/key.properties` and the keystore only for tagged
Android builds, then removes them even when a build fails. They are never uploaded
as artifacts. PRs and ordinary branch runs do not need signing secrets. See the
README's [Android signing](../README.md#android-signing) instructions for local
release builds.

Only the final publishing job receives `contents: write`. All build jobs use
read-only repository permissions. Tagged runs are not cancelled by a newer run;
obsolete branch and PR checks are cancelled.

## Prepare the next beta

1. Finish and commit the intended app changes. Set the next version/build in
   `pubspec.yaml`, currently `1.0.0-beta.7+7` for beta 7. Increase the Android
   build number for each uploaded release and update the README release notes.
2. Select **Flutter 3.44.4**, matching CI, before resolving dependencies or
   running checks. With mise, run `mise trust` and `mise install`; the repository's
   `mise.toml` pins this version. Other SDK managers and the IDE must select the
   same SDK. Check `flutter --version`, then run:

   ```sh
   flutter --version
   flutter pub get --enforce-lockfile
   dart format --output=none --set-exit-if-changed lib test
   flutter analyze
   flutter test --coverage
   python3 -m unittest discover -s tool/ci -p 'test_*.py' -v
   ```

3. Push the release commit to `main` and wait for all four builds to succeed.
   Download the desktop packages and debug APK from the workflow run. Check the
   platform flows below. Debug APKs have a separate signing identity from release
   APKs; test release upgrades separately.
4. Confirm the four Android signing secrets are configured. The macOS beta does
   not require Apple credentials. This repository's setup does not create a
   Developer ID signed/notarized Mac build or an Authenticode-signed Windows build.
5. When ready to publish, create an annotated tag matching the app version
   **without** the `+BUILD` suffix. For the example above:

   ```sh
   git tag -a v1.0.0-beta.7 -m 'TingShuo 1.0.0 beta 7'
   git push origin v1.0.0-beta.7
   ```

   These commands publish through the workflow; do not use a release tag just
   to check compilation. A mismatched tag fails before platform builds start.
6. Confirm the tagged run succeeds and the release includes five packages,
   `SHA256SUMS`, and `release.json`. Prerelease versions such as `-beta.7` are
   marked **Pre-release** and do not replace the latest stable release.
7. Install the signed Android APK over the previous direct-install beta and
   verify saved learning data and pronunciation. Check the final desktop
   downloads too. Review the generated notes and include any known beta issues.

The current app version is deliberately not advanced by the CI setup itself.
Release metadata always comes from the checked-out `pubspec.yaml`.

## Google Play internal testing

Follow [Google Play internal testing](google-play-internal-testing.md) to upload
the signed beta 7 app bundle and invite testers. A local signed bundle can be
uploaded without creating a GitHub release tag. If using the tagged workflow,
upload `tingshuo-1.0.0-beta.7-android.aab` from the verified release assets.
GitHub publication and Play Console rollout are separate actions; this workflow
does not publish to Google Play.

## Install and check the packages

### Linux

Extract the archive into a new folder and run `./tingshuo`. Keep the entire
`lib` and `data` folders alongside the executable; moving only the executable
breaks the bundle. Tar preserves executable permissions and symlinks.

GTK 3, ALSA, libsecret, and the C/C++ runtime must be available. On Ubuntu 22.04:

```sh
sudo apt install libgtk-3-0 libasound2 libsecret-1-0 libstdc++6
```

Saving personal AI keys needs a running, unlocked Secret Service keyring such
as GNOME Keyring. The Ubuntu 22.04 build host limits the app's glibc baseline;
it does not guarantee compatibility with every distribution or downloaded
native dependency. Test the intended Ubuntu and Arch/Omarchy environments.
Linux ARM64, AppImage, Flatpak, and distribution-specific installers are not
produced by this workflow.

### macOS

Extract the ZIP using Archive Utility and move `TingShuo.app` into Applications.
The runner targets macOS 11 or later; test the actual native dependencies on
your supported versions before claiming a minimum version to users.

This beta is **unsigned for public distribution**: ad-hoc signing gives the
bundle a local signature but does not establish an Apple Developer identity or
notarization. Gatekeeper may block a downloaded app. For a trusted download,
follow Apple's [Open Anyway instructions](https://support.apple.com/en-au/102445)
in System Settings → Privacy & Security. Leave Gatekeeper enabled globally.
If a particular macOS version still refuses the package, record that beta
limitation rather than treating the signature check as a distribution approval.

Test on both Intel and Apple Silicon Macs. Network, microphone, and selected-file
read/write entitlements remain enabled in the sandbox, allowing AI requests,
dictation, and user-selected backup import/export. Verify saving and reloading
personal AI configuration through the macOS keychain.

### Windows

Extract the entire ZIP and run `tingshuo.exe`. Keep its DLLs and `data` directory
in place. This is a portable application, not an installer. Windows may display
a warning because the executable has no Authenticode publisher signature.
Test on a clean x64 machine, including required Visual C++ runtime availability,
system speech, and secure storage. Windows ARM64 is not built here.

### Android

The `.apk` is directly installable after allowing installation from the chosen
browser/file manager. The `.aab` is for Play Console and cannot be installed like
an APK. Verify the system Mandarin TTS voice is installed; Android deliberately
uses system speech instead of Kokoro. Test on a physical arm64 device as well
as any emulator used during development.

### Platform smoke checks

Use disposable test profiles or test devices for restore/reset checks. Back up
any real learner data before upgrading; do not reset a real learner database
as a test.

| Flow | Verify on every target |
| --- | --- |
| Offline startup | First launch and subsequent launch work with networking disabled and no AI configuration |
| Study and review | Rate flashcards, restart mid-session, resume, and confirm shared vocabulary progress persists |
| Native audio | Linux/Windows: bundled word recordings and system sentence fallback; macOS: Kokoro and system fallback; Android: system Mandarin speech. Unavailable optional audio does not block study. |
| Backup files | Export to a user-selected location and restore in a disposable profile, preserving curriculum and progress |
| Personal AI settings | Save and reload configuration using the platform's secure storage; startup still makes no AI request |
| Dictation | Grant/deny microphone and speech permissions; unsupported or denied dictation does not block study |
| Upgrade | Install over the previous beta and confirm existing lessons, reviews, settings, and sessions survive |
| Layout | Exercise mobile/narrow and desktop widths, including Hanzi, pinyin, and English text |

## Verify checksums

Download all assets into the same directory. Linux:

```sh
sha256sum --check SHA256SUMS
```

macOS:

```sh
shasum -a 256 --check SHA256SUMS
```

Windows PowerShell can compute an individual downloaded file's hash with
`Get-FileHash -Algorithm SHA256 PATH_TO_FILE`; compare it to the corresponding
entry in `SHA256SUMS`. The checksums detect changed or incomplete downloads.

## Failed runs and retries

- **Lockfile cannot be satisfied:** check `flutter --version`. Flutter pins some
  transitive dependencies, so resolving with a different SDK can produce a
  lockfile that CI rejects. Select the repository's Flutter 3.44.4, run
  `flutter pub get` once to regenerate `pubspec.lock`, review and commit its
  changes, then verify `flutter pub get --enforce-lockfile`. Keep enforcement
  enabled in CI. Intentional Flutter upgrades must update CI, `mise.toml`, the
  documentation, and the lockfile together.
- **Wrong tag:** update the app version before creating the correct release tag.
  Do not retag an already published release. The `+BUILD` suffix belongs only
  in `pubspec.yaml`, not in the tag.
- **Missing signing secret or platform failure:** fix the configuration and
  rerun the failed jobs for the same commit. Artifact uploads replace that
  run's previous artifacts so retries do not collide. A code fix needs a new
  commit and normally a new beta version/tag.
- **Upload or publication failure:** the complete verified asset set remains
  available as a workflow artifact. GitHub CLI stages uploads in a draft before
  publishing. Inspect any draft left by a failed upload; finish it after
  verifying the assets, or remove that unpublished draft and rerun publication.
- **Release already exists:** publication fails rather than replacing published
  assets. Use a new beta version for a changed build. Do not delete a published
  release just to rerun CI.
- **Manual run:** selecting a branch builds packages without publishing. Selecting
  a matching version tag also enables signed builds and publication, so use a
  branch when you only want verification.

## Reference documentation

- [Flutter Linux prerequisites](https://docs.flutter.dev/platform-integration/linux/setup)
- [Flutter macOS tooling](https://docs.flutter.dev/platform-integration/macos/setup)
- [GitHub runner labels and architectures](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [Artifact permission preservation](https://github.com/actions/upload-artifact#permission-loss)
- [GitHub CLI release staging and flags](https://cli.github.com/manual/gh_release_create)
