import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:jeevandhara2/models/weather_data.dart';
import 'api_service.dart' show ApiService, ApiException;

/// The backend responded but has no weather provider key configured (HTTP 503).
/// Distinct from a network failure so the UI can say something actionable
/// instead of a generic "try again".
class WeatherNotConfiguredException extends ApiException {
  WeatherNotConfiguredException()
      : super('The server has no WEATHER_API_KEY set, so weather is off.');
}

/// Client for the backend weather proxy endpoints.
///
/// The app never talks to WeatherAPI.com directly — the API key stays on the
/// backend. This service also exposes pure parser functions so tests can
/// validate response→model mapping without any HTTP.
class WeatherService {
  final String baseUrl;
  final http.Client? client;

  WeatherService({this.baseUrl = ApiService.baseUrl, this.client});

  http.Client _http() => client ?? http.Client();

  bool _ownsClient() => client == null;

  /// Performs the GET and normalizes every failure mode into an
  /// [ApiException], so callers never have to reason about http internals:
  /// unreachable backend, 503 (no key), or a provider/proxy error detail.
  Future<String> _getJson(Uri uri, {required String fallback}) async {
    final c = _http();
    try {
      late final http.Response response;
      try {
        response = await c.get(uri, headers: _headers);
      } on http.ClientException {
        throw ApiException(
          'Cannot reach the server at $baseUrl. Is the backend running?',
        );
      }
      _ensureSuccess(response, fallback: fallback);
      return response.body;
    } finally {
      if (_ownsClient()) c.close();
    }
  }

  Future<List<WeatherSuggestion>> suggestions(
    String query, {
    String? state,
  }) async {
    final uri = Uri.parse('$baseUrl/weather/suggestions').replace(
      queryParameters: {
        'q': query,
        if (state != null && state.isNotEmpty) 'state': state,
      },
    );
    return parseSuggestions(
      await _getJson(uri, fallback: 'Could not load place suggestions'),
    );
  }

  /// Offline location hierarchy (State → District → Taluk → Village) served
  /// by the backend from a bundled GeoNames gazetteer. Needs no API key and
  /// every option carries real coordinates.
  Future<List<IndianState>> fetchStates() async {
    final uri = Uri.parse('$baseUrl/weather/places/states');
    return parseStates(
      await _getJson(uri, fallback: 'Could not load states'),
    );
  }

  Future<List<PlaceOption>> fetchDistricts(String state) =>
      _fetchOptions('districts', {'state': state}, 'districts');

  Future<List<PlaceOption>> fetchTaluks(String state, String district) =>
      _fetchOptions('taluks', {'state': state, 'district': district}, 'taluks');

  Future<List<PlaceOption>> fetchVillages(
    String state,
    String district,
    String taluk,
  ) =>
      _fetchOptions(
        'villages',
        {'state': state, 'district': district, 'taluk': taluk},
        'villages',
      );

  Future<List<PlaceOption>> _fetchOptions(
    String path,
    Map<String, String> params,
    String kind,
  ) async {
    final uri = Uri.parse('$baseUrl/weather/places/$path').replace(
      queryParameters: params,
    );
    return parsePlaceOptions(
      await _getJson(uri, fallback: 'Could not load $kind'),
    );
  }

  /// Resolves the browsed selection to coordinates. The user may stop at any
  /// level -- state, district, taluk or village are all valid answers.
  Future<ResolvedPlace> resolvePlace({
    required String state,
    String? district,
    String? taluk,
    String? village,
  }) async {
    final uri = Uri.parse('$baseUrl/weather/places/resolve').replace(
      queryParameters: {
        'state': state,
        if (district != null && district.isNotEmpty) 'district': district,
        if (taluk != null && taluk.isNotEmpty) 'taluk': taluk,
        if (village != null && village.isNotEmpty) 'village': village,
      },
    );
    return parseResolvedPlace(
      await _getJson(uri, fallback: 'Could not resolve that place'),
    );
  }

  Future<WeatherData> fetchWeather({
    required double lat,
    required double lon,
    String? name,
  }) async {
    final uri = Uri.parse('$baseUrl/weather').replace(
      queryParameters: {
        'lat': '$lat',
        'lon': '$lon',
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    return parseWeatherData(
      await _getJson(uri, fallback: 'Could not load weather'),
    );
  }

  static const _headers = {'Accept': 'application/json'};

  void _ensureSuccess(http.Response response, {required String fallback}) {
    if (response.statusCode == 200) return;
    if (response.statusCode == 503) {
      throw WeatherNotConfiguredException();
    }
    String message = fallback;
    try {
      final detail = (jsonDecode(response.body) as Map)['detail'];
      if (detail is String && detail.isNotEmpty) message = detail;
    } catch (_) {}
    throw ApiException(message);
  }
}

/// Pure → tested: parse provider search JSON into suggestions.
List<WeatherSuggestion> parseSuggestions(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((e) => WeatherSuggestion.fromJson(e.cast<String, dynamic>()))
      .toList();
}

/// Pure → tested: parse the backend weather payload into [WeatherData].
WeatherData parseWeatherData(String body) {
  final decoded = jsonDecode(body);
  return WeatherData.fromJson((decoded as Map).cast<String, dynamic>());
}

/// Pure → tested: parse the states payload into a list of state options.
List<IndianState> parseStates(String body) {
  final decoded = jsonDecode(body);
  final list = decoded is Map ? decoded['states'] : decoded;
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => IndianState.fromJson(e.cast<String, dynamic>()))
      .toList();
}

/// Pure → tested: parse a gazetteer list of `{name, lat, lon}` options.
List<PlaceOption> parsePlaceOptions(String body) {
  final decoded = jsonDecode(body);
  final list =
      decoded is Map ? (decoded['items'] ?? decoded['results']) : decoded;
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => PlaceOption.fromJson(e.cast<String, dynamic>()))
      .toList();
}

/// Pure → tested: parse the `/weather/places/resolve` payload.
ResolvedPlace parseResolvedPlace(String body) {
  final decoded = jsonDecode(body);
  return ResolvedPlace.fromJson((decoded as Map).cast<String, dynamic>());
}
