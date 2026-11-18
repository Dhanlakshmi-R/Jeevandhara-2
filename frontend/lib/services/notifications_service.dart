import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:jeevandhara2/models/app_notification.dart';
import 'package:jeevandhara2/services/api_service.dart'
    show ApiService, ApiException;

/// Client for the backend's `/notifications` inbox.
class NotificationsService {
  final String baseUrl;
  final http.Client? client;

  NotificationsService({this.baseUrl = ApiService.baseUrl, this.client});

  http.Client _http() => client ?? http.Client();
  bool _ownsClient() => client == null;

  Future<List<AppNotification>> fetch() async {
    final c = _http();
    try {
      final token = await ApiService.readToken();
      final uri = Uri.parse('$baseUrl/notifications');
      late final http.Response response;
      try {
        response = await c.get(uri, headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        });
      } on http.ClientException {
        throw ApiException('Cannot reach the server at $baseUrl.');
      }
      if (response.statusCode == 401) {
        throw ApiException('Sign in to see your notifications.');
      }
      if (response.statusCode != 200) {
        throw ApiException('Request failed (${response.statusCode})');
      }
      final decoded = jsonDecode(response.body);
      final items = decoded is List
          ? decoded
          : (decoded is Map ? decoded['items'] : null);
      if (items is! List) return const [];
      final out = <AppNotification>[];
      for (final raw in items) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        out.add(AppNotification(
          type: NotificationType.system,
          title: (m['title'] ?? '').toString(),
          message: (m['body_en'] ?? '').toString(),
          time: _timeAgo(m['created_at']?.toString()),
          seen: false,
        ));
      }
      return out;
    } finally {
      if (_ownsClient()) c.close();
    }
  }

  static String _timeAgo(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
