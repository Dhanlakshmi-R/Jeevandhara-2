import 'package:flutter/material.dart';

import 'package:jeevandhara2/app/destinations.dart';
import 'package:jeevandhara2/app/shell/app_shell.dart';
import 'package:jeevandhara2/design/provenance.dart';
import 'package:jeevandhara2/models/crop.dart';
import 'package:jeevandhara2/models/market_price.dart';
import 'package:jeevandhara2/models/user.dart';
import 'package:jeevandhara2/models/weather.dart';
import 'package:jeevandhara2/models/weather_data.dart';
import 'package:jeevandhara2/models/soil_moisture.dart';
import 'package:jeevandhara2/services/api_service.dart';
import 'package:jeevandhara2/services/crops_service.dart';
import 'package:jeevandhara2/services/market_service.dart';
import 'package:jeevandhara2/services/weather_place_store.dart';
import 'package:jeevandhara2/services/weather_service.dart';
import 'package:jeevandhara2/services/soil_moisture_service.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/theme/locale.dart';
import 'package:jeevandhara2/widgets/layout.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'package:jeevandhara2/widgets/ui/provenance_chip.dart';
import 'package:jeevandhara2/widgets/ui/states.dart';
import 'package:jeevandhara2/widgets/weather_card.dart';

/// The farmer's entry point.
///
/// The chat is now the landing surface and the sidebar carries the rest, so
/// this is a thin wrapper over [AppShell] rather than a page of its own. The
/// dashboard survives as [FarmerDashboardPage] and is reachable from the
/// sidebar and the command palette.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.user});

  /// Passed by the login flow so the avatar is right on the first frame. The
  /// shell refetches the profile itself, so omitting it is fine too.
  final AppUser? user;

  @override
  Widget build(BuildContext context) =>
      AppShell(role: AppRole.farmer, initialUser: user);
}

/// The farmer's overview page.
///
/// [user] and [onRefresh] are optional so this can be constructed straight
/// from the destination registry; when omitted it fetches the current user
/// itself and refreshes on pull.
class FarmerDashboardPage extends StatefulWidget {
  final AppUser? user;
  final Future<void> Function()? onRefresh;
  final WeatherService? weatherService;

  const FarmerDashboardPage({
    super.key,
    this.user,
    this.onRefresh,
    this.weatherService,
  });

  @override
  State<FarmerDashboardPage> createState() => FarmerDashboardPageState();
}

class FarmerDashboardPageState extends State<FarmerDashboardPage> {
  final _apiService = ApiService();
  AppUser? _ownUser;
  bool _loading = false;

  AppUser? get _user => widget.user ?? _ownUser;

  @override
  void initState() {
    super.initState();
    // Only fetch when nobody upstream supplied the user, so a shell that
    // already loaded it does not pay for a second round trip.
    if (widget.user == null) _loadUser();
  }

  Future<void> _loadUser() async {
    if (_loading) return;
    _loading = true;
    try {
      final user = await _apiService.getCurrentUser();
      if (mounted) setState(() => _ownUser = user);
    } catch (_) {
      // An unauthenticated or offline session just leaves the stats as they
      // are; this page is still useful without them.
    } finally {
      _loading = false;
    }
  }

  Future<void> _refresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
      return;
    }
    await _loadUser();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const SizedBox(height: 8),
          _WelcomeBanner(name: _user?.name),
          const SizedBox(height: 20),
          _DashboardGrid(weatherService: widget.weatherService),
          const SizedBox(height: 20),
          _buildQuickActions(),
          const SizedBox(height: 20),
          const _RecentSection(),
          const SizedBox(height: 20),
          const _TipCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
            title: 'Quick Actions',
            actionLabel: 'View All',
            actionIcon: Icons.chevron_right),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = responsiveCols(constraints.maxWidth);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisExtent: 128,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _quickActions(context).length,
              itemBuilder: (context, i) =>
                  _QuickActionCard(spec: _quickActions(context)[i]),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionSpec {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionSpec(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap});
}

