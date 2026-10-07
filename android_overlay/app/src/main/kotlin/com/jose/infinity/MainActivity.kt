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

    private var pendingPick: MethodChannel.Result? = null

    @Deprecated("Dipakai untuk pemilih file sederhana")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK) return
        val r = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            r.success(null)
            return
        }
        try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            var name = "file"
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                val idx = c.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && c.moveToFirst()) name = c.getString(idx) ?: name
            }
            r.success(mapOf("name" to name, "bytes" to bytes))
        } catch (e: Exception) {
            r.error("read", e.message, null)
        }
    }

    companion object {
        private const val REQ_PICK = 4242
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
                    "saveDownloadBytes" -> {
                        val name = call.argument<String>("name") ?: "infinity-backup.bin"
                        val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
                        val mime = call.argument<String>("mime") ?: "application/octet-stream"
                        result.success(saveDownloadRaw(name, bytes, mime))
                    }
                    "pickFile" -> {
                        if (pendingPick != null) {
                            result.error("busy", "Pemilih file sedang terbuka", null)
                        } else {
                            pendingPick = result
                            val i = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                            @Suppress("DEPRECATION")
                            startActivityForResult(i, REQ_PICK)
                        }
                    }
                    "showQuickBar" -> {
                        QuickBar.setEnabled(this, true)
                        QuickBar.show(this)
                        result.success(null)
                    }
                    "hideQuickBar" -> {
                        QuickBar.setEnabled(this, false)
                        QuickBar.hide(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveDownload(name: String, text: String): Boolean =
        saveDownloadRaw(name, text.toByteArray(), "application/json")

    /** Simpan file ke Download/Infinity (Android 10+) atau folder app (lama). */
    private fun saveDownloadRaw(name: String, data: ByteArray, mime: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= 29) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                    put(MediaStore.MediaColumns.MIME_TYPE, mime)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Infinity")
                }
                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: return false
                contentResolver.openOutputStream(uri)?.use { it.write(data) }
                    ?: return false
                true
            } else {
                val dir = java.io.File(getExternalFilesDir(null), "backup")
                dir.mkdirs()
                java.io.File(dir, name).writeBytes(data)
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
