import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:jeevandhara2/design/provenance.dart';
import 'package:jeevandhara2/models/market_price.dart';
import 'api_service.dart' show ApiService, ApiException;

/// Client for the backend's `/market` endpoints.
///
/// Two rules this service keeps:
///
/// 1. **Never falls back to a local sample.** A failed read throws
///    [MarketUnavailableException] carrying the per-source reasons, so the
///    screen can say *why* rather than rendering an empty list that reads as
///    "no prices today".
/// 2. **Parsing is separated from I/O.** `parse*` functions are pure, so the
///    response-to-model contract is testable without any HTTP.
class MarketService {
  final String baseUrl;
  final http.Client? client;

  MarketService({this.baseUrl = ApiService.baseUrl, this.client});

  http.Client _http() => client ?? http.Client();

  bool _ownsClient() => client == null;

  Future<String> _getJson(Uri uri) async {
    final c = _http();
    try {
      late final http.Response response;
      try {
        response = await c.get(uri, headers: {'Accept': 'application/json'});
      } on http.ClientException {
        throw ApiException(
          'Cannot reach the server at $baseUrl. Is the backend running?',
        );
      }
      final body = response.body;
      if (response.statusCode == 503) {
        throw MarketUnavailableException(
          _detailMessage(body) ?? 'Market data is unavailable right now.',
          parseAttempts(_detailBody(body)),
          kind: _detailKind(body),
        );
      }
      if (response.statusCode != 200) {
        throw ApiException(
          _detailMessage(body) ?? 'Market request failed (${response.statusCode})',
        );
      }
      return body;
    } finally {
      if (_ownsClient()) c.close();
    }
  }

  /// Latest quotations for one crop, each row carrying its provenance.
  ///
  /// [commodity] accepts any spelling the backend knows - "pyaz", "onions",
  /// "ಈರುಳ್ಳಿ" - because normalisation happens server-side, in the same table
  /// the AI assistant uses.
  Future<PricePage> prices({
    required String commodity,
    String? state,
    String? district,
    String? market,
    int limit = 200,
  }) async {
    final uri = Uri.parse('$baseUrl/market/prices').replace(
      queryParameters: {
        'commodity': commodity,
        if (state != null && state.isNotEmpty) 'state': state,
        if (district != null && district.isNotEmpty) 'district': district,
        if (market != null && market.isNotEmpty) 'market': market,
        'limit': '$limit',
      },
    );
    return parsePricePage(await _getJson(uri));
  }

  /// Per-feed health, including the reason each disabled feed is off.
  Future<MarketStatus> status() async {
    final uri = Uri.parse('$baseUrl/market/status');
    return parseMarketStatus(await _getJson(uri));
  }

  /// Mandis we actually hold rows for. Empty when we hold none - a picker
  /// entry with no prices behind it is a dead end.
  Future<List<Mandi>> mandis({String? state}) async {
    final uri = Uri.parse('$baseUrl/market/mandis').replace(
      queryParameters: {
        if (state != null && state.isNotEmpty) 'state': state,
      },
    );
    return parseMandis(await _getJson(uri));
  }

  /// Crops we can answer for. `hasData` marks the ones storage already holds.
  Future<List<Commodity>> commodities() async {
    final uri = Uri.parse('$baseUrl/market/commodities');
    return parseCommodities(await _getJson(uri));
  }

  /// Daily average modal price series for the sparkline.
  Future<PriceHistory> history({
    required String commodity,
    required String state,
    int days = 90,
  }) async {
    final uri = Uri.parse('$baseUrl/market/prices/history').replace(
      queryParameters: {
        'commodity': commodity,
        'state': state,
        'days': '$days',
      },
    );
    return parsePriceHistory(await _getJson(uri));
  }
}

/// One crop's price response: the rows plus the feed-level `meta` block.
class PricePage {
  const PricePage({
    required this.commodity,
    required this.rows,
    required this.source,
    required this.provenance,
  });

  final String commodity;
  final List<MarketPrice> rows;

  /// The feed that answered, and its block. Shown once at the top so each row
  /// does not have to repeat the same attribution.
  final String source;
  final Provenance provenance;

  /// True when the rows are old enough that no sell advice may be built from
  /// them. Drives the banner, not the rows - each row also carries its own
  /// freshness so a mixed-age window cannot be flattened into one verdict.
  bool get hasActionable => rows.any((r) => r.provenance.actionable);
}

class PriceHistory {
  const PriceHistory({
    required this.commodity,
    required this.state,
    required this.points,
    required this.provenance,
  });

  final String commodity;
  final String state;
  final List<HistoryPoint> points;
  final Provenance provenance;
}

class HistoryPoint {
  const HistoryPoint({
    required this.date,
    required this.modalPrice,
    this.minPrice,
    this.maxPrice,
    this.dataPoints,
  });

  final DateTime date;
  final double modalPrice;
  final double? minPrice;
  final double? maxPrice;

  /// How many observations this day's average is built from. A day with one
  /// data point is a weaker average than a day with forty, and the UI says so.
  final int? dataPoints;
}

