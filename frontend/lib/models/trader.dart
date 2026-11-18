/// A trader's public "I am buying" card, as served by `/traders`.
///
/// The card is the trader's own claim: crops, price and availability are not
/// verified by anyone, and `rating` is null until real reviews exist (the UI
/// renders null as "New", never as a star score).
class Trader {
  final int id;
  final String name;
  final String company;
  final String? location;
  final List<String> crops;

  /// What the trader says they pay per quintal. Null means "ask".
  final double? offeredPricePerQuintal;
  final String? note;
  final String emoji;
  final bool available;
  final String? phone;

  /// Null until reviews exist; screens must never default it to a score.
  final double? rating;

  const Trader({
    required this.id,
    required this.name,
    this.company = '',
    this.location,
    this.crops = const [],
    this.offeredPricePerQuintal,
    this.note,
    this.emoji = '\u{1F3EA}',
    required this.available,
    this.phone,
    this.rating,
  });

  factory Trader.fromJson(Map<String, dynamic> json) {
    final emoji = json['emoji']?.toString();
    return Trader(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      location: json['location']?.toString(),
      crops: [
        if (json['crops'] is List)
          for (final c in json['crops'] as List) c.toString(),
      ],
      offeredPricePerQuintal:
          (json['offered_price_per_quintal'] as num?)?.toDouble(),
      note: json['note']?.toString(),
      emoji: (emoji != null && emoji.isNotEmpty) ? emoji : '\u{1F3EA}',
      available: json['available'] == true,
      phone: json['phone']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }

  String get cropLabel => crops.isEmpty ? 'Multiple crops' : crops.join(', ');

  String get priceLabel {
    final price = offeredPricePerQuintal;
    if (price == null || price <= 0) return 'Price on call';
    return '\u20B9${price.toStringAsFixed(0)}/quintal';
  }
}