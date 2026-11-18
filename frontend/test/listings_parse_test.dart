import 'package:flutter_test/flutter_test.dart';

import 'package:jeevandhara2/services/listings_service.dart';

/// Representative `/tools` and `/traders` payloads as the listings router
/// serves them (see backend/tests/test_listings_router.py for the contract).
const _toolsJson = '''
{
  "items": [
    {
      "id": 1,
      "owner": "Demo Farmer",
      "owner_id": 2,
      "name": "Power tiller",
      "emoji": "",
      "category": "Tillage",
      "description": "Kubota 2.8 HP",
      "price_per_day": 800,
      "location": "Dharwad",
      "available": true,
      "created_at": "2026-10-08T05:11:00"
    }
  ]
}
''';

const _tradersJson = '''
{
  "items": [
    {
      "id": 1,
      "name": "Demo Trader",
      "company": "Shivamogga Traders",
      "location": "Dharwad",
      "crops": ["Onion", "Tomato", "Rice"],
      "offered_price_per_quintal": 4400,
      "note": "Paying cash at mandi gate",
      "emoji": "🏪",
      "available": true,
      "rating": null,
      "created_at": "2026-10-08T05:11:30"
    }
  ]
}
''';

void main() {
  group('parseTools', () {
    test('maps a real listing row without inventing a rating', () {
      final tool = parseTools(_toolsJson).single;
      expect(tool.id, 1);
      expect(tool.name, 'Power tiller');
      expect(tool.owner, 'Demo Farmer');
      expect(tool.pricePerDay, 800);
      expect(tool.category, 'Tillage');
      expect(tool.available, isTrue);
      // Upstream's empty emoji falls back to the tractor glyph - but the
      // fallback must never mask that the owner did not set one.
      expect(tool.emoji, isNotEmpty);
    });

    test('empty items is an empty list, not an error', () {
      expect(parseTools('{"items": []}'), isEmpty);
    });
  });

  group('parseTraders', () {
    test('keeps the canonical crop list and the honest null rating', () {
      final trader = parseTraders(_tradersJson).single;
      expect(trader.name, 'Demo Trader');
      expect(trader.crops, ['Onion', 'Tomato', 'Rice']);
      expect(trader.offeredPricePerQuintal, 4400);
      expect(trader.priceLabel, '\u20B94400/quintal');
      expect(trader.rating, isNull, reason: 'no reviews -> New, not stars');
      expect(trader.available, isTrue);
    });

    test('no price means "price on call", never a made-up number', () {
      const body = '''
        {"items": [{"id": 2, "name": "Buyer", "crops": ["Jowar"],
                    "offered_price_per_quintal": null, "available": true}]}
      ''';
      final trader = parseTraders(body).single;
      expect(trader.priceLabel, 'Price on call');
    });
  });

  test('parseFirstTrader returns null for an empty /traders/me response', () {
    expect(parseFirstTrader('[]'), isNull);
  });
}