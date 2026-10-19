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
 * Widget 2x2 (v5.0): cincin dengan maskot dan sisa jatah hari ini.
 * Ketuk untuk membuka Infinity.
 */
class InfinityMiniWidgetProvider : HomeWidgetProvider() {

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
            val views = RemoteViews(context.packageName, R.layout.infinity_widget_mini).apply {
                setImageViewBitmap(R.id.wm_ring, WidgetArt.ring(context, mood, ring, 256, theme, skin, skinPath))
                setTextViewText(R.id.wm_safe, widgetData.getString("w_safe", null) ?: "Buka Infinity")
                setTextViewText(R.id.wm_label, widgetData.getString("w_safe_label", null) ?: "Aman dibelanjakan")
                setInt(R.id.wm_root, "setBackgroundResource", theme.bg)
                setTextColor(R.id.wm_safe, theme.fg)
                setTextColor(R.id.wm_label, theme.fg2)
                setOnClickPendingIntent(R.id.wm_root, launch(context, "infinity://open"))
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
    ): RemoteViews = RemoteViews(context.packageName, R.layout.infinity_widget_mini_clean).apply {
        setTextViewText(R.id.cm_label, d.getString("w_safe_label", null) ?: "Aman dibelanjakan")
        setTextViewText(R.id.cm_safe, d.getString("w_safe", null) ?: "Buka Infinity")
        setTextViewText(R.id.cm_days, d.getString("w_days", null) ?: "")
        setTextViewText(R.id.cm_balance, d.getString("w_balance", null) ?: "")
        val over = mood == "over"
        setViewVisibility(R.id.cm_bar, if (over) View.GONE else View.VISIBLE)
        setViewVisibility(R.id.cm_bar_over, if (over) View.VISIBLE else View.GONE)
        setProgressBar(if (over) R.id.cm_bar_over else R.id.cm_bar, 100, if (over) 100 else ring.coerceIn(0, 100), false)
        setOnClickPendingIntent(R.id.cm_root, launch(context, "infinity://open"))
    }

    private fun launch(context: Context, uri: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))
}
