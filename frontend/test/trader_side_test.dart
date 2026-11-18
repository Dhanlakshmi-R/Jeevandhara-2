import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:jeevandhara2/screens/trader_dashboard_screen.dart';
import 'package:jeevandhara2/services/listings_service.dart';
import 'package:jeevandhara2/services/trader_offer_store.dart';
import 'package:jeevandhara2/theme/app_theme.dart';
import 'package:jeevandhara2/widgets/ui/app_input.dart';

/// `/traders/me` returns a bare array with at most one card.
const _offerArrayJson = '''
[
  {"id": 1, "name": "Demo Trader", "company": "Shivamogga Traders",
   "location": "Dharwad", "crops": ["Onion", "Tomato"],
   "offered_price_per_quintal": 4400, "note": "Paying cash at mandi gate",
   "emoji": "\uD83C\uDFEA", "available": true, "rating": null,
   "created_at": "2026-10-08T05:11:30"}
]
''';

const _offerObjectJson = '''
{"id": 1, "name": "Demo Trader", "company": "Shivamogga Traders",
 "location": "Dharwad", "crops": ["Onion"],
 "offered_price_per_quintal": 4400, "note": "Paying cash at mandi gate",
 "emoji": "\uD83C\uDFEA", "available": true, "rating": null,
 "created_at": "2026-10-08T05:11:30"}
''';

ListingsService _service(MockClient client) =>
    ListingsService(baseUrl: 'http://test', client: client);

MockClient _returning(String body, {int status = 200}) {
  return MockClient((request) async => http.Response(
        body,
        status,
        headers: {'content-type': 'application/json'},
      ));
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
  setUp(() => TraderOfferStore.instance.reset());

  group('trader offer service', () {
    test('parseTraders accepts the bare array /traders/me returns', () {
      final trader = parseTraders(_offerArrayJson).single;
      expect(trader.id, 1);
      expect(trader.company, 'Shivamogga Traders');
      expect(trader.crops, ['Onion', 'Tomato']);
      expect(trader.priceLabel, '\u20B94400/quintal');
      expect(trader.available, isTrue);
      expect(trader.rating, isNull);
    });

    test('myOffer reads the caller card from /traders/me', () async {
      late http.Request captured;
      final service = _service(MockClient((request) async {
        captured = request;
        return http.Response(_offerArrayJson, 200,
            headers: {'content-type': 'application/json'});
      }));

      final offer = await service.myOffer();

      expect(captured.method, 'GET');
      expect(captured.url.path, '/traders/me');
      expect(offer, isNotNull);
      expect(offer!.company, 'Shivamogga Traders');
    });

    test('saveTraderOffer posts the card, price and availability', () async {
      late http.Request captured;
      final service = _service(MockClient((request) async {
        captured = request;
        return http.Response(_offerObjectJson, 201,
            headers: {'content-type': 'application/json'});
      }));

      final saved = await service.saveTraderOffer(
        company: 'Shivamogga Traders',
        crops: const ['Onion'],
        offeredPricePerQuintal: 4400,
        note: 'Paying cash at mandi gate',
        available: false,
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/traders/me');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['company'], 'Shivamogga Traders');
      expect(body['crops'], ['Onion']);
      expect(body['offered_price_per_quintal'], 4400);
      expect(body['note'], 'Paying cash at mandi gate');
      expect(body['available'], isFalse);
      expect(saved.id, 1);
    });

    test('deleteTraderOffer DELETEs /traders/me and accepts 204', () async {
      late http.Request captured;
      final service = _service(MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }));

      await service.deleteTraderOffer();

      expect(captured.method, 'DELETE');
      expect(captured.url.path, '/traders/me');
    });
  });

  group('TraderOverviewPage', () {
    testWidgets('shows the real buying card and no invented deal figures',
        (tester) async {
      await _pump(
        tester,
        TraderOverviewPage(service: _service(_returning(_offerArrayJson))),
      );

      expect(find.text('Shivamogga Traders'), findsOneWidget);
      expect(find.textContaining('Onion, Tomato'), findsOneWidget);
      expect(find.text('\u20B94400/quintal'), findsOneWidget);
      expect(find.text('Accepting offers'), findsOneWidget);
      expect(find.textContaining('Paying cash at mandi gate'), findsOneWidget);

      // The old page showed invented money, deal counts and ratings.
      expect(find.text('\u20B94,82,500'), findsNothing);
      expect(find.text('24'), findsNothing);
      expect(find.text('4.6'), findsNothing);
      expect(find.text('Active Deals'), findsNothing);
      expect(find.text('Tomato'), findsNothing);
    });

    testWidgets('no card is an honest invitation, not an error',
        (tester) async {
      await _pump(
        tester,
        TraderOverviewPage(service: _service(_returning('[]'))),
      );

      expect(find.text('No buying offer yet'), findsOneWidget);
      expect(find.text('Post an offer'), findsOneWidget);
      expect(find.text('Could not load your buying card'), findsNothing);
    });

    testWidgets('a failed read shows a retryable error state', (tester) async {
      await _pump(
        tester,
        TraderOverviewPage(
            service: _service(_returning('{"detail": "down"}', status: 503))),
      );

      expect(find.text('Could not load your buying card'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('TraderPostOfferPage', () {
    testWidgets('prefills the existing card from /traders/me', (tester) async {
      await _pump(
        tester,
        TraderPostOfferPage(service: _service(_returning(_offerArrayJson))),
      );

      expect(find.text('Edit your buying card'), findsOneWidget);
      expect(
        tester.widget<AppTextField>(_field('Crops you buy')).controller.text,
        'Onion, Tomato',
      );
      expect(
        tester
            .widget<AppTextField>(_field('Offered price per quintal'))
            .controller
            .text,
        '4400',
      );
    });

    testWidgets('publishing posts the entered card', (tester) async {
      late http.Request posted;
      final service = _service(MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }
        posted = request;
        return http.Response(_offerObjectJson, 201,
            headers: {'content-type': 'application/json'});
      }));

      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(tester, TraderPostOfferPage(service: service));

      await tester.enterText(_field('Crops you buy'), 'Onion, Tomato');
      await tester.enterText(_field('Offered price per quintal'), '4400');
      await tester.enterText(
          _field('Company / shop name'), 'Shivamogga Traders');
      await tester.tap(find.text('Publish card'));
      await tester.pumpAndSettle();

      expect(posted.method, 'POST');
      expect(posted.url.path, '/traders/me');
      final body = jsonDecode(posted.body) as Map<String, dynamic>;
      expect(body['crops'], ['Onion', 'Tomato']);
      expect(body['offered_price_per_quintal'], 4400);
      expect(body['company'], 'Shivamogga Traders');
      expect(body['available'], isTrue);

      expect(find.text('Your buying card is live. Farmers can now find you.'),
          findsOneWidget);
      expect(TraderOfferStore.instance.offer?.id, 1);
    });

    testWidgets('requires at least one crop instead of posting an empty card',
        (tester) async {
      await _pump(
        tester,
        TraderPostOfferPage(service: _service(_returning('[]'))),
      );

      await tester.tap(find.text('Publish card'));
      await tester.pump();

      expect(find.text('List at least one crop you buy.'), findsOneWidget);
      expect(TraderOfferStore.instance.offer, isNull);
    });
  });
}
