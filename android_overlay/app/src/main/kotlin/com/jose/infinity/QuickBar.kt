package com.jose.infinity

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Notifikasi menetap berisi 4 ikon (Riwayat, Cari, Template, Tambah),
 * mirip pintasan Money Manager. Tombol membuka app lewat URI infinity://
 * yang ditangani main.dart (sama seperti tombol widget).
 */
object QuickBar {
    // v2: kepentingan DEFAULT (tanpa suara) supaya tidak masuk lipatan
    // "notifikasi senyap" di HP seperti Huawei/Honor/Xiaomi.
    private const val CHANNEL = "infinity_quickbar_v2"
    private const val OLD_CHANNEL = "infinity_quickbar"
    private const val PREFS = "infinity_quickbar"
    private const val ID = 900001

    /** Ingat pilihan user supaya pintasan muncul lagi setelah HP restart. */
    fun setEnabled(context: Context, on: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("on", on).apply()
    }

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("on", false)

    fun show(context: Context) {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            if (nm.getNotificationChannel(OLD_CHANNEL) != null) nm.deleteNotificationChannel(OLD_CHANNEL)
            if (nm.getNotificationChannel(CHANNEL) == null) {
                val ch = NotificationChannel(CHANNEL, "Pintasan Infinity", NotificationManager.IMPORTANCE_DEFAULT)
                ch.description = "Ikon Riwayat, Cari, Template, Tambah di panel notifikasi"
                ch.setShowBadge(false)
                ch.setSound(null, null)
                ch.enableVibration(false)
                ch.lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                nm.createNotificationChannel(ch)
            }
        }
        val views = RemoteViews(context.packageName, R.layout.infinity_quickbar).apply {
            setOnClickPendingIntent(R.id.qb_history, launch(context, "infinity://history"))
            setOnClickPendingIntent(R.id.qb_search, launch(context, "infinity://search"))
            setOnClickPendingIntent(R.id.qb_template, launch(context, "infinity://template"))
            setOnClickPendingIntent(R.id.qb_add, launch(context, "infinity://add?type=expense"))
        }
        val n = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_infinity)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(views)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(launch(context, "infinity://open"))
            .build()
        nm.notify(ID, n)
    }

    fun hide(context: Context) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(ID)
    }

    private fun launch(context: Context, uri: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))
}

/** Tampilkan lagi pintasan setelah HP dinyalakan ulang (kalau user mengaktifkannya). */
class QuickBarBootReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: android.content.Intent) {
        val a = intent.action ?: return
        if (a == android.content.Intent.ACTION_BOOT_COMPLETED ||
            a == android.content.Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            if (QuickBar.isEnabled(context)) QuickBar.show(context)
        }
    }
}
