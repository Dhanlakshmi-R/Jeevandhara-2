import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:jeevandhara2/screens/marketplace_screen.dart';
import 'package:jeevandhara2/screens/my_crops_screen.dart';
import 'package:jeevandhara2/screens/sell_crop_screen.dart';
import 'package:jeevandhara2/services/crops_service.dart';
import 'package:jeevandhara2/services/marketplace_service.dart';
import 'package:jeevandhara2/theme/app_theme.dart';
import 'package:jeevandhara2/widgets/ui/app_input.dart';

const _cropsBody = '''
[
  {"id": 1, "name": "Tomato", "emoji": "\uD83C\uDF45", "quantity": 250,
   "unit": "kg", "expected_price": 28, "location": "Dharwad",
   "status": "active", "created_at": "2026-10-30T10:00:00"},
  {"id": 2, "name": "Onion", "emoji": "\uD83E\uDDC5", "quantity": 1,
   "unit": "quintal", "expected_price": null, "status": "hidden"}
]
''';

const _productsBody = '''
{"items": [
  {"id": 3, "poster": "Demo Farmer", "poster_id": 4, "name": "Urea",
   "emoji": "\uD83C\uDF31", "category": "Fertilizers", "price": 270,
   "unit": "bag", "rating": null, "in_stock": true}
]}
''';

const _createdCropJson = '''
{"id": 9, "name": "Tomato", "emoji": "\uD83C\uDF45", "quantity": 12,
 "unit": "kg", "expected_price": 30, "status": "active",
 "created_at": "2026-11-01T10:00:00"}
''';

CropsService _cropsReturning(String body, {int status = 200}) {
  return CropsService(
    baseUrl: 'http://test',
    client: MockClient((request) async => http.Response(body, status,
        headers: {'content-type': 'application/json'})),
  );
}

MarketplaceService _productsReturning(String body, {int status = 200}) {
  return MarketplaceService(
    baseUrl: 'http://test',
    client: MockClient((request) async => http.Response(body, status,
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

Finder _field(String label) => find.byWidgetPredicate(
      (widget) => widget is AppTextField && widget.label == label,
    );

void main() {
  group('MyCropsScreen', () {
    testWidgets('lists real crops and hides rows the farmer took down',
        (tester) async {
      await _pump(tester, MyCropsScreen(service: _cropsReturning(_cropsBody)));

      expect(find.text('Tomato'), findsOneWidget);
      expect(find.textContaining('250 kg'), findsOneWidget);
      expect(find.text('\u20B928/kg'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('1 crop listed'), findsOneWidget);
      // The hidden row is kept server-side for history but is not listed.
      expect(find.text('Onion'), findsNothing);
    });

    testWidgets('no rows shows the honest empty state, not an error',
        (tester) async {
      await _pump(tester, MyCropsScreen(service: _cropsReturning('[]')));

      expect(find.text('No crops listed yet'), findsOneWidget);
      expect(find.text('List a crop'), findsOneWidget);
      expect(find.text('Could not load your crops'), findsNothing);
    });

    testWidgets('a failed read shows a retryable error state', (tester) async {
      await _pump(
        tester,
        MyCropsScreen(
            service: _cropsReturning('{"detail": "down"}', status: 503)),
      );

      expect(find.text('Could not load your crops'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('MarketplaceScreen', () {
    testWidgets('lists real products; no rating means no fake stars',
        (tester) async {
      await _pump(
        tester,
        MarketplaceScreen(service: _productsReturning(_productsBody)),
      );

      expect(find.text('Urea'), findsOneWidget);
      expect(find.text('\u20B9270/bag'), findsOneWidget);
      expect(find.text('Fertilizers'), findsWidgets);
      expect(find.text('No reviews'), findsOneWidget);
      expect(find.text('1 input listed'), findsOneWidget);
      // No reviews -> no star at all, never a fabricated figure.
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('no products invites the user to list the first one',
        (tester) async {
      await _pump(
        tester,
        MarketplaceScreen(service: _productsReturning('{"items": []}')),
      );

      expect(find.text('No inputs listed yet'), findsOneWidget);
      expect(find.text('List an input'), findsWidgets);
      expect(find.text('Could not load the marketplace'), findsNothing);
    });

    testWidgets('a failed read shows a retryable error state', (tester) async {
      await _pump(
        tester,
        MarketplaceScreen(
            service: _productsReturning('{"detail": "down"}', status: 503)),
      );

      expect(find.text('Could not load the marketplace'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('SellCropScreen', () {
    testWidgets('posts the farmer\u2019s figures and pops with the real row',
        (tester) async {
      late http.Request captured;
      final service = CropsService(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            _createdCropJson,
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        navigatorKey: navKey,
        home: const Scaffold(body: SizedBox()),
      ));
      navKey.currentState!.push(
        MaterialPageRoute(builder: (_) => SellCropScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(_field('Crop type'), 'Tomato');
      await tester.enterText(_field('Quantity'), '12');
      await tester.enterText(_field('Expected price'), '30');
      await tester.tap(find.text('Post Crop for Traders'));
      await tester.pumpAndSettle();

      expect(captured.method, 'POST');
      expect(captured.url.path, '/my-crops');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['name'], 'Tomato');
      expect(body['quantity'], 12);
      expect(body['expected_price'], 30);
      // The form itself is gone: the route popped with the server's row.
      expect(find.text('Post Crop for Traders'), findsNothing);
    });
  });
}
