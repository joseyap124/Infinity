package com.jose.infinity

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget 4x2 ala Money Manager: saldo, bulan ini, sisa anggaran,
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
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.infinity_widget).apply {
                setTextViewText(R.id.w_month, widgetData.getString("w_month", null) ?: "")
                setTextViewText(R.id.w_balance, widgetData.getString("w_balance", null) ?: "Buka Infinity")
                setTextViewText(R.id.w_income, widgetData.getString("w_income", null) ?: "Masuk -")
                setTextViewText(R.id.w_expense, widgetData.getString("w_expense", null) ?: "Keluar -")
                setTextViewText(R.id.w_budget, widgetData.getString("w_budget", null) ?: "")

                setOnClickPendingIntent(R.id.w_root, launch(context, "infinity://open"))
                setOnClickPendingIntent(R.id.w_btn_expense, launch(context, "infinity://add?type=expense"))
                setOnClickPendingIntent(R.id.w_btn_income, launch(context, "infinity://add?type=income"))
                setOnClickPendingIntent(R.id.w_btn_transfer, launch(context, "infinity://add?type=transfer"))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun launch(context: Context, uri: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))
}
