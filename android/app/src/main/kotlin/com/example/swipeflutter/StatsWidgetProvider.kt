package com.example.swipeflutter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Locale

class StatsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val freed = widgetData.getInt("stg_freed", 0)
            val deleted = widgetData.getInt("stg_deleted", 0)
            val launch = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

            val views = RemoteViews(context.packageName, R.layout.stats_widget_layout).apply {
                setTextViewText(R.id.stats_freed, "${formatBytes(freed)} liberados")
                setTextViewText(
                    R.id.stats_deleted,
                    if (deleted == 1) "1 foto eliminada" else "$deleted fotos eliminadas",
                )
                setOnClickPendingIntent(R.id.stats_container, launch)
                setOnClickPendingIntent(R.id.stats_button, launch)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun formatBytes(bytes: Int): String {
        if (bytes <= 0) return "0 B"
        val units = arrayOf("B", "KB", "MB", "GB", "TB")
        var size = bytes.toDouble()
        var i = 0
        while (size >= 1024 && i < units.size - 1) {
            size /= 1024
            i++
        }
        return if (i == 0) {
            "${size.toInt()} ${units[i]}"
        } else {
            String.format(Locale.US, "%.1f %s", size, units[i])
        }
    }
}
