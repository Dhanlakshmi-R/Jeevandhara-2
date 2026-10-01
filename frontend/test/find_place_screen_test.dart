import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:jeevandhara2/models/weather_data.dart';
import 'package:jeevandhara2/screens/find_place_screen.dart';
import 'package:jeevandhara2/services/weather_service.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';

/// A backend client that serves the all-India GeoNames gazetteer plus a
/// resolvable village ("Adagal", Badami taluk, Bagalkot district).
MockClient _hierarchyClient({bool resolveAdagal = true}) {
  return MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/weather/places/states')) {
      return _json([
        {
          'name': 'Karnataka',
          'available': true,
          'lat': 15.3173,
          'lon': 75.7139,
          'districts': 31,
        },
      ]);
    }
    if (path.endsWith('/weather/places/districts')) {
      return _json([
        {'name': 'Bagalkot', 'lat': 16.19, 'lon': 75.7},
        {'name': 'Belgaum', 'lat': 15.85, 'lon': 74.5},
      ]);
    }
    if (path.endsWith('/weather/places/taluks')) {
      return _json([
        {'name': 'Badami', 'lat': 16.17, 'lon': 75.69},
        {'name': 'Mudhol', 'lat': 16.2, 'lon': 75.66},
      ]);
    }
    if (path.endsWith('/weather/places/villages')) {
      return _json([
        {'name': 'Adagal', 'lat': 16.05, 'lon': 75.66},
        {'name': 'Sulla', 'lat': 16.08, 'lon': 75.62},
      ]);
    }
    if (path.endsWith('/weather/places/resolve')) {
      final q = request.url.queryParameters;
      final village = q['village'];
      final taluk = q['taluk'];
      final district = q['district'];
      String label, matched, level;
      double lat, lon;
      var fallback = false;
      if (village == 'Adagal' && resolveAdagal) {
        label = 'Adagal, Badami, Bagalkot, Karnataka';
        matched = 'Adagal';
        level = 'village';
        lat = 16.05;
        lon = 75.66;
      } else if (village != null) {
        // Unknown village → taluk point, explicitly flagged as a fallback.
        label = 'Badami, Bagalkot, Karnataka';
        matched = 'Badami';
        level = 'taluk';
        lat = 16.17;
        lon = 75.69;
        fallback = true;
      } else if (taluk != null) {
        label = '$taluk, $district, Karnataka';
        matched = taluk;
        level = 'taluk';
        lat = 16.17;
        lon = 75.69;
      } else if (district != null) {
        label = '$district, Karnataka';
        matched = district;
        level = 'district';
        lat = 16.19;
        lon = 75.7;
      } else {
        label = 'Karnataka';
        matched = 'Karnataka';
        level = 'state';
        lat = 15.3173;
        lon = 75.7139;
      }
      return _json({
        'label': label,
        'state': 'Karnataka',
        'district': district,
        'taluk': taluk,
        'village': village,
        'lat': lat,
        'lon': lon,
        'level': level,
        'matched': matched,
        'fallback': fallback,
      });
    }
    if (path.endsWith('/weather/suggestions')) {
      final q = request.url.queryParameters['q'] ?? '';
      if (q.contains('Adagal')) {
        if (!resolveAdagal) return _json([]);
        return _json([
          {
            'name': 'Adagal',
            'region': 'Karnataka',
            'country': 'India',
            'lat': 16.05,
            'lon': 75.66,
          }
        ]);
      }
      return _json([
        {
          'name': 'Bagalkot',
          'region': 'Karnataka',
          'country': 'India',
          'lat': 16.19,
          'lon': 75.7
        }
      ]);
    }
    return http.Response('{"detail":"Not found"}', 404);
  });
}

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

