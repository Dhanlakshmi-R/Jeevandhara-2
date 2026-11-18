import 'package:flutter/material.dart';

import 'package:jeevandhara2/services/current_location.dart';
import 'package:jeevandhara2/services/weather_service.dart';
import 'package:jeevandhara2/services/weather_speaker.dart';
import 'package:jeevandhara2/widgets/weather/weather_panel.dart';

/// Real-time weather tab.
///
/// A thin host around [WeatherPanel], which is shared with the admin console so
/// both audiences get the identical panel. The injectable dependencies exist
/// only so tests can drive the panel without GPS or text-to-speech plugins.
class WeatherScreen extends StatelessWidget {
  final WeatherService? service;
  final CurrentLocationService? locationService;
  final WeatherSpeaker? speaker;

  const WeatherScreen({
    super.key,
    this.service,
    this.locationService,
    this.speaker,
  });

  @override
  Widget build(BuildContext context) {
    return WeatherPanel(
      service: service,
      locationService: locationService,
      speaker: speaker,
    );
  }
}
