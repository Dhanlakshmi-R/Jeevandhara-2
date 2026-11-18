import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:jeevandhara2/screens/market_prices_screen.dart';
import 'package:jeevandhara2/services/market_service.dart';

/// One fresh A-tier row and one stale C-tier row, so the screen has to cope
/// with a mixed-age window rather than a uniformly rosy one.
const _pricesJson = '''
{
  "commodity": "Onion",
  "rows": [
    {
      "commodity": "Onion", "variety": "Nashik Red",
      "state": "Karnataka", "district": "Kolar", "market": "Kolar APMC",
      "date": "2026-10-07",
      "min_price": 1300, "modal_price": 1450, "max_price": 1600,
      "unit": "quintal",
      "_provenance": {"source": "enam", "attribution": "eNAM",
        "confidence": "medium", "verified": true, "tier": "A",
        "fetched_at": "2026-10-07T04:00:00", "stale": false, "note": null,
        "freshness": "fresh", "actionable": true,
        "observed_at": "2026-10-07", "lag_days": 0.0}
    },
    {
      "commodity": "Onion",
      "state": "Karnataka", "district": "Chitradurga", "market": "Chitradurga APMC",
      "date": "2026-10-04",
      "min_price": 1000, "modal_price": 1050, "max_price": 1100,
      "unit": "quintal",
      "_provenance": {"source": "mandi_api", "attribution": "community feed",
        "confidence": "low", "verified": false, "tier": "C",
        "fetched_at": "2026-10-07T04:00:00", "stale": true,
        "note": "source publishes a rolling window",
        "freshness": "stale", "actionable": false,
        "observed_at": "2026-10-04", "lag_days": 3.0}
    }
  ],
  "meta": {"source": "enam", "confidence": "medium", "verified": true,
    "attribution": "eNAM", "tier": "A",
    "fetched_at": "2026-10-07T04:00:00", "stale": false, "note": null}
}
''';

const _commoditiesJson = '''
{
  "items": [
    {"commodity": "Onion", "aliases": ["Pyaz"], "has_data": true}
  ]
}
''';

const _mandisJson = '{"items": []}';

const _statusJson = '''
{
  "live": false, "prices": "stale", "arrivals": "unavailable",
  "demand_capable": false, "checked_at": "2026-10-07T04:05:00",
  "sources": [
    {"name": "data_gov_in", "enabled": false, "verified": false,
     "confidence": "high", "attribution": "data.gov.in", "tier": "A",
     "kind": "price", "dev_only": false,
     "disabled_reason": "no DATA_GOV_API_KEY configured"},
    {"name": "enam", "enabled": true, "verified": true,
     "confidence": "medium", "attribution": "eNAM", "tier": "A",
     "kind": "price", "dev_only": false}
  ],
  "notes": ["Traded quantity is not published by any public endpoint."]
}
''';

const _statusDownJson = '''
{
  "live": false, "prices": "unavailable", "arrivals": "unavailable",
  "demand_capable": false, "checked_at": "2026-10-07T04:05:00",
  "sources": [
    {"name": "enam", "enabled": false, "verified": false,
     "confidence": "medium", "attribution": "eNAM", "tier": "A",
     "kind": "price", "dev_only": false,
     "disabled_reason": "upstream HTTP 500"}
  ],
  "notes": []
}
''';

const _pricesDownDetail = '''
{"detail": {"kind": "price",
  "message": "No market source is available right now.",
  "attempts": [
    {"source": "data_gov_in", "reason": "disabled"},
    {"source": "enam", "reason": "HTTP 500"}
  ]}}
''';

MockClient _client(http.Response Function(Uri uri) respond) =>
    MockClient((request) async => respond(request.url));

Widget _screen(MockClient client) => MaterialApp(
      home: Scaffold(body: MarketPricesScreen(service: MarketService(client: client))),
    );

