class Tool {
  final String name;
  final String emoji;
  final String category;
  final double pricePerDay;
  final String location;
  final double ownerRating;
  final bool available;
  final String description;

  const Tool({
    required this.name,
    required this.emoji,
    required this.category,
    required this.pricePerDay,
    required this.location,
    required this.ownerRating,
    required this.available,
    required this.description,
  });

  static List<Tool> sampleData() => const [
        Tool(
          name: 'Mahindra Tractor 575',
          emoji: '\uD83D\uDE9C',
          category: 'Tractor',
          pricePerDay: 2500,
          location: 'Dharwad',
          ownerRating: 4.7,
          available: true,
          description: '75 HP tractor with trolley. Ideal for ploughing and hauling.',
        ),
        Tool(
          name: 'Power Tiller',
          emoji: '\uD83D\uDEE1\uFE0F',
          category: 'Tiller',
          pricePerDay: 1200,
          location: 'Hubballi',
          ownerRating: 4.5,
          available: true,
          description: '8 HP tiller, perfect for small-to-medium plots.',
        ),
        Tool(
          name: 'Combine Harvester',
          emoji: '\uD83C\uDF3E',
          category: 'Harvester',
          pricePerDay: 6000,
          location: 'Belagavi',
          ownerRating: 4.8,
          available: false,
          description: 'Wheat & paddy harvester with operator included.',
        ),
        Tool(
          name: 'Knapsack Sprayer',
          emoji: '\uD83D\uDCAA',
          category: 'Sprayer',
          pricePerDay: 300,
          location: 'Dharwad',
          ownerRating: 4.3,
          available: true,
          description: '16 L battery sprayer for pesticides and fertilizers.',
        ),
        Tool(
          name: 'Water Pump (2 HP)',
          emoji: '\uD83D\uDCA7',
          category: 'Pump',
          pricePerDay: 500,
          location: 'Gadag',
          ownerRating: 4.4,
          available: true,
          description: 'Portable diesel pump for irrigation and drainage.',
        ),
      ];
}