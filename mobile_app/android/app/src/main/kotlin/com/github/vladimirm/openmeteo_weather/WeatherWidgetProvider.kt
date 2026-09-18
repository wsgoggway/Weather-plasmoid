package com.github.vladimirm.openmeteo_weather

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews

/**
 * Домашний виджет «Погода» — собирательный образ виджетов Apple Weather /
 * Pixel Weather / Gismeteo: текущая погода, почасовая лента, метрики,
 * прогноз на 3 дня.

 * Данные пишет Dart-сторона через плагин home_widget (prefs
 * "HomeWidgetPreferences"); onUpdate и системные периодические обновления
 * перерисовывают сохранённые значения. Тап открывает приложение.

 * Адаптивность: при высоте >= 180dp — полный вид 4×3; меньше — часы
 * и метрики скрываются (setViewVisibility), остаётся компакт 4×2.
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

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?,
    ) {
        // Пользователь изменил размер — пересобираем видимость секций.
        render(context, appWidgetManager, appWidgetId)
    }

    companion object {
        /** Граница полного вида: ниже — компакт без часов и метрик (dp). */
        private const val LARGE_MIN_HEIGHT_DP = 180

        fun render(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
            val prefs =
                context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val large = isLarge(manager.getAppWidgetOptions(appWidgetId))
            val views = RemoteViews(context.packageName, R.layout.weather_widget).apply {
                setTextViewText(R.id.widget_emoji, prefs.getString("emoji", "🌤️"))
                setTextViewText(R.id.widget_temp, prefs.getString("temp", "--°"))
                setTextViewText(R.id.widget_city, prefs.getString("city", "Погода"))
                setTextViewText(
                    R.id.widget_condition,
                    prefs.getString("condition", "Откройте приложение"),
                )
                setTextViewText(R.id.widget_details, prefs.getString("details", ""))

                // Секции полного вида.
                val sectionVisibility =
                    if (large) android.view.View.VISIBLE else android.view.View.GONE
                setViewVisibility(R.id.widget_hourly_section, sectionVisibility)
                setViewVisibility(R.id.widget_metrics_section, sectionVisibility)
                val hourTimeIds = intArrayOf(
                    R.id.widget_h0_time, R.id.widget_h1_time, R.id.widget_h2_time,
                    R.id.widget_h3_time, R.id.widget_h4_time,
                )
                val hourEmojiIds = intArrayOf(
                    R.id.widget_h0_emoji, R.id.widget_h1_emoji, R.id.widget_h2_emoji,
                    R.id.widget_h3_emoji, R.id.widget_h4_emoji,
                )
                val hourTempIds = intArrayOf(
                    R.id.widget_h0_temp, R.id.widget_h1_temp, R.id.widget_h2_temp,
                    R.id.widget_h3_temp, R.id.widget_h4_temp,
                )
                for (i in hourTimeIds.indices) {
                    setTextViewText(hourTimeIds[i], prefs.getString("h${i}_time", ""))
                    setTextViewText(hourEmojiIds[i], prefs.getString("h${i}_emoji", ""))
                    setTextViewText(hourTempIds[i], prefs.getString("h${i}_temp", ""))
                }
                setTextViewText(R.id.widget_m_humidity, prefs.getString("m_humidity", ""))
                setTextViewText(R.id.widget_m_wind, prefs.getString("m_wind", ""))
                setTextViewText(R.id.widget_m_pressure, prefs.getString("m_pressure", ""))
                setTextViewText(R.id.widget_m_uv, prefs.getString("m_uv", ""))

                // Прогноз на 3 дня.
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

        private fun getResourceId(name: String): Int =
            R.id::class.java.getField(name).getInt(null)

        private fun isLarge(options: Bundle?): Boolean {
            val h = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
            // 0 = размер ещё не известен (только что добавили) — показываем полный.
            return h == 0 || h >= LARGE_MIN_HEIGHT_DP
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
