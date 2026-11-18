import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:jeevandhara2/models/tool.dart';
import 'package:jeevandhara2/models/trader.dart';
import 'api_service.dart' show ApiService, ApiException;

/// Client for the backend's `/traders` and `/tools` endpoints.
///
/// Two rules this service keeps, the same ones the market service obeys:
///
/// 1. **Never invents rows.** A failed read throws; an empty response is
///    returned as an empty list and the screens show a real empty state with
///    an invitation to be the first to post.
/// 2. **Parsing is separated from I/O.** `parse*` functions are pure so the
///    response-to-model contract is unit-testable without HTTP.
class ListingsService {
  final String baseUrl;
  final http.Client? client;

  ListingsService({this.baseUrl = ApiService.baseUrl, this.client});

  http.Client _http() => client ?? http.Client();

  bool _ownsClient() => client == null;

  Future<String> _getJson(Uri uri) async {
    final c = _http();
    try {
      late final http.Response response;
      try {
        final token = await ApiService.readToken();
        response = await c.get(uri, headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        });
      } on http.ClientException {
        throw ApiException(
          'Cannot reach the server at $baseUrl. Is the backend running?',
        );
      }
      if (response.statusCode == 401) {
        throw ApiException('Sign in to manage your trading card.');
      }
      if (response.statusCode != 200) {
        throw ApiException(
          _message(response.body) ?? 'Request failed (${response.statusCode})',
        );
      }
      return response.body;
    } finally {
      if (_ownsClient()) c.close();
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final c = _http();
    try {
      final token = await ApiService.readToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      late final http.Response response;
      try {
        switch (method) {
          case 'POST':
            response =
                await c.post(uri, headers: headers, body: jsonEncode(body));
          case 'PATCH':
            response =
                await c.patch(uri, headers: headers, body: jsonEncode(body));
          default:
            response = await c.delete(uri, headers: headers);
        }
      } on http.ClientException {
        throw ApiException(
          'Cannot reach the server at $baseUrl. Is the backend running?',
        );
      }
      if (response.statusCode == 401) {
        throw ApiException(
            'This needs you to be logged in. Please sign in first.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _message(response.body) ?? 'Request failed (${response.statusCode})',
        );
      }
      if (response.body.isEmpty) return const {};
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } finally {
      if (_ownsClient()) c.close();
    }
  }

  // ----------------------------------------------------------------- reads

  /// Rentable tools, newest first. `[]` means nobody has listed one yet.
  Future<List<Tool>> tools({String? q, String? category}) async {
    final uri = Uri.parse('$baseUrl/tools').replace(
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (category != null && category.isNotEmpty && category != 'All')
          'category': category,
      },
    );
    return parseTools(await _getJson(uri));
  }

  /// Trader cards, newest first. `[]` means nobody has published one yet.
  Future<List<Trader>> traders({String? q, String? crop}) async {
    final uri = Uri.parse('$baseUrl/traders').replace(
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (crop != null && crop.isNotEmpty && crop != 'All') 'crop': crop,
      },
    );
    return parseTraders(await _getJson(uri));
  }

  Future<Trader?> myOffer() async {
    final uri = Uri.parse('$baseUrl/traders/me');
    return parseFirstTrader(await _getJson(uri));
  }

  // ---------------------------------------------------------------- writes

  /// Publish (or replace) the caller's "I am buying" card.
  Future<Trader> saveTraderOffer({
    String? company,
    List<String> crops = const [],
    double? offeredPricePerQuintal,
    String? note,
    bool available = true,
    String? emoji,
  }) async {
    final uri = Uri.parse('$baseUrl/traders/me');
    final decoded = await _send(
      'POST',
      uri,
      body: {
        if (company != null && company.isNotEmpty) 'company': company,
        'crops': crops,
        if (offeredPricePerQuintal != null)
          'offered_price_per_quintal': offeredPricePerQuintal,
        if (note != null && note.isNotEmpty) 'note': note,
        'available': available,
        if (emoji != null && emoji.isNotEmpty) 'emoji': emoji,
      },
    );
    return Trader.fromJson(decoded);
  }

  /// Take the caller's card down (soft delete: the row is kept for history).
  Future<void> deleteTraderOffer() async {
    final uri = Uri.parse('$baseUrl/traders/me');
    await _send('DELETE', uri);
  }

  /// List a rentable tool under the caller's name. Returns the created row.
  Future<Tool> createTool({
    required String name,
    required String category,
    double? pricePerDay,
    String? description,
    String? emoji,
  }) async {
    final uri = Uri.parse('$baseUrl/tools');
    final decoded = await _send(
      'POST',
      uri,
      body: {
        'name': name,
        'category': category,
        if (pricePerDay != null) 'price_per_day': pricePerDay,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (emoji != null && emoji.isNotEmpty) 'emoji': emoji,
      },
    );
    return Tool.fromJson(decoded);
  }

  /// Set a tool available/unavailable. Only its owner may call this.
  Future<Tool> setToolAvailability(int toolId, bool available) async {
    final uri = Uri.parse('$baseUrl/tools/$toolId');
    return Tool.fromJson(
        await _send('PATCH', uri, body: {'available': available}));
  }
}

// ------------------------------------------------------------------ parsing

List<Tool> parseTools(String body) {
  final decoded = jsonDecode(body);
  final items = decoded is Map ? decoded['items'] : null;
  if (items is! List) return const [];
  return [
    for (final i in items)
      if (i is Map) Tool.fromJson(Map<String, dynamic>.from(i)),
  ];
}

List<Trader> parseTraders(String body) {
  final decoded = jsonDecode(body);
  final items =
      decoded is List ? decoded : (decoded is Map ? decoded['items'] : null);
  if (items is! List) return const [];
  return [
    for (final i in items)
      if (i is Map) Trader.fromJson(Map<String, dynamic>.from(i)),
  ];
}

/// `/traders/me` returns a list; callers want the single card (or null).
Trader? parseFirstTrader(String body) {
  final traders = parseTraders(body);
  return traders.isEmpty ? null : traders.first;
}

String? _message(String body) {
  try {
    final decoded = jsonDecode(body);
    final detail = decoded is Map ? decoded['detail'] : null;
    if (detail is String && detail.isNotEmpty) return detail;
  } on FormatException {
    return null;
  }
  return null;
}
