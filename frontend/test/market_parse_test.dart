import 'package:flutter_test/flutter_test.dart';

import 'package:jeevandhara2/design/provenance.dart';
import 'package:jeevandhara2/models/market_price.dart';
import 'package:jeevandhara2/services/market_service.dart';

/// Representative `/market/prices` payload: one fresh A-tier row, one stale
/// C-tier row, and a meta block as the registry serves it.
const _pricesJson = '''
{
  "commodity": "Onion",
  "state": null,
  "district": null,
  "market": null,
  "rows": [
    {
      "commodity": "Onion", "variety": "Nashik Red", "grade": "FAQ",
      "state": "Karnataka", "district": "Kolar", "market": "Kolar APMC",
      "date": "2026-10-07",
      "min_price": 1300, "modal_price": 1450, "max_price": 1600,
      "unit": "quintal", "arrival_quantity": 120,
      "source": "enam",
      "_provenance": {
        "source": "enam", "attribution": "eNAM market platform",
        "confidence": "medium", "verified": true, "tier": "A",
        "fetched_at": "2026-10-07T04:00:00+00:00", "stale": false,
        "note": null,
        "freshness": "fresh", "actionable": true,
        "observed_at": "2026-10-07", "lag_days": 0.0
      }
    },
    {
      "commodity": "Onion", "variety": null, "grade": null,
      "state": "Karnataka", "district": "Chitradurga", "market": "Chitradurga APMC",
      "date": "2026-10-04",
      "min_price": 1000, "modal_price": 1050, "max_price": 1100,
      "unit": "quintal", "arrival_quantity": null,
      "source": "mandi_api",
      "_provenance": {
        "source": "mandi_api", "attribution": "community feed",
        "confidence": "low", "verified": false, "tier": "C",
        "fetched_at": "2026-10-07T04:00:00+00:00", "stale": true,
        "note": "source publishes a rolling window",
        "freshness": "stale", "actionable": false,
        "observed_at": "2026-10-04", "lag_days": 3.0
      }
    }
  ],
  "meta": {
    "source": "enam", "confidence": "medium", "verified": true,
    "attribution": "eNAM market platform", "tier": "A",
    "fetched_at": "2026-10-07T04:00:00+00:00", "stale": false, "note": null
  }
}
''';

const _historyJson = '''
{
  "commodity": "Onion", "state": "Karnataka", "days": 30,
  "rows": [
    {"date": "2026-10-01", "modal_price": 1320, "min_price": 1200,
     "max_price": 1440, "data_points": 12},
    {"date": "2026-10-02", "modal_price": null, "min_price": 1000,
     "max_price": 1500, "data_points": 0},
    {"date": "2026-10-03", "modal_price": 1400, "min_price": 1350,
     "max_price": 1470, "data_points": 9}
  ],
  "meta": {"source": "storage", "tier": "C", "confidence": "medium",
           "verified": true, "attribution": "our own stored rows",
           "fetched_at": "2026-10-07T04:00:00+00:00", "stale": false,
           "note": null}
}
''';

const _statusJson = '''
{
  "live": false,
  "prices": "stale",
  "arrivals": "unavailable",
  "demand_capable": false,
  "checked_at": "2026-10-07T04:05:00+00:00",
  "sources": [
    {"name": "data_gov_in", "enabled": false, "verified": false,
     "confidence": "high", "attribution": "data.gov.in",
     "tier": "A", "kind": "price", "dev_only": false,
     "disabled_reason": "no DATA_GOV_API_KEY configured",
     "verification_note": null, "last_error": null,
     "last_success_at": null},
    {"name": "enam", "enabled": true, "verified": true,
     "confidence": "medium", "attribution": "eNAM market platform",
     "tier": "A", "kind": "price", "dev_only": false,
     "disabled_reason": null, "verification_note": "live payload parsed",
     "last_error": null, "last_success_at": "2026-10-07T03:45:00+00:00"},
    {"name": "mandi_api", "enabled": true, "verified": true,
     "confidence": "low", "attribution": "community feed",
     "tier": "C", "kind": "price", "dev_only": true,
     "disabled_reason": null, "verification_note": null,
     "last_error": "upstream HTTP 500",
     "last_success_at": "2026-09-30T02:00:00+00:00"}
  ],
  "notes": ["Traded quantity is not published by any public endpoint."]
}
''';

const _commoditiesJson = '''
{
  "items": [
    {"commodity": "Potato", "aliases": ["Aloo"], "has_data": false},
    {"commodity": "Onion", "aliases": ["Pyaz", "ಈರುಳ್ಳಿ"], "has_data": true},
    {"commodity": "Tomato", "aliases": ["Tamato"], "has_data": false}
  ]
}
''';

const _mandisJson = '''
{
  "items": [
    {"market": "Kolar APMC", "district": "Kolar", "state": "Karnataka",
     "last_observed": "2026-10-07", "observations": 42, "has_data": true}
  ]
}
''';

