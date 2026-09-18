class Weather {
  final String location;
  final double temperature;
  final String condition;
  final int rainChance;

  const Weather({
    required this.location,
    required this.temperature,
    required this.condition,
    required this.rainChance,
  });

  factory Weather.sampleDharwad() => const Weather(
        location: 'Dharwad, Karnataka',
        temperature: 32,
        condition: 'Partly Cloudy',
        rainChance: 20,
      );
}