import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:jeevandhara2/models/crop.dart';
import 'api_service.dart' show ApiService, ApiException;

/// Client for the backend's `/my-crops` endpoints.
///
/// Two rules this service keeps, the same ones the other listing services obey:
///
/// 1. **Never invents rows.** A failed read throws; an empty response is
///    returned as an empty list and the screen shows a real empty state with an
///    invitation to post the first crop.
/// 2. **Parsing is separated from I/O.** `parse*` functions are pure so the
///    response-to-model contract is unit-testable without HTTP.
///
/// Writes are owned server-side: every call carries the caller's access token,
/// and the backend returns 403 for a row someone else owns. This client does
/// not try to work around that.
class CropsService {
  final String baseUrl;
  final http.Client? client;

  CropsService({this.baseUrl = ApiService.baseUrl, this.client});

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
        throw ApiException('Sign in to see your crops.');
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

  /// The caller's listings, newest first. `[]` means none posted yet.
  Future<List<CropListing>> crops() async {
    final uri = Uri.parse('$baseUrl/my-crops');
    return parseCrops(await _getJson(uri));
  }

  // ---------------------------------------------------------------- writes

  /// Post "I have this to sell". Returns the row the server created, so the
  /// screen renders the canonical crop name and id rather than its own guess.
  Future<CropListing> create({
    required String name,
    required double quantity,
    String unit = 'kg',
    double? expectedPrice,
    String? location,
    String? description,
    DateTime? harvestDate,
    String? emoji,
  }) async {
    final uri = Uri.parse('$baseUrl/my-crops');
    final decoded = await _send(
      'POST',
      uri,
      body: {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        if (expectedPrice != null) 'expected_price': expectedPrice,
        if (location != null && location.isNotEmpty) 'location': location,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (harvestDate != null) 'harvest_date': _isoDate(harvestDate),
        if (emoji != null && emoji.isNotEmpty) 'emoji': emoji,
      },
    );
    return CropListing.fromJson(decoded);
  }

  /// Change the lifecycle (active -> sold, or hidden to take it down).
  Future<CropListing> setStatus(int cropId, String status) async {
    final uri = Uri.parse('$baseUrl/my-crops/$cropId');
    return CropListing.fromJson(
        await _send('PATCH', uri, body: {'status': status}));
  }

  /// Edit any editable field. Only fields passed are sent.
  Future<CropListing> update(
    int cropId, {
    String? name,
    double? quantity,
    String? unit,
    double? expectedPrice,
    String? location,
    String? description,
    DateTime? harvestDate,
  }) async {
    final uri = Uri.parse('$baseUrl/my-crops/$cropId');
    final decoded = await _send(
      'PATCH',
      uri,
      body: {
        if (name != null) 'name': name,
        if (quantity != null) 'quantity': quantity,
        if (unit != null) 'unit': unit,
        if (expectedPrice != null) 'expected_price': expectedPrice,
        if (location != null) 'location': location,
        if (description != null) 'description': description,
        if (harvestDate != null) 'harvest_date': _isoDate(harvestDate),
      },
    );
    return CropListing.fromJson(decoded);
  }

  /// Take a listing down (soft delete). The server keeps the row for history.
  Future<void> retire(int cropId) async {
    final uri = Uri.parse('$baseUrl/my-crops/$cropId');
    await _send('DELETE', uri);
  }
}

// ------------------------------------------------------------------ parsing

/// `/my-crops` returns a bare JSON array; the parser also accepts `{items}` so
/// one function covers both shapes without a second code path.
List<CropListing> parseCrops(String body) {
  final decoded = jsonDecode(body);
  final items =
      decoded is List ? decoded : (decoded is Map ? decoded['items'] : null);
  if (items is! List) return const [];
  return [
    for (final item in items)
      if (item is Map) CropListing.fromJson(Map<String, dynamic>.from(item)),
  ];
}

/// A single crop row (the POST/PATCH response).
CropListing parseCrop(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FormatException('Expected a crop object');
  }
  return CropListing.fromJson(Map<String, dynamic>.from(decoded));
}

String _isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
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
