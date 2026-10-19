package com.jose.infinity

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget 4x2: cincin sisa jatah dengan maskot, jatah hari ini, total saldo,
 * plus tombol cepat Keluar / Masuk / Transfer.
 * Data teks dikirim dari main.dart lewat home_widget (HomeWidgetBridge).
 */
class InfinityWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val mood = widgetData.getString("w_mood", null) ?: "ok"
        val ring = (widgetData.getString("w_ring", null) ?: "0").toIntOrNull() ?: 0
        val skin = widgetData.getString("w_skin", null)
        val skinPath = widgetData.getString("w_skin_path", null)
        val theme = WidgetTheme.of(widgetData.getString("w_pack", null), skin)
        val clean = WidgetTheme.isClean(widgetData.getString("w_pack", null))
        appWidgetIds.forEach { widgetId ->
            if (clean) {
                appWidgetManager.updateAppWidget(widgetId, cleanViews(context, widgetData, mood, ring))
                return@forEach
            }
            val views = RemoteViews(context.packageName, R.layout.infinity_widget).apply {
                setImageViewBitmap(R.id.w_ring, WidgetArt.ring(context, mood, ring, 256, theme, skin, skinPath))
                setTextViewText(R.id.w_safe_label, widgetData.getString("w_safe_label", null) ?: "Aman dibelanjakan")
                setTextViewText(R.id.w_safe, widgetData.getString("w_safe", null) ?: "Buka Infinity")
                setTextViewText(R.id.w_perday, widgetData.getString("w_perday", null) ?: "")
                setTextViewText(R.id.w_balance, widgetData.getString("w_balance", null) ?: "")

                setTextViewText(R.id.w_btn_expense, widgetData.getString("w_btn_expense", null) ?: "− Keluar")
                setTextViewText(R.id.w_btn_income, widgetData.getString("w_btn_income", null) ?: "+ Masuk")
                setTextViewText(R.id.w_btn_transfer, widgetData.getString("w_btn_transfer", null) ?: "⇄ Transfer")

                setInt(R.id.w_root, "setBackgroundResource", theme.bg)
                setTextColor(R.id.w_safe_label, theme.fg2)
                setTextColor(R.id.w_safe, theme.fg)
                setTextColor(R.id.w_perday, theme.acc)
                setTextColor(R.id.w_balance, theme.fg2)

                setOnClickPendingIntent(R.id.w_root, launch(context, "infinity://open"))
                setOnClickPendingIntent(R.id.w_btn_expense, launch(context, "infinity://add?type=expense"))
                setOnClickPendingIntent(R.id.w_btn_income, launch(context, "infinity://add?type=income"))
                setOnClickPendingIntent(R.id.w_btn_transfer, launch(context, "infinity://add?type=transfer"))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /** Tampilan bersih (v5.11): tanpa maskot, bar sisa jatah; warna ikut mode gelap HP. */
    private fun cleanViews(
        context: Context,
        d: SharedPreferences,
        mood: String,
        ring: Int,
    ): RemoteViews = RemoteViews(context.packageName, R.layout.infinity_widget_clean).apply {
        setTextViewText(R.id.c_label, d.getString("w_safe_label", null) ?: "Aman dibelanjakan")
        setTextViewText(R.id.c_safe, d.getString("w_safe", null) ?: "Buka Infinity")
        setTextViewText(R.id.c_perday, d.getString("w_perday", null) ?: "")
        setTextViewText(R.id.c_balance, d.getString("w_balance", null) ?: "")
        setTextViewText(R.id.c_btn_expense, d.getString("w_btn_expense", null) ?: "− Keluar")
        setTextViewText(R.id.c_btn_income, d.getString("w_btn_income", null) ?: "+ Masuk")
        setTextViewText(R.id.c_btn_transfer, d.getString("w_btn_transfer", null) ?: "⇄ Transfer")
        val over = mood == "over"
        setViewVisibility(R.id.c_bar, if (over) View.GONE else View.VISIBLE)
        setViewVisibility(R.id.c_bar_over, if (over) View.VISIBLE else View.GONE)
        setProgressBar(if (over) R.id.c_bar_over else R.id.c_bar, 100, if (over) 100 else ring.coerceIn(0, 100), false)
        setOnClickPendingIntent(R.id.c_root, launch(context, "infinity://open"))
        setOnClickPendingIntent(R.id.c_btn_expense, launch(context, "infinity://add?type=expense"))
        setOnClickPendingIntent(R.id.c_btn_income, launch(context, "infinity://add?type=income"))
        setOnClickPendingIntent(R.id.c_btn_transfer, launch(context, "infinity://add?type=transfer"))
    }

    private fun launch(context: Context, uri: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))
}
