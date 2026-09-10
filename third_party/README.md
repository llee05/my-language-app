# Native library stubs for the Android build

The Android build of TingShuo does not use Kokoro: voice lines always come
from the system Mandarin (`zh-CN`) TTS voice, configured in
`lib/services/pronunciation_service_native.dart`. Because Flutter cannot
exclude a published plugin's native libraries per platform through
`pubspec.yaml`, the four Android ABI packages of `sherpa_onnx`
(`sherpa_onnx_android_arm64`, `sherpa_onnx_android_armeabi`,
`sherpa_onnx_android_x86`, and `sherpa_onnx_android_x86_64`, together about
105 MB of `.so` files) are replaced by the empty FFI-plugin stubs in this
directory via `dependency_overrides` in the root `pubspec.yaml`.

Each stub is a valid Android library plugin with no `jniLibs`, so the Gradle
plugin loader still finds a well-formed module for the `sherpa_onnx` plugin
graph while nothing native is packaged into the APK. iOS, Linux, macOS, and
Windows keep the real `sherpa_onnx` packages unchanged.

`flutter_soloud` (also unused on Android, because only Kokoro playback used
it) is excluded from the Android APK through a Gradle exclusion in
`android/app/build.gradle.kts` instead; it cannot be stubbed this way
because the same package provides its desktop native libraries.

If the app ever wants Kokoro back on Android, remove the
`dependency_overrides` section for these packages and the
`configurations.all` exclusion from `android/app/build.gradle.kts`.

# Vendored flutter_secure_storage_linux

`flutter_secure_storage_linux` 3.0.2 is vendored (unmodified upstream sources
from pub.dev, plus two fixes in `linux/include/Secret.hpp`) and wired up
through `dependency_overrides` for desktop Linux builds.

1. The `SecretStorage` schema name was captured from `label.c_str()` while the
   label still held its short constructor value; after `setLabel()` moved the
   string to the heap the name dangled, and items were stored and searched
   under whatever bytes the abandoned buffer contained. `setLabel()` now
   rebuilds the schema so the name is stable (upstream issue
   `juliansteenbakker/flutter_secure_storage#1230`).
2. gnome-keyring 50.x can accept a store and still persist the item without
   its secret body; replacements of such a hollow item silently stay broken.
   `storeToKeyring()` now verifies every store by reading it back, and when
   verification fails it removes the hollow item and re-creates it from
   scratch (up to three attempts) before reporting success.

Because the schema name changes, keys saved by older builds (stored under the
old garbage schema) are not visible to the fixed plugin and must be re-entered
once. When upstream publishes a release containing both fixes, remove the
`flutter_secure_storage_linux` entry from `dependency_overrides` and this
directory.
