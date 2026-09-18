import 'package:flutter/material.dart';
import '../models/weather.dart';
import '../theme/colors.dart';
import '../widgets/ui/cards.dart';
import '../widgets/weather_card.dart';

class WeatherAlertsScreen extends StatelessWidget {
  const WeatherAlertsScreen({super.key});

  static const _forecast = [
    _Day(day: 'Today', emoji: '\u2600\uFE0F', condition: 'Partly Cloudy', temp: 32, rain: 20),
    _Day(day: 'Fri', emoji: '\uD83C\uDF27\uFE0F', condition: 'Rain Showers', temp: 29, rain: 70),
    _Day(day: 'Sat', emoji: '\u2614', condition: 'Heavy Rain', temp: 27, rain: 90),
    _Day(day: 'Sun', emoji: '\uD83C\uDF27\uFE0F', condition: 'Light Rain', temp: 28, rain: 60),
    _Day(day: 'Mon', emoji: '\u2600\uFE0F', condition: 'Sunny', temp: 33, rain: 10),
    _Day(day: 'Tue', emoji: '\u2601\uFE0F', condition: 'Cloudy', temp: 31, rain: 30),
    _Day(day: 'Wed', emoji: '\u2600\uFE0F', condition: 'Sunny', temp: 34, rain: 5),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WeatherCard(weather: Weather.sampleDharwad()),
        const SizedBox(height: 20),
        Text(
          '7-day forecast',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary),
        ),
        const SizedBox(height: 12),
        ..._forecast.map((d) => _ForecastRow(day: d, isToday: d.day == 'Today')),
        const SizedBox(height: 20),
        Text(
          'Farming advisory',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: c.warning, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Heavy rain expected Saturday',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Complete harvesting of ready crops before Saturday. Delay pesticide spraying. Store feed in dry, elevated areas.',
                style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.dry_cleaning, color: c.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ideal window for sowing next week \u2014 soil moisture will be excellent after rains.',
                  style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ForecastRow extends StatelessWidget {
  final _Day day;
  final bool isToday;

  const _ForecastRow({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday ? c.primary : c.border,
          width: isToday ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              day.day,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                color: isToday ? c.primary : c.textPrimary,
              ),
            ),
          ),
          Text(day.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              day.condition,
              style: TextStyle(fontSize: 13.5, color: c.textPrimary),
            ),
          ),
          Icon(Icons.water_drop, size: 14, color: c.info),
          const SizedBox(width: 4),
          Text(
            '${day.rain}%',
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          const SizedBox(width: 14),
          Text(
            '${day.temp}\u00B0',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Day {
  final String day;
  final String emoji;
  final String condition;
  final int temp;
  final int rain;

  const _Day({
    required this.day,
    required this.emoji,
    required this.condition,
    required this.temp,
    required this.rain,
  });
}