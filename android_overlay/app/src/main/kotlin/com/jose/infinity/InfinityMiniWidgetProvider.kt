package com.jose.infinity

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
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
        appWidgetIds.forEach { widgetId ->
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

    private fun launch(context: Context, uri: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))
}