/// Routes a request to the canned body for its path, with prices optionally
/// failing so we can exercise the honest-error path.
MockClient _routing({String? priceStatus}) => MockClient((request) async {
      switch (request.url.path) {
        case '/market/status':
          return http.Response(
            priceStatus == 'down' ? _statusDownJson : _statusJson,
            200,
            headers: {'content-type': 'application/json'},
          );
        case '/market/commodities':
          return http.Response(_commoditiesJson, 200);
        case '/market/mandis':
          return http.Response(_mandisJson, 200);
        case '/market/prices':
          if (priceStatus == 'down') {
            return http.Response(
              _pricesDownDetail,
              503,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(_pricesJson, 200);
        default:
          return http.Response('{"detail":"not found"}', 404);
      }
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders rows with tier, freshness and the observation date',
      (tester) async {
    await tester.pumpWidget(_screen(_routing()));
    await tester.pumpAndSettle();

    expect(find.text('Onion'), findsWidgets);
    expect(find.text('\u20B91450/quintal'), findsOneWidget);
    // Provenance appears on the banner (feeds) and on each row (source chips).
    expect(find.text('enam'), findsWidgets);
    expect(find.text('mandi_api'), findsWidgets);
    // The stale row's own age is printed next to it.
    expect(find.textContaining('3 day(s) ago'), findsOneWidget);
    // And the strip above the list says why the window is not all current.
    expect(find.textContaining('Oldest rate is 3 day(s) old'), findsOneWidget);
    // The A-tier banner note is shown verbatim.
    expect(
      find.text('Traded quantity is not published by any public endpoint.'),
      findsOneWidget,
    );
  });

  testWidgets('a stale row carries a do-not-sell warning',
      (tester) async {
    await tester.pumpWidget(_screen(_routing()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Too old to act on'),
      findsWidgets,
    );
    // The fresh row must not carry the warning: find exactly one (stale row).
    expect(find.textContaining('Too old to act on'), findsOneWidget);
  });

  testWidgets('503 shows the per-source reasons instead of an empty list',
      (tester) async {
    await tester.pumpWidget(_screen(_routing(priceStatus: 'down')));
    await tester.pumpAndSettle();

    expect(find.text('No market data'), findsNothing);
    expect(
      find.textContaining('No market source is available right now.'),
      findsOneWidget,
    );
    expect(find.textContaining('data_gov_in: disabled'), findsOneWidget);
    expect(find.textContaining('enam: HTTP 500'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the status banner names each feed that is off, with its reason',
      (tester) async {
    await tester.pumpWidget(_screen(_routing()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no DATA_GOV_API_KEY configured'),
      findsOneWidget,
    );
    // Stale-but-present rates are not called "live" and not called an outage
    // either: the banner says what is actually true.
    expect(find.textContaining('Stored rates only'), findsOneWidget);
    expect(find.textContaining('Live market data'), findsNothing);
  });

  testWidgets('a wholly-off status still prints the stated reason',
      (tester) async {
    await tester.pumpWidget(_screen(_routing(priceStatus: 'down')));
    await tester.pumpAndSettle();

    expect(find.textContaining('upstream HTTP 500'), findsWidgets);
    expect(find.textContaining('Market data unavailable'), findsOneWidget);
  });

  testWidgets('search narrows the rows', (tester) async {
    await tester.pumpWidget(_screen(_routing()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'chitradurga');
    await tester.pumpAndSettle();

    expect(find.textContaining('Kolar APMC'), findsNothing);
    expect(find.textContaining('Chitradurga APMC'), findsWidgets);
  });

  testWidgets('no rows yields the honest empty state, not a fabricated list',
      (tester) async {
    final client = _client((uri) {
      if (uri.path == '/market/status') {
        return http.Response(_statusJson, 200);
      }
      if (uri.path == '/market/commodities') {
        return http.Response(_commoditiesJson, 200);
      }
      if (uri.path == '/market/mandis') {
        return http.Response(_mandisJson, 200);
      }
      return http.Response('{"commodity":"Onion","rows":[],"meta":{}}', 200);
    });
    await tester.pumpWidget(_screen(client));
    await tester.pumpAndSettle();

    expect(find.text('No market data'), findsOneWidget);
    expect(
      find.textContaining('Nothing is shown here until a source reports one'),
      findsOneWidget,
    );
    expect(find.text('\u20B90'), findsNothing);
  });
}