class Mandi {
  const Mandi({
    required this.market,
    required this.district,
    required this.state,
    required this.observations,
    this.lastObserved,
  });

  final String market;
  final String? district;
  final String? state;
  final int observations;
  final DateTime? lastObserved;
}

class Commodity {
  const Commodity({
    required this.commodity,
    required this.aliases,
    required this.hasData,
  });

  final String commodity;
  final List<String> aliases;

  /// Whether storage already holds an observation for this crop. The picker
  /// puts these first so a farmer never taps a crop that can only answer
  /// "no data".
  final bool hasData;
}

// ------------------------------------------------------------------ parsing

PricePage parsePricePage(String body) {
  final data = jsonDecode(body);
  if (data is! Map<String, dynamic>) {
    throw const FormatException('price response is not an object');
  }
  final rawRows = data['rows'];
  final meta = data['meta'] is Map
      ? Map<String, dynamic>.from(data['meta'] as Map)
      : const <String, dynamic>{};

  return PricePage(
    commodity: data['commodity']?.toString() ?? '',
    rows: [
      if (rawRows is List)
        for (final r in rawRows)
          if (r is Map) MarketPrice.fromJson(Map<String, dynamic>.from(r)),
    ],
    source: meta['source']?.toString() ?? 'unknown',
    provenance: Provenance.fromJson(meta),
  );
}

PriceHistory parsePriceHistory(String body) {
  final data = jsonDecode(body);
  if (data is! Map<String, dynamic>) {
    throw const FormatException('history response is not an object');
  }
  final rawRows = data['rows'];
  final meta = data['meta'] is Map
      ? Map<String, dynamic>.from(data['meta'] as Map)
      : const <String, dynamic>{};

  return PriceHistory(
    commodity: data['commodity']?.toString() ?? '',
    state: data['state']?.toString() ?? '',
    points: [
      if (rawRows is List)
        for (final r in rawRows)
          // A day with no modal price is not a point on the line. It is
          // skipped rather than interpolated: bridging two neighbours would
          // put a number on a day nobody quoted one.
          if (r is Map && r['modal_price'] is num)
            _historyPoint(Map<String, dynamic>.from(r)),
    ],
    provenance: Provenance.fromJson(meta),
  );
}

HistoryPoint _historyPoint(Map<String, dynamic> json) {
  final modal = json['modal_price'] as num;
  return HistoryPoint(
    date: DateTime.parse(json['date'].toString()),
    modalPrice: modal.toDouble(),
    minPrice: (json['min_price'] as num?)?.toDouble(),
    maxPrice: (json['max_price'] as num?)?.toDouble(),
    dataPoints: (json['data_points'] as num?)?.toInt(),
  );
}

MarketStatus parseMarketStatus(String body) {
  final data = jsonDecode(body);
  if (data is! Map<String, dynamic>) {
    throw const FormatException('status response is not an object');
  }
  return MarketStatus.fromJson(data);
}

List<Mandi> parseMandis(String body) {
  final data = jsonDecode(body);
  final items = data is Map ? data['items'] : null;
  if (items is! List) return const [];
  return [
    for (final i in items)
      if (i is Map) _mandi(Map<String, dynamic>.from(i)),
  ];
}

List<Commodity> parseCommodities(String body) {
  final data = jsonDecode(body);
  final items = data is Map ? data['items'] : null;
  if (items is! List) return const [];
  final out = <Commodity>[];
  for (final i in items) {
    if (i is! Map) continue;
    final m = Map<String, dynamic>.from(i);
    final name = m['commodity']?.toString();
    if (name == null || name.isEmpty) continue;
    out.add(
      Commodity(
        commodity: name,
        aliases: [
          if (m['aliases'] is List)
            for (final a in m['aliases'] as List) a.toString(),
        ],
        hasData: m['has_data'] == true,
      ),
    );
  }
  // Crops we can actually quote first: a picker entry with nothing behind it
  // is a dead end, so the useful ones are the ones a farmer sees first.
  out.sort((a, b) {
    if (a.hasData != b.hasData) return a.hasData ? -1 : 1;
    return a.commodity.compareTo(b.commodity);
  });
  return out;
}

Mandi _mandi(Map<String, dynamic> json) => Mandi(
      market: json['market']?.toString() ?? '',
      district: json['district']?.toString(),
      state: json['state']?.toString(),
      observations: (json['observations'] as num?)?.toInt() ?? 0,
      lastObserved: DateTime.tryParse(json['last_observed']?.toString() ?? ''),
    );

// -------------------------------------------------------------------- 503s

Map<String, dynamic>? _detailBody(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['detail'] is Map) {
      return Map<String, dynamic>.from(decoded['detail'] as Map);
    }
  } on FormatException {
    return null;
  }
  return null;
}

String? _detailMessage(String body) =>
    _detailBody(body)?['message']?.toString();

String? _detailKind(String body) => _detailBody(body)?['kind']?.toString();
