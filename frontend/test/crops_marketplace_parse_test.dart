import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:jeevandhara2/services/crops_service.dart';
import 'package:jeevandhara2/services/marketplace_service.dart';

/// Representative rows as the routers serve them (see
/// backend/tests/test_mycrops_router.py and test_marketplace_router.py).
const _cropJson = '''
{
  "id": 9,
  "name": "Tomato",
  "emoji": "\uD83C\uDF45",
  "quantity": 12,
  "unit": "kg",
  "expected_price": 30,
  "location": "Dharwad",
  "description": "Grade A",
  "harvest_date": "2026-11-15",
  "status": "active",
  "created_at": "2026-10-30T10:00:00"
}
''';

const _productJson = '''
{
  "id": 3,
  "poster": "Demo Farmer",
  "poster_id": 4,
  "name": "Urea",
  "emoji": "\uD83C\uDF31",
  "category": "Fertilizers",
  "price": 270.5,
  "unit": "bag",
  "rating": null,
  "in_stock": true,
  "created_at": "2026-10-20T09:00:00"
}
''';

MockClient _mock(void Function(http.Request request) capture, String body,
    {int status = 200}) {
  return MockClient((request) async {
    capture(request);
    return http.Response(
      body,
      status,
      headers: {'content-type': 'application/json'},
    );
  });
}

