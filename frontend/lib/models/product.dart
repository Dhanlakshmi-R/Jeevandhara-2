/// A farming input listed for sale on the community marketplace, as served by
/// `/marketplace`.
///
/// [rating] is null until real reviews exist. The backend hardcodes it to null
/// for exactly that reason, and this model keeps the null rather than turning
/// it into "0.0 stars" — a fabricated rating is the one thing a buyer cannot
/// check for themselves.
class MarketplaceProduct {
  final int id;
  final String name;
  final String emoji;
  final String category;
  final double price;
  final String unit;

  /// Null means "no reviews yet", not zero.
  final double? rating;
  final bool inStock;
  final String? description;
  final String? poster;
  final int? posterId;
  final DateTime? createdAt;

  const MarketplaceProduct({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.price,
    required this.unit,
    this.rating,
    this.inStock = true,
    this.description,
    this.poster,
    this.posterId,
    this.createdAt,
  });

  factory MarketplaceProduct.fromJson(Map<String, dynamic> json) {
    return MarketplaceProduct(
      id: _asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      emoji: _nonEmpty(json['emoji']) ?? '\u{1F6D2}',
      category: _nonEmpty(json['category']) ?? 'Seeds',
      price: _asDouble(json['price']) ?? 0,
      unit: _nonEmpty(json['unit']) ?? 'pack',
      rating: _asDouble(json['rating']),
      inStock: json['in_stock'] == true,
      description: _nonEmpty(json['description']),
      poster: _nonEmpty(json['poster']),
      posterId: _asInt(json['poster_id']),
      createdAt: _asDate(json['created_at']),
    );
  }

  bool get hasRating => rating != null;

  String get priceLabel =>
      '\u20B9${price.toStringAsFixed(price % 1 == 0 ? 0 : 1)}/$unit';

  /// Whether [userId] may edit/remove this row. The server enforces the same
  /// rule; this only decides whether to show the control.
  bool isOwnedBy(int? userId) =>
      userId != null && posterId != null && posterId == userId;

  /// Categories the backend accepts for a new listing, plus the all-categories
  /// sentinel used by the filter chips.
  static const categories = [
    'All',
    'Seeds',
    'Fertilizers',
    'Pesticides',
    'Tools',
    'Eco-friendly',
  ];

  /// The categories a seller may choose (everything except the filter sentinel).
  static const sellCategories = [
    'Seeds',
    'Fertilizers',
    'Pesticides',
    'Tools',
    'Eco-friendly',
  ];
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