class _QuickActionCard extends StatelessWidget {
  final _QuickActionSpec spec;
  const _QuickActionCard({required this.spec});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: spec.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: spec.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(spec.icon, color: spec.color, size: 22)),
              const Spacer(),
              Text(spec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(spec.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({this.name});

  /// The signed-in farmer. Falls back to a neutral label rather than a
  /// hardcoded name when the profile has not loaded yet.
  final String? name;

  String get _firstName {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return 'Farmer';
    return raw.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final greeting = _greeting(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c.primary, c.primaryDark]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: c.primary.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 10))
          ]),
      child: Stack(children: [
        Positioned(
            right: -40,
            top: -50,
            child: Icon(Icons.eco_rounded,
                size: 180, color: Colors.white.withValues(alpha: 0.06))),
        Positioned(
            right: 50,
            bottom: -50,
            child: Icon(Icons.grass_rounded,
                size: 140, color: Colors.white.withValues(alpha: 0.05))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greeting,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(_firstName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('Welcome back to your farm dashboard.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
          const SizedBox(height: 16),
          const Wrap(spacing: 10, runSpacing: 10, children: [
            _BannerStat(
                icon: Icons.landscape_outlined,
                value: '2.4 acres',
                label: 'Land'),
            _BannerStat(
                icon: Icons.eco_outlined, value: '5 crops', label: 'Active'),
            _BannerStat(
                icon: Icons.inventory_2_outlined,
                value: '250 kg',
                label: 'To sell'),
          ]),
        ]),
      ]),
    );
  }

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _BannerStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _BannerStat(
      {required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
      ]),
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  final WeatherService? weatherService;
  const _DashboardGrid({this.weatherService});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
            title: 'Weather Summary',
            actionLabel: 'Details',
            actionIcon: Icons.arrow_forward_ios),
        const SizedBox(height: 10),
        _WeatherSummaryCard(
          service: weatherService,
          onMore: () =>
              AppShellScope.maybeOf(context)?.open(AppDestination.weather),
        ),
        const SizedBox(height: 20),
        const SectionHeader(
            title: 'Soil Moisture',
            actionLabel: 'Details',
            actionIcon: Icons.arrow_forward_ios),
        const SizedBox(height: 10),
        const _SoilMoistureCard(),
        const SizedBox(height: 20),
        const SectionHeader(
            title: 'Live Market Prices',
            actionLabel: 'View All',
            actionIcon: Icons.trending_up),
        const SizedBox(height: 10),
        const _MiniPrices(),
      ],
    );
  }
}

/// Real weather summary card for the dashboard.
class _WeatherSummaryCard extends StatefulWidget {
  final WeatherService? service;
  final VoidCallback? onMore;

  const _WeatherSummaryCard({this.service, this.onMore});

  @override
  State<_WeatherSummaryCard> createState() => _WeatherSummaryCardState();
}

class _WeatherSummaryCardState extends State<_WeatherSummaryCard> {
  late final WeatherService _service = widget.service ?? WeatherService();
  final WeatherPlaceStore _store = WeatherPlaceStore();
  Weather? _weather;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    WeatherSuggestion place;
    final saved = await _store.load();
    if (saved != null) {
      place = saved;
    } else {
      place = const WeatherSuggestion(
        name: 'Dharwad',
        region: 'Karnataka',
        country: 'India',
        lat: 15.46,
        lon: 75.01,
      );
    }
    try {
      final data = await _service.fetchWeather(
        lat: place.lat,
        lon: place.lon,
        name: place.name,
      );
      if (!mounted) return;
      final location = data.region.isNotEmpty
          ? '${data.name}, ${data.region}'
          : (data.name.isNotEmpty ? data.name : place.label);
      setState(() {
        _weather = Weather(
          location: location,
          temperature: data.tempC,
          condition: data.condition.text,
          rainChance: data.todayRainChance.round(),
        );
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (_error != null) {
      return Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Icon(Icons.cloud_off, color: c.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Weather unavailable. $_error',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    final weather = _weather;
    if (weather == null) {
      return const SizedBox(height: 150);
    }
    return WeatherCard(weather: weather, onMore: widget.onMore);
  }
}

class _SoilMoistureCard extends StatefulWidget {
  const _SoilMoistureCard();

  @override
  State<_SoilMoistureCard> createState() => _SoilMoistureCardState();
}

class _SoilMoistureCardState extends State<_SoilMoistureCard> {
  final SoilMoistureService _service = SoilMoistureService();
  SoilMoistureReading? _reading;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _service.latest();
      if (!mounted) return;
      setState(() {
        _reading = r;
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Icon(Icons.cloud_off, color: c.warning),
          const SizedBox(width: 10),
          Expanded(child: Text('Soil sensor unavailable. $_error', style: TextStyle(fontSize: 13, color: c.textSecondary))),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    final r = _reading;
    if (r == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Icon(Icons.sensors_off, color: c.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No soil-moisture sensor connected yet. Point your device at '
              'POST /sensors/soil-moisture to start reporting.',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
        ]),
      );
    }
    final pct = r.moisturePct;
    final advice = pct < 30
        ? 'Low moisture — irrigate soon.'
        : pct < 60
            ? 'Moderate moisture — monitor daily.'
            : 'Good moisture — no irrigation needed.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.grass, color: c.primary),
          const SizedBox(width: 8),
          Text('Soil moisture', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const Spacer(),
          Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.primaryDark)),
        ]),
        const SizedBox(height: 6),
        Text(advice, style: TextStyle(fontSize: 13, color: c.textSecondary)),
        if (r.temperatureC != null) ...[
          const SizedBox(height: 4),
          Text('Soil temp ${r.temperatureC!.toStringAsFixed(1)}°C', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ],
      ]),
    );
  }
}

