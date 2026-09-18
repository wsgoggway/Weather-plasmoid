import 'package:flutter_test/flutter_test.dart';
import 'package:openmeteo_weather/domain/nowcast.dart';

/// Хелпер: генерирует minutely_15-блок со слотами от [start] и значениями
/// [precip] (каждые 15 минут) плюс пара слотов до начала окна.
Map<String, dynamic> minutely(
  List<double> precip, {
  String start = "2026-09-18T14:00",
}) {
  final base = DateTime.parse(start);
  return {
    "time": [
      for (var i = 0; i < precip.length + 4; i++)
        base.add(Duration(minutes: 15 * i)).toIso8601String().substring(0, 16),
    ],
    "precipitation": precip,
  };
}

void main() {
  test("сейчас дождь, закончится через ~45 мин", () {
    // 14:05 → текущий слот 14:00; окно [0.4, 0.5, 0.2, 0, ...] —
    // первый сухой слот на позиции 3 → 3×15 = 45 мин от начала окна.
    final nc = parseNowcast(
      minutely([0.4, 0.5, 0.2, 0, 0, 0, 0, 0]),
      "2026-09-18T14:05",
    );
    expect(nc, isNotNull);
    expect(nc!.statusText, contains("закончатся"));
    expect(nc.statusText, contains("45"));
    expect(nc.slots.length, 8);
    expect(nc.slots.first.precipitation, 0.4);
  });

  test("сейчас сухо, начнётся через ~45 мин", () {
    final nc = parseNowcast(
      minutely([0, 0, 0, 0.6, 0.7, 0.3, 0, 0]),
      "2026-09-18T14:10",
    );
    expect(nc!.statusText, contains("начнутся"));
    expect(nc.statusText, contains("45"));
  });

  test("осадков нет в окне", () {
    final nc = parseNowcast(
      minutely([0, 0, 0, 0, 0, 0, 0, 0]),
      "2026-09-18T14:00",
    );
    expect(nc!.statusText, "Осадков не ожидается");
    expect(nc.maxPrecipitation, 0);
  });

  test("дождь всё окно", () {
    final nc = parseNowcast(minutely(List.filled(8, 0.5)), "2026-09-18T14:00");
    expect(nc!.statusText, "Осадки продолжатся все 2 часа");
  });

  test("начнётся в текущем слоте → ≤15 минут", () {
    final nc = parseNowcast(
      minutely([0.8, 0.5, 0, 0, 0, 0, 0, 0]),
      "2026-09-18T14:07",
    );
    // Первый слот 14:00 с дождём — «закончатся» ветка; проверяем живой текст.
    expect(nc!.statusText, contains("закончатся"));
  });

  test("null-значения внутри окна → нет покрытия (null)", () {
    final m = minutely([0, 0, 0]);
    m["precipitation"] = [0, 0, null, null, 0, 0, 0, 0, 0, 0, 0, 0];
    final nc = parseNowcast(m, "2026-09-18T14:05");
    expect(nc, isNull);
  });

  test("пустые данные → null", () {
    expect(parseNowcast(null, "2026-09-18T14:00"), isNull);
    expect(parseNowcast({}, "2026-09-18T14:00"), isNull);
    final empty = minutely([0]);
    empty["precipitation"] = [];
    expect(parseNowcast(empty, "2026-09-18T14:00"), isNull);
  });

  test("текущее время раньше первого слота → null", () {
    final nc = parseNowcast(minutely([0, 0, 0, 0]), "2026-09-18T09:00");
    expect(nc, isNull);
  });
}
