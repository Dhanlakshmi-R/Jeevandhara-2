/// A rentable tool listed by a real user on the backend.
///
/// Fields mirror the `/tools` response. There is deliberately **no rating** on
/// a tool yet: reviews do not exist, and a fake star count on another
/// farmer's tiller would be worse than none.
class Tool {
  final int id;
  final String name;
  final String emoji;
  final String category;
  final String description;
  final double pricePerDay;
  final String location;
  final bool available;
  final String owner;

  const Tool({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.description,
    required this.pricePerDay,
    required this.location,
    required this.available,
    required this.owner,
  });

  factory Tool.fromJson(Map<String, dynamic> json) {
    final emoji = json['emoji']?.toString();
    final category = json['category']?.toString();
    return Tool(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      emoji: (emoji != null && emoji.isNotEmpty) ? emoji : '\u{1FA9C}',
      category: (category != null && category.isNotEmpty)
          ? category
          : 'Other',
      description: json['description']?.toString() ?? '',
      pricePerDay: (json['price_per_day'] as num?)?.toDouble() ?? 0,
      location: json['location']?.toString() ?? '',
      available: json['available'] == true,
      owner: json['owner']?.toString() ?? '',
    );
  }
}