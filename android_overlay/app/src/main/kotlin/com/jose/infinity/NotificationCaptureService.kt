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

/**
 * Antrean sederhana (maks. 300 item) di SharedPreferences privat.
 * Item baru dihapus dari antrean hanya setelah Infinity memastikan isinya
 * sudah tersimpan (peek lalu ack), supaya tidak hilang kalau app ditutup
 * paksa di tengah proses (mis. saat update).
 */
object CaptureStore {
    private const val PREFS = "infinity_capture"
    private const val KEY = "items"
    private const val MAX = 300
    private var counter = 0L

    private fun read(ctx: Context): JSONArray {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return try {
            JSONArray(prefs.getString(KEY, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
    }

    private fun write(ctx: Context, arr: JSONArray) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, arr.toString()).commit()
    }

    private fun newQid(): String {
        counter++
        return "${System.currentTimeMillis()}_${System.nanoTime()}_$counter"
    }

    @Synchronized
    fun add(ctx: Context, item: JSONObject) {
        val arr = read(ctx)
        item.put("qid", newQid())
        arr.put(item)
        val trimmed = JSONArray()
        val start = maxOf(0, arr.length() - MAX)
        for (i in start until arr.length()) trimmed.put(arr.get(i))
        write(ctx, trimmed)
    }

    /** Lihat semua item tanpa menghapus. Item lama tanpa qid diberi qid. */
    @Synchronized
    fun peek(ctx: Context): String {
        val arr = read(ctx)
        var changed = false
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            if (!o.has("qid")) {
                o.put("qid", newQid())
                changed = true
            }
        }
        if (changed) write(ctx, arr)
        return arr.toString()
    }

    /** Hapus item yang sudah tersimpan di Infinity. */
    @Synchronized
    fun ack(ctx: Context, ids: List<String>) {
        if (ids.isEmpty()) return
        val set = ids.toHashSet()
        val arr = read(ctx)
        val kept = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i)
            if (o != null && set.contains(o.optString("qid"))) continue
            kept.put(arr.get(i))
        }
        write(ctx, kept)
    }
}
