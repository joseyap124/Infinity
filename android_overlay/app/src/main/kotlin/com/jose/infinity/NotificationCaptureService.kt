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

    /**
     * Sebagian HP (Oppo/Realme/Vivo, dan setelah update app) memutus layanan
     * ini tanpa memberi tahu. Minta Android menyambungkannya lagi.
     */
    override fun onListenerConnected() {
        super.onListenerConnected()
        connected = true
        CaptureStore.markConnected(this)
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        connected = false
        rebind(this)
    }

    companion object {
        /** True selama Android menyambungkan layanan ini (per proses). */
        @Volatile
        var connected = false

        fun rebind(ctx: Context) {
            try {
                if (android.os.Build.VERSION.SDK_INT >= 24) {
                    NotificationListenerService.requestRebind(
                        android.content.ComponentName(ctx, NotificationCaptureService::class.java)
                    )
                }
            } catch (_: Exception) {
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        CaptureStore.markSeen(this, sbn.packageName)
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
        CaptureStore.markMoney(this, sbn.packageName)
        try {
            CaptureAlert.show(this, item)
        } catch (_: Exception) {
        }
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
    private const val KEY_DECISIONS = "decisions"
    private const val KEY_CONFIG = "config"
    private const val MAX = 300
    private var counter = 0L

    /** True selama layar Infinity terbuka. Saat itu app sendiri yang menampilkan notifikasinya. */
    @Volatile
    var appForeground = false

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

    // ---- Kesehatan layanan: kapan tersambung, dan notifikasi terakhir yang diterima ----

    private var lastSeenWrite = 0L

    fun markConnected(ctx: Context) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putLong("connectedAt", System.currentTimeMillis()).apply()
    }

    /** Dicatat paling sering sekali per 3 detik supaya tidak membebani penyimpanan. */
    fun markSeen(ctx: Context, pkg: String) {
        val now = System.currentTimeMillis()
        if (now - lastSeenWrite < 3000) return
        lastSeenWrite = now
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putLong("lastSeen", now).putString("lastSeenPkg", pkg).apply()
    }

    fun markMoney(ctx: Context, pkg: String) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putLong("lastMoney", System.currentTimeMillis()).putString("lastMoneyPkg", pkg).apply()
    }

    fun health(ctx: Context): String {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return JSONObject()
            .put("connected", NotificationCaptureService.connected)
            .put("connectedAt", p.getLong("connectedAt", 0L))
            .put("lastSeen", p.getLong("lastSeen", 0L))
            .put("lastSeenPkg", p.getString("lastSeenPkg", "") ?: "")
            .put("lastMoney", p.getLong("lastMoney", 0L))
            .put("lastMoneyPkg", p.getString("lastMoneyPkg", "") ?: "")
            .toString()
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

    // ---- Keputusan dari tombol notifikasi (Keluar / Masuk / Abaikan) ----
    // Data Infinity terenkripsi dan hanya bisa ditulis oleh Dart, jadi tombol
    // hanya mencatat pilihan di sini. Dart menerapkannya saat app dibuka.

    private fun readDecisions(ctx: Context): JSONArray {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return try {
            JSONArray(prefs.getString(KEY_DECISIONS, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
    }

    private fun writeDecisions(ctx: Context, arr: JSONArray) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_DECISIONS, arr.toString()).commit()
    }

    /**
     * Pindahkan item [qid] dari antrean notifikasi ke antrean keputusan.
     * Mengembalikan item (dengan "decision") atau null kalau item sudah
     * diambil Infinity lebih dulu.
     */
    @Synchronized
    fun decide(ctx: Context, qid: String, decision: String): JSONObject? {
        val arr = read(ctx)
        var found: JSONObject? = null
        val kept = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i)
            if (found == null && o != null && o.optString("qid") == qid) {
                found = o
                continue
            }
            kept.put(arr.get(i))
        }
        val item = found ?: return null
        item.put("decision", decision)
        val dec = readDecisions(ctx)
        dec.put(item)
        val trimmed = JSONArray()
        val start = maxOf(0, dec.length() - MAX)
        for (i in start until dec.length()) trimmed.put(dec.get(i))
        // Tulis keputusan dulu, baru hapus dari antrean, supaya tidak hilang.
        writeDecisions(ctx, trimmed)
        write(ctx, kept)
        return item
    }

    @Synchronized
    fun peekDecisions(ctx: Context): String = readDecisions(ctx).toString()

    @Synchronized
    fun ackDecisions(ctx: Context, ids: List<String>) {
        if (ids.isEmpty()) return
        val set = ids.toHashSet()
        val arr = readDecisions(ctx)
        val kept = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i)
            if (o != null && set.contains(o.optString("qid"))) continue
            kept.put(arr.get(i))
        }
        writeDecisions(ctx, kept)
    }

    // ---- Pengaturan dari Dart (mode, daftar app, teks terjemahan) ----

    fun setConfig(ctx: Context, json: String) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_CONFIG, json).commit()
    }

    fun config(ctx: Context): JSONObject {
        val s = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_CONFIG, null)
        return try {
            if (s == null) JSONObject() else JSONObject(s)
        } catch (e: Exception) {
            JSONObject()
        }
    }
}
