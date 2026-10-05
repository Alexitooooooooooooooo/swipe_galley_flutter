package com.example.swipeflutter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DailyWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val goal = widgetData.getInt("dgo_goal", 10)
            val storedDate = widgetData.getString("dgo_date", "")
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val done = if (storedDate == today) widgetData.getInt("dgo_done", 0) else 0
            val reached = goal > 0 && done >= goal
            val progress = if (goal <= 0) 0 else (done * 100 / goal).coerceIn(0, 100)

            val assetId = widgetData.getString("dgo_image_id", null)
            val uri = if (assetId != null) {
                Uri.parse("swipegallery://start?asset=$assetId")
            } else {
                Uri.parse("swipegallery://start")
            }
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                uri,
            )

            val views = RemoteViews(context.packageName, R.layout.daily_widget_layout).apply {
                setTextViewText(
                    R.id.widget_text,
                    if (reached) "Meta del día cumplida" else "Revisa $goal fotos hoy",
                )
                setTextViewText(R.id.widget_count, "$done/$goal")
                setProgressBar(R.id.widget_progress, 100, progress, false)
                setOnClickPendingIntent(R.id.widget_container, launchIntent)
                setOnClickPendingIntent(R.id.widget_button, launchIntent)

                // Foto al frente (si la app guardó una). Si no, placeholder.
                val imagePath = widgetData.getString("dgo_image", null)
                val bitmap = imagePath?.let { BitmapFactory.decodeFile(it) }
                if (bitmap != null) {
                    setImageViewBitmap(R.id.widget_img, bitmap)
                } else {
                    setImageViewResource(R.id.widget_img, R.drawable.widget_placeholder)
                }
                setViewVisibility(R.id.widget_img, View.VISIBLE)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
