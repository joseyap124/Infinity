package com.jose.infinity

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * Menangkap notifikasi dari aplikasi bank/e-wallet yang berisi nominal "Rp".
 * Berjalan oleh sistem Android walau Infinity ditutup. Hasilnya hanya
 * disimpan di HP (SharedPreferences privat) sampai dibaca main.dart.
 */
class NotificationCaptureService : NotificationListenerService() {

    private val money = Regex("""(?i)(rp\.?|idr)\s?[0-9]""")

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        val n = sbn.notification ?: return
        // Lewati ringkasan grup supaya tidak dobel.
        if ((n.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
        val extras = n.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: ""
        if (!money.containsMatchIn("$title\n$text")) return

        val item = JSONObject()
            .put("pkg", sbn.packageName)
            .put("title", title)
            .put("text", text)
            .put("time", sbn.postTime)
        CaptureStore.add(this, item)
    }
}

/** Antrean sederhana (maks. 200 item) di SharedPreferences privat. */
object CaptureStore {
    private const val PREFS = "infinity_capture"
    private const val KEY = "items"
    private const val MAX = 200

    @Synchronized
    fun add(ctx: Context, item: JSONObject) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = try {
            JSONArray(prefs.getString(KEY, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
        arr.put(item)
        val trimmed = JSONArray()
        val start = maxOf(0, arr.length() - MAX)
        for (i in start until arr.length()) trimmed.put(arr.get(i))
        prefs.edit().putString(KEY, trimmed.toString()).apply()
    }

    /** Ambil semua lalu kosongkan antrean. */
    @Synchronized
    fun drain(ctx: Context): String {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val s = prefs.getString(KEY, "[]") ?: "[]"
        prefs.edit().putString(KEY, "[]").apply()
        return s
    }
}
