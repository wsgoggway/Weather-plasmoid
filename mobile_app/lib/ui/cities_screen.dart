/// Экран «Города»: избранные списком + поиск по Open-Meteo geocoding + GPS.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/cities_store.dart';
import '../data/location_service.dart';
import '../data/open_meteo_api.dart';
import 'background/weather_background.dart';
import 'widgets/glass_card.dart';

class CitiesScreen extends StatefulWidget {
  final CitiesStore cities;
  final OpenMeteoApi api;

  const CitiesScreen({super.key, required this.cities, required this.api});

  @override
  State<CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends State<CitiesScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<GeocodeResult> _results = const [];
  bool _searching = false;
  bool _locating = false;
  String? _searchError;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _searching = true;
        _searchError = null;
      });
      final results = await widget.api.geocode(query);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _results = results;
        if (results.isEmpty) _searchError = "Ничего не найдено";
      });
    });
  }

  Future<void> _addResult(GeocodeResult r) async {
    await widget.cities.addAndActivate(
      SavedPlace(name: r.name, lat: r.lat, lon: r.lon),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _locateByGps() async {
    setState(() => _locating = true);
    try {
      final place = await LocationService().currentPlace();
      await widget.cities.addAndActivate(place);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Scaffold(
      body: Stack(
        children: [
          const WeatherBackground(kind: WeatherKind.cloudy, animate: false),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      BackButton(color: glass.textPrimary),
                      Expanded(
                        child: Text(
                          "Города",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: glass.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: "Определить по GPS",
                        onPressed: _locating ? null : _locateByGps,
                        icon: _locating
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: glass.accent,
                                ),
                              )
                            : const Icon(Icons.my_location_outlined),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: _onQueryChanged,
                    style: TextStyle(color: glass.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Поиск города…",
                      prefixIcon: Icon(
                        Icons.search,
                        color: glass.textSecondary,
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.close,
                                color: glass.textSecondary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onQueryChanged("");
                              },
                            ),
                      filled: true,
                      fillColor: glass.card,
                    ),
                  ),
                ),
                Expanded(child: _buildList(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final glass = context.glass;
    final query = _searchController.text.trim();

    // Режим поиска: результаты geocoding.
    if (query.length >= 2) {
      if (_searching) {
        return Center(child: CircularProgressIndicator(color: glass.accent));
      }
      if (_searchError != null) {
        return Center(
          child: Text(
            _searchError!,
            style: TextStyle(color: glass.textSecondary),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: _results.length,
        itemBuilder: (context, i) {
          final r = _results[i];
          return GlassCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: InkWell(
              onTap: () => _addResult(r),
              child: Row(
                children: [
                  const Text("📍", style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: TextStyle(
                            fontSize: 15,
                            color: glass.textPrimary,
                          ),
                        ),
                        if (r.subtitle.isNotEmpty)
                          Text(
                            r.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: glass.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.add, color: glass.accent),
                ],
              ),
            ),
          );
        },
      );
    }

    // Обычный режим: избранные города.
    final places = widget.cities.places;
    final activeId = widget.cities.activeId;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: places.length,
      itemBuilder: (context, i) {
        final p = places[i];
        final isActive = p.id == activeId;
        return Dismissible(
          key: ValueKey(p.id),
          direction: places.length > 1
              ? DismissDirection.endToStart
              : DismissDirection.none,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: glass.danger.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.delete_outline, color: glass.danger),
          ),
          onDismissed: (_) => widget.cities.remove(p.id),
          child: GlassCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.zero,
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Text(
                isActive ? "🌤️" : "🏙",
                style: const TextStyle(fontSize: 18),
              ),
              title: Text(
                p.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: glass.textPrimary,
                ),
              ),
              subtitle: Text(
                "${p.lat.toStringAsFixed(2)}, ${p.lon.toStringAsFixed(2)}",
                style: TextStyle(fontSize: 12, color: glass.textSecondary),
              ),
              trailing: isActive
                  ? Icon(Icons.check_circle, color: glass.accent, size: 20)
                  : null,
              onTap: () async {
                await widget.cities.activate(p.id);
                if (mounted) Navigator.of(this.context).pop();
              },
            ),
          ),
        );
      },
    );
  }
}
