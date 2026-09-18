package com.github.vladimirm.openmeteo_weather

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Домашний виджет с погодой. Данные пишет Dart-сторона через плагин
 * home_widget (файл prefs "HomeWidgetPreferences"); onUpdate и системные
 * периодические обновления просто перерисовывают сохранённые значения.
 * Тап по виджету открывает приложение.
 */
class WeatherWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            render(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun render(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
            val prefs =
                context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.weather_widget).apply {
                setTextViewText(R.id.widget_emoji, prefs.getString("emoji", "🌤️"))
                setTextViewText(R.id.widget_temp, prefs.getString("temp", "--°"))
                setTextViewText(R.id.widget_city, prefs.getString("city", "Погода"))
                setTextViewText(
                    R.id.widget_condition,
                    prefs.getString("condition", "Откройте приложение"),
                )
                setTextViewText(R.id.widget_details, prefs.getString("details", ""))
                setTextViewText(R.id.widget_d0_label, prefs.getString("d0_label", ""))
                setTextViewText(R.id.widget_d0, prefs.getString("d0", ""))
                setTextViewText(R.id.widget_d1_label, prefs.getString("d1_label", ""))
                setTextViewText(R.id.widget_d1, prefs.getString("d1", ""))
                setTextViewText(R.id.widget_d2_label, prefs.getString("d2_label", ""))
                setTextViewText(R.id.widget_d2, prefs.getString("d2", ""))
                setTextViewText(R.id.widget_updated, prefs.getString("updated", ""))
                setOnClickPendingIntent(R.id.widget_root, launchIntent(context))
            }
            manager.updateAppWidget(appWidgetId, views)
        }

        private fun launchIntent(context: Context): PendingIntent {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent().setClassName(context, "com.github.vladimirm.openmeteo_weather.MainActivity")
            return PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