/// A short strip of real quotations for crops we actually hold rows for.
///
/// This used to be a bundled list of six invented crops with invented trends,
/// painted on the first screen a farmer sees. It now reads `/market/prices`
/// for the first crops storage can answer for, and says plainly when it
/// cannot: a dashboard that shows nothing is recoverable, one that shows a
/// confident wrong rate is not.
class _MiniPrices extends StatefulWidget {
  const _MiniPrices();

  @override
  State<_MiniPrices> createState() => _MiniPricesState();
}

class _MiniPricesState extends State<_MiniPrices> {
  final MarketService _service = MarketService();
  List<MarketPrice> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Two round trips by design: the crop list tells us which rows exist, so
    // we never fire off requests for crops nobody has quoted.
    List<String> crops;
    try {
      final items = await _service.commodities();
      crops = [for (final i in items.take(4)) i.commodity];
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Market feed unreachable';
      });
      return;
    }
    if (crops.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _rows = [];
      });
      return;
    }

    final pages = await Future.wait([
      for (final crop in crops)
        // A crop that fails is simply skipped: the strip would rather show
        // three real rows than a fourth padded with a placeholder.
        _service
            .prices(commodity: crop, limit: 1)
            .then((p) => p.rows)
            .catchError((_) => <MarketPrice>[]),
    ]);
    if (!mounted) return;
    setState(() {
      // One freshest row per crop, newest first, so the strip cannot repeat
      // the same mandi four times.
      final best = <String, MarketPrice>{};
      for (final rows in pages) {
        for (final r in rows) {
          final prev = best[r.commodity];
          if (prev == null ||
              (r.date?.isAfter(prev.date ?? DateTime(0)) ?? false)) {
            best[r.commodity] = r;
          }
        }
      }
      final all = best.values.toList()..sort(_compareByFreshness);
      _rows = all;
      _loading = false;
    });
  }

  /// Fresh rows first - a dashboard strip that leads with last week's rate
  /// makes the whole app look stale - then newest observation first.
  static int _compareByFreshness(MarketPrice a, MarketPrice b) {
    int rank(Freshness f) => switch (f) {
          Freshness.fresh => 0,
          Freshness.stale => 1,
          Freshness.unverified => 2,
          Freshness.unknown => 3,
        };
    final byFresh =
        rank(a.provenance.freshness).compareTo(rank(b.provenance.freshness));
    if (byFresh != 0) return byFresh;
    return (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return const SizedBox(
        height: 130,
        child: Row(
          children: [
            SkeletonBox(width: 210, height: 114),
            SizedBox(width: 12),
            SkeletonBox(width: 210, height: 114),
          ],
        ),
      );
    }
    if (_error != null) {
      return Container(
        height: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Icon(Icons.cloud_off, color: c.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$_error. ${context.str(K.pricesUnavailableRightNow)}',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
        ]),
      );
    }
    if (_rows.isEmpty) {
      return Container(
        height: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Icon(Icons.trending_up, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.str(K.noQuotationsYet),
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
        ]),
      );
    }
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _MiniPriceCard(price: _rows[i]),
      ),
    );
  }
}

class _MiniPriceCard extends StatelessWidget {
  final MarketPrice price;
  const _MiniPriceCard({required this.price});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
                color: c.shadow, blurRadius: 8, offset: const Offset(0, 3))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(price.commodity,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary)),
              Text(price.market ?? context.str(K.mandiNotReported),
                  style: TextStyle(fontSize: 11, color: c.textSecondary)),
            ],
          ),
        ),
        Text(price.priceLabelOf(context.str),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: c.primaryDark)),
        const SizedBox(height: 6),
        ProvenanceChip(provenance: price.provenance, dense: true),
      ]),
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final sideBySide = constraints.maxWidth >= 840;
      if (sideBySide) {
        return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ListingsCard()),
              SizedBox(width: 16),
              Expanded(child: _OffersCard())
            ]);
      }
      return const Column(
          children: [_ListingsCard(), SizedBox(height: 16), _OffersCard()]);
    });
  }
}

