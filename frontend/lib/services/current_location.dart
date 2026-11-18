import 'package:geolocator/geolocator.dart';

import 'package:jeevandhara2/models/weather_data.dart';

/// Why a current-location lookup did or did not produce a place.
enum LocationOutcome { located, denied, deniedForever, serviceDisabled, error }

/// Result of a current-location attempt. [place] is set only when
/// [outcome] is [LocationOutcome.located].
class LocationResult {
  final LocationOutcome outcome;
  final WeatherSuggestion? place;

  const LocationResult(this.outcome, [this.place]);

  bool get ok => outcome == LocationOutcome.located && place != null;
}

/// Wraps the device GPS behind one method so the weather panel can be driven
/// with a fake in tests. Real implementation asks for permission and returns
/// the coordinates as a [WeatherSuggestion].
class CurrentLocationService {
  const CurrentLocationService();

  Future<LocationResult> resolve() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationOutcome.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationOutcome.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationOutcome.deniedForever);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationResult(
        LocationOutcome.located,
        WeatherSuggestion(
          name: 'Current location',
          region: '',
          country: '',
          lat: position.latitude,
          lon: position.longitude,
        ),
      );
    } catch (_) {
      return const LocationResult(LocationOutcome.error);
    }
  }
}
