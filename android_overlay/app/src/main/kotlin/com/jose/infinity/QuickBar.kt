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
    private const val CHANNEL = "infinity_quickbar"
    private const val ID = 900001

    fun show(context: Context) {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            val ch = NotificationChannel(CHANNEL, "Pintasan Infinity", NotificationManager.IMPORTANCE_LOW)
            ch.description = "Tombol catat cepat di panel notifikasi"
            ch.setShowBadge(false)
            nm.createNotificationChannel(ch)
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
            .setPriority(NotificationCompat.PRIORITY_LOW)
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
