class CropListing {
  final String name;
  final String emoji;
  final String quantity;
  final String expectedPrice;
  final String location;
  final String listedAgo;
  final String status;
  final DateTime? harvestDate;

  const CropListing({
    required this.name,
    required this.emoji,
    required this.quantity,
    required this.expectedPrice,
    required this.location,
    required this.listedAgo,
    required this.status,
    this.harvestDate,
  });

  static List<CropListing> sampleData() => const [
        CropListing(
          name: 'Tomato',
          emoji: '\uD83C\uDF45',
          quantity: '250 kg',
          expectedPrice: '\u20B928/kg',
          location: 'Dharwad',
          listedAgo: '2 days ago',
          status: 'Active',
        ),
        CropListing(
          name: 'Wheat',
          emoji: '\uD83C\uDF3E',
          quantity: '5 quintal',
          expectedPrice: '\u20B92,200/quintal',
          location: 'Hubballi',
          listedAgo: '5 days ago',
          status: 'Offer received',
        ),
        CropListing(
          name: 'Onion',
          emoji: '\uD83E\uDDC5',
          quantity: '1 quintal',
          expectedPrice: '\u20B936/kg',
          location: 'Dharwad',
          listedAgo: '2 weeks ago',
          status: 'Sold',
        ),
      ];
}