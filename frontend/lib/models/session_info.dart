/// One signed-in device, as returned by `GET /auth/sessions`.
///
/// The fields are exactly what the server records — no city or country is
/// invented, because the server does not store one. [deviceLabel] is the short
/// human label the backend derives from the User-Agent ("Windows · Chrome");
/// [ipAddress] is the raw address the request came from.
class SessionInfo {
  final int id;
  final DateTime? startedAt;
  final DateTime? lastSeenAt;
  final DateTime? endedAt;
  final String? endReason;
  final String? ipAddress;
  final String? userAgent;
  final String? deviceLabel;
  final bool isActive;
  final bool isCurrent;

  const SessionInfo({
    required this.id,
    this.startedAt,
    this.lastSeenAt,
    this.endedAt,
    this.endReason,
    this.ipAddress,
    this.userAgent,
    this.deviceLabel,
    this.isActive = true,
    this.isCurrent = false,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: json['id'] as int,
      startedAt: _date(json['started_at']),
      lastSeenAt: _date(json['last_seen_at']),
      endedAt: _date(json['ended_at']),
      endReason: json['end_reason'] as String?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      deviceLabel: json['device_label'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }

  /// A display name for the device, falling back to a parsed User-Agent and
  /// finally to a neutral label rather than an empty string.
  String get displayName {
    final label = deviceLabel;
    if (label != null && label.trim().isNotEmpty) return label;
    final parsed = _parseUserAgent(userAgent);
    return parsed ?? 'Unknown device';
  }

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  static String? _parseUserAgent(String? ua) {
    if (ua == null || ua.trim().isEmpty) return null;
    final lower = ua.toLowerCase();
    final String platform;
    if (lower.contains('android')) {
      platform = 'Android';
    } else if (lower.contains('iphone') ||
        lower.contains('ipad') ||
        lower.contains('ios')) {
      platform = 'iOS';
    } else if (lower.contains('windows')) {
      platform = 'Windows';
    } else if (lower.contains('mac os') || lower.contains('macintosh')) {
      platform = 'macOS';
    } else if (lower.contains('linux')) {
      platform = 'Linux';
    } else {
      platform = 'Unknown';
    }
    final String? browser;
    if (lower.contains('edg')) {
      browser = 'Edge';
    } else if (lower.contains('chrome') && !lower.contains('chromium')) {
      browser = 'Chrome';
    } else if (lower.contains('firefox')) {
      browser = 'Firefox';
    } else if (lower.contains('safari')) {
      browser = 'Safari';
    } else {
      browser = null;
    }
    return browser == null ? platform : '$platform · $browser';
  }
}
