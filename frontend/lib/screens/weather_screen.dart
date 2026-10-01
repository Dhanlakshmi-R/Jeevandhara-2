import 'package:flutter/material.dart';

import 'package:jeevandhara2/models/weather_data.dart';
import 'package:jeevandhara2/services/weather_place_store.dart';
import 'package:jeevandhara2/services/weather_recommendations.dart';
import 'package:jeevandhara2/services/weather_service.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'package:jeevandhara2/widgets/ui/states.dart';
import 'find_place_screen.dart';

/// Real-time weather dashboard (slots into the home shell's "Weather" tab).
class WeatherScreen extends StatefulWidget {
  final WeatherService? service;

  const WeatherScreen({super.key, this.service});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late final WeatherService _service = widget.service ?? WeatherService();
  final WeatherPlaceStore _store = WeatherPlaceStore();

  WeatherSuggestion? _place;
  WeatherData? _data;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final place = await _store.load();
    if (!mounted) return;
    if (place != null) {
      setState(() => _place = place);
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final place = _place;
    if (place == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchWeather(
        lat: place.lat,
        lon: place.lon,
        name: place.name,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _choosePlace() async {
    final place = await Navigator.of(context).push<WeatherSuggestion>(
      MaterialPageRoute(
          builder: (_) => FindPlaceScreen(service: widget.service)),
    );
    if (place == null || !mounted) return;
    setState(() {
      _place = place;
      _data = null;
      _error = null;
    });
    await _store.save(place);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: context.colors.primary,
      child: _data == null ? _buildPlaceholder() : _buildDashboard(),
    );
  }

  Widget _buildPlaceholder() {
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 2.8),
              ),
            ),
          )
        else if (_error != null)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.cloud_off_rounded, size: 44, color: c.danger),
                const SizedBox(height: 12),
                Text(
                  'Weather unavailable',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.5, color: c.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: AppTonalButton(
                          label: 'Retry',
                          icon: Icons.refresh,
                          onPressed: _refresh),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppTonalButton(
                        label: 'Change place',
                        icon: Icons.location_on_outlined,
                        onPressed: _choosePlace,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          EmptyState(
            icon: Icons.wb_sunny_outlined,
            title: _place == null ? 'No location yet' : 'Loading…',
            subtitle: _place == null
                ? 'Choose a place to see live weather and farming guidance.'
                : 'Fetching the latest conditions for ${_place!.name}.',
            actionLabel: _place == null ? 'Choose a location' : null,
            onAction: _place == null ? _choosePlace : null,
          ),
      ],
    );
  }

  Widget _buildDashboard() {
    final data = _data!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _TopRow(place: _place!, onChoose: _choosePlace, onRefresh: _refresh),
        const SizedBox(height: 10),
        if (_error != null)
          _InlineErrorBanner(message: _error!, onRetry: _refresh)
        else
          const SizedBox.shrink(),
        _HeroCard(data: data),
        const SizedBox(height: 14),
        _MetricsGrid(data: data),
        const SizedBox(height: 16),
        _AstroRow(sunrise: data.sunrise, sunset: data.sunset),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Hourly forecast'),
        const SizedBox(height: 10),
        _HourlyStrip(hourly: data.hourly),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Daily forecast'),
        const SizedBox(height: 10),
        _DailyList(daily: data.daily),
        if (data.alerts.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Weather alerts'),
          const SizedBox(height: 10),
          ...data.alerts
              .map((a) => _AlertCard(alert: a, key: ValueKey(a.headline))),
        ],
        const SizedBox(height: 24),
        const SectionHeader(title: 'Farmer recommendations'),
        const SizedBox(height: 6),
        Text(
          recommendationDisclaimer,
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 10),
        ...buildFarmRecommendations(data).map((r) => _RecommendationCard(
            rec: r, key: ValueKey('${r.title}|${r.message}'))),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'Last updated: ${_timeLabel(data.lastUpdated)}',
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

String _timeLabel(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${dt.hour < 12 ? 'AM' : 'PM'}';
}

String _hourLabel(DateTime time) {
  return '${time.hour % 12 == 0 ? 12 : time.hour % 12} ${time.hour < 12 ? 'AM' : 'PM'}';
}

String _weekday(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[date.weekday - 1];
}

class _TopRow extends StatelessWidget {
  final WeatherSuggestion place;
  final VoidCallback onChoose;
  final VoidCallback onRefresh;

  const _TopRow(
      {required this.place, required this.onChoose, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(Icons.location_on, size: 18, color: c.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            place.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.textPrimary),
          ),
        ),
        const SizedBox(width: 8),
        AppIconButton(
            icon: Icons.edit_location_alt_outlined,
            onPressed: onChoose,
            tooltip: 'Change location'),
        const SizedBox(width: 4),
        AppIconButton(
            icon: Icons.refresh, onPressed: onRefresh, tooltip: 'Refresh'),
      ],
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.dangerSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: c.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: c.textPrimary),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final WeatherData data;

  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.brandGradientStart, c.brandGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                data.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              _ConditionImage(
                  condition: data.condition, isDay: data.isDay, size: 56),
            ],
          ),
          if (data.region.isNotEmpty)
            Text(
              '${data.region}, ${data.country}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
            ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.tempC.round()}\u00B0',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.condition.text,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Feels like ${data.feelsLikeC.round()}\u00B0',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroPill(
                  icon: Icons.water_drop,
                  label: 'Humidity ${data.humidity.round()}%'),
              const SizedBox(width: 10),
              _HeroPill(
                icon: Icons.air,
                label: data.windDir.isEmpty
                    ? '${data.windKph.round()} km/h'
                    : '${data.windKph.round()} km/h ${data.windDir}',
              ),
              const SizedBox(width: 10),
              _HeroPill(
                icon: Icons.umbrella,
                label: '${data.todayRainChance.round()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ConditionImage extends StatelessWidget {
  final WeatherCondition condition;
  final bool isDay;
  final double size;

  const _ConditionImage(
      {required this.condition, required this.isDay, required this.size});

  @override
  Widget build(BuildContext context) {
    if (condition.httpsIcon.isNotEmpty) {
      return Image.network(
        condition.httpsIcon,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(condition.materialIcon, size: size, color: Colors.white),
      );
    }
    return Icon(condition.materialIcon, size: size, color: Colors.white);
  }
}

