import 'package:flutter_test/flutter_test.dart';
import 'package:openmeteo_weather/domain/alerts.dart';

void main() {
  test("перепад −8° и больше → резкое похолодание", () {
    final alerts = computeAlerts(todayMax: 10, tomorrowMax: 2);
    expect(alerts, hasLength(1));
    expect(alerts.first.text, contains("похолодание"));
  });

  test("перепад +8° и больше → резкое потепление", () {
    final alerts = computeAlerts(todayMax: 5, tomorrowMax: 14);
    expect(alerts.first.text, contains("потепление"));
  });

  test("перепад 7° → тишина", () {
    expect(computeAlerts(todayMax: 10, tomorrowMax: 3), isEmpty);
    expect(computeAlerts(todayMax: 10, tomorrowMax: 17), isEmpty);
  });

  test("гроза сегодня", () {
    final alerts = computeAlerts(todayWmo: 95);
    expect(alerts, hasLength(1));
    expect(alerts.first.text, contains("Гроза"));
  });

  test("сильный ветер ≥15 м/с, конвертация из км/ч", () {
    final alerts = computeAlerts(todayWindMax: 60, windUnit: "kmh");
    expect(alerts, hasLength(1));
    expect(alerts.first.text, contains("17 м/с")); // 60/3.6 ≈ 16.7 → 17
  });

  test("ветер 14 м/с в м/с → тишина", () {
    expect(computeAlerts(todayWindMax: 14, windUnit: "ms"), isEmpty);
  });

  test("всё сразу — три предупреждения", () {
    final alerts = computeAlerts(
      todayMax: 20,
      tomorrowMax: 8,
      todayWmo: 99,
      todayWindMax: 60,
      windUnit: "kmh",
    );
    expect(alerts, hasLength(3));
  });

  test("windToMs: все единицы", () {
    expect(windToMs(10, "ms"), closeTo(10, 0.001));
    expect(windToMs(36, "kmh"), closeTo(10, 0.001));
    expect(windToMs(22.37, "mph"), closeTo(10, 0.01));
    expect(windToMs(19.44, "kn"), closeTo(10, 0.01));
  });
}
