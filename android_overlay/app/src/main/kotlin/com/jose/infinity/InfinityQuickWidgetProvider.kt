package com.jose.infinity

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget kecil 2x1: maskot kecil, sisa aman dibelanjakan hari ini, dan satu
 * tombol "+". Datanya sama dengan widget besar (dikirim dari main.dart).
 */
class InfinityQuickWidgetProvider : HomeWidgetProvider() {

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
            val views = RemoteViews(context.packageName, R.layout.infinity_widget_small).apply {
                setImageViewBitmap(R.id.ws_ring, WidgetArt.ring(context, mood, ring, 160, theme, skin, skinPath))
                setTextViewText(R.id.ws_label, widgetData.getString("w_safe_label", null) ?: "Aman dibelanjakan")
                setTextViewText(R.id.ws_safe, widgetData.getString("w_safe", null) ?: "Buka Infinity")
                setInt(R.id.ws_root, "setBackgroundResource", theme.bg)
                setTextColor(R.id.ws_label, theme.fg2)
                setTextColor(R.id.ws_safe, theme.fg)
                setOnClickPendingIntent(R.id.ws_root, launch(context, "infinity://open"))
                setOnClickPendingIntent(R.id.ws_btn, launch(context, "infinity://add?type=expense"))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /** Tampilan bersih (v5.11): tanpa maskot; warna ikut mode gelap HP. */
    private fun cleanViews(
        context: Context,
        d: SharedPreferences,
        mood: String,
        ring: Int,
    ): RemoteViews = RemoteViews(context.packageName, R.layout.infinity_widget_small_clean).apply {
        setTextViewText(R.id.cs_label, d.getString("w_safe_label", null) ?: "Aman dibelanjakan")
        setTextViewText(R.id.cs_safe, d.getString("w_safe", null) ?: "Buka Infinity")
        setOnClickPendingIntent(R.id.cs_root, launch(context, "infinity://open"))
        setOnClickPendingIntent(R.id.cs_btn, launch(context, "infinity://add?type=expense"))
    }

    private fun launch(context: Context, uri: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))
}
