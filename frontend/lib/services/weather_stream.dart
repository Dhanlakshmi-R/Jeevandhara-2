import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:jeevandhara2/models/weather_data.dart';
import 'api_service.dart' show ApiService;

/// Minimal Server-Sent Events client for the live weather stream.
class WeatherStreamService {
  final String baseUrl;
  WeatherStreamService({this.baseUrl = ApiService.baseUrl});

  Stream<WeatherData> stream({
    required double lat,
    required double lon,
    String name = '',
  }) async* {
    final client = http.Client();
    try {
      final request = http.Request(
        'GET',
        Uri.parse('$baseUrl/weather/stream').replace(
          queryParameters: {'lat': '$lat', 'lon': '$lon', 'name': name},
        ),
      );
      request.headers['Accept'] = 'text/event-stream';
      final response = await client.send(request);

      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final frame = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);
          for (final line in frame.split('\n')) {
            if (line.startsWith('data: ')) {
              try {
                final json = jsonDecode(line.substring(6));
                if (json is Map) {
                  yield WeatherData.fromJson(json.cast<String, dynamic>());
                }
              } catch (_) {
                // Ignore malformed frames.
              }
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }
}