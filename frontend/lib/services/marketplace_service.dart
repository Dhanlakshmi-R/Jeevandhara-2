import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:jeevandhara2/models/product.dart';
import 'api_service.dart' show ApiService, ApiException;

/// Client for the backend's `/marketplace` endpoints.
///
/// Reads are public (a logged-out farmer still needs to find seed at a good
/// price), but writes carry the caller's token and are owned server-side.
/// A failed read throws; an empty response is an honest empty shelf, not an
/// error and never a local sample.
class MarketplaceService {
  final String baseUrl;
  final http.Client? client;

  MarketplaceService({this.baseUrl = ApiService.baseUrl, this.client});

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

  /// Active products, newest first. `[]` means nobody has listed one yet.
  Future<List<MarketplaceProduct>> products({
    String? category,
    String? q,
    bool? inStock,
  }) async {
    final uri = Uri.parse('$baseUrl/marketplace').replace(
      queryParameters: {
        if (category != null && category.isNotEmpty && category != 'All')
          'category': category,
        if (q != null && q.isNotEmpty) 'q': q,
        if (inStock != null) 'in_stock': '$inStock',
      },
    );
    return parseProducts(await _getJson(uri));
  }

  // ---------------------------------------------------------------- writes

  /// List a farming input under the caller's name. Returns the created row.
  Future<MarketplaceProduct> create({
    required String name,
    required double price,
    String category = 'Seeds',
    String unit = 'pack',
    bool inStock = true,
    String? description,
    String? emoji,
  }) async {
    final uri = Uri.parse('$baseUrl/marketplace');
    final decoded = await _send(
      'POST',
      uri,
      body: {
        'name': name,
        'price': price,
        'category': category,
        'unit': unit,
        'in_stock': inStock,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (emoji != null && emoji.isNotEmpty) 'emoji': emoji,
      },
    );
    return MarketplaceProduct.fromJson(decoded);
  }

  /// Edit a product the caller owns. Only fields passed are sent.
  Future<MarketplaceProduct> update(
    int productId, {
    String? name,
    double? price,
    String? category,
    String? unit,
    bool? inStock,
    String? description,
  }) async {
    final uri = Uri.parse('$baseUrl/marketplace/$productId');
    final decoded = await _send(
      'PATCH',
      uri,
      body: {
        if (name != null) 'name': name,
        if (price != null) 'price': price,
        if (category != null) 'category': category,
        if (unit != null) 'unit': unit,
        if (inStock != null) 'in_stock': inStock,
        if (description != null) 'description': description,
      },
    );
    return MarketplaceProduct.fromJson(decoded);
  }

  /// Take a product down (soft delete). Only its owner may call this.
  Future<void> retire(int productId) async {
    final uri = Uri.parse('$baseUrl/marketplace/$productId');
    await _send('DELETE', uri);
  }
}

// ------------------------------------------------------------------ parsing

/// `/marketplace` wraps rows in `{"items": [...]}`; a bare array is accepted
/// too so the parser is tolerant of either shape.
List<MarketplaceProduct> parseProducts(String body) {
  final decoded = jsonDecode(body);
  final items =
      decoded is List ? decoded : (decoded is Map ? decoded['items'] : null);
  if (items is! List) return const [];
  return [
    for (final item in items)
      if (item is Map)
        MarketplaceProduct.fromJson(Map<String, dynamic>.from(item)),
  ];
}

/// A single product row (the POST/PATCH response).
MarketplaceProduct parseProduct(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FormatException('Expected a product object');
  }
  return MarketplaceProduct.fromJson(Map<String, dynamic>.from(decoded));
}

String? _message(String body) {
  try {
    final decoded = jsonDecode(body);
    final detail = decoded is Map ? decoded['detail'] : null;
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) return first['msg'].toString();
    }
  } on FormatException {
    return null;
  }
  return null;
}
