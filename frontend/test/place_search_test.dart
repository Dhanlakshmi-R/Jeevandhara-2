import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:jeevandhara2/models/weather_data.dart';
import 'package:jeevandhara2/screens/place_search_screen.dart';
import 'package:jeevandhara2/services/place_search.dart';
import 'package:jeevandhara2/services/weather_service.dart';
import 'package:jeevandhara2/theme/app_theme.dart';

/// Indian gazetteer the fake backend serves. The real
/// `/weather/suggestions` endpoint already drops non-Indian hits, so the
/// fixture is India-only — that contract is what these tests pin down.
const _gazetteer = <Map<String, Object>>[
  {
    'name': 'Bengaluru',
    'region': 'Karnataka',
    'country': 'India',
    'lat': 12.97,
    'lon': 77.59
  },
  {
    'name': 'Bengaluru Rural',
    'region': 'Karnataka',
    'country': 'India',
    'lat': 13.02,
    'lon': 77.72
  },
  {
    'name': 'Mysuru',
    'region': 'Karnataka',
    'country': 'India',
    'lat': 12.29,
    'lon': 76.64
  },
  {
    'name': 'Mumbai',
    'region': 'Maharashtra',
    'country': 'India',
    'lat': 19.07,
    'lon': 72.87
  },
];

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

/// Fake backend for the location search. Records every `q[|state]` it is
/// asked for so debounce and filtering can be asserted directly.
MockClient _searchClient({
  List<Map<String, Object>>? results,
  bool failSuggestions = false,
  List<String>? callLog,
}) {
  return MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/weather/places/states')) {
      return _json([
        {'name': 'Karnataka', 'available': true},
        {'name': 'Maharashtra', 'available': false},
      ]);
    }
    if (path.endsWith('/weather/suggestions')) {
      final q = (request.url.queryParameters['q'] ?? '').toLowerCase();
      final state = request.url.queryParameters['state'];
      callLog?.add(state == null ? q : '$q|$state');
      if (failSuggestions) {
        return http.Response('{"detail":"weather provider unreachable"}', 502);
      }
      if (results != null) return _json(results);

      var hits = _gazetteer
          .where((p) => (p['name'] as String).toLowerCase().contains(q))
          .toList();
      if (state != null) {
        // Mirrors the backend: prefer the state, fall back to all India.
        final narrowed = hits.where((p) => p['region'] == state).toList();
        if (narrowed.isNotEmpty) hits = narrowed;
      }
      return _json(hits);
    }
    return http.Response('{"detail":"Not found"}', 404);
  });
}

WeatherService _service(MockClient client) =>
    WeatherService(baseUrl: 'https://x.test', client: client);

/// Long enough to clear the 300ms debounce.
const _settle = Duration(milliseconds: 350);

Widget _pane(
    WeatherService service, ValueChanged<WeatherSuggestion> onSelected) {
  return MaterialApp(
    theme: buildLightTheme(),
    home: Scaffold(
      body: PlaceSearchPane(service: service, onSelected: onSelected),
    ),
  );
}

/// Mutable holder so a widget test can observe the choice made *after* the
/// pane was mounted. Returning the variable directly would snapshot null.
class _Selection {
  WeatherSuggestion? value;
}

/// Boots the pane with the state list already resolved.
Future<_Selection> _openPane(
  WidgetTester tester, {
  required MockClient client,
}) async {
  final selection = _Selection();
  await tester.pumpWidget(_pane(_service(client), (p) => selection.value = p));
  await tester.pumpAndSettle();
  return selection;
}

