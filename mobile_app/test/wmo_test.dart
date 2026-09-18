import 'package:flutter_test/flutter_test.dart';
import 'package:openmeteo_weather/domain/wmo.dart';

void main() {
  group("wmoInfo — карта WMO → эмодзи/текст (перенос из виджета)", () {
    test("известные коды", () {
      expect(wmoInfo(0).emoji, "☀️");
      expect(wmoInfo(0).text, "Ясно");
      expect(wmoInfo(2).text, "Перем. облачность");
      expect(wmoInfo(45).text, "Туман");
      expect(wmoInfo(63).text, "Дождь");
      expect(wmoInfo(75).emoji, "❄️");
      expect(wmoInfo(95).text, "Гроза");
      expect(wmoInfo(99).text, "Сильная гроза");
    });

    test("неизвестный код → 🌈", () {
      final info = wmoInfo(42);
      expect(info.emoji, "🌈");
      expect(info.text, "Неизвестно");
    });

    test("все 28 кодов виджета покрыты", () {
      const codes = [
        0,
        1,
        2,
        3,
        45,
        48,
        51,
        53,
        55,
        56,
        57,
        61,
        63,
        65,
        66,
        67,
        71,
        73,
        75,
        77,
        80,
        81,
        82,
        85,
        86,
        95,
        96,
        99,
      ];
      for (final c in codes) {
        expect(wmoInfo(c).text, isNot("Неизвестно"), reason: "код $c");
      }
    });
  });

  test("ночью ясно → 🌙", () {
    expect(isClearNight(0, 0), isTrue);
    expect(isClearNight(1, 0), isTrue);
    expect(isClearNight(0, 1), isFalse);
    expect(isClearNight(3, 0), isFalse);
  });

  test("румбы: 16 направлений", () {
    expect(windDegToCompass(0), "С");
    expect(windDegToCompass(90), "В");
    expect(windDegToCompass(180), "Ю");
    expect(windDegToCompass(270), "З");
    expect(windDegToCompass(315), "СЗ");
    expect(windDegToCompass(359), "С");
  });

  test("метки AQI и уровни", () {
    expect(aqiInfo(15).text, "15 · Отличное");
    expect(aqiInfo(15).level, 0);
    expect(aqiInfo(39).text, "39 · Хорошее");
    expect(aqiInfo(45).text, "45 · Среднее"); // <60 — Среднее
    expect(aqiInfo(50).level, 1);
    expect(aqiInfo(90).text, "90 · Очень плохое");
    expect(aqiInfo(90).level, 2);
    expect(aqiInfo(120).text, "120 · Крайне плохое");
  });

  test("метки УФ", () {
    expect(uvText(1), "1 · низкий");
    expect(uvText(4), "4 · умер.");
    expect(uvText(7), "7 · высокий");
    expect(uvText(9), "9 · оч. высок.");
    expect(uvText(12), "12 · экстрим");
  });

  test("isoToHM", () {
    expect(isoToHM("2026-09-18T06:38"), "06:38");
    expect(isoToHM(""), "--:--");
    expect(isoToHM("мусор"), "--:--");
  });

  test("dayLabel: Сегодня + дни недели (Сакамото)", () {
    expect(dayLabel("2026-09-18", 0), "Сегодня");
    // 2026-09-19 — суббота.
    expect(dayLabel("2026-09-19", 1), "Сб");
    // 2026-09-20 — воскресенье.
    expect(dayLabel("2026-09-20", 2), "Вс");
    // 2026-01-01 — четверг.
    expect(dayLabel("2026-01-01", 5), "Чт");
  });
}
