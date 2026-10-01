import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeevandhara2/models/weather_data.dart';
import 'package:jeevandhara2/services/weather_service.dart';

const _suggestionsJson = '''
[
  {"name": "Bengaluru", "region": "Karnataka", "country": "India", "lat": 12.97, "lon": 77.59},
  {"name": "Dharwad", "region": "Karnataka", "country": "India", "lat": 15.46, "lon": 75.01}
]
''';

const _weatherJson = '''
{
  "location": {"name": "Dharwad", "region": "Karnataka", "country": "India", "localtime": "2026-09-24 10:00"},
  "current": {
    "temp_c": 27.4, "feelslike_c": 29.1, "humidity": 58, "wind_kph": 12.6,
    "wind_dir": "WSW", "precip_mm": 1.2, "uv": 6.1, "is_day": 1,
    "condition": {"text": "Partly cloudy", "icon": "//cdn.weatherapi.com/weather/64x64/day/116.png"},
    "last_updated": "2026-09-24 10:00"
  },
  "astro": {"sunrise": "06:12 AM", "sunset": "06:25 PM"},
  "hourly": [
    {"time": "2026-09-24 11:00", "temp_c": 28.6, "chance_of_rain": 20, "condition": {"text": "Partly cloudy"}},
    {"time": "2026-09-24 12:00", "temp_c": 29.4, "chance_of_rain": 30, "condition": {"text": "Light drizzle"}}
  ],
  "daily": [
    {"date": "2026-09-24", "max_temp_c": 31.5, "min_temp_c": 21.2, "chance_of_rain": 65, "uv": 6.1,
     "condition": {"text": "Moderate rain"}},
    {"date": "2026-09-25", "max_temp_c": 30.1, "min_temp_c": 20.5, "chance_of_rain": 40, "uv": 5.9,
     "condition": {"text": "Patchy rain"}}
  ],
  "alerts": [
    {"headline": "Moderate rain expected", "severity": "Moderate", "instruction": "Carry rain gear.",
     "event": "Rain", "effective": "2026-09-24 09:00", "expires": "2026-09-24 18:00"}
  ],
  "source": "weatherapi"
}
''';

void main() {
  group('parseSuggestions', () {
    test('maps provider search results to suggestions with display label', () {
      final list = parseSuggestions(_suggestionsJson);
      expect(list, hasLength(2));
      expect(list.first.label, 'Bengaluru, Karnataka, India');
      expect(list.first.lat, closeTo(12.97, 0.001));
      expect(list.last.lon, closeTo(75.01, 0.001));
    });

    test('non-list bodies produce an empty list', () {
      expect(parseSuggestions('{"error": "oops"}'), isEmpty);
      expect(parseSuggestions('null'), isEmpty);
    });
  });

  group('parseWeatherData', () {
    final data = parseWeatherData(_weatherJson);

    test('maps location and current conditions', () {
      expect(data.name, 'Dharwad');
      expect(data.region, 'Karnataka');
      expect(data.tempC, closeTo(27.4, 0.001));
      expect(data.feelsLikeC, closeTo(29.1, 0.001));
      expect(data.humidity, 58);
      expect(data.windKph, closeTo(12.6, 0.001));
      expect(data.windDir, 'WSW');
      expect(data.uv, closeTo(6.1, 0.001));
      expect(data.isDay, isTrue);
    });

    test('condition exposes normalized https icon', () {
      expect(data.condition.httpsIcon, startsWith('https://'));
      expect(data.condition.materialIcon, isNotNull);
    });

    test('maps astro and forecast sections', () {
      expect(data.sunrise, '06:12 AM');
      expect(data.sunset, '06:25 PM');
      expect(data.hourly, hasLength(2));
      expect(data.daily, hasLength(2));
      expect(data.hourly.first.chanceOfRain, 20);
      expect(data.daily.first.maxTempC, closeTo(31.5, 0.001));
    });

    test('exposes today rain chance from the first daily entry', () {
      expect(data.todayRainChance, 65);
    });

    test('maps alerts', () {
      expect(data.alerts, hasLength(1));
      expect(data.alerts.first.severity, 'Moderate');
    });

    test('lenient on missing sections', () {
      final empty = WeatherData.fromJson(const {
        'location': {'name': 'X'},
        'current': {'is_day': 0},
      });
      expect(empty.daily, isEmpty);
      expect(empty.hourly, isEmpty);
      expect(empty.alerts, isEmpty);
      expect(empty.isDay, isFalse);
    });
  });

  test('suggestions JSON round-trips through toJson for persistence', () {
    final list = parseSuggestions(_suggestionsJson);
    final restored = WeatherSuggestion.fromJson(list.first.toJson());
    expect(restored.label, list.first.label);
    expect(restored.lat, list.first.lat);
  });

  test('parse functions reject invalid JSON by throwing FormatException', () {
    expect(() => parseSuggestions('not json'), throwsFormatException);
  });

  group('jsonEncode helpers are stable', () {
    test('decodes without lossy coercion', () {
      final decoded = jsonDecode(_weatherJson) as Map<String, dynamic>;
      expect(decoded['current']['temp_c'], isA<num>());
    });
  });
}
