package com.jose.infinity

import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity dibutuhkan oleh local_auth (sidik jari/wajah).
 * Channel "infinity/native" dipakai NativeBridge di main.dart.
 */
class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Layar aman diatur dari app (Keamanan > Mode layar aman), bawaan mati
        // supaya screenshot bisa.
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "infinity/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val on = call.argument<Boolean>("on") ?: true
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    "isListenerEnabled" -> result.success(isListenerEnabled())
                    "openListenerSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null)
                            )
                        )
                        result.success(null)
                    }
                    "fetchCaptured" -> result.success(CaptureStore.drain(this))
                    "saveDownload" -> {
                        val name = call.argument<String>("name") ?: "infinity-backup.json"
                        val text = call.argument<String>("text") ?: ""
                        result.success(saveDownload(name, text))
                    }
                    "showQuickBar" -> {
                        QuickBar.show(this)
                        result.success(null)
                    }
                    "hideQuickBar" -> {
                        QuickBar.hide(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Simpan backup ke Download/Infinity (Android 10+) atau folder app (lama). */
    private fun saveDownload(name: String, text: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= 29) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Infinity")
                }
                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: return false
                contentResolver.openOutputStream(uri)?.use { it.write(text.toByteArray()) }
                    ?: return false
                true
            } else {
                val dir = java.io.File(getExternalFilesDir(null), "backup")
                dir.mkdirs()
                java.io.File(dir, name).writeText(text)
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun isListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            ?: return false
        val me = ComponentName(this, NotificationCaptureService::class.java)
        return flat.split(":").any { ComponentName.unflattenFromString(it) == me }
    }
}
