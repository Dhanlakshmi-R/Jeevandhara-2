import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import 'admin_models.dart';

/// Raised when the stored session is missing, expired or not an administrator's.
///
/// The shell catches this and shows the "administrator access required" screen
/// instead of a generic error, so the operator knows the fix is to sign in as an
/// admin (not to retry).
class AdminAuthException implements Exception {
  final String message;
  AdminAuthException([this.message = 'Administrator access required.']);
  @override
  String toString() => message;
}

/// Raised for any non-auth failure so the shell can show a retryable error.
class AdminApiException implements Exception {
  final String message;
  final int? statusCode;
  AdminApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Thin client over the `/admin` API. It never caches or fabricates: every call
/// reflects what the server returned, or throws.
class AdminApi {
  AdminApi._();
  static final AdminApi instance = AdminApi._();

  String get _base => ApiService.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await ApiService.readToken();
    if (token == null || token.isEmpty) {
      throw AdminAuthException('No admin session. Sign in again.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_base$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    http.Response res;
    try {
      res = await http.get(uri, headers: await _headers());
    } catch (e) {
      throw AdminApiException('Could not reach the admin service.');
    }
    return _decode(res);
  }

  Future<dynamic> _post(String path) async {
    http.Response res;
    try {
      res = await http.post(
        Uri.parse('$_base$path'),
        headers: await _headers(),
      );
    } catch (e) {
      throw AdminApiException('Could not reach the admin service.');
    }
    return _decode(res);
  }

  Future<dynamic> _sendJson(
    String method,
    String path, [
    Object? body,
  ]) async {
    final headers = await _headers();
    if (body != null) headers['Content-Type'] = 'application/json';
    http.Response res;
    try {
      final uri = Uri.parse('$_base$path');
      if (method == 'POST') {
        res = await http.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      } else {
        res = await http.put(
          uri,
          headers: headers,
          body: jsonEncode(body),
        );
      }
    } catch (e) {
      throw AdminApiException('Could not reach the admin service.');
    }
    return _decode(res);
  }

  /// Raw GET used for export endpoints that return CSV rather than JSON.
  Future<String> _getText(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_base$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    http.Response res;
    try {
      res = await http.get(uri, headers: await _headers());
    } catch (e) {
      throw AdminApiException('Could not reach the admin service.');
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw AdminAuthException(_detail(res) ?? 'Administrator access required.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AdminApiException(
        _detail(res) ?? 'Request failed (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }
    return utf8.decode(res.bodyBytes);
  }

  Future<dynamic> _delete(String path) async {
    http.Response res;
    try {
      res = await http.delete(Uri.parse('$_base$path'), headers: await _headers());
    } catch (e) {
      throw AdminApiException('Could not reach the admin service.');
    }
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw AdminAuthException(_detail(res) ?? 'Administrator access required.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AdminApiException(
        _detail(res) ?? 'Request failed (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  String? _detail(http.Response res) {
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map && data['detail'] is String) {
        return convertApiMessage(data['detail'] as String);
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------- calls

  Future<AdminOverview> overview() async {
    final data = await _get('/admin/overview');
    return AdminOverview.fromJson(_map(data));
  }

  Future<AdminUserPage> users({
    String? query,
    String? role,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _get('/admin/users', {
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (role != null && role.isNotEmpty) 'role': role,
      if (status != null && status.isNotEmpty) 'status': status,
      'limit': '$limit',
      'offset': '$offset',
    });
    return AdminUserPage.fromJson(_map(data));
  }

  Future<AdminUserDetail> user(int id) async {
    final data = await _get('/admin/users/$id');
    return AdminUserDetail.fromJson(_map(data));
  }

  Future<AdminUser> suspendUser(int id) async {
    final data = await _post('/admin/users/$id/suspend');
    return AdminUser.fromJson(_map(data));
  }

  Future<AdminUser> unsuspendUser(int id) async {
    final data = await _post('/admin/users/$id/unsuspend');
    return AdminUser.fromJson(_map(data));
  }

  Future<AdminActivityPage> activity({
    String? eventType,
    int? actorUserId,
    DateTime? since,
    DateTime? until,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _get('/admin/activity', {
      if (eventType != null && eventType.isNotEmpty) 'event_type': eventType,
      if (actorUserId != null) 'actor_user_id': '$actorUserId',
      if (since != null) 'since': since.toUtc().toIso8601String(),
      if (until != null) 'until': until.toUtc().toIso8601String(),
      'limit': '$limit',
      'offset': '$offset',
    });
    return AdminActivityPage.fromJson(_map(data));
  }

  Future<List<AdminSession>> sessions({
    int? userId,
    bool activeOnly = true,
    int limit = 100,
  }) async {
    final data = await _get('/admin/sessions', {
      if (userId != null) 'user_id': '$userId',
      'active_only': '$activeOnly',
      'limit': '$limit',
    });
    if (data is! List) return const [];
    return [
      for (final e in data)
        if (e is Map) AdminSession.fromJson(e.cast<String, dynamic>()),
    ];
  }

  Future<void> revokeSession(int id) async {
    await _delete('/admin/sessions/$id');
  }

  Future<List<DailyStat>> dailyStats({int days = 14}) async {
    final data = await _get('/admin/stats/daily', {'days': '$days'});
    if (data is! List) return const [];
    return [
      for (final e in data)
        if (e is Map) DailyStat.fromJson(e.cast<String, dynamic>()),
    ];
  }

  Map<String, dynamic> _map(dynamic data) =>
      data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};

  // ------------------------------------------------------- weather & alerts

  Future<List<AdminWeatherAlert>> weatherAlerts({
    bool activeOnly = false,
    String? severity,
  }) async {
    final data = await _get('/admin/weather-alerts', {
      if (activeOnly) 'active_only': 'true',
      if (severity != null && severity.isNotEmpty) 'severity': severity,
    });
    return _list(data, AdminWeatherAlert.fromJson);
  }

  Future<AdminWeatherAlert> createWeatherAlert(Map<String, dynamic> payload) async {
    final data = await _sendJson('POST', '/admin/weather-alerts', payload);
    return AdminWeatherAlert.fromJson(_map(data));
  }

  Future<AdminWeatherAlert> updateWeatherAlert(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final data = await _sendJson('PUT', '/admin/weather-alerts/$id', payload);
    return AdminWeatherAlert.fromJson(_map(data));
  }

  Future<void> deleteWeatherAlert(int id) async {
    await _delete('/admin/weather-alerts/$id');
  }

  // ------------------------------------------------------- notifications

  Future<List<AdminNotification>> notifications({int limit = 50}) async {
    final data = await _get('/admin/notifications', {'limit': '$limit'});
    return _list(data, AdminNotification.fromJson);
  }

  Future<AdminNotification> sendNotification(Map<String, dynamic> payload) async {
    final data = await _sendJson('POST', '/admin/notifications', payload);
    return AdminNotification.fromJson(_map(data));
  }

  // ------------------------------------------------------------ settings

  Future<List<AdminSetting>> settings() async {
    final data = await _get('/admin/settings');
    final m = _map(data);
    return _list(m['settings'], AdminSetting.fromJson);
  }

  Future<List<AdminSetting>> updateSettings(Map<String, dynamic> values) async {
    final data = await _sendJson('PUT', '/admin/settings', {'values': values});
    final m = _map(data);
    return _list(m['settings'], AdminSetting.fromJson);
  }

  // ------------------------------------------------------------- reports

  Future<AdminReportSummary> reportSummary({int days = 30}) async {
    final data = await _get('/admin/reports/summary', {'days': '$days'});
    return AdminReportSummary.fromJson(_map(data));
  }

  Future<List<AdminCount>> reportActivity({int days = 30}) async {
    final data = await _get('/admin/reports/activity', {'days': '$days'});
    return _list(data, AdminCount.fromJson);
  }

  Future<List<AdminCount>> reportCrops({int days = 30}) async {
    final data = await _get('/admin/reports/crops', {'days': '$days'});
    return _list(data, AdminCount.fromJson);
  }

  /// Returns CSV text for the chosen report (the export endpoint streams CSV).
  Future<String> reportExportCsv({
    String kind = 'summary',
    int days = 30,
  }) async {
    return _getText('/admin/reports/export', {
      'kind': kind,
      'days': '$days',
      'format': 'csv',
    });
  }

  // ------------------------------------------------------ crop analytics

  Future<AdminCropAnalytics> cropAnalytics({int days = 90, int limit = 20}) async {
    final data = await _get('/admin/analytics/crops', {
      'days': '$days',
      'limit': '$limit',
    });
    return AdminCropAnalytics.fromJson(_map(data));
  }

  Future<AdminCropDetail> cropDetail(String commodity) async {
    final data = await _get('/admin/analytics/crops/${Uri.encodeComponent(commodity)}');
    return AdminCropDetail.fromJson(_map(data));
  }

  // ---------------------------------------------------- market management

  Future<AdminMarketPricePage> marketPrices({
    String? commodity,
    String? market,
    String? state,
    bool? verified,
    int? days,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _get('/admin/market/prices', {
      if (commodity != null && commodity.isNotEmpty) 'commodity': commodity,
      if (market != null && market.isNotEmpty) 'market': market,
      if (state != null && state.isNotEmpty) 'state': state,
      if (verified != null) 'verified': '$verified',
      if (days != null) 'days': '$days',
      'limit': '$limit',
      'offset': '$offset',
    });
    return AdminMarketPricePage.fromJson(_map(data));
  }

  Future<AdminMarketPrice> verifyMarketPrice(int id) async {
    final data = await _post('/admin/market/prices/$id/verify');
    return AdminMarketPrice.fromJson(_map(data));
  }

  Future<AdminMarketPrice> unverifyMarketPrice(int id) async {
    final data = await _post('/admin/market/prices/$id/unverify');
    return AdminMarketPrice.fromJson(_map(data));
  }

  Future<List<AdminMarketSource>> marketSources() async {
    final data = await _get('/admin/market/sources');
    return _list(data, AdminMarketSource.fromJson);
  }

  Future<AdminForecast> marketForecast(
    String commodity, {
    String? state,
    int horizon = 7,
  }) async {
    final data = await _get('/admin/market/forecast', {
      'commodity': commodity,
      if (state != null && state.isNotEmpty) 'state': state,
      'horizon': '$horizon',
    });
    return AdminForecast.fromJson(_map(data));
  }

  // --------------------------------------------------------- permissions

  Future<AdminPermissions> permissions() async {
    final data = await _get('/admin/permissions');
    return AdminPermissions.fromJson(_map(data));
  }

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) build) {
    if (data is! List) return const [];
    return [
      for (final e in data)
        if (e is Map) build(e.cast<String, dynamic>()),
    ];
  }
}
