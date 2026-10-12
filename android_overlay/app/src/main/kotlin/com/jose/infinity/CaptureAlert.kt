package com.jose.infinity

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONObject

/**
 * Notifikasi "Transaksi terdeteksi" dengan tombol Keluar / Masuk / Abaikan,
 * ditampilkan saat NotificationCaptureService menangkap notifikasi bank atau
 * e-wallet. Pengaturan (nyala/mati, daftar app, teks) dikirim dari Dart lewat
 * [CaptureStore.setConfig], supaya satu sumber kebenaran dan ikut bahasa app.
 */
object CaptureAlert {
    private const val CHANNEL = "infinity_capture_alert"
    const val ACTION = "com.jose.infinity.CAPTURE_DECIDE"
    private const val BASE_ID = 910000
    private const val DEDUPE_MS = 3 * 60 * 1000L

    private val amountRe = Regex("""(?i)(?:rp\.?|idr)\s?[0-9][0-9.,]*""")
    private val recent = HashMap<String, Long>()

    fun notifId(qid: String): Int = BASE_ID + (qid.hashCode() and 0x7fffffff) % 80000

    fun cancel(ctx: Context, qid: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(notifId(qid))
    }

    private fun canPost(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun ensureChannel(ctx: Context, nm: NotificationManager, name: String) {
        if (Build.VERSION.SDK_INT < 26) return
        if (nm.getNotificationChannel(CHANNEL) != null) return
        val ch = NotificationChannel(CHANNEL, name, NotificationManager.IMPORTANCE_DEFAULT)
        ch.setShowBadge(false)
        ch.lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
        nm.createNotificationChannel(ch)
    }

    private fun appLabel(ctx: Context, pkg: String): String {
        return try {
            val pm = ctx.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (_: Exception) {
            pkg.substringAfterLast('.')
        }
    }

    private fun decisionIntent(ctx: Context, qid: String, decision: String, id: Int, n: Int): PendingIntent {
        val i = Intent(ctx, CaptureActionReceiver::class.java)
            .setAction(ACTION)
            .setData(Uri.parse("infinity-capture://$qid/$decision"))
            .putExtra("qid", qid)
            .putExtra("decision", decision)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getBroadcast(ctx, id * 3 + n, i, flags)
    }

    fun show(ctx: Context, item: JSONObject) {
        val cfg = CaptureStore.config(ctx)
        if (!cfg.optBoolean("on", false)) return
        // Saat app terbuka, Dart sendiri yang membaca antreannya tiap 20 detik.
        if (CaptureStore.appForeground) return
        if (!canPost(ctx)) return

        val qid = item.optString("qid")
        val pkg = item.optString("pkg")
        val title = item.optString("title")
        val text = item.optString("text")
        if (qid.isEmpty()) return
        val all = "$title\n$text"
        val lower = all.lowercase()

        // Hanya aplikasi keuangan yang dikenali Infinity, bukan semua app yang menyebut "Rp".
        val pkgs = cfg.optJSONArray("pkgs")
        var known = false
        val lp = pkg.lowercase()
        if (pkgs != null) {
            for (i in 0 until pkgs.length()) {
                if (lp.contains(pkgs.optString(i).lowercase())) { known = true; break }
            }
        }
        if (!known) return
        val promo = cfg.optJSONArray("promo")
        if (promo != null) {
            for (i in 0 until promo.length()) {
                val w = promo.optString(i).lowercase()
                if (w.isNotEmpty() && lower.contains(w)) return
            }
        }
        val amount = amountRe.find(all)?.value?.trim() ?: return

        // Notifikasi yang sama sering dikirim ulang oleh app bank.
        val key = "$pkg|$title|$text"
        val now = System.currentTimeMillis()
        synchronized(recent) {
            val last = recent[key]
            if (last != null && now - last < DEDUPE_MS) return
            recent[key] = now
            if (recent.size > 50) recent.entries.removeAll { now - it.value > DEDUPE_MS }
        }

        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(ctx, nm, cfg.optString("channel", "Transaksi terdeteksi"))
        val label = appLabel(ctx, pkg)
        val id = notifId(qid)
        val body = (if (text.isNotEmpty()) text else title).take(160)
        val publicView = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_infinity)
            .setContentTitle(cfg.optString("hiddenTitle", "Transaksi terdeteksi"))
            .build()
        val b = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_infinity)
            .setContentTitle("$label · $amount")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setWhen(item.optLong("time", now))
            .setShowWhen(true)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicView)
            .setContentIntent(
                HomeWidgetLaunchIntent.getActivity(ctx, MainActivity::class.java, Uri.parse("infinity://open"))
            )
            .addAction(0, cfg.optString("out", "Keluar"), decisionIntent(ctx, qid, "expense", id, 0))
            .addAction(0, cfg.optString("inn", "Masuk"), decisionIntent(ctx, qid, "income", id, 1))
            .addAction(0, cfg.optString("ignore", "Abaikan"), decisionIntent(ctx, qid, "ignore", id, 2))
        nm.notify(id, b.build())
    }

    /** Ganti notifikasi dengan konfirmasi singkat setelah tombol ditekan. */
    fun confirm(ctx: Context, item: JSONObject, decision: String) {
        val cfg = CaptureStore.config(ctx)
        if (!canPost(ctx)) return
        val qid = item.optString("qid")
        val pkg = item.optString("pkg")
        val amount = amountRe.find("${item.optString("title")}\n${item.optString("text")}")?.value?.trim() ?: ""
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(ctx, nm, cfg.optString("channel", "Transaksi terdeteksi"))
        val head = if (decision == "income") cfg.optString("doneIn", "Pemasukan") else cfg.optString("doneOut", "Pengeluaran")
        val n = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_infinity)
            .setContentTitle("$head $amount · ${appLabel(ctx, pkg)}".trim())
            .setContentText(cfg.optString("doneNote", "Dicatat saat Infinity dibuka."))
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setTimeoutAfter(7000)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setContentIntent(
                HomeWidgetLaunchIntent.getActivity(ctx, MainActivity::class.java, Uri.parse("infinity://open"))
            )
            .build()
        nm.notify(notifId(qid), n)
    }
}

/** Menerima tombol Keluar / Masuk / Abaikan dari notifikasi. */
class CaptureActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != CaptureAlert.ACTION) return
        val qid = intent.getStringExtra("qid") ?: return
        val decision = intent.getStringExtra("decision") ?: return
        if (decision != "expense" && decision != "income" && decision != "ignore") return
        val item = CaptureStore.decide(context, qid, decision)
        if (item == null || decision == "ignore") {
            CaptureAlert.cancel(context, qid)
            return
        }
        CaptureAlert.confirm(context, item, decision)
    }
}
