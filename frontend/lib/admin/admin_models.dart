/// Read-only view models for the administrator console.
///
/// Parsing mirrors the backend schemas exactly and is defensive: a missing or
/// malformed field becomes null / zero rather than a fabricated value, because
/// the console must never invent data.
class AdminOverview {
  final int totalUsers;
  final int activeUsers;
  final int suspendedUsers;
  final int farmers;
  final int traders;
  final int admins;
  final int activeSessions;
  final int eventsToday;
  final int signupsToday;

  const AdminOverview({
    required this.totalUsers,
    required this.activeUsers,
    required this.suspendedUsers,
    required this.farmers,
    required this.traders,
    required this.admins,
    required this.activeSessions,
    required this.eventsToday,
    required this.signupsToday,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> j) => AdminOverview(
        totalUsers: _int(j['total_users']),
        activeUsers: _int(j['active_users']),
        suspendedUsers: _int(j['suspended_users']),
        farmers: _int(j['farmers']),
        traders: _int(j['traders']),
        admins: _int(j['admins']),
        activeSessions: _int(j['active_sessions']),
        eventsToday: _int(j['events_today']),
        signupsToday: _int(j['signups_today']),
      );

  /// Non-admin accounts are the ones an operator typically manages.
  Map<String, int> get roleCounts => {
        'farmer': farmers,
        'trader': traders,
        'admin': admins,
      };
}

class AdminUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String authProvider;
  final String? location;
  final bool profileComplete;
  final bool isActive;
  final bool isSuperadmin;
  final DateTime? createdAt;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.authProvider = 'password',
    this.location,
    this.profileComplete = true,
    required this.isActive,
    required this.isSuperadmin,
    this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: _int(j['id']),
        name: (j['name'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
        phone: j['phone']?.toString(),
        authProvider: (j['auth_provider'] ?? 'password').toString(),
        location: j['location']?.toString(),
        profileComplete: j['profile_complete'] != false,
        isActive: j['is_active'] != false,
        isSuperadmin: j['is_superadmin'] == true,
        createdAt: _date(j['created_at']),
      );
}

class AdminUserDetail {
  final AdminUser user;
  final int activeSessionCount;
  final int eventCount;
  final DateTime? lastSeenAt;

  const AdminUserDetail({
    required this.user,
    required this.activeSessionCount,
    required this.eventCount,
    this.lastSeenAt,
  });

  factory AdminUserDetail.fromJson(Map<String, dynamic> j) => AdminUserDetail(
        user: AdminUser.fromJson(j),
        activeSessionCount: _int(j['active_session_count']),
        eventCount: _int(j['event_count']),
        lastSeenAt: _date(j['last_seen_at']),
      );
}

class AdminUserPage {
  final List<AdminUser> users;
  final int total;
  final int limit;
  final int offset;