class _ListingsCard extends StatefulWidget {
  const _ListingsCard();

  @override
  State<_ListingsCard> createState() => _ListingsCardState();
}

class _ListingsCardState extends State<_ListingsCard> {
  final CropsService _service = CropsService();
  List<CropListing> _crops = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final crops = await _service.crops();
      if (!mounted) return;
      setState(() {
        _crops = crops
            .where((crop) => !crop.isHidden)
            .take(3)
            .toList(growable: false);
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openMyCrops() {
    AppShellScope.maybeOf(context)?.open(AppDestination.myCrops);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Recent Crop Listings',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary)),
            TextButton(onPressed: _openMyCrops, child: const Text('View all'))
          ]),
          const Divider(),
          const SizedBox(height: 8),
          ..._body(context),
        ]));
  }

  List<Widget> _body(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return const [LoadingSkeleton(rows: 2)];
    }
    if (_error != null) {
      return [
        Row(children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: c.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not load your crops',
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
          ),
          TextButton(onPressed: _reload, child: const Text('Retry')),
        ]),
      ];
    }
    if (_crops.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Icon(Icons.eco_outlined, size: 18, color: c.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No crops listed yet.',
                style: TextStyle(fontSize: 12.5, color: c.textSecondary),
              ),
            ),
            TextButton(
                onPressed: _openMyCrops, child: const Text('List a crop')),
          ]),
        ),
      ];
    }
    return [for (final crop in _crops) _CropRow(crop: crop)];
  }
}

class _CropRow extends StatelessWidget {
  final CropListing crop;
  const _CropRow({required this.crop});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final statusColor = crop.isSold
        ? c.textSecondary
        : crop.isActive
            ? c.positive
            : c.textSecondary;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: c.primaryLight,
                  borderRadius: BorderRadius.circular(14)),
              child: Center(
                  child:
                      Text(crop.emoji, style: const TextStyle(fontSize: 26)))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(crop.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
                Text(crop.quantityLabel,
                    style: TextStyle(fontSize: 12, color: c.textSecondary))
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(crop.priceLabel,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.primaryDark)),
            const SizedBox(height: 3),
            StatusBadge(text: crop.statusLabel, color: statusColor)
          ]),
        ]));
  }
}

class _OffersCard extends StatelessWidget {
  const _OffersCard();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
            title: 'Recent Trader Offers',
            actionLabel: 'View All',
            actionIcon: Icons.people_outline),
        const SizedBox(height: 10),
        EmptyState(
          icon: Icons.people_outline,
          title: context.str(K.noOffersYet),
          subtitle: context.str(K.noOffersYetHint),
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [c.accentLight, c.accent.withValues(alpha: 0.2)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.accent.withValues(alpha: 0.4))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: c.accent, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.lightbulb_outlined,
                color: Colors.black87, size: 24)),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Farming Tip of the Day',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textOnAccent)),
          const SizedBox(height: 8),
          Text(
              'Water your crops early in the morning to reduce evaporation. Soil moisture is highest before sunrise \u2014 you can save up to 30% water.',
              style: TextStyle(
                  fontSize: 13.5, height: 1.45, color: c.textOnAccent))
        ])),
      ]),
    );
  }
}

List<_QuickActionSpec> _quickActions(BuildContext context) => [
      _QuickActionSpec(
          title: 'Sell Crop',
          subtitle: 'List produce to traders',
          icon: Icons.sell_outlined,
          color: const Color(0xFF1F6B45),
          onTap: () =>
              AppShellScope.maybeOf(context)?.open(AppDestination.myCrops)),
      _QuickActionSpec(
          title: 'Analyze Quality',
          subtitle: 'AI grade & scan crops',
          icon: Icons.biotech_outlined,
          color: const Color(0xFF5DAE54),
          onTap: () => AppShellScope.maybeOf(context)
              ?.open(AppDestination.qualityAnalysis)),
      _QuickActionSpec(
          title: 'Find Traders',
          subtitle: 'Matched buyers nearby',
          icon: Icons.handshake_outlined,
          color: const Color(0xFFF4B942),
          onTap: () =>
              AppShellScope.maybeOf(context)?.open(AppDestination.traders)),
      _QuickActionSpec(
          title: 'Rent Tools',
          subtitle: 'Tractors & equipment',
          icon: Icons.agriculture_outlined,
          color: const Color(0xFF2E86AB),
          onTap: () =>
              AppShellScope.maybeOf(context)?.open(AppDestination.toolRental)),
    ];
