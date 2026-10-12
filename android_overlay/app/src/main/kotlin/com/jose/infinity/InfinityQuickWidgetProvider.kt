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
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.infinity_widget_small).apply {
                setImageViewBitmap(R.id.ws_ring, WidgetArt.ring(context, mood, ring, 160))
                setTextViewText(R.id.ws_label, widgetData.getString("w_safe_label", null) ?: "Aman dibelanjakan")
                setTextViewText(R.id.ws_safe, widgetData.getString("w_safe", null) ?: "Buka Infinity")
                setOnClickPendingIntent(R.id.ws_root, launch(context, "infinity://open"))
                setOnClickPendingIntent(R.id.ws_btn, launch(context, "infinity://add?type=expense"))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun launch(context: Context, uri: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))
}
