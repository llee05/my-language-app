package io.github.llee05.tingshuo

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.Settings
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tingshuo/system_voice")
            .setMethodCallHandler { call, result ->
                if (call.method != "installVoiceData") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val engine = call.argument<String>("engine")
                val intents = mutableListOf<Intent>()
                if (!engine.isNullOrBlank()) {
                    intents.add(Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA).setPackage(engine))
                } else {
                    intents.add(Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA))
                }
                // Some engines do not expose an installer. Settings lets the
                // learner choose/configure a speech engine instead.
                intents.add(Intent("com.android.settings.TTS_SETTINGS"))
                intents.add(Intent(Settings.ACTION_SETTINGS))
                val opened = intents.any { intent ->
                    try {
                        startActivity(intent)
                        true
                    } catch (_: ActivityNotFoundException) {
                        false
                    } catch (_: SecurityException) {
                        false
                    }
                }
                if (opened) {
                    result.success(null)
                } else {
                    result.error("voice_installer_unavailable", "Could not open speech settings.", null)
                }
            }
    }
}
