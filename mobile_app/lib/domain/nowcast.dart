/// Nowcast «Осадки сейчас»: разбор minutely_15 из Open-Meteo на окно 2 часа
/// (8 слотов по 15 минут) с человеческим статусом «начнётся/закончится».
library;

/// Один 15-минутный слот: локальное время ISO и интенсивность осадков, мм.
class NowcastSlot {
  final String time;
  final double precipitation;
  const NowcastSlot(this.time, this.precipitation);
}

class Nowcast {
  final List<NowcastSlot> slots;
  final String statusText;
  const Nowcast({required this.slots, required this.statusText});

  /// Максимальная интенсивность в окне — для нормализации столбиков.
  double get maxPrecipitation =>
      slots.fold(0.0, (m, s) => s.precipitation > m ? s.precipitation : m);
}

/// [minutely] — блок minutely_15 из ответа API, [currentTimeIso] — локальное
/// время current.time того же ответа (минутная точность). Возвращает null,
/// если данных нет или покрытие не действует (вне Центральной Европы/США).
Nowcast? parseNowcast(Map<String, dynamic>? minutely, String currentTimeIso) {
  if (minutely == null) return null;
  final times = (minutely['time'] as List?)?.cast<String>() ?? const [];
  final precip = (minutely['precipitation'] as List?) ?? const [];
  if (times.isEmpty || precip.isEmpty) return null;

  // Граница текущего 15-минутного слота: последний time <= текущего момента.
  final nowPrefix = currentTimeIso.length >= 16
      ? currentTimeIso.substring(0, 16)
      : currentTimeIso;
  var idx = -1;
  for (var i = 0; i < times.length; i++) {
    if (times[i].length >= 16 &&
        times[i].substring(0, 16).compareTo(nowPrefix) <= 0) {
      idx = i;
    } else {
      break;
    }
  }
  if (idx < 0) return null;

  final slots = <NowcastSlot>[];
  for (var i = idx; i < times.length && slots.length < 8; i++) {
    final v = (precip[i] as num?)?.toDouble();
    if (v == null) return null; // null внутри окна = нет покрытия модели
    slots.add(NowcastSlot(times[i], v));
  }
  if (slots.isEmpty) return null;

  return Nowcast(slots: slots, statusText: _status(slots));
}

String _status(List<NowcastSlot> slots) {
  final rainingNow = slots.first.precipitation > 0;
  if (rainingNow) {
    final endIdx = slots.indexWhere((s) => s.precipitation <= 0);
    if (endIdx < 0) return "Осадки продолжатся все 2 часа";
    return _inMinutes("Осадки закончатся через", endIdx * 15);
  }
  final startIdx = slots.indexWhere((s) => s.precipitation > 0);
  if (startIdx < 0) return "Осадков не ожидается";
  return _inMinutes("Осадки начнутся через", startIdx * 15);
}

String _inMinutes(String prefix, int minutes) {
  if (minutes <= 0) return "$prefix ≤15 минут";
  if (minutes % 60 == 0 && minutes >= 60) return "$prefix ~${minutes ~/ 60} ч";
  if (minutes > 60) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return "$prefix ~$h ч $m мин";
  }
  return "$prefix ~$minutes мин";
}
