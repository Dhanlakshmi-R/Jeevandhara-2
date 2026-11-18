import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:jeevandhara2/models/soil_moisture.dart';
import 'api_service.dart' show ApiService, ApiException;

class SoilMoistureService {
  final String baseUrl;
  final http.Client? client;

  SoilMoistureService({this.baseUrl = ApiService.baseUrl, this.client});

  http.Client _http() => client ?? http.Client();
  bool _owns() => client == null;

  Future<SoilMoistureReading?> latest({String? deviceId}) async {
    final uri = Uri.parse('$baseUrl/sensors/soil-moisture/latest').replace(
      queryParameters: {if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId},
    );
    final c = _http();
    try {
      final response = await c.get(uri, headers: const {'Accept': 'application/json'});
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw ApiException('Could not load soil moisture');
      }
      return SoilMoistureReading.fromJson(
        (jsonDecode(response.body) as Map).cast<String, dynamic>(),
      );
    } on http.ClientException {
      throw ApiException('Cannot reach the server at $baseUrl');
    } finally {
      if (_owns()) c.close();
    }
  }
}