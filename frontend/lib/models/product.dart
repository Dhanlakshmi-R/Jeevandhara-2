class MarketplaceProduct {
  final String name;
  final String emoji;
  final String category;
  final double price;
  final double rating;
  final bool inStock;
  final String unit;

  const MarketplaceProduct({
    required this.name,
    required this.emoji,
    required this.category,
    required this.price,
    required this.rating,
    required this.inStock,
    required this.unit,
  });

  String get priceLabel => '\u20B9${price.toStringAsFixed(price % 1 == 0 ? 0 : 1)}/$unit';

  static List<MarketplaceProduct> sampleData() => const [
        MarketplaceProduct(name: 'Hybrid Tomato Seeds', emoji: '\uD83C\uDF31', category: 'Seeds', price: 450, rating: 4.5, inStock: true, unit: 'pack'),
        MarketplaceProduct(name: 'Wheat Seeds (MPO)', emoji: '\uD83C\uDF3E', category: 'Seeds', price: 1600, rating: 4.7, inStock: true, unit: 'bag'),
        MarketplaceProduct(name: 'NPK Fertilizer 19-19-19', emoji: '\uD83E\uDDF1', category: 'Fertilizers', price: 640, rating: 4.4, inStock: true, unit: 'bag'),
        MarketplaceProduct(name: 'Urea (45 kg)', emoji: '\u2697\uFE0F', category: 'Fertilizers', price: 290, rating: 4.2, inStock: false, unit: 'bag'),
        MarketplaceProduct(name: 'Neem Oil Pesticide', emoji: '\uD83C\uDF3F', category: 'Pesticides', price: 380, rating: 4.6, inStock: true, unit: 'litre'),
        MarketplaceProduct(name: 'Folding Paddy Cutter', emoji: '\uD83D\uDD28', category: 'Tools', price: 750, rating: 4.3, inStock: true, unit: 'piece'),
        MarketplaceProduct(name: 'Organic Compost', emoji: '\uD83E\uDDCA', category: 'Eco-friendly', price: 220, rating: 4.8, inStock: true, unit: 'bag'),
        MarketplaceProduct(name: 'Cow Dung Vermicompost', emoji: '\uD83D\uDC0C', category: 'Eco-friendly', price: 180, rating: 4.9, inStock: false, unit: 'bag'),
      ];

  static const categories = ['All', 'Seeds', 'Fertilizers', 'Pesticides', 'Tools', 'Eco-friendly'];
}