class MarketPrice {
  final String crop;
  final String emoji;
  final String unit;
  final double price;
  final double changePercent;
  final List<double> weekTrend;

  const MarketPrice({
    required this.crop,
    required this.emoji,
    required this.unit,
    required this.price,
    required this.changePercent,
    required this.weekTrend,
  });

  bool get isRising => changePercent > 0;

  String get trendLabel {
    if (changePercent > 1.5) return 'Rising';
    if (changePercent < -1.5) return 'Falling';
    return 'Stable';
  }

  String get priceLabel {
    final digits = price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
    return '\u20B9$digits/$unit';
  }

  static List<MarketPrice> sampleData() => const [
        MarketPrice(crop: 'Tomato', emoji: '\uD83C\uDF45', unit: 'kg', price: 28, changePercent: 5.2, weekTrend: [20, 22, 21, 24, 26, 27, 28]),
        MarketPrice(crop: 'Potato', emoji: '\uD83E\uDD54', unit: 'kg', price: 22, changePercent: -3.1, weekTrend: [26, 25, 24, 24, 23, 22, 22]),
        MarketPrice(crop: 'Wheat', emoji: '\uD83C\uDF3E', unit: 'quintal', price: 2150, changePercent: 2.4, weekTrend: [2000, 2030, 2050, 2080, 2100, 2130, 2150]),
        MarketPrice(crop: 'Onion', emoji: '\uD83E\uDDC5', unit: 'kg', price: 35, changePercent: -1.8, weekTrend: [38, 37, 36, 36, 35, 35, 35]),
        MarketPrice(crop: 'Cotton', emoji: '\u2611\uFE0F', unit: 'quintal', price: 6900, changePercent: 0.6, weekTrend: [6820, 6850, 6840, 6880, 6890, 6880, 6900]),
        MarketPrice(crop: 'Groundnut', emoji: '\uD83E\uDD5C', unit: 'kg', price: 64, changePercent: 4.0, weekTrend: [58, 60, 59, 61, 62, 63, 64]),
      ];
}