import 'package:flutter/material.dart';
import '../models/weather.dart';
import '../theme/colors.dart';

class WeatherCard extends StatelessWidget {
  final Weather weather;
  final VoidCallback? onMore;

  const WeatherCard({super.key, required this.weather, this.onMore});

  IconData _iconForCondition(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('rain')) return Icons.umbrella;
    if (c.contains('thunder')) return Icons.thunderstorm;
    if (c.contains('cloud') || c.contains('overcast')) return Icons.wb_cloudy;
    if (c.contains('sun') || c.contains('clear')) return Icons.wb_sunny;
    return Icons.cloud_queue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  weather.location,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${weather.temperature.toStringAsFixed(0)}\u00B0C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(_iconForCondition(weather.condition), color: Colors.white, size: 44),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                weather.condition,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Icon(Icons.water_drop, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                'Rain ${weather.rainChance}%',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          if (onMore != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onMore,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: const Text('7-day forecast', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}