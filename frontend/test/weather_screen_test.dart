import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeevandhara2/screens/weather_screen.dart';
import 'package:jeevandhara2/services/weather_service.dart';

const _weatherJson = '''
{
  "location": {"name": "Dharwad", "region": "Karnataka", "country": "India", "localtime": "2026-09-24 10:00"},
  "current": {
    "temp_c": 27.4, "feelslike_c": 29.1, "humidity": 58, "wind_kph": 12.6,
    "wind_dir": "WSW", "precip_mm": 1.2, "uv": 6.1, "is_day": 1,
    "condition": {"text": "Partly cloudy", "icon": ""},
    "last_updated": "2026-09-24 09:00"
  },
  "astro": {"sunrise": "06:12 AM", "sunset": "06:25 PM"},
  "hourly": [
    {"time": "2026-09-24 11:00", "temp_c": 28.6, "chance_of_rain": 20, "condition": {"text": "Partly cloudy"}},
    {"time": "2026-09-24 12:00", "temp_c": 29.4, "chance_of_rain": 30, "condition": {"text": "Partly cloudy"}}
  ],
  "daily": [
    {"date": "2026-09-24", "max_temp_c": 31.5, "min_temp_c": 21.2, "chance_of_rain": 65,
     "condition": {"text": "Moderate rain"}},
    {"date": "2026-09-25", "max_temp_c": 30.1, "min_temp_c": 20.5, "chance_of_rain": 40,
     "condition": {"text": "Patchy rain"}}
  ],
  "alerts": []
}
''';

Widget _app(WeatherService service) {
  return MaterialApp(home: Scaffold(body: WeatherScreen(service: service)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'last_weather_place':
          '{"name":"Dharwad","region":"Karnataka","country":"India","lat":15.46,"lon":75.01}',
    });
  });

  testWidgets(
      'loads persisted place and renders hero, metrics and recommendations',
      (WidgetTester tester) async {
    // Tall viewport so the whole (mock-fed) dashboard is built for assertions.
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/weather')) {
        return http.Response(_weatherJson, 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{"detail":"Not found"}', 404);
    });
    final service = WeatherService(baseUrl: 'https://x.test', client: client);

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.textContaining('Dharwad'), findsWidgets);
    expect(find.textContaining('27\u00B0'), findsWidgets);
    expect(find.text('Hourly forecast'), findsOneWidget);
    expect(find.text('Daily forecast'), findsOneWidget);
    expect(find.text('Farmer recommendations'), findsOneWidget);

    // 65% rain chance must surface a caution recommendation.
    expect(find.text('Chance of rain'), findsOneWidget);
  });

  testWidgets('shows empty state when no place is persisted',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((request) async => http.Response('{}', 503));
    final service = WeatherService(baseUrl: 'https://x.test', client: client);

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('No location yet'), findsOneWidget);
    expect(find.text('Choose a location'), findsOneWidget);
  });
}
