import 'package:flutter_test/flutter_test.dart';

import 'package:jeevandhara2/models/weather_data.dart';
import 'package:jeevandhara2/services/weather_recommendations.dart';

WeatherData _weather({
  double rain = 0,
  double wind = 0,
  double temp = 25,
  double humidity = 50,
}) {
  return WeatherData(
    name: 'Test',
    region: '',
    country: '',
    localtime: '',
    tempC: temp,
    feelsLikeC: temp,
    condition: const WeatherCondition(text: 'Sunny'),
    humidity: humidity,
    windKph: wind,
    windDir: '',
    precipMm: 0,
    uv: 5,
    isDay: true,
    sunrise: '06:00',
    sunset: '18:30',
    lastUpdated: '',
    hourly: const [],
    daily: [
      DailyForecast(
        date: DateTime.now(),
        maxTempC: temp,
        minTempC: temp - 5,
        chanceOfRain: rain.toInt(),
        condition: const WeatherCondition(text: 'Sunny'),
      ),
    ],
    alerts: const [],
  );
}

void main() {
  group('buildFarmRecommendations', () {
    test('heavy rain ≥85% emits a danger-level rain warning', () {
      final recs = buildFarmRecommendations(_weather(rain: 90));
      expect(
          recs.any((r) =>
              r.title == 'Heavy rain likely' && r.level == AdviceLevel.danger),
          isTrue);
    });

    test('rain ≥70% emits high-probability caution', () {
      final recs = buildFarmRecommendations(_weather(rain: 75));
      expect(
          recs.any((r) =>
              r.title == 'High rain probability' &&
              r.level == AdviceLevel.caution),
          isTrue);
    });

    test('rain ≥40% emits chance-of-rain caution', () {
      final recs = buildFarmRecommendations(_weather(rain: 50));
      expect(recs.any((r) => r.title == 'Chance of rain'), isTrue);
    });

    test('wind ≥32 km/h emits danger', () {
      final recs = buildFarmRecommendations(_weather(wind: 40));
      expect(
          recs.any((r) =>
              r.title == 'Very strong wind' && r.level == AdviceLevel.danger),
          isTrue);
    });

    test('wind ≥20 km/h emits caution', () {
      final recs = buildFarmRecommendations(_weather(wind: 25));
      expect(
          recs.any((r) =>
              r.title == 'Strong wind' && r.level == AdviceLevel.caution),
          isTrue);
    });

    test('temp ≥42 emits extreme-heat danger and one caution', () {
      final recs = buildFarmRecommendations(_weather(temp: 45));
      expect(
          recs.where((r) =>
              r.title == 'Extreme heat' && r.level == AdviceLevel.danger),
          hasLength(1));
      final mild = buildFarmRecommendations(_weather(temp: 39));
      expect(
          mild.any((r) =>
              r.title == 'Extreme heat' && r.level == AdviceLevel.caution),
          isTrue);
    });

    test('humidity ≥85 with rain ≥40 flags fungal-disease risk', () {
      final recs = buildFarmRecommendations(_weather(humidity: 90, rain: 50));
      expect(recs.any((r) => r.title == 'Humidity + rain risk'), isTrue);
    });

    test('calm conditions yield exactly one good-level recommendation', () {
      final recs =
          buildFarmRecommendations(_weather(rain: 10, wind: 5, temp: 25));
      expect(recs, hasLength(1));
      expect(recs.first.level, AdviceLevel.good);
      expect(recs.first.isWarning, isFalse);
    });

    test('all warming recommendations are flagged as warnings', () {
      final recs = buildFarmRecommendations(
          _weather(rain: 90, wind: 45, temp: 45, humidity: 95));
      expect(recs.length, greaterThan(1));
      expect(recs.every((r) => r.isWarning), isTrue);
    });
  });
}
