/// Геолокация устройства: координаты + имя города через placemark'и платформы
/// (замена «Определить по IP» из виджета — на телефоне GPS уместнее).
library;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'cities_store.dart';

class LocationService {
  /// Возвращает SavedPlace по GPS или кидает исключение с русским текстом
  /// для SnackBar.
  Future<SavedPlace> currentPlace() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        "Геолокация выключена — включите её в настройках",
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException("Доступ к геолокации отклонён");
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        "Геолокация запрещена для приложения — разрешите в настройках системы",
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 15),
      ),
    );

    String name = "Моё местоположение";
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final pm = placemarks.firstOrNull;
      if (pm != null) {
        final locality = [
          pm.locality,
          pm.subAdministrativeArea,
          pm.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty).firstOrNull;
        if (locality != null) name = locality;
      }
    } catch (_) {
      // Не получили адрес — останется «Моё местоположение».
    }

    return SavedPlace(
      name: name,
      lat: position.latitude,
      lon: position.longitude,
    );
  }
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
  @override
  String toString() => message;
}

/// Показ снека с ошибкой (для GPS/сети) — общий помощник экранов.
void showErrorSnackBar(BuildContext context, Object error) {
  final message = error is LocationException ? error.message : error.toString();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
