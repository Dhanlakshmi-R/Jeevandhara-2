import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeevandhara2/ai/prompt/ai_context.dart';
import 'package:jeevandhara2/models/weather_data.dart';

const _dharwad = WeatherSuggestion(
  name: 'Dharwad',
  region: 'Karnataka',
  country: 'India',
  lat: 15.46,
  lon: 75.01,
);

const _hubballi = WeatherSuggestion(
  name: 'Hubballi',
  region: 'Karnataka',
  country: 'India',
  lat: 15.36,
  lon: 75.12,
);

/// A suggestion whose coordinates never resolved. Treating it as a real
/// position would send weather requests to 0,0.
const _unresolved = WeatherSuggestion(
  name: 'Nowhere',
  region: '',
  country: '',
  lat: 0,
  lon: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an unset place leaves the assistant without coordinates', () async {
    final context = AiContext();
    await context.load();

    expect(context.hasLocation, isFalse);
    expect(context.placeName, isEmpty);
    expect(context.lat, isNull);
  });

  test('a stored place is picked up', () async {
    await AiContext().adopt(_dharwad);

    final context = AiContext();
    await context.load();

    expect(context.hasLocation, isTrue);
    expect(context.placeName, 'Dharwad');
    expect(context.lat, 15.46);
    expect(context.lon, 75.01);
  });

  test('load re-reads the store so a changed place is not missed', () async {
    final context = AiContext();
    await context.adopt(_dharwad);
    await context.load();
    expect(context.placeName, 'Dharwad');

    // Simulate the Weather screen writing a different place through its own
    // store instance, which is exactly what happens when the user changes
    // village while the chat is mounted underneath the shell.
    await AiContext().adopt(_hubballi);

    await context.load();

    expect(context.placeName, 'Hubballi');
    expect(context.lat, 15.36);
  });

  test('a zeroed suggestion counts as no location', () async {
    final context = AiContext();
    await context.adopt(_unresolved);
    await context.load();

    expect(context.hasLocation, isFalse);
  });

  test('clear drops the stored place', () async {
    final context = AiContext();
    await context.adopt(_dharwad);
    await context.clear();
    await context.load();

    expect(context.hasLocation, isFalse);
    expect(context.placeName, isEmpty);
  });
}