  const AdminUserPage({
    required this.users,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory AdminUserPage.fromJson(Map<String, dynamic> j) {
    final raw = j['users'] as List? ?? const [];
    return AdminUserPage(
      users: [
        for (final e in raw)
          if (e is Map) AdminUser.fromJson(e.cast<String, dynamic>()),
      ],
      total: _int(j['total'] ?? raw.length),
      limit: _int(j['limit']),
      offset: _int(j['offset']),
    );
  }

  bool get hasMore => offset + users.length < total;
}

class AdminActivityEvent {
  final int id;
  final String eventType;
  final int? actorUserId;
  final String? actorRole;
  final String? entityType;
  final String? entityId;
  final String? action;
  final String? summaryEn;
  final String? summaryKn;
  final Map<String, dynamic>? metadata;
  final String? ipAddress;
  final String? deviceLabel;
  final int? sessionId;
  final DateTime createdAt;

  const AdminActivityEvent({
    required this.id,
    required this.eventType,
    this.actorUserId,
    this.actorRole,
    this.entityType,
    this.entityId,
    this.action,
    this.summaryEn,
    this.summaryKn,
    this.metadata,
    this.ipAddress,
    this.deviceLabel,
    this.sessionId,
    required this.createdAt,
  });

  factory AdminActivityEvent.fromJson(Map<String, dynamic> j) {
    final rawMeta = j['metadata'];
    return AdminActivityEvent(
      id: _int(j['id']),
      eventType: (j['event_type'] ?? '').toString(),
      actorUserId: j['actor_user_id'] == null ? null : _int(j['actor_user_id']),
      actorRole: j['actor_role']?.toString(),
      entityType: j['entity_type']?.toString(),
      entityId: j['entity_id']?.toString(),
      action: j['action']?.toString(),
      summaryEn: j['summary_en']?.toString(),
      summaryKn: j['summary_kn']?.toString(),
      metadata: rawMeta is Map ? rawMeta.cast<String, dynamic>() : null,
      ipAddress: j['ip_address']?.toString(),
      deviceLabel: j['device_label']?.toString(),
      sessionId: j['session_id'] == null ? null : _int(j['session_id']),
      createdAt: _date(j['created_at']) ?? DateTime.now(),
    );
  }
}

class AdminActivityPage {
  final List<AdminActivityEvent> events;
  final int total;
  final int limit;
  final int offset;

  const AdminActivityPage({
    required this.events,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory AdminActivityPage.fromJson(Map<String, dynamic> j) {
    final raw = j['events'] as List? ?? const [];
    return AdminActivityPage(
      events: [
        for (final e in raw)
          if (e is Map) AdminActivityEvent.fromJson(e.cast<String, dynamic>()),
      ],
      total: _int(j['total'] ?? raw.length),
      limit: _int(j['limit']),
      offset: _int(j['offset']),
    );
  }

  bool get hasMore => offset + events.length < total;
}

class AdminSession {
  final int id;
  final int userId;
  final String? userName;
  final String? userEmail;
  final String? deviceLabel;
  final String? userAgent;
  final String? ipAddress;
  final bool isActive;
  final bool isCurrent;
  final DateTime? startedAt;
  final DateTime? lastSeenAt;
  final DateTime? endedAt;
  final String? endReason;

  const AdminSession({
    required this.id,
    required this.userId,
    this.userName,
    this.userEmail,
    this.deviceLabel,
    this.userAgent,
    this.ipAddress,
    required this.isActive,
    this.isCurrent = false,
    this.startedAt,
    this.lastSeenAt,
    this.endedAt,
    this.endReason,
  });

  factory AdminSession.fromJson(Map<String, dynamic> j) => AdminSession(
        id: _int(j['id']),
        userId: _int(j['user_id']),
        userName: j['user_name']?.toString(),
        userEmail: j['user_email']?.toString(),
        deviceLabel: j['device_label']?.toString(),
        userAgent: j['user_agent']?.toString(),
        ipAddress: j['ip_address']?.toString(),
        isActive: j['is_active'] != false,
        isCurrent: j['is_current'] == true,
        startedAt: _date(j['started_at']),
        lastSeenAt: _date(j['last_seen_at']),
        endedAt: _date(j['ended_at']),
        endReason: j['end_reason']?.toString(),
      );
}

class DailyStat {
  final DateTime? day;
  final int signups;
  final int events;

  const DailyStat({this.day, this.signups = 0, this.events = 0});

  factory DailyStat.fromJson(Map<String, dynamic> j) => DailyStat(
        day: _date(j['date']),
        signups: _int(j['signups']),
        events: _int(j['events']),
      );
}

// ----------------------------------------------------- weather & alerts (4.4)

class AdminWeatherAlert {
  final int id;
  final String title;
  final String messageEn;
  final String? messageKn;
  final String severity;
  final String scopeType;
  final String? scopeValue;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminWeatherAlert({
    required this.id,
    required this.title,
    required this.messageEn,
    this.messageKn,
    required this.severity,
    required this.scopeType,
    this.scopeValue,
    this.validFrom,
    this.validUntil,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminWeatherAlert.fromJson(Map<String, dynamic> j) => AdminWeatherAlert(
        id: _int(j['id']),
        title: _str(j['title']),
        messageEn: _str(j['message_en']),
        messageKn: _strOrNull(j['message_kn']),
        severity: _str(j['severity'], fallback: 'info'),
        scopeType: _str(j['scope_type'], fallback: 'all'),
        scopeValue: _strOrNull(j['scope_value']),
        validFrom: _date(j['valid_from']),
        validUntil: _date(j['valid_until']),
        isActive: j['is_active'] != false,
        createdAt: _date(j['created_at']),
        updatedAt: _date(j['updated_at']),
      );
}

// ---------------------------------------------------------- notifications (4.9)

class AdminNotification {
  final int id;
  final String title;
  final String bodyEn;
  final String? bodyKn;
  final String priority;
  final String audience;
  final String? audienceValue;
  final int recipientCount;
  final String? audienceSummary;
  final DateTime? createdAt;

  const AdminNotification({
    required this.id,
    required this.title,
    required this.bodyEn,
    this.bodyKn,
    required this.priority,
    required this.audience,
    this.audienceValue,
    required this.recipientCount,
    this.audienceSummary,
    this.createdAt,
  });

  factory AdminNotification.fromJson(Map<String, dynamic> j) => AdminNotification(
        id: _int(j['id']),
        title: _str(j['title']),
        bodyEn: _str(j['body_en']),
        bodyKn: _strOrNull(j['body_kn']),
        priority: _str(j['priority'], fallback: 'info'),
        audience: _str(j['audience'], fallback: 'all'),
        audienceValue: _strOrNull(j['audience_value']),
        recipientCount: _int(j['recipient_count']),
        audienceSummary: _strOrNull(j['audience_summary']),
        createdAt: _date(j['created_at']),
      );
}

// --------------------------------------------------------------- settings (4.8)

class AdminSetting {
  final String key;
  final String? value;
  final String type;
  final String label;
  final String? defaultValue;
  final DateTime? updatedAt;

  const AdminSetting({
    required this.key,
    this.value,
    required this.type,
    required this.label,
    this.defaultValue,
    this.updatedAt,
  });

  bool get isBool => type == 'bool';
  bool get isInt => type == 'int';
  bool get isEnum => type.startsWith('enum:');
  List<String> get enumValues =>
      isEnum ? type.substring(5).split(',') : const [];

  bool get boolValue => (value ?? defaultValue ?? '').toLowerCase() == 'true';

  factory AdminSetting.fromJson(Map<String, dynamic> j) => AdminSetting(
        key: _str(j['key']),
        value: _strOrNull(j['value']),
        type: _str(j['type']),
        label: _str(j['label']),
        defaultValue: _strOrNull(j['default']),
        updatedAt: _date(j['updated_at']),
      );
}

// ---------------------------------------------------------------- reports (4.7)

class AdminReportSummary {
  final int days;
  final int usersTotal;
  final int usersNew;
  final int eventsTotal;
  final int eventsInPeriod;
  final int cropsTotal;
  final int cropsActive;
  final int marketplaceTotal;
  final int inquiriesTotal;
  final int priceAlertsTotal;
  final int weatherAlertsActive;
  final int notificationsSent;

  const AdminReportSummary({
    required this.days,
    required this.usersTotal,
    required this.usersNew,
    required this.eventsTotal,
    required this.eventsInPeriod,
    required this.cropsTotal,
    required this.cropsActive,
    required this.marketplaceTotal,
    required this.inquiriesTotal,
    required this.priceAlertsTotal,
    required this.weatherAlertsActive,
    required this.notificationsSent,
  });

  factory AdminReportSummary.fromJson(Map<String, dynamic> j) => AdminReportSummary(
        days: _int(j['days']),
        usersTotal: _int(j['users_total']),
        usersNew: _int(j['users_new']),
        eventsTotal: _int(j['events_total']),
        eventsInPeriod: _int(j['events_in_period']),
        cropsTotal: _int(j['crops_total']),
        cropsActive: _int(j['crops_active']),
        marketplaceTotal: _int(j['marketplace_total']),
        inquiriesTotal: _int(j['inquiries_total']),
        priceAlertsTotal: _int(j['price_alerts_total']),
        weatherAlertsActive: _int(j['weather_alerts_active']),
        notificationsSent: _int(j['notifications_sent']),
      );
}

class AdminCount {
  final String key;
  final String label;
  final int count;

  const AdminCount({required this.key, required this.label, required this.count});

  factory AdminCount.fromJson(Map<String, dynamic> j) => AdminCount(
        key: _str(j['key'] ?? j['event_type']),
        label: _str(j['label'] ?? j['event_type'] ?? j['key']),
        count: _int(j['count']),
      );
}

// --------------------------------------------------------- crop analytics (4.5)

class AdminCropStat {
  final String commodity;
  final int listings;
  final int activeListings;
  final double totalQuantity;
  final double? avgExpectedPrice;
  final int marketRows;
  final double? latestModalPrice;

  const AdminCropStat({
    required this.commodity,
    required this.listings,
    required this.activeListings,
    required this.totalQuantity,
    this.avgExpectedPrice,
    required this.marketRows,
    this.latestModalPrice,
  });

  factory AdminCropStat.fromJson(Map<String, dynamic> j) => AdminCropStat(
        commodity: _str(j['commodity']),
        listings: _int(j['listings']),
        activeListings: _int(j['active_listings']),
        totalQuantity: _double(j['total_quantity']),
        avgExpectedPrice: _doubleOrNull(j['avg_expected_price']),
        marketRows: _int(j['market_rows']),
        latestModalPrice: _doubleOrNull(j['latest_modal_price']),
      );
}

class AdminCropAnalytics {
  final int days;
  final List<AdminCropStat> crops;
  final List<AdminCount> listingsByStatus;

  const AdminCropAnalytics({
    required this.days,
    required this.crops,
    required this.listingsByStatus,
  });

  factory AdminCropAnalytics.fromJson(Map<String, dynamic> j) =>
      AdminCropAnalytics(
        days: _int(j['days']),
        crops: _listOf(j['crops'], AdminCropStat.fromJson),
        listingsByStatus: _listOf(j['listings_by_status'], AdminCount.fromJson),
      );
}

class AdminCropDetail {
  final String commodity;
  final int listings;
  final int activeListings;
  final int soldListings;
  final double totalQuantity;
  final double? avgExpectedPrice;
  final int marketRows;
  final int distinctMarkets;
  final double? latestModalPrice;
  final DateTime? latestTradeDate;
  final List<String> states;

  const AdminCropDetail({
    required this.commodity,
    required this.listings,
    required this.activeListings,
    required this.soldListings,
    required this.totalQuantity,
    this.avgExpectedPrice,
    required this.marketRows,
    required this.distinctMarkets,
    this.latestModalPrice,
    this.latestTradeDate,
    required this.states,
  });

  factory AdminCropDetail.fromJson(Map<String, dynamic> j) => AdminCropDetail(
        commodity: _str(j['commodity']),
        listings: _int(j['listings']),
        activeListings: _int(j['active_listings']),
        soldListings: _int(j['sold_listings']),
        totalQuantity: _double(j['total_quantity']),
        avgExpectedPrice: _doubleOrNull(j['avg_expected_price']),
        marketRows: _int(j['market_rows']),
        distinctMarkets: _int(j['distinct_markets']),
        latestModalPrice: _doubleOrNull(j['latest_modal_price']),
        latestTradeDate: _date(j['latest_trade_date']),
        states: [
          for (final s in (j['states'] as List? ?? const [])) s.toString(),
        ],
      );
}

// ----------------------------------------------------- market management (4.6)

class AdminMarketPrice {
  final int id;
  final String commodity;
  final String? variety;
  final String? grade;
  final String? state;
  final String? district;
  final String market;
  final DateTime? tradeDate;
  final double? minPrice;
  final double? modalPrice;
  final double? maxPrice;
  final String sourceName;
  final String? sourceConfidence;
  final bool sourceVerified;
  final DateTime? fetchedAt;

  const AdminMarketPrice({
    required this.id,
    required this.commodity,
    this.variety,
    this.grade,
    this.state,
    this.district,
    required this.market,
    this.tradeDate,
    this.minPrice,
    this.modalPrice,
    this.maxPrice,
    required this.sourceName,
    this.sourceConfidence,
    required this.sourceVerified,
    this.fetchedAt,
  });

  factory AdminMarketPrice.fromJson(Map<String, dynamic> j) => AdminMarketPrice(
        id: _int(j['id']),
        commodity: _str(j['commodity']),
        variety: _strOrNull(j['variety']),
        grade: _strOrNull(j['grade']),
        state: _strOrNull(j['state']),
        district: _strOrNull(j['district']),
        market: _str(j['market']),
        tradeDate: _date(j['trade_date']),
        minPrice: _doubleOrNull(j['min_price']),
        modalPrice: _doubleOrNull(j['modal_price']),
        maxPrice: _doubleOrNull(j['max_price']),
        sourceName: _str(j['source_name']),
        sourceConfidence: _strOrNull(j['source_confidence']),
        sourceVerified: j['source_verified'] == true,
        fetchedAt: _date(j['fetched_at']),
      );
}

class AdminMarketPricePage {
  final List<AdminMarketPrice> items;
  final int total;
  final int limit;
  final int offset;

  const AdminMarketPricePage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory AdminMarketPricePage.fromJson(Map<String, dynamic> j) =>
      AdminMarketPricePage(
        items: _listOf(j['items'], AdminMarketPrice.fromJson),
        total: _int(j['total']),
        limit: _int(j['limit']),
        offset: _int(j['offset']),
      );

  bool get hasMore => offset + items.length < total;
}

class AdminMarketSource {
  final String sourceName;
  final int rows;
  final DateTime? latestFetch;
  final int verifiedRows;

  const AdminMarketSource({
    required this.sourceName,
    required this.rows,
    this.latestFetch,
    required this.verifiedRows,
  });

  factory AdminMarketSource.fromJson(Map<String, dynamic> j) => AdminMarketSource(
        sourceName: _str(j['source_name']),
        rows: _int(j['rows']),
        latestFetch: _date(j['latest_fetch']),
        verifiedRows: _int(j['verified_rows']),
      );
}

class AdminForecastPoint {
  final DateTime? date;
  final double value;

  const AdminForecastPoint({this.date, required this.value});

  factory AdminForecastPoint.fromJson(Map<String, dynamic> j) =>
      AdminForecastPoint(date: _date(j['date']), value: _double(j['value']));
}

class AdminForecast {
  final String commodity;
  final String? state;
  final String status;
  final String? reason;
  final double? slopePerDay;
  final double? lastValue;
  final int basisPoints;
  final int horizonDays;
  final String method;
  final List<AdminForecastPoint> projection;

  const AdminForecast({
    required this.commodity,
    this.state,
    required this.status,
    this.reason,
    this.slopePerDay,
    this.lastValue,
    required this.basisPoints,
    required this.horizonDays,
    required this.method,
    required this.projection,
  });

  bool get isOk => status == 'ok';

  factory AdminForecast.fromJson(Map<String, dynamic> j) => AdminForecast(
        commodity: _str(j['commodity']),
        state: _strOrNull(j['state']),
        status: _str(j['status'], fallback: 'insufficient_data'),
        reason: _strOrNull(j['reason']),
        slopePerDay: _doubleOrNull(j['slope_per_day']),
        lastValue: _doubleOrNull(j['last_value']),
        basisPoints: _int(j['basis_points']),
        horizonDays: _int(j['horizon_days']),
        method: _str(j['method']),
        projection: _listOf(j['projection'], AdminForecastPoint.fromJson),
      );
}

// --------------------------------------------------------- permissions (4.10)

class AdminCapability {
  final String key;
  final String label;
  final String description;
  final List<String> roles;

  const AdminCapability({
    required this.key,
    required this.label,
    required this.description,
    required this.roles,
  });

  factory AdminCapability.fromJson(Map<String, dynamic> j) => AdminCapability(
        key: _str(j['key']),
        label: _str(j['label']),
        description: _str(j['description']),
        roles: [
          for (final r in (j['roles'] as List? ?? const [])) r.toString(),
        ],
      );
}

class AdminPermissions {
  final List<String> roles;
  final List<AdminCapability> capabilities;

  const AdminPermissions({required this.roles, required this.capabilities});

  factory AdminPermissions.fromJson(Map<String, dynamic> j) => AdminPermissions(
        roles: [for (final r in (j['roles'] as List? ?? const [])) r.toString()],
        capabilities: _listOf(j['capabilities'], AdminCapability.fromJson),
      );
}

// -------------------------------------------------------------- helpers

int _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _double(Object? v) => _doubleOrNull(v) ?? 0;

double? _doubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

String _str(Object? v, {String fallback = ''}) => v?.toString() ?? fallback;

String? _strOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString())?.toLocal();
}

List<T> _listOf<T>(Object? raw, T Function(Map<String, dynamic>) build) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map) build(e.cast<String, dynamic>()),
  ];
}
