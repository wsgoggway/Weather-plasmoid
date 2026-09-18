/// Избранные города: сохранение в shared_preferences, активный город.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedPlace {
  final String name;
  final double lat;
  final double lon;

  const SavedPlace({required this.name, required this.lat, required this.lon});

  String get id => "${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}";

  Map<String, dynamic> toJson() => {"name": name, "lat": lat, "lon": lon};

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
    name: json["name"] as String? ?? "",
    lat: (json["lat"] as num?)?.toDouble() ?? 0,
    lon: (json["lon"] as num?)?.toDouble() ?? 0,
  );
}

class CitiesStore extends ChangeNotifier {
  CitiesStore(this._prefs);

  static const _kPlaces = "places";
  static const _kActive = "activePlaceId";
  static const String _defaultPlaceId = "55.7558,37.6173";
  static const String _defaultPlaceName = "Москва";

  final SharedPreferences _prefs;

  List<SavedPlace> _places = const [];
  String _activeId = _defaultPlaceId;

  List<SavedPlace> get places => List.unmodifiable(_places);
  String get activeId => _activeId;

  SavedPlace get active =>
      _places.where((p) => p.id == _activeId).firstOrNull ??
      _places.firstOrNull ??
      SavedPlace(name: _defaultPlaceName, lat: 55.7558, lon: 37.6173);

  Future<void> load() async {
    final raw = _prefs.getString(_kPlaces);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => SavedPlace.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) _places = list;
      } catch (_) {
        // битый JSON — откатываемся к дефолту ниже
      }
    }
    if (_places.isEmpty) {
      _places = const [
        SavedPlace(name: _defaultPlaceName, lat: 55.7558, lon: 37.6173),
      ];
    }
    _activeId = _prefs.getString(_kActive) ?? _places.first.id;
    if (!_places.any((p) => p.id == _activeId)) {
      _activeId = _places.first.id;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _kPlaces,
      jsonEncode(_places.map((p) => p.toJson()).toList()),
    );
    await _prefs.setString(_kActive, _activeId);
  }

  /// Добавляет город и делает его активным. Дубликат по координатам
  /// просто активируется.
  Future<void> addAndActivate(SavedPlace place) async {
    final existing = _places.indexWhere((p) => p.id == place.id);
    if (existing >= 0) {
      _activeId = _places[existing].id;
    } else {
      _places = [..._places, place];
      _activeId = place.id;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> activate(String id) async {
    if (!_places.any((p) => p.id == id)) return;
    _activeId = id;
    await _persist();
    notifyListeners();
  }

  /// Удаляет город; если удалили активный — активирует первый оставшийся.
  Future<void> remove(String id) async {
    if (_places.length <= 1) return;
    _places = _places.where((p) => p.id != id).toList();
    if (_activeId == id) _activeId = _places.first.id;
    await _persist();
    notifyListeners();
  }
}
