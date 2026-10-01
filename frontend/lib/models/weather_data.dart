/// Real weather data models for the Weather module.
///
/// Mirrors the shapes returned by the backend `/weather` endpoints
/// (which proxy WeatherAPI.com, so these are real provider values —
/// the app never fabricates conditions).
library;

import 'package:flutter/material.dart' show IconData, Icons;

class WeatherCondition {
  final String text;
  final String iconUrl;

  const WeatherCondition({required this.text, this.iconUrl = ''});

  factory WeatherCondition.fromJson(Map<String, dynamic> json) =>
      WeatherCondition(
        text: (json['text'] as String?) ?? '',
        iconUrl: (json['icon'] as String?) ?? '',
      );

  /// Provider icons are protocol-relative; normalize for the image widget.
  String get httpsIcon => iconUrl.isEmpty
      ? ''
      : (iconUrl.startsWith('//') ? 'https:$iconUrl' : iconUrl);

  IconData get materialIcon {
    final c = text.toLowerCase();
    if (c.contains('thunder') || c.contains('storm'))
      return Icons.thunderstorm_rounded;
    if (c.contains('snow') || c.contains('sleet')) return Icons.ac_unit_rounded;
    if (c.contains('rain') || c.contains('drizzle'))
      return Icons.umbrella_rounded;
    if (c.contains('fog') || c.contains('mist') || c.contains('haze'))
      return Icons.foggy;
    if (c.contains('cloud')) return Icons.wb_cloudy_rounded;
    if (c.contains('sun') || c.contains('clear')) return Icons.wb_sunny_rounded;
    if (c.contains('overcast')) return Icons.cloud_queue_rounded;
    return Icons.cloud_rounded;
  }

  int get code => materialIcon.codePoint;
}

class IndianState {
  final String name;
  final bool available;
  final double lat;
  final double lon;
  final int districts;

  const IndianState({
    required this.name,
    required this.available,
    this.lat = 0,
    this.lon = 0,
    this.districts = 0,
  });

  factory IndianState.fromJson(Map<String, dynamic> json) => IndianState(
        name: (json['name'] as String?) ?? '',
        available: (json['available'] as bool?) ?? false,
        lat: _toDouble(json['lat']),
        lon: _toDouble(json['lon']),
        districts: (json['districts'] as num?)?.toInt() ?? 0,
      );
}

/// One row from the offline gazetteer (a district, taluk or village). Every
/// option carries real coordinates, so picking one never needs a geocode call.
class PlaceOption {
  final String name;
  final double lat;
  final double lon;

  const PlaceOption({required this.name, required this.lat, required this.lon});

  factory PlaceOption.fromJson(Map<String, dynamic> json) => PlaceOption(
        name: (json['name'] as String?) ?? '',
        lat: _toDouble(json['lat']),
        lon: _toDouble(json['lon']),
      );
}

/// What `/weather/places/resolve` came back with: the coordinates to use, plus
/// the admin level they belong to so the UI can be honest about precision.
class ResolvedPlace {
  final String label;
  final String state;
  final String? district;
  final String? taluk;
  final String? village;
  final double lat;
  final double lon;

  /// `state`, `district`, `taluk` or `village` -- the level [lat]/[lon]
  /// actually describe.
  final String level;
  final String matched;

  /// True when a village was asked for but only a coarser level could be
  /// located. The UI must say so rather than imply village precision.
  final bool fallback;

  const ResolvedPlace({
    required this.label,
    required this.state,
    required this.district,
    required this.taluk,
    required this.village,
    required this.lat,
    required this.lon,
    required this.level,
    required this.matched,
    required this.fallback,
  });

  factory ResolvedPlace.fromJson(Map<String, dynamic> json) => ResolvedPlace(
        label: (json['label'] as String?) ?? (json['name'] as String?) ?? '',
        state: (json['state'] as String?) ?? '',
        district: json['district'] as String?,
        taluk: json['taluk'] as String?,
        village: json['village'] as String?,
        lat: _toDouble(json['lat']),
        lon: _toDouble(json['lon']),
        level: (json['level'] as String?) ?? 'village',
        matched: (json['matched'] as String?) ?? '',
        fallback: (json['fallback'] as bool?) ?? false,
      );

  /// Feeds the existing weather fetch, which already takes coordinates.
  WeatherSuggestion get suggestion => WeatherSuggestion(
        name: matched.isNotEmpty ? matched : label,
        region: district ?? state,
        country: 'India',
        lat: lat,
        lon: lon,
      );