void main() {
  group('parseCrops', () {
    test('reads the bare array the /my-crops router returns', () {
      final crops = parseCrops('[$_cropJson]');
      expect(crops, hasLength(1));
      final crop = crops.single;
      expect(crop.id, 9);
      expect(crop.name, 'Tomato');
      expect(crop.quantityLabel, '12 kg');
      expect(crop.priceLabel, '\u20B930/kg');
      expect(crop.statusLabel, 'Active');
      expect(crop.harvestDate, DateTime(2026, 11, 15));
      expect(crop.location, 'Dharwad');
    });

    test('accepts an {items: []} envelope and an empty array alike', () {
      expect(parseCrops('{"items": []}'), isEmpty);
      expect(parseCrops('[]'), isEmpty);
    });

    test('an absent asking price is reported as absent, never as \u20B90', () {
      final crop =
          parseCrops('[{"id": 1, "name": "Onion", "quantity": 4}]').single;
      expect(crop.expectedPrice, isNull);
      expect(crop.priceLabel, 'No asking price');
    });

    test('status labels follow the lifecycle', () {
      expect(
        parseCrops('[{"id": 1, "name": "Onion", "quantity": 4, '
                '"status": "sold"}]')
            .single
            .statusLabel,
        'Sold',
      );
      expect(
        parseCrops('[{"id": 1, "name": "Onion", "quantity": 4, '
                '"status": "hidden"}]')
            .single
            .statusLabel,
        'Hidden',
      );
    });

    test('listedAgo derives age from created_at with an injectable clock', () {
      final crop = parseCrops('[$_cropJson]').single;
      expect(crop.listedAgo(DateTime(2026, 11, 2, 10)), '3 days ago');
      expect(crop.listedAgo(DateTime(2026, 10, 30, 10)), 'Today');
      expect(
        parseCrops('[{"id": 1, "name": "Onion", "quantity": 4}]')
            .single
            .listedAgo(),
        'Date unknown',
      );
    });
  });

  group('CropsService writes', () {
    test('create posts the farmer\u2019s own figures and parses the row',
        () async {
      late http.Request captured;
      final service = CropsService(
        baseUrl: 'http://test',
        client: _mock((r) => captured = r, _cropJson, status: 201),
      );

      final created = await service.create(
        name: 'Tomato',
        quantity: 12,
        unit: 'kg',
        expectedPrice: 30,
        location: 'Dharwad',
        description: 'Grade A',
        harvestDate: DateTime(2026, 11, 15),
        emoji: '\uD83C\uDF45',
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/my-crops');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['name'], 'Tomato');
      expect(body['quantity'], 12);
      expect(body['expected_price'], 30);
      expect(body['harvest_date'], '2026-11-15');
      expect(body['emoji'], '\uD83C\uDF45');
      expect(created.id, 9);
      expect(created.name, 'Tomato');
    });

    test('create omits a price the farmer did not state', () async {
      late http.Request captured;
      final service = CropsService(
        baseUrl: 'http://test',
        client: _mock((r) => captured = r, _cropJson, status: 201),
      );

      await service.create(name: 'Tomato', quantity: 12);

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body.containsKey('expected_price'), isFalse);
    });

    test('retire DELETEs the row and accepts an empty 204', () async {
      late http.Request captured;
      final service = CropsService(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          captured = request;
          return http.Response('', 204);
        }),
      );

      await service.retire(7);

      expect(captured.method, 'DELETE');
      expect(captured.url.path, '/my-crops/7');
    });

    test('setStatus PATCHes only the lifecycle field', () async {
      late http.Request captured;
      final service = CropsService(
        baseUrl: 'http://test',
        client: _mock((r) => captured = r, _cropJson),
      );

      final updated = await service.setStatus(9, 'sold');

      expect(captured.method, 'PATCH');
      expect(captured.url.path, '/my-crops/9');
      expect(jsonDecode(captured.body), {'status': 'sold'});
      expect(updated.id, 9);
    });
  });

  group('parseProducts', () {
    test('reads the {items: [...]} envelope the router returns', () {
      final products = parseProducts('{"items": [$_productJson]}');
      expect(products, hasLength(1));
      final product = products.single;
      expect(product.id, 3);
      expect(product.name, 'Urea');
      expect(product.priceLabel, '\u20B9270.5/bag');
      expect(product.hasRating, isFalse);
      expect(product.isOwnedBy(4), isTrue);
      expect(product.isOwnedBy(5), isFalse);
    });

    test('a null rating stays null instead of becoming zero stars', () {
      final product = parseProduct(_productJson);
      expect(product.rating, isNull);
      expect(product.hasRating, isFalse);
    });

    test('a real rating is kept', () {
      final product = parseProduct(
        '{"id": 3, "name": "Urea", "price": 270, "rating": 4.5}',
      );
      expect(product.rating, 4.5);
      expect(product.hasRating, isTrue);
    });
  });

  group('MarketplaceService writes', () {
    test('create posts the listing and parses the created row', () async {
      late http.Request captured;
      final service = MarketplaceService(
        baseUrl: 'http://test',
        client: _mock((r) => captured = r, _productJson, status: 201),
      );

      final created = await service.create(
        name: 'Urea',
        price: 270.5,
        category: 'Fertilizers',
        unit: 'bag',
        description: '46% nitrogen',
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/marketplace');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['name'], 'Urea');
      expect(body['price'], 270.5);
      expect(body['category'], 'Fertilizers');
      expect(body['unit'], 'bag');
      expect(body['in_stock'], isTrue);
      expect(created.id, 3);
    });

    test('products forwards the category and stock filters', () async {
      late http.Request captured;
      final service = MarketplaceService(
        baseUrl: 'http://test',
        client: _mock((r) => captured = r, '{"items": []}'),
      );

      await service.products(category: 'Seeds', inStock: true);

      expect(captured.url.path, '/marketplace');
      expect(captured.url.queryParameters['category'], 'Seeds');
      expect(captured.url.queryParameters['in_stock'], 'true');
      expect(captured.url.queryParameters.containsKey('q'), isFalse);
    });

    test('retire DELETEs the owned row', () async {
      late http.Request captured;
      final service = MarketplaceService(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          captured = request;
          return http.Response('', 204);
        }),
      );

      await service.retire(3);

      expect(captured.method, 'DELETE');
      expect(captured.url.path, '/marketplace/3');
    });
  });
}
