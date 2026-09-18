import 'package:flutter_test/flutter_test.dart';
import 'package:openmeteo_weather/data/cities_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(CitiesStore, SharedPreferences)> makeStore({
  Map<String, Object> init = const {},
}) async {
  SharedPreferences.setMockInitialValues(init);
  final prefs = await SharedPreferences.getInstance();
  final store = CitiesStore(prefs);
  await store.load();
  return (store, prefs);
}

void main() {
  test("по умолчанию — Москва, активная", () async {
    final (store, _) = await makeStore();
    expect(store.places, hasLength(1));
    expect(store.active.name, "Москва");
    expect(store.active.lat, 55.7558);
    expect(store.active.lon, 37.6173);
  });

  test("добавление города делает его активным", () async {
    final (store, _) = await makeStore();
    await store.addAndActivate(
      const SavedPlace(name: "Тверь", lat: 56.85, lon: 35.91),
    );
    expect(store.places, hasLength(2));
    expect(store.active.name, "Тверь");
  });

  test("дубликат по координатам не дублируется, только активируется", () async {
    final (store, _) = await makeStore();
    await store.addAndActivate(
      const SavedPlace(name: "Тверь", lat: 56.85, lon: 35.91),
    );
    await store.addAndActivate(
      const SavedPlace(
        name: "Тверь (другое имя)",
        lat: 56.85004,
        lon: 35.91004,
      ),
    );
    // id совпал (4 знака) → второй элемент не добавлен, активирован первый.
    expect(store.places, hasLength(2));
    expect(store.active.name, "Тверь");
  });

  test("удаление активного города активирует первый оставшийся", () async {
    final (store, _) = await makeStore();
    await store.addAndActivate(
      const SavedPlace(name: "Тверь", lat: 56.85, lon: 35.91),
    );
    await store.remove(store.activeId);
    expect(store.places, hasLength(1));
    expect(store.active.name, "Москва");
  });

  test("последний город удалить нельзя", () async {
    final (store, _) = await makeStore();
    await store.remove(store.activeId);
    expect(store.places, hasLength(1));
  });

  test("состояние переживает перезагрузку (persist в prefs)", () async {
    final (store, _) = await makeStore();
    await store.addAndActivate(
      const SavedPlace(name: "Тверь", lat: 56.85, lon: 35.91),
    );

    // Новый стор над тем же хранилищем восстанавливает список и активный город.
    final prefs2 = await SharedPreferences.getInstance();
    final store2 = CitiesStore(prefs2);
    await store2.load();
    expect(store2.places.map((p) => p.name), contains("Тверь"));
    expect(store2.active.name, "Тверь");
  });
}
