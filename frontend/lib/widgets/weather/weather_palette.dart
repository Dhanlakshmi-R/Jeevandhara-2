import 'package:flutter/material.dart';

import 'package:jeevandhara2/models/weather_data.dart';

/// A dedicated, high-contrast palette for the weather panel.
///
/// The weather surface is deliberately its own light blue/white look (as in the
/// approved design) so the same panel reads correctly whether it is embedded in
/// the farmer app or the dark admin console. Keeping the colours here means the
/// panel never borrows the host theme and changes appearance between the two.
class WeatherPalette {
  const WeatherPalette._();

  static const background = Color(0xFFF2F7FD);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFEAF2FB);
  static const border = Color(0xFFD6E4F4);

  static const primary = Color(0xFF1976D2);
  static const primaryDark = Color(0xFF0D47A1);
  static const primaryLight = Color(0xFF64B5F6);
  static const sidebarActive = Color(0xFF1565C0);

  static const gradientStart = Color(0xFF1E88E5);
  static const gradientEnd = Color(0xFF4FB0F5);

  static const textPrimary = Color(0xFF0D2B45);
  static const textSecondary = Color(0xFF5B7385);
  static const onPrimary = Colors.white;

  static const sunny = Color(0xFFF2A81D);
  static const cloudy = Color(0xFF7A93A8);
  static const rainy = Color(0xFF2E7DD1);
  static const stormy = Color(0xFF6A4FB6);
  static const snowy = Color(0xFF63B7D6);
  static const foggy = Color(0xFF9AA7B1);

  static const good = Color(0xFF2E9E5B);
  static const moderate = Color(0xFFF2A81D);
  static const unhealthySensitive = Color(0xFFE8710A);
  static const unhealthy = Color(0xFFD64545);
  static const veryUnhealthy = Color(0xFF8E24AA);
  static const hazardous = Color(0xFF6D4C41);

  static const danger = Color(0xFFD64545);
  static const dangerSurface = Color(0xFFFDECEC);
  static const warnSurface = Color(0xFFFFF6E6);
  static const successSurface = Color(0xFFE9F7EF);
  static const infoSurface = Color(0xFFE8F1FD);

  /// Colour paired with a condition so the icon itself carries the meaning.
  static Color forCategory(WeatherCategory category) {
    switch (category) {
      case WeatherCategory.sunny:
        return sunny;
      case WeatherCategory.cloudy:
        return cloudy;
      case WeatherCategory.rainy:
        return rainy;
      case WeatherCategory.stormy:
        return stormy;
      case WeatherCategory.snowy:
        return snowy;
      case WeatherCategory.foggy:
        return foggy;
      case WeatherCategory.other:
        return cloudy;
    }
  }

  /// Colour + label for the 1-6 US EPA air-quality index.
  static (Color, String) forAirQuality(int? index, String providerCategory) {
    switch (index) {
      case 1:
        return (good, 'Good');
      case 2:
        return (moderate, 'Moderate');
      case 3:
        return (unhealthySensitive, 'Unhealthy for sensitive groups');
      case 4:
        return (unhealthy, 'Unhealthy');
      case 5:
        return (veryUnhealthy, 'Very unhealthy');
      case 6:
        return (hazardous, 'Hazardous');
      default:
        return (
          cloudy,
          providerCategory.isEmpty ? 'Unavailable' : providerCategory,
        );
    }
  }
}
