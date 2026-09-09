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
