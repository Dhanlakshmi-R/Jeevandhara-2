/// Rule-based farming guidance derived from real weather values.
///
/// These are decision-support hints generated from conditions returned by the
/// weather provider — clearly labelled as weather-based recommendations, NOT
/// expert agricultural guarantees. Always confirm locally before acting.
library;

import 'package:jeevandhara2/models/weather_data.dart';

enum AdviceLevel { good, caution, danger }

class FarmRecommendation {
  final AdviceLevel level;
  final String title;
  final String message;

  const FarmRecommendation({
    required this.level,
    required this.title,
    required this.message,
  });

  bool get isWarning => level != AdviceLevel.good;
}

const String recommendationDisclaimer =
    'Weather-based suggestions only — verify locally before taking field actions.';

List<FarmRecommendation> buildFarmRecommendations(WeatherData weather) {
  final rain = weather.todayRainChance;
  final wind = weather.windKph;
  final temp = weather.tempC;
  final humidity = weather.humidity;

  final recs = <FarmRecommendation>[];

  if (rain >= 85) {
    recs.add(const FarmRecommendation(
      level: AdviceLevel.danger,
      title: 'Heavy rain likely',
      message:
          'Avoid pesticide spraying today — sprays will be washed off. Clear field drains and delay fertilizer application.',
    ));
  } else if (rain >= 70) {
    recs.add(const FarmRecommendation(
      level: AdviceLevel.caution,
      title: 'High rain probability',
      message:
          'Avoid pesticide spraying today. If harvesting, complete it before rains arrive.',
    ));
  } else if (rain >= 40) {
    recs.add(const FarmRecommendation(
      level: AdviceLevel.caution,
      title: 'Chance of rain',
      message:
          'Keep sowing/harvesting schedules flexible and cover harvested produce.',
    ));
  }

  if (wind >= 32) {
    recs.add(const FarmRecommendation(
      level: AdviceLevel.danger,
      title: 'Very strong wind',
      message:
          'Secure greenhouse covers and awnings. Avoid spraying — drift will be severe.',
    ));
  } else if (wind >= 20) {
    recs.add(const FarmRecommendation(
      level: AdviceLevel.caution,
      title: 'Strong wind',
      message: 'Secure greenhouse covers and avoid spraying today.',
    ));
  }

  if (temp >= 42) {
    recs.add(const FarmRecommendation(
      level: AdviceLevel.danger,
      title: 'Extreme heat',
      message:
          'Protect young seedlings with shade. Irrigate early morning or evening to reduce water loss.',
    ));
  } else if (temp >= 38) {
    recs.add(const FarmRecommendation(
      level: AdviceLevel.caution,
      title: 'Extreme heat',
      message:
          'Plan irrigation during early morning or evening to cut evaporation.',
    ));
  }

  if (humidity >= 85 && rain >= 40) {
    recs.add(const FarmRecommendation(
      level: AdviceLevel.caution,
      title: 'Humidity + rain risk',
      message: 'Monitor crops for fungal disease (blight, powdery mildew).',
    ));
  }

  if (recs.isEmpty) {
    recs.add(const FarmRecommendation(
      level: AdviceLevel.good,
      title: 'Good conditions',
      message:
          'Suitable weather for field activities like sowing and harvesting.',
    ));
  }

  return recs;
}
