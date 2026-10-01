import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeevandhara2/models/weather_data.dart';

/// Persists the last selected place so the weather page reopens on it.
/// Uses the project's existing storage (SharedPreferences).
class WeatherPlaceStore {
  static const _key = 'last_weather_place';

  Future<void> save(WeatherSuggestion place) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(place.toJson()));
  }

  Future<WeatherSuggestion?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return WeatherSuggestion.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
