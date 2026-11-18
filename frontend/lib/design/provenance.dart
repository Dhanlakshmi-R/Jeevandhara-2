/// Provenance: where a number came from, how old it is, and how far it may be
/// trusted. Every market figure the app renders carries one of these.
///
/// The backend attaches `_provenance` to every row it serves; this file is the
/// client-side mirror of that block plus the two enums the UI paints with
/// (`DataTier`, `Freshness`). Nothing here derives, estimates or invents a
/// value: if a field is absent it stays `null`, and a `null` renders as
/// "unknown" rather than as a favourable guess.
library;

/// How much a number is worth, per the tiers documented in
/// `backend/app/market/data_sources.yaml`:
///
/// * [a] official statistics or a government platform (data.gov.in, eNAM)
/// * [b] first-party - a number this app itself owns (a farmer's inquiry)
/// * [c] a third-party or community feed we do not control
/// * [d] derived in-app from A/B/C inputs, always an estimate
///
/// There is deliberately no tier E: seeded, mocked or illustrative rows are
/// forbidden, so the enum cannot express one.
enum DataTier {
  a('A'),
  b('B'),
  c('C'),
  d('D'),

  /// The source declared nothing, or declared something we do not recognise.
  /// Rendered as `?`, never as a favourable tier: an absent tier must not be
  /// drawn as A.
  unknown('?');

  const DataTier(this.code);

  /// The letter shown on chips.
  final String code;

  /// Maps the wire value to an enum member.
  static DataTier parse(Object? raw) {
    switch (raw.toString().trim().toUpperCase()) {
      case 'A':
        return DataTier.a;
      case 'B':
        return DataTier.b;
      case 'C':
        return DataTier.c;
      case 'D':
        return DataTier.d;
      default:
        return DataTier.unknown;
    }
  }
}

extension DataTierX on DataTier {
  bool get isKnown => this != DataTier.unknown;
}

/// Whether a rate may be acted on today.
///
/// [fresh] within a day of its own market date, [stale] real data but too old
/// to sell against, [unverified] from a feed we have never parsed a live
/// payload from. Age always comes from the observation's own date - never from
/// when we fetched it, which is how a week-old rate gets dressed as today's.
enum Freshness {
  fresh,
  stale,
  unverified,
  unknown;

  static Freshness parse(Object? raw) => switch (raw?.toString()) {
        'fresh' => Freshness.fresh,
        'stale' => Freshness.stale,
        'unverified' => Freshness.unverified,
        _ => Freshness.unknown,
      };
}

/// The `_provenance` block attached to a served row.
class Provenance {
  const Provenance({
    required this.source,
    required this.attribution,
    required this.confidence,
    required this.verified,
    required this.tier,
    required this.freshness,
    required this.actionable,
    required this.observedAt,
    required this.lagDays,
    required this.fetchedAt,
    required this.stale,
    this.note,
  });

  final String source;
  final String attribution;

  /// `high | medium | low | unknown` as declared by the feed itself.
  final String confidence;
  final bool verified;
  final DataTier tier;
  final Freshness freshness;

  /// True only for a fresh, dated, verified observation. A stale rate is never
  /// actionable no matter how confident the feed is.
  final bool actionable;

  /// The market date the row is about (not the fetch time).
  final DateTime? observedAt;

  /// Whole days between [observedAt] and now, as reported by the backend.
  final double? lagDays;

  /// When we actually pulled the payload - context only, never freshness.
  final DateTime? fetchedAt;
  final bool stale;
  final String? note;

  factory Provenance.fromJson(Map<String, dynamic> json) {
    return Provenance(
      source: json['source']?.toString() ?? 'unknown',
      attribution: json['attribution']?.toString() ?? '',
      confidence: json['confidence']?.toString() ?? 'unknown',
      verified: json['verified'] == true,
      tier: DataTier.parse(json['tier']),
      freshness: Freshness.parse(json['freshness']),
      actionable: json['actionable'] == true,
      observedAt: DateTime.tryParse(json['observed_at']?.toString() ?? ''),
      lagDays: (json['lag_days'] as num?)?.toDouble(),
      fetchedAt: DateTime.tryParse(json['fetched_at']?.toString() ?? ''),
      stale: json['stale'] == true,
      note: json['note']?.toString(),
    );
  }

  /// A row the backend served without a provenance block. Kept explicit so a
  /// contract regression shows up as an `unknown` chip on screen instead of
  /// silently inheriting a previous row's source.
  static const none = Provenance(
    source: 'unknown',
    attribution: '',
    confidence: 'unknown',
    verified: false,
    tier: DataTier.unknown,
    freshness: Freshness.unknown,
    actionable: false,
    observedAt: null,
    lagDays: null,
    fetchedAt: null,
    stale: false,
    note: 'row carried no provenance block',
  );
}