  /// Shown under the location so the user knows what they are looking at.
  /// `null` when the coordinates are the place they picked.
  String? get precisionNote {
    if (!fallback) return null;
    return 'Nearest weather point: $matched $level, not the village itself.';
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class WeatherSuggestion {
  final String name;
  final String region;
  final String country;
  final double lat;
  final double lon;

  const WeatherSuggestion({
    required this.name,
    required this.region,
    required this.country,
    required this.lat,
    required this.lon,
  });

  factory WeatherSuggestion.fromJson(Map<String, dynamic> json) =>
      WeatherSuggestion(
        name: (json['name'] as String?) ?? '',
        region: (json['region'] as String?) ?? '',
        country: (json['country'] as String?) ?? '',
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lon: (json['lon'] as num?)?.toDouble() ?? 0,
      );

  /// Display form required by the spec, e.g. `Bengaluru, Karnataka, India`.
  String get label =>
      [name, region, country].where((p) => p.isNotEmpty).join(', ');

  Map<String, dynamic> toJson() => {
        'name': name,
        'region': region,
        'country': country,
        'lat': lat,
        'lon': lon,
      };
}

class HourlyForecast {
  final DateTime time;
  final double tempC;
  final int chanceOfRain;
  final WeatherCondition condition;

  const HourlyForecast({
    required this.time,
    required this.tempC,
    required this.chanceOfRain,
    required this.condition,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) => HourlyForecast(
        time: DateTime.tryParse((json['time'] as String?) ?? '') ??
            DateTime.now(),
        tempC: (json['temp_c'] as num?)?.toDouble() ?? 0,
        chanceOfRain: (json['chance_of_rain'] as num?)?.toInt() ?? 0,
        condition: WeatherCondition.fromJson(
            (json['condition'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}

class DailyForecast {
  final DateTime date;
  final double maxTempC;
  final double minTempC;
  final int chanceOfRain;
  final double? uv;
  final WeatherCondition condition;

  const DailyForecast({
    required this.date,
    required this.maxTempC,
    required this.minTempC,
    required this.chanceOfRain,
    required this.condition,
    this.uv,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) => DailyForecast(
        date: DateTime.tryParse((json['date'] as String?) ?? '') ??
            DateTime.now(),
        maxTempC: (json['max_temp_c'] as num?)?.toDouble() ?? 0,
        minTempC: (json['min_temp_c'] as num?)?.toDouble() ?? 0,
        chanceOfRain: (json['chance_of_rain'] as num?)?.toInt() ?? 0,
        uv: (json['uv'] as num?)?.toDouble(),
        condition: WeatherCondition.fromJson(
            (json['condition'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}

class WeatherAlertData {
  final String headline;
  final String severity;
  final String instruction;
  final String event;
  final String effective;
  final String expires;

  const WeatherAlertData({
    required this.headline,
    required this.severity,
    required this.instruction,
    required this.event,
    required this.effective,
    required this.expires,
  });

  factory WeatherAlertData.fromJson(Map<String, dynamic> json) =>
      WeatherAlertData(
        headline: (json['headline'] as String?) ?? '',
        severity: (json['severity'] as String?) ?? '',
        instruction: (json['instruction'] as String?) ?? '',
        event: (json['event'] as String?) ?? '',
        effective: (json['effective'] as String?) ?? '',
        expires: (json['expires'] as String?) ?? '',
      );
}

class WeatherData {
  final String name;
  final String region;
  final String country;
  final String localtime;

  final double tempC;
  final double feelsLikeC;
  final WeatherCondition condition;
  final double humidity;
  final double windKph;
  final String windDir;
  final double precipMm;
  final double? uv;
  final bool isDay;

  final String sunrise;
  final String sunset;
  final String lastUpdated;

  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
  final List<WeatherAlertData> alerts;

  const WeatherData({
    required this.name,
    required this.region,
    required this.country,
    required this.localtime,
    required this.tempC,
    required this.feelsLikeC,
    required this.condition,
    required this.humidity,
    required this.windKph,
    required this.windDir,
    required this.precipMm,
    required this.uv,
    required this.isDay,
    required this.sunrise,
    required this.sunset,
    required this.lastUpdated,
    required this.hourly,
    required this.daily,
    required this.alerts,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final location =
        (json['location'] as Map?)?.cast<String, dynamic>() ?? const {};
    final current =
        (json['current'] as Map?)?.cast<String, dynamic>() ?? const {};
    final astro = (json['astro'] as Map?)?.cast<String, dynamic>() ?? const {};
    final hourly = (json['hourly'] as List?) ?? const [];
    final daily = (json['daily'] as List?) ?? const [];
    final alerts = (json['alerts'] as List?) ?? const [];

    return WeatherData(
      name: (location['name'] as String?) ?? '',
      region: (location['region'] as String?) ?? '',
      country: (location['country'] as String?) ?? '',
      localtime: (location['localtime'] as String?) ?? '',
      tempC: (current['temp_c'] as num?)?.toDouble() ?? 0,
      feelsLikeC: (current['feelslike_c'] as num?)?.toDouble() ?? 0,
      condition: WeatherCondition.fromJson(
          (current['condition'] as Map?)?.cast<String, dynamic>() ?? const {}),
      humidity: (current['humidity'] as num?)?.toDouble() ?? 0,
      windKph: (current['wind_kph'] as num?)?.toDouble() ?? 0,
      windDir: (current['wind_dir'] as String?) ?? '',
      precipMm: (current['precip_mm'] as num?)?.toDouble() ?? 0,
      uv: (current['uv'] as num?)?.toDouble(),
      isDay: (current['is_day'] as num?)?.toInt() == 1,
      sunrise: (astro['sunrise'] as String?) ?? '',
      sunset: (astro['sunset'] as String?) ?? '',
      lastUpdated: (current['last_updated'] as String?) ?? '',
      hourly: hourly
          .map((e) =>
              HourlyForecast.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      daily: daily
          .map(
              (e) => DailyForecast.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      alerts: alerts
          .map((e) =>
              WeatherAlertData.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  /// Today's rain probability (from the daily forecast, matching the spec).
  double get todayRainChance =>
      daily.isEmpty ? 0 : daily.first.chanceOfRain.toDouble();
}