void main() {
  group('parsePricePage', () {
    final page = parsePricePage(_pricesJson);

    test('keeps the meta block as the page-level provenance', () {
      expect(page.commodity, 'Onion');
      expect(page.source, 'enam');
      expect(page.provenance.tier, DataTier.a);
      expect(page.provenance.verified, isTrue);
    });

    test('every row carries its own provenance, not just the page one', () {
      expect(page.rows, hasLength(2));
      expect(page.rows.first.provenance.tier, DataTier.a);
      expect(page.rows.last.provenance.tier, DataTier.c);
      expect(page.rows.last.provenance.freshness, Freshness.stale);
      expect(page.rows.last.provenance.actionable, isFalse);
    });

    test('a stale row is never counted as actionable', () {
      expect(page.hasActionable, isTrue); // the fresh one still is
      expect(page.rows.last.provenance.actionable, isFalse);
    });

    test('headline price prefers modal and falls back to the range midpoint', () {
      expect(page.rows.first.headlinePrice, 1450);
      final midOnly = MarketPriceFromJsonOnly.midpointRow();
      expect(midOnly.headlinePrice, 1200);
    });

    test('priceLabel is labelled and never a bare zero', () {
      expect(page.rows.first.priceLabel, '\u20B91450/quintal');
      expect(_noPriceRow().priceLabel, 'Price not reported');
    });

    test('observedLabel reports the observation age, not the fetch time', () {
      expect(page.rows.first.observedLabel, '2026-10-07 (today)');
      expect(page.rows.last.observedLabel, '2026-10-04 (3 day(s) ago)');
    });
  });

  group('parsePriceHistory', () {
    test('drops days that have no modal price rather than interpolating', () {
      final h = parsePriceHistory(_historyJson);
      expect(h.points.map((p) => p.date.day), [1, 3]);
      expect(h.points.first.modalPrice, 1320);
      expect(h.points.first.dataPoints, 12);
      expect(h.provenance.tier, DataTier.c);
    });
  });

  group('parseMarketStatus', () {
    final s = parseMarketStatus(_statusJson);

    test('lists only untrusted price feeds as broken', () {
      expect(s.live, isFalse);
      expect(s.prices, 'stale');
      expect(s.broken.map((b) => b.name), ['data_gov_in']);
      expect(s.broken.single.disabledReason, 'no DATA_GOV_API_KEY configured');
    });

    test('a serving feed with a recent error is not broken', () {
      expect(s.sources.any((x) => x.name == 'mandi_api' && x.trusted), isTrue);
      expect(s.sources.firstWhere((x) => x.name == 'enam').trusted, isTrue);
    });

    test('notes survive so the UI can print them verbatim', () {
      expect(s.notes.single, contains('Traded quantity'));
    });
  });

  group('reference lists', () {
    test('commodities with data sort to the front of the picker', () {
      final items = parseCommodities(_commoditiesJson);
      expect(items.first.commodity, 'Onion');
      expect(items.first.hasData, isTrue);
      expect(items.first.aliases, contains('Pyaz'));
      expect(items, hasLength(3));
    });

    test('mandis come back with their observation counts', () {
      final items = parseMandis(_mandisJson);
      expect(items.single.market, 'Kolar APMC');
      expect(items.single.observations, 42);
      expect(items.single.lastObserved, isNotNull);
    });

    test('non-list bodies degrade to empty instead of throwing', () {
      expect(parseMandis('{"error": 1}'), isEmpty);
      expect(parseCommodities('null'), isEmpty);
    });
  });

  group('503 detail parsing', () {
    test('reads attempts and kind from FastAPI detail', () {
      const detail = {
        'kind': 'price',
        'message': 'No market source is available.',
        'attempts': [
          {'source': 'data_gov_in', 'reason': 'disabled'},
          {'source': 'enam', 'reason': 'HTTP 500'},
        ],
      };
      final attempts = parseAttempts(detail);
      expect(attempts, hasLength(2));
      expect(attempts.first.source, 'data_gov_in');
      expect(attempts.last.reason, 'HTTP 500');
    });

    test('an absent or malformed attempts block is empty, not a crash', () {
      expect(parseAttempts(null), isEmpty);
      expect(parseAttempts('nope'), isEmpty);
      expect(parseAttempts({'attempts': 'x'}), isEmpty);
    });
  });

  group('tier parsing', () {
    test('unknown tiers stay unknown instead of defaulting to A', () {
      expect(DataTier.parse('A'), DataTier.a);
      expect(DataTier.parse('d'), DataTier.d);
      expect(DataTier.parse('E'), DataTier.unknown);
      expect(DataTier.parse(null), DataTier.unknown);
      expect(DataTier.parse('').isKnown, isFalse);
      expect(DataTier.unknown.code, '?');
    });
  });
}

MarketPrice _noPriceRow() => MarketPrice.fromJson(const {
      'commodity': 'Onion',
      'market': 'Kolar APMC',
      'date': null,
      'min_price': null,
      'modal_price': null,
      'max_price': null,
    });

/// A row whose source published only a min and a max - no modal.
class MarketPriceFromJsonOnly {
  static MarketPrice midpointRow() => MarketPrice.fromJson(const {
        'commodity': 'Onion',
        'market': 'Kolar APMC',
        'min_price': 1000,
        'modal_price': null,
        'max_price': 1400,
        'unit': 'quintal',
      });
}
