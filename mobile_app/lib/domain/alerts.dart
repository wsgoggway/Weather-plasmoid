/// Предупреждения о резких изменениях — аналог фишки Яндекс Погоды,
/// вычисляется эвристикой из уже загруженных данных (без доп. API):
/// перепад t° ≥ 8° за сутки, гроза сегодня, ветер ≥ 15 м/с.
library;

class WeatherAlert {
  final String icon;
  final String text;
  const WeatherAlert(this.icon, this.text);
}

/// Нормализация скорости ветра из единицы API-запроса в м/с
/// (те же коэффициенты, что в виджете, main.qml:562-565).
double windToMs(num value, String unit) {
  switch (unit) {
    case "kmh":
      return value / 3.6;
    case "mph":
      return value * 0.44704;
    case "kn":
      return value * 0.514444;
    default:
      return value.toDouble(); // ms
  }
}

/// [todayMax]/[tomorrowMax] — дневные максимумы, [todayWmo] — код погоды
/// сегодня, [todayWindMax] — максимум ветра за день в единице [windUnit].
List<WeatherAlert> computeAlerts({
  double? todayMax,
  double? tomorrowMax,
  int? todayWmo,
  double? todayWindMax,
  String windUnit = "ms",
}) {
  final alerts = <WeatherAlert>[];
  if (todayMax != null && tomorrowMax != null) {
    final diff = tomorrowMax - todayMax;
    if (diff <= -8) {
      alerts.add(
        const WeatherAlert(
          "📉",
          "Резкое похолодание завтра: заметно холоднее, чем сегодня",
        ),
      );
    } else if (diff >= 8) {
      alerts.add(
        const WeatherAlert(
          "📈",
          "Резкое потепление завтра: заметно теплее, чем сегодня",
        ),
      );
    }
  }
  if (todayWmo != null && todayWmo >= 95) {
    alerts.add(
      const WeatherAlert("⛈️", "Гроза сегодня — осторожнее на открытых местах"),
    );
  }
  if (todayWindMax != null) {
    final ms = windToMs(todayWindMax, windUnit);
    if (ms >= 15) {
      alerts.add(
        WeatherAlert("💨", "Сильный ветер: до ${ms.round()} м/с — шапку держи"),
      );
    }
  }
  return alerts;
}
