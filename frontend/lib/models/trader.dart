class Trader {
  final String name;
  final String company;
  final String location;
  final double rating;
  final String offeredPrice;
  final String cropType;
  final String distance;
  final bool available;
  final String phone;
  final String emoji;

  const Trader({
    required this.name,
    required this.company,
    required this.location,
    required this.rating,
    required this.offeredPrice,
    required this.cropType,
    required this.distance,
    required this.available,
    required this.phone,
    required this.emoji,
  });

  static List<Trader> sampleData() => const [
        Trader(
          name: 'Ramesh Patil',
          company: 'Patil Agro Traders',
          location: 'Hubballi',
          rating: 4.6,
          offeredPrice: '\u20B930/kg',
          cropType: 'Tomato',
          distance: '18 km',
          available: true,
          phone: '+91 98765 43210',
          emoji: '\uD83D\uDC68\u200D\uD83C\uDFED',
        ),
        Trader(
          name: 'Sunita Kulkarni',
          company: 'KS Food Supplies',
          location: 'Belagavi',
          rating: 4.8,
          offeredPrice: '\u20B92,250/quintal',
          cropType: 'Wheat',
          distance: '62 km',
          available: true,
          phone: '+91 91234 56780',
          emoji: '\uD83D\uDC69\u200D\uD83C\uDFED',
        ),
        Trader(
          name: 'Irfan Shaikh',
          company: 'Shaikh Grain House',
          location: 'Dharwad',
          rating: 4.2,
          offeredPrice: '\u20B933/kg',
          cropType: 'Onion',
          distance: '7 km',
          available: false,
          phone: '+91 90000 11223',
          emoji: '\uD83D\uDC68\u200D\uD83C\uDFED',
        ),
        Trader(
          name: 'Meena Gowda',
          company: 'GreenValley Exports',
          location: 'Gadag',
          rating: 4.9,
          offeredPrice: '\u20B967/kg',
          cropType: 'Groundnut',
          distance: '40 km',
          available: true,
          phone: '+91 99887 76655',
          emoji: '\uD83D\uDC69\u200D\uD83C\uDFED',
        ),
      ];
}