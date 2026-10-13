# Release TingShuo v2 beta 1

Prepared identity: `2.0.0-beta.1+9` in `pubspec.yaml`.
Publishing tag: `v2.0.0-beta.1`. The Android application ID remains
`io.github.llee05.tingshuo`; the Android build number continues from the v1
series instead of restarting. This guide prepares a prerelease, not stable v2.

Preparation checks on 13 October 2026 passed: Flutter 3.44.4 / Dart 3.12.2,
enforced lockfile unchanged, required Dart formatting, clean analyzer, all 701
Flutter tests with coverage, and all 13 release-tool tests. A fixture-based CLI
preflight also verified the current package names, manifest, checksums, and
inclusion of the actual v2 release notes without creating a tag or publishing.

Local Linux release, signed Android APK, and signed Android AAB builds passed.
APK signature verification confirmed package `io.github.llee05.tingshuo`, version
name `2.0.0-beta.1`, and version code `9`; App Bundle signature verification passed.
Linux's bundled version metadata also reports v2 beta 1 / build 9.
These checks do not complete Windows/macOS builds, physical-device testing,
verification of GitHub signing secrets, or checking unused codes in Play Console.

## 1. Confirm signing and build number

The prepared source and notes are committed locally. Publishing, GitHub signing
secrets, and device upgrade checks remain manual steps in this guide.

Check Play Console's previously uploaded version codes: `9` must be unused and
higher than the versions being upgraded. If necessary, increase the `+BUILD`
suffix and current-version references before building. The tag still excludes
that suffix. Reuse the existing upload keystore and alias.

On GitHub, open the repository's **Settings → Secrets and variables → Actions**.
Confirm `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` are configured. Only their names
can be checked after saving; existing secret values cannot be read back.
See [GitHub's secret instructions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets).

If you need to add the Base64 keystore secret from Linux, authenticate GitHub CLI
and substitute the path to your existing keystore:

```sh
gh auth login
base64 -w 0 /path/to/existing-upload-keystore.jks | gh secret set ANDROID_KEYSTORE_BASE64 --repo llee05/my-language-app
```

Enter the password/alias secrets through GitHub's form or `gh secret set` prompts.
Keep keystores, passwords, and `android/key.properties` out of Git.

## 2. Validate the prepared files

From the repository root, using Flutter 3.44.4 and Dart 3.12.2:

```sh
git status --short
flutter --version
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage --concurrency=2
python3 -m unittest discover -s tool/ci -p 'test_*.py' -v
GITHUB_REF=refs/tags/v2.0.0-beta.1 python3 tool/ci/release_metadata.py
```

The last command validates the proposed tag without creating it. Metadata must
report version `2.0.0-beta.1+9`, release version `2.0.0-beta.1`, build number `9`,
and both release/prerelease flags as true. If you changed the build number,
expect that new number instead.

## 3. Push main and wait for all builds

The release preparation and its documentation are committed locally. Push them:

```sh
git push origin main
```

Open [GitHub Actions](https://github.com/llee05/my-language-app/actions) and the
**Flutter CI/CD** run for that exact commit. Wait for validation, Linux x64,
macOS universal, Windows x64, and Android to pass. A main-branch run produces
testing artifacts without publishing. To rerun it, use **Actions → Flutter
CI/CD → Run workflow → main**; see
[GitHub's manual workflow instructions](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).

## 4. Test installation and upgrade

Download the desktop packages and debug APK from that run. Test offline startup,
ratings and restart/resume, appearance restoration, Mandarin speech, backup
export/restore, and denied microphone access using disposable profiles/devices.
The [platform smoke checks](beta-releases.md#platform-smoke-checks) cover each OS.

For a signed Android upgrade test, keep an existing `android/key.properties`.
If it is missing, copy `android/key.properties.example` once and fill in the
existing key's absolute path, alias, and passwords. Then build:

```sh
flutter build apk --release
```

Install `build/app/outputs/flutter-apk/app-release.apk` over an earlier signed
direct-install beta and verify its saved learning data. A debug APK has a different
signing identity; test Play-to-Play upgrades through the Play testing track.
The package ID and learner database identity stay unchanged for v2.
The locally prepared APK is already at that path; the signed AAB is at
`build/app/outputs/bundle/release/app-release.aab`. Rebuild if you change the source,
version, build number, or signing configuration after these preparation checks.

## 5. Publish the matching tag

After the builds and installation checks pass, run:

```sh
git tag -a v2.0.0-beta.1 -m 'TingShuo 2.0.0 beta 1'
git push origin v2.0.0-beta.1
```

Pushing the tag starts publication. The workflow rebuilds all four platforms,
signs Android APK/AAB files, verifies the complete package set, and publishes a
GitHub prerelease after all jobs succeed. The matching
[release notes](releases/2.0.0-beta.1.md) are included automatically.
Use a new version/tag for later changed builds; published releases are not
overwritten. No release tag is created by preparing these files.

## 6. Verify the release and invite testers

Open [Releases](https://github.com/llee05/my-language-app/releases) and check the
tagged run's **Publish complete release** job and the prerelease's seven assets:

```text
tingshuo-2.0.0-beta.1-linux-x64.tar.gz
tingshuo-2.0.0-beta.1-macos-universal-unsigned.zip
tingshuo-2.0.0-beta.1-windows-x64.zip
tingshuo-2.0.0-beta.1-android.apk
tingshuo-2.0.0-beta.1-android.aab
SHA256SUMS
release.json
```

Download them to one directory and run `sha256sum --check SHA256SUMS` on Linux.
Confirm `release.json` has the expected version, build number, and source commit.
Give direct-install testers the APK or the appropriate desktop package.

For Google Play, upload the `.aab` under **Test and release → Testing → Internal
testing → Releases → Create new release**, add the supplied notes, review the
draft, and roll it out to the selected testers. Copy the opt-in link from the
**Testers** tab. GitHub publication does not upload or roll out a Play release.
Follow [the internal-testing guide](google-play-internal-testing.md), including
Google's [release instructions](https://support.google.com/googleplay/android-developer/answer/9859348?hl=en).
