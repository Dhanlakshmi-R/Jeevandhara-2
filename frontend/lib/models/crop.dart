/// A farmer's "I have this to sell" posting, as served by `/my-crops`.
///
/// The backend sends typed fields (numbers, dates, a lifecycle status), so the
/// model keeps them typed rather than flattening everything to display strings.
/// Nothing is invented on the way in: a missing asking price stays `null` and
/// renders as "No asking price", because the farmer's expectation is either
/// something they stated or something we do not have.
class CropListing {
  final int id;
  final String name;
  final String emoji;

  /// Quantity in [unit]. The server normalises nothing here — it is the
  /// farmer's own figure.
  final double quantity;
  final String unit;

  /// The farmer's own asking price per [unit], not a mandi quote.
  final double? expectedPrice;

  final String? location;
  final String? description;
  final DateTime? harvestDate;

  /// `active | sold | hidden`. Hidden rows are taken down but kept for history.
  final String status;
  final DateTime? createdAt;

  const CropListing({
    required this.id,
    required this.name,
    required this.emoji,
    required this.quantity,
    required this.unit,
    this.expectedPrice,
    this.location,
    this.description,
    this.harvestDate,
    this.status = 'active',
    this.createdAt,
  });

  factory CropListing.fromJson(Map<String, dynamic> json) {
    return CropListing(
      id: _asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      emoji: _nonEmpty(json['emoji']) ?? '\u{1F33E}',
      quantity: _asDouble(json['quantity']) ?? 0,
      unit: _nonEmpty(json['unit']) ?? 'kg',
      expectedPrice: _asDouble(json['expected_price']),
      location: _nonEmpty(json['location']),
      description: _nonEmpty(json['description']),
      harvestDate: _asDate(json['harvest_date']),
      status: _nonEmpty(json['status']) ?? 'active',
      createdAt: _asDate(json['created_at']),
    );
  }

  bool get isActive => status == 'active';
  bool get isSold => status == 'sold';
  bool get isHidden => status == 'hidden';

  String get quantityLabel => '${_number(quantity)} $unit';

  /// Never falls back to ₹0: no price means the farmer did not state one.
  String get priceLabel => expectedPrice == null
      ? 'No asking price'
      : '\u20B9${_number(expectedPrice!)}/$unit';

  String get statusLabel => switch (status) {
        'sold' => 'Sold',
        'hidden' => 'Hidden',
        _ => 'Active',
      };

  /// Age of the posting, derived from the server's `created_at`.
  ///
  /// [now] is injectable so the age contract is testable without freezing the
  /// clock. An undated row says so rather than pretending to be new.
  String listedAgo([DateTime? now]) {
    final created = createdAt;
    if (created == null) return 'Date unknown';
    final days = (now ?? DateTime.now()).difference(created).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 30) return '$days days ago';
    final months = days ~/ 30;
    return months == 1 ? '1 month ago' : '$months months ago';
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

DateTime? _asDate(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

String? _nonEmpty(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// `12.0` reads as `12`, `12.5` stays `12.5`.
String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