/// One entry of `/market/status.sources`.
class SourceStatus {
  const SourceStatus({
    required this.name,
    required this.enabled,
    required this.verified,
    required this.confidence,
    required this.attribution,
    required this.tier,
    required this.kind,
    required this.devOnly,
    this.disabledReason,
    this.verificationNote,
    this.lastError,
    this.lastSuccessAt,
  });

  final String name;
  final bool enabled;
  final bool verified;
  final String confidence;
  final String attribution;
  final DataTier tier;

  /// `price` or `arrival`.
  final String kind;
  final bool devOnly;
  final String? disabledReason;
  final String? verificationNote;
  final String? lastError;
  final DateTime? lastSuccessAt;

  /// A feed is trustworthy for display only when it is both enabled and
  /// verified. Anything else must be shown as not-yet-proven.
  bool get trusted => enabled && verified;

  factory SourceStatus.fromJson(Map<String, dynamic> json) {
    return SourceStatus(
      name: json['name']?.toString() ?? 'unknown',
      enabled: json['enabled'] == true,
      verified: json['verified'] == true,
      confidence: json['confidence']?.toString() ?? 'unknown',
      attribution: json['attribution']?.toString() ?? '',
      tier: DataTier.parse(json['tier']),
      kind: json['kind']?.toString() ?? 'price',
      devOnly: json['dev_only'] == true,
      disabledReason: json['disabled_reason']?.toString(),
      verificationNote: json['verification_note']?.toString(),
      lastError: json['last_error']?.toString(),
      lastSuccessAt: DateTime.tryParse(json['last_success_at']?.toString() ?? ''),
    );
  }
}

/// The `/market/status` payload: what the feeds are doing, and what the app
/// can therefore promise.
class MarketStatus {
  const MarketStatus({
    required this.live,
    required this.prices,
    required this.arrivals,
    required this.demandCapable,
    required this.checkedAt,
    required this.sources,
    required this.notes,
  });

  final bool live;

  /// `live | stale | unavailable`.
  final String prices;
  final String arrivals;
  final bool demandCapable;
  final DateTime? checkedAt;
  final List<SourceStatus> sources;
  final List<String> notes;

  /// Price feeds that are off, each with its stated reason. The banner shows
  /// these verbatim: "no API key" and "upstream 500" lead a farmer to very
  /// different next steps, so collapsing them would lose the only actionable
  /// part of the message.
  List<SourceStatus> get broken =>
      sources.where((s) => s.kind == 'price' && !s.trusted).toList();

  factory MarketStatus.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    return MarketStatus(
      live: json['live'] == true,
      prices: json['prices']?.toString() ?? 'unavailable',
      arrivals: json['arrivals']?.toString() ?? 'unavailable',
      demandCapable: json['demand_capable'] == true,
      checkedAt: DateTime.tryParse(json['checked_at']?.toString() ?? ''),
      sources: [
        if (rawSources is List)
          for (final s in rawSources)
            if (s is Map) SourceStatus.fromJson(Map<String, dynamic>.from(s)),
      ],
      notes: [
        if (json['notes'] is List)
          for (final n in (json['notes'] as List)) n.toString(),
      ],
    );
  }
}

/// Error raised when the backend answered 503 for a market read.
///
/// It carries the per-source `attempts` block so the UI can say *why* the
/// data is missing. Collapsing that into "no data today" is exactly the
/// failure this class exists to prevent.
class MarketUnavailableException implements Exception {
  const MarketUnavailableException(this.message, this.attempts, {this.kind});

  final String message;
  final List<SourceAttempt> attempts;
  final String? kind;

  @override
  String toString() => message;
}

/// One line of the 503 `attempts` array: a source and why it did not answer.
class SourceAttempt {
  const SourceAttempt({required this.source, required this.reason});

  final String source;
  final String reason;

  factory SourceAttempt.fromJson(Map<String, dynamic> json) => SourceAttempt(
        source: json['source']?.toString() ?? 'unknown',
        reason: json['reason']?.toString() ?? 'no reason given',
      );
}

/// Parses the `detail` object FastAPI sends with our 503s.
List<SourceAttempt> parseAttempts(Object? detail) {
  if (detail is! Map) return const [];
  final raw = detail['attempts'];
  if (raw is! List) return const [];
  return [
    for (final a in raw)
      if (a is Map) SourceAttempt.fromJson(Map<String, dynamic>.from(a)),
  ];
}
