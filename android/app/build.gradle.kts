import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties()
if (releaseSigningFile.isFile) {
    releaseSigningFile.inputStream().use(releaseSigningProperties::load)
}

val requiredReleaseSigningProperties =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingReleaseSigningProperties =
    requiredReleaseSigningProperties.filter {
        releaseSigningProperties.getProperty(it).isNullOrBlank()
    }
val releaseSigningConfigured =
    releaseSigningFile.isFile && missingReleaseSigningProperties.isEmpty()

val releaseKeystoreFile =
    releaseSigningProperties.getProperty("storeFile")?.takeIf { it.isNotBlank() }?.let(rootProject::file)

val verifyAndroidSigning = tasks.register("verifyAndroidSigning") {
    group = "verification"
    description = "Verifies that Android release signing is configured."
    doLast {
        if (!releaseSigningFile.isFile) {
            throw GradleException(
                "Android release signing is not configured. " +
                    "Copy android/key.properties.example to android/key.properties and fill in the values.",
            )
        }
        if (missingReleaseSigningProperties.isNotEmpty()) {
            throw GradleException(
                "Android release signing is incomplete in android/key.properties. " +
                    "Missing: ${missingReleaseSigningProperties.joinToString()}.",
            )
        }
        if (releaseKeystoreFile?.isFile != true) {
            throw GradleException(
                "Android release keystore was not found at " +
                    "${releaseKeystoreFile?.absolutePath ?: "the configured storeFile path"}.",
            )
        }
    }
}

tasks.configureEach {
    if (name.contains("release", ignoreCase = true)) {
        dependsOn(verifyAndroidSigning)
    }
}

android {
    namespace = "io.github.llee05.tingshuo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.llee05.tingshuo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
                storeFile = releaseKeystoreFile
                storePassword = releaseSigningProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// The Android build relies on the system Mandarin TTS voice instead of
// Kokoro, so the flutter_soloud playback engine and its bundled codec
// libraries are never used on this platform. Exclude the plugin's project
// dependency so its native libraries are not packaged into the APK. This
// is safe because flutter_soloud is an FFI-only plugin that is never
// registered with GeneratedPluginRegistrant and never called on Android.
configurations.all {
    exclude(mapOf("module" to "flutter_soloud"))
}