void main() {
  group('WeatherSuggestion.label', () {
    test('renders the spec format "Place, Region, Country"', () {
      const place = WeatherSuggestion(
        name: 'Bengaluru',
        region: 'Karnataka',
        country: 'India',
        lat: 12.97,
        lon: 77.59,
      );
      expect(place.label, 'Bengaluru, Karnataka, India');
    });

    test('omits empty parts instead of leaving stray commas', () {
      const place = WeatherSuggestion(
        name: 'Adagal',
        region: '',
        country: 'India',
        lat: 16.05,
        lon: 75.66,
      );
      expect(place.label, 'Adagal, India');
    });
  });

  group('PlaceSearchController', () {
    // The controller's debounce is a plain Timer, so these run on the test
    // binding's fake clock via tester.pump().
    Future<PlaceSearchController> controllerFor(
      WidgetTester tester, {
      required Future<List<WeatherSuggestion>> Function(String, {String? state})
          fetcher,
      Duration debounce = const Duration(milliseconds: 300),
    }) async {
      final c =
          PlaceSearchController(fetchSuggestions: fetcher, debounce: debounce);
      addTearDown(c.dispose);
      return c;
    }

    testWidgets('a single letter triggers exactly one search', (tester) async {
      final log = <String>[];
      final c = await controllerFor(
        tester,
        fetcher: (q, {state}) async {
          log.add(q);
          return const [];
        },
      );

      c.onQueryChanged('b');
      await tester.pump(_settle);
      expect(log, ['b']);
    });

    testWidgets('rapid keystrokes are coalesced by the debounce',
        (tester) async {
      final log = <String>[];
      final c = await controllerFor(
        tester,
        fetcher: (q, {state}) async {
          log.add(q);
          return const [];
        },
      );

      for (final q in ['b', 'be', 'ben', 'beng', 'benga', 'bengaluru']) {
        c.onQueryChanged(q);
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pump(_settle);

      // Six keystrokes across ~700ms must collapse into a single request.
      expect(log, ['bengaluru']);
    });

    testWidgets('does not fire before the debounce window elapses',
        (tester) async {
      final log = <String>[];
      final c = await controllerFor(
        tester,
        fetcher: (q, {state}) async {
          log.add(q);
          return const [];
        },
      );

      c.onQueryChanged('ben');
      await tester.pump(const Duration(milliseconds: 250));
      expect(log, isEmpty);

      await tester.pump(const Duration(milliseconds: 100));
      expect(log, ['ben']);
    });

    testWidgets('a query typed mid-flight does not stack a second request',
        (tester) async {
      final log = <String>[];
      final gate = Completer<void>();
      final c = await controllerFor(
        tester,
        fetcher: (q, {state}) async {
          log.add(q);
          if (log.length == 1) await gate.future;
          return const [];
        },
      );

      c.onQueryChanged('ben');
      await tester.pump(_settle);
      expect(log, ['ben']); // first request in flight, blocked on the gate

      c.onQueryChanged('bengaluru');
      await tester.pump(_settle);
      expect(log, ['ben'], reason: 'must not fire a concurrent request');

      gate.complete();
      await tester.pump();
      await tester.pump();
      // The queued query is served once the in-flight one settles.
      expect(log, ['ben', 'bengaluru']);
    });

    testWidgets('forwards the state filter to the fetcher', (tester) async {
      final log = <String>[];
      final c = await controllerFor(
        tester,
        fetcher: (q, {state}) async {
          log.add(state == null ? q : '$q|$state');
          return const [];
        },
      );

      c.setStateFilter('Karnataka');
      c.onQueryChanged('ben');
      await tester.pump(_settle);

      expect(log, ['ben|Karnataka']);
    });

    testWidgets('changing the filter re-queries without another keystroke',
        (tester) async {
      final log = <String>[];
      final c = await controllerFor(
        tester,
        fetcher: (q, {state}) async {
          log.add(state == null ? q : '$q|$state');
          return const [];
        },
      );

      c.onQueryChanged('ben');
      await tester.pump(_settle);
      c.setStateFilter('Maharashtra');
      await tester.pump(_settle);

      expect(log, ['ben', 'ben|Maharashtra']);
    });

    testWidgets('reports results and highlights the first row', (tester) async {
      final c = await controllerFor(
        tester,
        fetcher: (q, {state}) async => _gazetteer
            .where((e) => (e['name'] as String).toLowerCase().contains(q))
            .map((e) => WeatherSuggestion.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

      c.onQueryChanged('ben');
      await tester.pump(_settle);

      expect(c.status, PlaceSearchStatus.results);
      expect(c.suggestions, hasLength(2));
      expect(c.highlightIndex, 0);
      expect(c.canSubmit, isTrue);
    });

    testWidgets('no matches reports the empty state', (tester) async {
      final c = await controllerFor(
        tester,
        fetcher: (q, {state}) async => const [],
      );

      c.onQueryChanged('zzzz');
      await tester.pump(_settle);

      expect(c.status, PlaceSearchStatus.empty);
      expect(c.canSubmit, isFalse);
      expect(c.resolvable, isNull);
    });

    testWidgets('a provider failure surfaces as an error and Retry recovers',
        (tester) async {
      var broken = true;
      final c = await controllerFor(
        tester,
        fetcher: (q, {state}) async {
          if (broken) throw Exception('weather provider unreachable');
          return [
            const WeatherSuggestion(
              name: 'Mysuru',
              region: 'Karnataka',
              country: 'India',
              lat: 12.29,
              lon: 76.64,
            ),
          ];
        },
      );

      c.onQueryChanged('mys');
      await tester.pump(_settle);

      expect(c.status, PlaceSearchStatus.error);
      expect(c.error, 'weather provider unreachable');
      expect(c.canSubmit, isFalse);

      broken = false;
      await c.retry();
      await tester.pump();

      expect(c.status, PlaceSearchStatus.results);
      expect(c.suggestions.single.name, 'Mysuru');
    });

    testWidgets('clearing the input returns to the idle state', (tester) async {
      final c = await controllerFor(
        tester,
        fetcher: (q, {state}) async => const [
          WeatherSuggestion(
            name: 'Mysuru',
            region: 'Karnataka',
            country: 'India',
            lat: 12.29,
            lon: 76.64,
          ),
        ],
      );

      c.onQueryChanged('mys');
      await tester.pump(_settle);
      expect(c.status, PlaceSearchStatus.results);

      c.onQueryChanged('');
      expect(c.status, PlaceSearchStatus.idle);
      expect(c.suggestions, isEmpty);
      expect(c.hasQuery, isFalse);
    });

    testWidgets('highlight movement clamps at both ends', (tester) async {
      final c = await controllerFor(
        tester,
        fetcher: (q, {state}) async => _gazetteer
            .where((e) => (e['name'] as String).toLowerCase().contains(q))
            .map((e) => WeatherSuggestion.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

      c.onQueryChanged('bengaluru');
      await tester.pump(_settle);
      expect(c.highlightIndex, 0);

      c.moveHighlight(-1);
      expect(c.highlightIndex, 0, reason: 'stops at the top');

      c.moveHighlight(1);
      expect(c.highlightIndex, 1);

      c.moveHighlight(5);
      expect(c.highlightIndex, 1, reason: 'stops at the bottom');
    });

    testWidgets('select pins the exact place used for the weather fetch',
        (tester) async {
      final c = await controllerFor(
        tester,
        fetcher: (q, {state}) async => _gazetteer
            .where((e) => (e['name'] as String).toLowerCase().contains(q))
            .map((e) => WeatherSuggestion.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

      c.onQueryChanged('bengaluru');
      await tester.pump(_settle);

      final target =
          c.suggestions.firstWhere((p) => p.name == 'Bengaluru Rural');
      c.select(target);

      expect(c.selected, target);
      expect(c.query, 'Bengaluru Rural, Karnataka, India');
      expect(c.resolvable, target);
    });
  });

  group('PlaceSearchPane', () {
    testWidgets('shows a prompt before anything is typed', (tester) async {
      await _openPane(tester, client: _searchClient());

      expect(
          find.text('Search for your village, town or city'), findsOneWidget);
      expect(find.text('Place or city'), findsOneWidget);
      expect(find.text('All states'), findsOneWidget);
    });

    testWidgets('typing shows debounced Indian suggestions with full labels',
        (tester) async {
      final log = <String>[];
      await _openPane(tester, client: _searchClient(callLog: log));

      await tester.enterText(find.byType(TextField), 'beng');
      await tester.pump(const Duration(milliseconds: 100));
      expect(log, isEmpty, reason: 'still inside the debounce window');

      await tester.pump(_settle);

      expect(find.text('Bengaluru'), findsOneWidget);
      // Both hits sit in Karnataka, so the subtitle repeats once per row.
      expect(find.text('Karnataka, India'), findsNWidgets(2));
      expect(find.text('Bengaluru Rural'), findsOneWidget);
      expect(find.text('2 matches in India'), findsOneWidget);
    });

    testWidgets('selecting a suggestion reports the exact coordinates',
        (tester) async {
      final selection = await _openPane(tester, client: _searchClient());

      await tester.enterText(find.byType(TextField), 'bengaluru');
      await tester.pump(_settle);
      await tester.tap(find.text('Bengaluru'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final chosen = selection.value;
      expect(chosen, isNotNull);
      expect(chosen!.name, 'Bengaluru');
      expect(chosen.region, 'Karnataka');
      expect(chosen.country, 'India');
      expect(chosen.lat, 12.97);
      expect(chosen.lon, 77.59);
    });

    testWidgets('the state filter narrows suggestions to that state',
        (tester) async {
      final log = <String>[];
      await _openPane(tester, client: _searchClient(callLog: log));

      // A query that matches two states.
      await tester.enterText(find.byType(TextField), 'm');
      await tester.pump(_settle);
      expect(find.text('Mysuru'), findsOneWidget);
      expect(find.text('Mumbai'), findsOneWidget);

      await tester.tap(find.text('All states'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maharashtra').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(log.last, 'm|Maharashtra');
      expect(find.text('Mumbai'), findsOneWidget);
      expect(find.text('Mysuru'), findsNothing);
    });

    testWidgets('a query with no Indian match shows the empty state',
        (tester) async {
      await _openPane(tester, client: _searchClient());

      await tester.enterText(find.byType(TextField), 'qqzzxx');
      await tester.pump(_settle);

      expect(find.text('No matching places in India'), findsOneWidget);
      expect(find.text('Show weather'), findsNothing);
    });

    testWidgets('a provider failure shows an error card with Retry',
        (tester) async {
      var broken = true;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/weather/places/states')) {
          return _json([
            {'name': 'Karnataka', 'available': true},
          ]);
        }
        if (path.endsWith('/weather/suggestions')) {
          if (broken) return http.Response('{"detail":"provider down"}', 502);
          return _json(_gazetteer.take(1).toList());
        }
        return http.Response('{"detail":"Not found"}', 404);
      });

      await _openPane(tester, client: client);
      await tester.enterText(find.byType(TextField), 'bengaluru');
      await tester.pump(_settle);

      expect(find.text('Weather service error'), findsOneWidget);
      expect(find.text('provider down'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      broken = false;
      await tester.tap(find.text('Retry'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Weather service error'), findsNothing);
      expect(find.text('Bengaluru'), findsOneWidget);
    });

    testWidgets('a 503 names the missing key instead of saying "retry"',
        (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/weather/places/states')) {
          return http.Response(
            '{"states":[{"name":"Karnataka","available":true}]}',
            200,
          );
        }
        return http.Response(
            '{"detail":"Weather service is not configured"}', 503);
      });

      await _openPane(tester, client: client);
      await tester.enterText(find.byType(TextField), 'bengaluru');
      await tester.pump(_settle);

      expect(find.text('Weather is not set up yet'), findsOneWidget);
      expect(find.textContaining('WEATHER_API_KEY'), findsOneWidget);
      // A missing server key cannot be fixed by retrying, so no Retry button.
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('an unreachable backend says so, and offers retry',
        (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/weather/places/states')) {
          return http.Response(
            '{"states":[{"name":"Karnataka","available":true}]}',
            200,
          );
        }
        throw http.ClientException('Connection refused', request.url);
      });

      await _openPane(tester, client: client);
      await tester.enterText(find.byType(TextField), 'bengaluru');
      await tester.pump(_settle);

      expect(find.text('Cannot reach the server'), findsOneWidget);
      expect(find.textContaining('port 8000'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('arrow keys move the highlight and Enter submits',
        (tester) async {
      final selection = await _openPane(tester, client: _searchClient());

      await tester.enterText(find.byType(TextField), 'bengaluru');
      await tester.pump(_settle);
      expect(find.text('2 matches in India'), findsOneWidget);

      // First row starts highlighted; move to the second.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selection.value, isNotNull);
      expect(selection.value!.name, 'Bengaluru Rural');
      expect(selection.value!.lat, 13.02);
    });

    testWidgets('Escape closes the suggestion list without choosing',
        (tester) async {
      final selection = await _openPane(tester, client: _searchClient());

      await tester.enterText(find.byType(TextField), 'bengaluru');
      await tester.pump(_settle);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(selection.value, isNull);
      // The typed text survives so the user can keep refining it.
      expect(find.text('bengaluru'), findsOneWidget);
    });

    testWidgets('the Search button resolves the top match', (tester) async {
      final selection = await _openPane(tester, client: _searchClient());

      await tester.enterText(find.byType(TextField), 'mys');
      await tester.pump(_settle);

      final button = find.text('Show weather');
      await tester.ensureVisible(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(selection.value, isNotNull);
      expect(selection.value!.name, 'Mysuru');
    });

    testWidgets('clearing the field resets to the idle prompt', (tester) async {
      await _openPane(tester, client: _searchClient());

      await tester.enterText(find.byType(TextField), 'bengaluru');
      await tester.pump(_settle);
      expect(find.text('Bengaluru'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
          find.text('Search for your village, town or city'), findsOneWidget);
      expect(find.text('Bengaluru'), findsNothing);
    });
  });
}
