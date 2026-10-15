package com.jose.infinity

import android.app.ActivityManager
import android.content.ComponentName
import android.content.ContentUris
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
        // Penjaga satu jendela: dua jendela Infinity yang hidup bersamaan
        // membuka dua salinan data di memori dan saling menimpa file yang
        // sama. Kalau sudah ada jendela yang hidup, jendela baru ini ditutup
        // dan jendela lama dibawa ke depan (intent-nya diteruskan).
        val other = live
        val dup = other != null && other !== this && !other.isFinishing && !other.isDestroyed
        note(
            this,
            "dibuat #${System.identityHashCode(this)} task=$taskId " +
                "aksi=${intent?.action} data=${intent?.data} flags=0x${Integer.toHexString(intent?.flags ?: 0)} " +
                "dari=${if (Build.VERSION.SDK_INT >= 22) referrer else null} " +
                "hidup=${if (other == null) "-" else "#" + System.identityHashCode(other) + " task=" + other.taskId}" +
                if (dup) " DUPLIKAT" else ""
        )
        if (dup && other != null) {
            // Lifecycle: onCreate lalu langsung onDestroy, tanpa onStart, jadi
            // mesin Flutter jendela ini tidak sempat menjalankan Dart.
            finish()
            super.onCreate(savedInstanceState)
            try {
                other.onNewIntent(intent)
            } catch (_: Exception) {
            }
            try {
                val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
                for (t in am.appTasks) {
                    @Suppress("DEPRECATION")
                    if (t.taskInfo.id == other.taskId) t.moveToFront()
                }
            } catch (_: Exception) {
            }
            return
        }
        live = this
        super.onCreate(savedInstanceState)
        // Layar aman diatur dari app (Keamanan > Mode layar aman), bawaan mati
        // supaya screenshot bisa.
    }

    override fun onDestroy() {
        if (live === this) live = null
        note(this, "dihancurkan #${System.identityHashCode(this)} selesai=$isFinishing")
        super.onDestroy()
    }

    override fun onPause() {
        CaptureStore.appForeground = false
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        CaptureStore.appForeground = true
        // Kalau izin akses notifikasi masih aktif tapi layanan terputus
        // (umum setelah update app), sambungkan lagi.
        if (isListenerEnabled()) NotificationCaptureService.rebind(this)
    }

    private var pendingPick: MethodChannel.Result? = null
    private var pendingSave: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null

    @Deprecated("Dipakai untuk pemilih file sederhana")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_SAVE) {
            val r = pendingSave ?: return
            val bytes = pendingSaveBytes ?: ByteArray(0)
            pendingSave = null
            pendingSaveBytes = null
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) {
                r.success(null)
                return
            }
            try {
                // Ditulis lewat penyedia dokumen yang dipilih user (mis. Google
                // Drive). Upload dikerjakan app Drive; Infinity tetap offline.
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes) }
                    ?: throw IllegalStateException("Tidak bisa menulis file")
                var name = "backup"
                contentResolver.query(uri, null, null, null, null)?.use { c ->
                    val idx = c.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0 && c.moveToFirst()) name = c.getString(idx) ?: name
                }
                r.success(name)
            } catch (e: Exception) {
                r.error("write", e.message, null)
            }
            return
        }
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
        private const val REQ_SAVE = 4243

        /** Jendela Infinity yang sedang hidup di proses ini (satu saja). */
        @Volatile
        private var live: MainActivity? = null

        /**
         * Catatan peluncuran, dibaca Dart dan digabung ke "Jejak penyimpanan"
         * (Laporan error), supaya kelihatan siapa yang membuka jendela kedua.
         */
        fun note(ctx: android.content.Context, msg: String) {
            try {
                val f = java.io.File(ctx.filesDir, "infinity_launch.log")
                val ts = java.text.SimpleDateFormat("MM-dd HH:mm:ss.SSS", java.util.Locale.US)
                    .format(java.util.Date())
                f.appendText("$ts native: $msg\n")
                if (f.length() > 12000) {
                    val all = f.readText()
                    f.writeText(all.substring(all.length - 6000))
                }
            } catch (_: Exception) {
            }
        }
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
                    "captureHealth" -> result.success(CaptureStore.health(this))
                    "rebindListener" -> {
                        NotificationCaptureService.rebind(this)
                        result.success(null)
                    }
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
                    "fetchCaptured" -> result.success(CaptureStore.peek(this))
                    "ackCaptured" -> {
                        val ids = call.argument<List<String>>("ids") ?: emptyList()
                        CaptureStore.ack(this, ids)
                        for (id in ids) CaptureAlert.cancel(this, id)
                        result.success(null)
                    }
                    "shareImage" -> {
                        val name = call.argument<String>("name") ?: "infinity.png"
                        val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
                        result.success(shareImage(name, bytes))
                    }
                    "fetchDecisions" -> result.success(CaptureStore.peekDecisions(this))
                    "ackDecisions" -> {
                        val ids = call.argument<List<String>>("ids") ?: emptyList()
                        CaptureStore.ackDecisions(this, ids)
                        result.success(null)
                    }
                    "setCaptureConfig" -> {
                        CaptureStore.setConfig(this, call.argument<String>("json") ?: "{}")
                        result.success(null)
                    }
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
                    "saveAs" -> {
                        if (pendingSave != null) {
                            result.error("busy", "Pemilih file sedang terbuka", null)
                        } else {
                            pendingSave = result
                            pendingSaveBytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
                            val i = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = call.argument<String>("mime") ?: "application/octet-stream"
                                putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "infinity-backup")
                            }
                            @Suppress("DEPRECATION")
                            startActivityForResult(i, REQ_SAVE)
                        }
                    }
                    "pruneBackups" -> {
                        val keep = call.argument<Int>("keep") ?: 8
                        result.success(pruneBackups(keep))
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

    /**
     * Bagikan gambar PNG lewat menu bagikan Android. File ditaruh sementara di
     * cache app dan dibagikan lewat FileProvider; Infinity tidak mengunggah apa pun.
     */
    private fun shareImage(name: String, bytes: ByteArray): Boolean {
        return try {
            if (bytes.isEmpty()) return false
            val dir = java.io.File(cacheDir, "share")
            dir.mkdirs()
            // Bersihkan gambar lama (lebih dari 1 jam).
            val cutoff = System.currentTimeMillis() - 60 * 60 * 1000
            dir.listFiles()?.forEach { if (it.lastModified() < cutoff) it.delete() }
            val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
            val f = java.io.File(dir, safe)
            f.writeBytes(bytes)
            val uri = androidx.core.content.FileProvider.getUriForFile(
                this, "$packageName.fileprovider", f
            )
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(send, null))
            true
        } catch (e: Exception) {
            false
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

    /**
     * Hapus backup lama di Download/Infinity, sisakan [keep] terbaru.
     * Hanya file buatan Infinity sendiri yang bisa dihapus (aturan Android);
     * file lain dilewati. Mengembalikan jumlah yang dihapus.
     */
    private fun pruneBackups(keep: Int): Int {
        var deleted = 0
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                val uri = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                val proj = arrayOf(MediaStore.MediaColumns._ID)
                val sel = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ? AND " +
                    "${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?"
                val args = arrayOf("${Environment.DIRECTORY_DOWNLOADS}/Infinity%", "infinity-backup-%")
                contentResolver.query(uri, proj, sel, args,
                    "${MediaStore.MediaColumns.DATE_ADDED} DESC")?.use { c ->
                    var i = 0
                    while (c.moveToNext()) {
                        if (i++ < keep) continue
                        try {
                            val id = c.getLong(0)
                            if (contentResolver.delete(ContentUris.withAppendedId(uri, id), null, null) > 0) deleted++
                        } catch (_: Exception) {
                        }
                    }
                }
            } else {
                val dir = java.io.File(getExternalFilesDir(null), "backup")
                dir.listFiles { f -> f.name.startsWith("infinity-backup-") }
                    ?.sortedByDescending { it.lastModified() }
                    ?.drop(keep)
                    ?.forEach { if (it.delete()) deleted++ }
            }
        } catch (_: Exception) {
        }
        return deleted
    }

    private fun isListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            ?: return false
        val me = ComponentName(this, NotificationCaptureService::class.java)
        return flat.split(":").any { ComponentName.unflattenFromString(it) == me }
    }
}