class _MetricsGrid extends StatelessWidget {
  final WeatherData data;

  const _MetricsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Feels like',
        '${data.feelsLikeC.round()}\u00B0C',
        Icons.thermostat_rounded
      ),
      ('Humidity', '${data.humidity.round()}%', Icons.water_drop_outlined),
      (
        'Wind',
        data.windDir.isEmpty
            ? '${data.windKph.round()} km/h'
            : '${data.windKph.round()} km/h ${data.windDir}',
        Icons.air
      ),
      (
        'Precipitation',
        '${data.precipMm.toStringAsFixed(1)} mm',
        Icons.umbrella_outlined
      ),
      (
        'UV index',
        data.uv == null ? 'n/a' : data.uv!.toStringAsFixed(1),
        Icons.wb_sunny_outlined
      ),
      ('Rain today', '${data.todayRainChance.round()}%', Icons.invert_colors),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 640 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: 92,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _MetricCard(
              label: items[i].$1, value: items[i].$2, icon: items[i].$3),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.primary),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AstroRow extends StatelessWidget {
  final String sunrise;
  final String sunset;

  const _AstroRow({required this.sunrise, required this.sunset});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AstroTile(
              icon: Icons.wb_twilight, label: 'Sunrise', value: sunrise),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AstroTile(
              icon: Icons.nights_stay_outlined, label: 'Sunset', value: sunset),
        ),
      ],
    );
  }
}

class _AstroTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AstroTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.accent),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
              Text(
                value.isEmpty ? '—' : value,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourlyStrip extends StatelessWidget {
  final List<HourlyForecast> hourly;

  const _HourlyStrip({required this.hourly});

  @override
  Widget build(BuildContext context) {
    if (hourly.isEmpty) {
      return Text(
        'Hourly data not available for your plan.',
        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
      );
    }
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hourly.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _HourlyCard(hour: hourly[i]),
      ),
    );
  }
}

class _HourlyCard extends StatelessWidget {
  final HourlyForecast hour;

  const _HourlyCard({required this.hour});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Text(
            _hourLabel(hour.time),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textSecondary),
          ),
          const SizedBox(height: 8),
          Icon(hour.condition.materialIcon, size: 22, color: c.primary),
          const SizedBox(height: 6),
          Text(
            '${hour.tempC.round()}\u00B0',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            '${hour.chanceOfRain}%',
            style: TextStyle(fontSize: 11, color: c.info),
          ),
        ],
      ),
    );
  }
}

class _DailyList extends StatelessWidget {
  final List<DailyForecast> daily;

  const _DailyList({required this.daily});

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return Text(
        'Daily forecast not available for your plan.',
        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < daily.length; i++)
          _DailyRow(day: daily[i], isToday: i == 0),
      ],
    );
  }
}

class _DailyRow extends StatelessWidget {
  final DailyForecast day;
  final bool isToday;

  const _DailyRow({required this.day, required this.isToday});

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
            width: 52,
            child: Text(
              isToday ? 'Today' : _weekday(day.date),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday ? c.primary : c.textPrimary,
              ),
            ),
          ),
          Icon(day.condition.materialIcon, size: 18, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              day.condition.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: c.textPrimary),
            ),
          ),
          Icon(Icons.water_drop, size: 13, color: c.info),
          const SizedBox(width: 4),
          SizedBox(
            width: 34,
            child: Text(
              '${day.chanceOfRain}%',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${day.minTempC.round()}\u00B0 / ${day.maxTempC.round()}\u00B0',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final WeatherAlertData alert;

  const _AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final danger = alert.severity.toLowerCase().contains('severe');
    final color = danger ? c.danger : c.warning;
    final surface = danger ? c.dangerSurface : c.warnSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.headline.isNotEmpty ? alert.headline : alert.event,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary),
                ),
                if (alert.instruction.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    alert.instruction,
                    style: TextStyle(
                        fontSize: 13, color: c.textSecondary, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final FarmRecommendation rec;

  const _RecommendationCard({super.key, required this.rec});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, surface, icon) = switch (rec.level) {
      AdviceLevel.good => (
          c.positive,
          c.successSurface,
          Icons.check_circle_outline
        ),
      AdviceLevel.caution => (c.warning, c.warnSurface, Icons.info_outline),
      AdviceLevel.danger => (c.danger, c.dangerSurface, Icons.error_outline),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  rec.message,
                  style: TextStyle(
                      fontSize: 13, color: c.textSecondary, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
