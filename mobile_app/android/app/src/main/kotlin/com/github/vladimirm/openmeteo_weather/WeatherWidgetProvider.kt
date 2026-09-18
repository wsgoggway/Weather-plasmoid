package com.github.vladimirm.openmeteo_weather

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Домашний виджет «Погода» v3 — по референсу Яндекс Погоды: светлое небо
 * с тёмным текстом днём, тёмное — ночью; огромная температура с «+»,
 * иконка между температурой и состоянием, почасовая полоса на 7 колонок.

 * Данные пишет Dart-сторона через home_widget (prefs
 * "HomeWidgetPreferences"); onUpdate перерисовывает сохранённые значения.
 * Тап открывает приложение.

 * Палитра: ключ "palette" = "light" | "dark". Провайдер выбирает фон
 * и перекрашивает тексты через setTextColor.
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
        /** Тёмно-синий текст на светлом небе (как у Яндекса). */
        private val LIGHT_PRIMARY = 0xFF22344C.toInt()
        private val LIGHT_SECONDARY = 0xFF6B7F93.toInt()
        private val LIGHT_TIME = 0xFF52709A.toInt()

        /** Белый текст на тёмном ночном фоне. */
        private val DARK_PRIMARY = 0xFFFFFFFF.toInt()
        private val DARK_SECONDARY = 0xFFB2B2B2.toInt()
        private val DARK_TIME = 0xFF999999.toInt()

        fun render(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
            val prefs =
                context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val dark = prefs.getString("palette", "light") == "dark"
            val primary = if (dark) DARK_PRIMARY else LIGHT_PRIMARY
            val secondary = if (dark) DARK_SECONDARY else LIGHT_SECONDARY
            val timeColor = if (dark) DARK_TIME else LIGHT_TIME

            val views = RemoteViews(context.packageName, R.layout.weather_widget).apply {
                // Фон: ночью всегда тёмный, днём — градиент под погоду.
                setInt(
                    R.id.widget_root,
                    "setBackgroundResource",
                    if (dark) R.drawable.wbg_clear_night
                    else backgroundFor(prefs.getString("theme", "clear_day")!!),
                )

                // Шапка.
                setTextViewText(R.id.widget_city, prefs.getString("city", "Погода"))
                setTextColor(R.id.widget_city, primary)

                // Герой.
                setTextViewText(R.id.widget_temp, prefs.getString("temp", "--°"))
                setTextColor(R.id.widget_temp, primary)
                setImageViewResource(
                    R.id.widget_icon,
                    iconFor(prefs.getString("icon", "cloud")!!),
                )
                setTextViewText(
                    R.id.widget_condition,
                    prefs.getString("condition", "Откройте приложение"),
                )
                setTextColor(R.id.widget_condition, primary)
                setTextViewText(R.id.widget_feels, prefs.getString("feels", ""))
                setTextColor(R.id.widget_feels, secondary)

                // Почасовая полоса: 7 колонок.
                val hourTimeIds = intArrayOf(
                    R.id.widget_h0_time, R.id.widget_h1_time, R.id.widget_h2_time,
                    R.id.widget_h3_time, R.id.widget_h4_time, R.id.widget_h5_time,
                    R.id.widget_h6_time,
                )
                val hourIconIds = intArrayOf(
                    R.id.widget_h0_icon, R.id.widget_h1_icon, R.id.widget_h2_icon,
                    R.id.widget_h3_icon, R.id.widget_h4_icon, R.id.widget_h5_icon,
                    R.id.widget_h6_icon,
                )
                val hourTempIds = intArrayOf(
                    R.id.widget_h0_temp, R.id.widget_h1_temp, R.id.widget_h2_temp,
                    R.id.widget_h3_temp, R.id.widget_h4_temp, R.id.widget_h5_temp,
                    R.id.widget_h6_temp,
                )
                for (i in hourTimeIds.indices) {
                    setTextViewText(hourTimeIds[i], prefs.getString("h${i}_time", ""))
                    setTextColor(hourTimeIds[i], timeColor)
                    setImageViewResource(
                        hourIconIds[i],
                        iconFor(prefs.getString("h${i}_icon", "cloud")!!),
                    )
                    setTextViewText(hourTempIds[i], prefs.getString("h${i}_temp", ""))
                    setTextColor(hourTempIds[i], primary)
                }

                setOnClickPendingIntent(R.id.widget_root, launchIntent(context))
            }
            manager.updateAppWidget(appWidgetId, views)
        }

        private fun backgroundFor(theme: String): Int = when (theme) {
            "clear_day" -> R.drawable.wbg_clear_day
            "partly" -> R.drawable.wbg_partly
            "cloud" -> R.drawable.wbg_cloud
            "rain" -> R.drawable.wbg_rain
            "snow" -> R.drawable.wbg_snow
            "storm" -> R.drawable.wbg_storm
            "fog" -> R.drawable.wbg_fog
            else -> R.drawable.wbg_clear_night
        }

        private fun iconFor(icon: String): Int = when (icon) {
            "sun" -> R.drawable.wi_sun
            "moon" -> R.drawable.wi_moon
            "partly" -> R.drawable.wi_partly
            "partly_night" -> R.drawable.wi_partly_night
            "rain" -> R.drawable.wi_rain
            "snow" -> R.drawable.wi_snow
            "storm" -> R.drawable.wi_storm
            "fog" -> R.drawable.wi_fog
            else -> R.drawable.wi_cloud
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
