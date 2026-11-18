import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:jeevandhara2/screens/find_traders_screen.dart';
import 'package:jeevandhara2/screens/tool_rental_screen.dart';
import 'package:jeevandhara2/services/listings_service.dart';
import 'package:jeevandhara2/theme/app_theme.dart';

const _toolsBody = '''
{"items": [{"id": 1, "owner": "Demo Farmer", "name": "Power tiller",
            "category": "Tillage", "price_per_day": 800,
            "location": "Dharwad", "available": true}]}
''';

const _tradersBody = '''
{"items": [{"id": 1, "name": "Demo Trader", "company": "Shivamogga Traders",
            "location": "Dharwad", "crops": ["Onion", "Tomato"],
            "offered_price_per_quintal": 4400, "note": "Cash at mandi",
            "available": true, "rating": null}]}
''';

ListingsService _serviceReturning(String body, {int status = 200}) {
  return ListingsService(
    client: MockClient((request) async => http.Response(
        body,
        status,
        headers: {'content-type': 'application/json'})),
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ToolRentalScreen', () {
    testWidgets('lists real tools and their categories', (tester) async {
      await _pump(tester,
          ToolRentalScreen(service: _serviceReturning(_toolsBody)));
      expect(find.text('Power tiller'), findsOneWidget);
      expect(find.text('Tillage'), findsWidgets);
      expect(find.text('₹800'), findsOneWidget);
      expect(find.text('No tools listed yet'), findsNothing);
    });

    testWidgets('empty backend shows the honest empty state, not an error',
        (tester) async {
      await _pump(
          tester, ToolRentalScreen(service: _serviceReturning('{"items": []}')));
      expect(find.text('No tools listed yet'), findsOneWidget);
      expect(find.text('List your tool'), findsOneWidget);
      expect(find.text('Could not load tools'), findsNothing);
    });

    testWidgets('a failed read shows a retryable error state', (tester) async {
      await _pump(tester,
          ToolRentalScreen(service: _serviceReturning('{"detail": "down"}', status: 503)));
      expect(find.text('Could not load tools'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('FindTradersScreen', () {
    testWidgets('shows a trader card; no rating means no fake stars',
        (tester) async {
      await _pump(tester,
          FindTradersScreen(service: _serviceReturning(_tradersBody)));
      expect(find.text('Demo Trader'), findsOneWidget);
      expect(find.text('Shivamogga Traders'), findsOneWidget);
      expect(find.text('Onion, Tomato: ₹4400/quintal'), findsOneWidget);
      // No reviews -> no star at all, never a fabricated figure.
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('no registered traders invites the user to register',
        (tester) async {
      await _pump(tester,
          FindTradersScreen(service: _serviceReturning('{"items": []}')));
      expect(find.text('No traders registered yet'), findsOneWidget);
      expect(find.text('Register as a trader'), findsOneWidget);
    });

    testWidgets('a failed read shows a retryable error state', (tester) async {
      await _pump(tester,
          FindTradersScreen(service: _serviceReturning('{"detail": "down"}', status: 503)));
      expect(find.text('Could not load traders'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}