Widget _harness({
  required WeatherService service,
  required void Function(WeatherSuggestion?) onResult,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final result =
                  await Navigator.of(context).push<WeatherSuggestion>(
                MaterialPageRoute(
                  builder: (_) => FindPlaceScreen(service: service),
                ),
              );
              onResult(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

WeatherService _serviceWith(MockClient client) =>
    WeatherService(baseUrl: 'https://x.test', client: client);

Future<void> _openPicker(WidgetTester tester, Widget harness) async {
  await tester.pumpWidget(harness);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Opens a cascading dropdown by its hint text and picks one option.
Future<void> _pick(WidgetTester tester, String hint, String option) async {
  final field = find.text(hint);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field, warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('full cascade resolves and pops the chosen village',
      (WidgetTester tester) async {
    WeatherSuggestion? chosen;
    final harness = _harness(
      service: _serviceWith(_hierarchyClient()),
      onResult: (r) => chosen = r,
    );
    await _openPicker(tester, harness);

    await _pick(tester, 'Select state', 'Karnataka');
    await _pick(tester, 'Select district', 'Bagalkot');
    await _pick(tester, 'Select taluk', 'Badami');
    await _pick(tester, 'Select village', 'Adagal');

    final button = find.text('Show weather for Adagal');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(chosen, isNotNull);
    expect(chosen!.name, 'Adagal');
    expect(chosen!.region, 'Bagalkot');
    expect(chosen!.country, 'India');
    expect(chosen!.lat, 16.05);
    expect(chosen!.lon, 75.66);
  });

  testWidgets('unknown village is never silently replaced by the taluk point',
      (WidgetTester tester) async {
    WeatherSuggestion? chosen;
    final harness = _harness(
      service: _serviceWith(_hierarchyClient(resolveAdagal: false)),
      onResult: (r) => chosen = r,
    );
    await _openPicker(tester, harness);

    await _pick(tester, 'Select state', 'Karnataka');
    await _pick(tester, 'Select district', 'Bagalkot');
    await _pick(tester, 'Select taluk', 'Badami');
    await _pick(tester, 'Select village', 'Adagal');

    await tester.ensureVisible(find.text('Show weather for Adagal'));
    await tester.tap(find.text('Show weather for Adagal'));
    await tester.pumpAndSettle();

    // The first tap must not navigate away pretending the village was found.
    expect(chosen, isNull);
    expect(find.textContaining('Showing taluk coordinates'), findsOneWidget);
    expect(
      find.textContaining('Nearest weather point: Badami taluk'),
      findsOneWidget,
    );

    // Only an explicit confirmation accepts the coarser point.
    await tester.tap(find.text('Use it anyway'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(chosen, isNotNull);
    expect(chosen!.name, 'Badami'); // the real matched place, not the village
    expect(chosen!.lat, 16.17);
    expect(chosen!.lon, 75.69);
  });

  testWidgets('declining the fallback keeps the picker open with the village',
      (WidgetTester tester) async {
    WeatherSuggestion? chosen;
    final harness = _harness(
      service: _serviceWith(_hierarchyClient(resolveAdagal: false)),
      onResult: (r) => chosen = r,
    );
    await _openPicker(tester, harness);

    await _pick(tester, 'Select state', 'Karnataka');
    await _pick(tester, 'Select district', 'Bagalkot');
    await _pick(tester, 'Select taluk', 'Badami');
    await _pick(tester, 'Select village', 'Adagal');

    await tester.ensureVisible(find.text('Show weather for Adagal'));
    await tester.tap(find.text('Show weather for Adagal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick another'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(chosen, isNull);
    // The picker is still showing the chosen state; only the fallback card is gone.
    expect(find.text('Karnataka'), findsOneWidget);
    expect(find.text('Use it anyway'), findsNothing);
    expect(find.text('Badami'), findsWidgets);
  });

  testWidgets('a failing resolve shows an inline error with retry',
      (WidgetTester tester) async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/weather/places/states')) {
        return _json([
          {
            'name': 'Karnataka',
            'available': true,
            'lat': 15.3173,
            'lon': 75.7139,
            'districts': 31,
          },
        ]);
      }
      if (path.endsWith('/weather/places/districts')) {
        return _json([
          {'name': 'Bagalkot', 'lat': 16.19, 'lon': 75.7},
        ]);
      }
      if (path.endsWith('/weather/places/resolve')) {
        return http.Response('boom', 500);
      }
      return http.Response('{"detail":"Not found"}', 404);
    });
    WeatherSuggestion? chosen;
    final harness =
        _harness(service: _serviceWith(client), onResult: (r) => chosen = r);
    await _openPicker(tester, harness);

    await _pick(tester, 'Select state', 'Karnataka');
    await _pick(tester, 'Select district', 'Bagalkot');

    await tester.ensureVisible(find.text('Show weather for Bagalkot'));
    await tester.tap(find.text('Show weather for Bagalkot'));
    await tester.pumpAndSettle();

    expect(chosen, isNull);
    // The resolve failure is reported on its own, separately from the
    // per-level load errors.
    expect(find.textContaining('Could not resolve'), findsOneWidget);
    expect(find.text('Retry'), findsWidgets);
  });

  testWidgets('unavailable state shows a note instead of deeper levels',
      (WidgetTester tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/weather/places/states')) {
        return _json([
          {
            'name': 'Kerala',
            'available': false,
            'lat': 10.85,
            'lon': 76.27,
            'districts': 14
          },
          {
            'name': 'Karnataka',
            'available': true,
            'lat': 15.32,
            'lon': 75.71,
            'districts': 31
          },
        ]);
      }
      return http.Response('{"detail":"Not found"}', 404);
    });
    final harness = _harness(service: _serviceWith(client), onResult: (_) {});
    await _openPicker(tester, harness);

    await _pick(tester, 'Select state', 'Kerala');

    expect(find.textContaining('isn\u2019t bundled yet'), findsOneWidget);
    expect(find.text('Select district'), findsNothing);
  });

  testWidgets('the search tab resolves a place by name and pops it',
      (WidgetTester tester) async {
    // Any village drill-down data is irrelevant here — the search tab talks
    // straight to the provider gazetteer.
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/weather/places/states')) {
        return _json([
          {
            'name': 'Karnataka',
            'available': true,
            'lat': 15.3173,
            'lon': 75.7139,
            'districts': 31,
          },
        ]);
      }
      if (path.endsWith('/weather/suggestions')) {
        return _json([
          {
            'name': 'Bengaluru',
            'region': 'Karnataka',
            'country': 'India',
            'lat': 12.97,
            'lon': 77.59
          }
        ]);
      }
      return http.Response('{"detail":"Not found"}', 404);
    });

    WeatherSuggestion? chosen;
    final harness =
        _harness(service: _serviceWith(client), onResult: (r) => chosen = r);
    await _openPicker(tester, harness);

    // The district cascade is the default view.
    expect(find.text('Browse district'), findsOneWidget);

    await tester.tap(find.text('Search by name'), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bengaluru');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bengaluru'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(chosen, isNotNull);
    expect(chosen!.name, 'Bengaluru');
    expect(chosen!.region, 'Karnataka');
    expect(chosen!.lat, 12.97);
  });

  testWidgets('district load failure is retryable',
      (WidgetTester tester) async {
    var failed = true;
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/weather/places/states')) {
        return _json([
          {
            'name': 'Karnataka',
            'available': true,
            'lat': 15.3173,
            'lon': 75.7139,
            'districts': 31,
          },
        ]);
      }
      if (path.endsWith('/weather/places/districts')) {
        if (failed) return http.Response('boom', 500);
        return _json([
          {'name': 'Bagalkot', 'lat': 16.19, 'lon': 75.7},
        ]);
      }
      return http.Response('{"detail":"Not found"}', 404);
    });
    final harness = _harness(service: _serviceWith(client), onResult: (_) {});
    await _openPicker(tester, harness);

    await _pick(tester, 'Select state', 'Karnataka');

    // The failure surfaces inline with a retry affordance instead of an empty
    // dropdown the user cannot act on.
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('District'), findsOneWidget);

    failed = false;
    await tester.tap(find.text('Retry'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsNothing);

    // Retry really refetched: the district is now selectable.
    await _pick(tester, 'Select district', 'Bagalkot');
    expect(find.text('Select district'), findsNothing);
  });

  testWidgets('a state on its own is enough to show weather',
      (WidgetTester tester) async {
    WeatherSuggestion? chosen;
    final harness = _harness(
      service: _serviceWith(_hierarchyClient()),
      onResult: (r) => chosen = r,
    );
    await _openPicker(tester, harness);

    // Nothing is chosen yet, so the action is disabled.
    expect(
      tester.widget<AppPrimaryButton>(find.byType(AppPrimaryButton)).onPressed,
      isNull,
    );

    await _pick(tester, 'Select state', 'Karnataka');

    // Enabled as soon as a state exists — no need to drill all the way down.
    expect(
      tester.widget<AppPrimaryButton>(find.byType(AppPrimaryButton)).onPressed,
      isNotNull,
    );

    await tester.ensureVisible(find.text('Show weather for Karnataka'));
    await tester.tap(find.text('Show weather for Karnataka'));
    await tester.pumpAndSettle();

    expect(chosen, isNotNull);
    expect(chosen!.name, 'Karnataka');
    expect(chosen!.lat, 15.3173);
    expect(chosen!.lon, 75.7139);
  });

  testWidgets('a district on its own is enough to show weather',
      (WidgetTester tester) async {
    WeatherSuggestion? chosen;
    final harness = _harness(
      service: _serviceWith(_hierarchyClient()),
      onResult: (r) => chosen = r,
    );
    await _openPicker(tester, harness);

    await _pick(tester, 'Select state', 'Karnataka');
    await _pick(tester, 'Select district', 'Bagalkot');
    await tester.ensureVisible(find.text('Show weather for Bagalkot'));
    await tester.tap(find.text('Show weather for Bagalkot'));
    await tester.pumpAndSettle();

    expect(chosen, isNotNull);
    expect(chosen!.name, 'Bagalkot');
    expect(chosen!.region, 'Bagalkot');
  });

  group('pure parsers', () {
    test('parseStates maps availability flags and coordinates', () {
      final states = parseStates(jsonEncode({
        'states': [
          {
            'name': 'Karnataka',
            'available': true,
            'lat': 15.3173,
            'lon': 75.7139,
            'districts': 31,
          },
          {'name': 'Kerala', 'available': false},
        ],
      }));
      expect(states, hasLength(2));
      expect(states.first.name, 'Karnataka');
      expect(states.first.available, isTrue);
      expect(states.first.lat, 15.3173);
      expect(states.first.districts, 31);
      expect(states.last.available, isFalse);
    });

    test('parsePlaceOptions reads gazetteer name/coordinate rows', () {
      final options = parsePlaceOptions(
        jsonEncode([
          {'name': 'Bagalkot', 'lat': 16.19, 'lon': 75.7},
        ]),
      );
      expect(options, hasLength(1));
      expect(options.first.name, 'Bagalkot');
      expect(options.first.lat, 16.19);
      expect(options.first.lon, 75.7);
    });

    test('parsePlaceOptions tolerates a non-list payload', () {
      expect(parsePlaceOptions('{"nope":1}'), isEmpty);
    });

    test('parseResolvedPlace keeps the precision metadata', () {
      final exact = parseResolvedPlace(jsonEncode({
        'label': 'Adagal, Badami, Bagalkot, Karnataka',
        'state': 'Karnataka',
        'district': 'Bagalkot',
        'taluk': 'Badami',
        'village': 'Adagal',
        'lat': 16.05,
        'lon': 75.66,
        'level': 'village',
        'matched': 'Adagal',
        'fallback': false,
      }));
      expect(exact.fallback, isFalse);
      expect(exact.level, 'village');
      expect(exact.precisionNote, isNull);
      expect(exact.suggestion.name, 'Adagal');

      final coarse = parseResolvedPlace(jsonEncode({
        'label': 'Badami, Bagalkot, Karnataka',
        'state': 'Karnataka',
        'district': 'Bagalkot',
        'taluk': 'Badami',
        'village': 'Adagal',
        'lat': 16.17,
        'lon': 75.69,
        'level': 'taluk',
        'matched': 'Badami',
        'fallback': true,
      }));
      expect(coarse.fallback, isTrue);
      expect(coarse.level, 'taluk');
      expect(coarse.precisionNote, contains('Badami'));
      // The suggestion must not be mislabelled as the requested village.
      expect(coarse.suggestion.name, 'Badami');
    });
  });
}
