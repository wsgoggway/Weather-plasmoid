import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:openmeteo_weather/domain/jokes.dart';

// Копия дождевого пула для проверки приоритета контекста
// (пулы намеренно приватны в библиотеке).
const _rainJokes = [
  "Дождь. Зонт сегодня не каприз, а средство выживания.",
  "Идеальная погода, чтобы остаться дома. Оправдание есть.",
  "Дождь проверяет твою веру в прогноз — и обычно проигрывает.",
  "Мокро так, что носки предают тебя в первые же минуты.",
];

void main() {
  group("температурные корзины", () {
    test("экстрим холод", () {
      expect(
        tempJokes(-35, "°C"),
        contains("На улице холоднее, чем в морге. И ветер злее."),
      );
    });
    test("жара", () {
      expect(tempJokes(35, "°C"), contains("Асфальт плавится, и ты рядом."));
    });
    test("граница: c < 0 берёт корзину нуля", () {
      final jokes = tempJokes(-0.5, "°C");
      expect(jokes, contains("Слякоть, ветер, серость — классика жанра."));
    });
    test("°F конвертируется в °C перед выбором корзины", () {
      // 13°F ≈ -10.6°C → корзина [-10): «Пуховик, шапка…»
      final jokes = tempJokes(13, "°F");
      expect(jokes, contains("Пуховик, шапка, гордость — и вперёд страдать."));
    });
  });

  test("детерминированный выбор с seeded Random", () {
    final results = List.generate(20, (_) {
      return feelsLikeJoke(
        feelsLike: 25,
        unitLabel: "°C",
        wmo: 0,
        windMs: 2,
        uv: 3,
        random: Random(1),
      );
    });
    expect(results.toSet().length, 1, reason: "один seed — одна реплика");
  });

  test("контекстные пулы приоритетнее при ~70%", () {
    var contextHits = 0;
    const runs = 2000;
    for (var i = 0; i < runs; i++) {
      final joke = feelsLikeJoke(
        feelsLike: 25,
        unitLabel: "°C",
        wmo: 63, // дождь
        windMs: 2,
        uv: 3,
        random: Random(i),
      );
      if (_rainJokes.contains(joke)) contextHits++;
    }
    // Ожидаем ~70%, допускаем 60-80%.
    expect(contextHits / runs, greaterThan(0.6));
    expect(contextHits / runs, lessThan(0.8));
  });

  test("гроза + дождь: обе группы в контексте", () {
    final joke = feelsLikeJoke(
      feelsLike: 25,
      unitLabel: "°C",
      wmo: 95,
      windMs: 2,
      uv: 3,
      random: Random(0),
    );
    expect(joke, isNotEmpty);
  });

  test("сильный ветер и высокий УФ дают свои реплики", () {
    final wind = feelsLikeJoke(
      feelsLike: 20,
      unitLabel: "°C",
      wmo: 0,
      windMs: 12,
      uv: 1,
      random: Random(3),
    );
    expect(wind, isNotEmpty);
    final uv = feelsLikeJoke(
      feelsLike: 30,
      unitLabel: "°C",
      wmo: 0,
      windMs: 2,
      uv: 8,
      random: Random(4),
    );
    expect(uv, isNotEmpty);
  });
}
