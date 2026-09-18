package com.github.vladimirm.openmeteo_weather

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews

/**
 * Домашний виджет «Погода» v2 — собирательный образ Apple Weather /
 * Pixel Weather: векторные иконки, фон-градиент под погоду и время суток,
 * крупная тонкая температура, цветные max/min, почасовая лента, плитки
 * метрик, прогноз на 3 дня.

 * Данные пишет Dart-сторона через home_widget (prefs
 * "HomeWidgetPreferences"); onUpdate перерисовывает сохранённые значения.
 * Тап открывает приложение.

 * Адаптивность: высота >= 180dp — полный вид 4×3; меньше — часы и метрики
 * скрываются (setViewVisibility), остаётся компакт 4×2.
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
                // Фон под погоду (Pixel style).
                setInt(
                    R.id.widget_root,
                    "setBackgroundResource",
                    backgroundFor(prefs.getString("theme", "clear_night")!!),
                )

                // Город | ↑max ↓min.
                setTextViewText(R.id.widget_city, prefs.getString("city", "Погода"))
                setTextViewText(R.id.widget_hi, prefs.getString("hi", ""))
                setTextViewText(R.id.widget_lo, prefs.getString("lo", ""))

                // Герой: иконка + температура + состояние/ощущается.
                setImageViewResource(
                    R.id.widget_icon,
                    iconFor(prefs.getString("icon", "cloud")!!),
                )
                setTextViewText(R.id.widget_temp, prefs.getString("temp", "--°"))
                setTextViewText(
                    R.id.widget_condition,
                    prefs.getString("condition", "Откройте приложение"),
                )
                setTextViewText(R.id.widget_feels, prefs.getString("feels", ""))

                // Секции полного вида.
                val sectionVisibility =
                    if (large) android.view.View.VISIBLE else android.view.View.GONE
                setViewVisibility(R.id.widget_hourly_section, sectionVisibility)
                setViewVisibility(R.id.widget_metrics_section, sectionVisibility)

                val hourTimeIds = intArrayOf(
                    R.id.widget_h0_time, R.id.widget_h1_time, R.id.widget_h2_time,
                    R.id.widget_h3_time, R.id.widget_h4_time,
                )
                val hourIconIds = intArrayOf(
                    R.id.widget_h0_icon, R.id.widget_h1_icon, R.id.widget_h2_icon,
                    R.id.widget_h3_icon, R.id.widget_h4_icon,
                )
                val hourTempIds = intArrayOf(
                    R.id.widget_h0_temp, R.id.widget_h1_temp, R.id.widget_h2_temp,
                    R.id.widget_h3_temp, R.id.widget_h4_temp,
                )
                for (i in hourTimeIds.indices) {
                    setTextViewText(hourTimeIds[i], prefs.getString("h${i}_time", ""))
                    setImageViewResource(
                        hourIconIds[i],
                        iconFor(prefs.getString("h${i}_icon", "cloud")!!),
                    )
                    setTextViewText(hourTempIds[i], prefs.getString("h${i}_temp", ""))
                }

                // Метрики: 4 плитки «значение + подпись».
                val valueIds = intArrayOf(
                    R.id.widget_mv0, R.id.widget_mv1, R.id.widget_mv2, R.id.widget_mv3,
                )
                val labelIds = intArrayOf(
                    R.id.widget_ml0, R.id.widget_ml1, R.id.widget_ml2, R.id.widget_ml3,
                )
                for (i in valueIds.indices) {
                    setTextViewText(valueIds[i], prefs.getString("mv$i", ""))
                    setTextViewText(labelIds[i], prefs.getString("ml$i", ""))
                }

                // Прогноз на 3 дня: подпись / иконка / ↑max / ↓min.
                val labelDayIds = intArrayOf(
                    R.id.widget_d0_label, R.id.widget_d1_label, R.id.widget_d2_label,
                )
                val dayIconIds = intArrayOf(
                    R.id.widget_d0_icon, R.id.widget_d1_icon, R.id.widget_d2_icon,
                )
                val dayMaxIds = intArrayOf(
                    R.id.widget_d0_max, R.id.widget_d1_max, R.id.widget_d2_max,
                )
                val dayMinIds = intArrayOf(
                    R.id.widget_d0_min, R.id.widget_d1_min, R.id.widget_d2_min,
                )
                for (i in labelDayIds.indices) {
                    setTextViewText(labelDayIds[i], prefs.getString("d${i}_label", ""))
                    setImageViewResource(
                        dayIconIds[i],
                        iconFor(prefs.getString("d${i}_icon", "cloud")!!),
                    )
                    setTextViewText(dayMaxIds[i], prefs.getString("d${i}_max", ""))
                    setTextViewText(dayMinIds[i], prefs.getString("d${i}_min", ""))
                }

                setTextViewText(R.id.widget_updated, prefs.getString("updated", ""))
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
