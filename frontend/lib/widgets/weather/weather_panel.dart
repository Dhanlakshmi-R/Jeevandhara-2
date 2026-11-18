import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeevandhara2/models/weather_data.dart';
import 'package:jeevandhara2/services/current_location.dart';
import 'package:jeevandhara2/services/place_search.dart';
import 'package:jeevandhara2/services/weather_place_store.dart';
import 'package:jeevandhara2/services/weather_recommendations.dart';
import 'package:jeevandhara2/services/weather_service.dart';
import 'package:jeevandhara2/services/weather_speaker.dart';
import 'package:jeevandhara2/widgets/weather/weather_palette.dart';
import 'package:jeevandhara2/widgets/weather/weather_strings.dart';

const String _langPrefKey = 'weather_lang';

/// The shared weather panel.
///
/// Self-contained: it owns location, search, fetching, the language selector
/// and read-aloud, so the farmer app and the admin console embed the exact same
/// widget and get identical behaviour. All colours come from [WeatherPalette]
/// rather than the host theme, so it looks the same in both places.
class WeatherPanel extends StatefulWidget {
  final WeatherService? service;
  final CurrentLocationService? locationService;
  final WeatherSpeaker? speaker;
  final WeatherPlaceStore? store;

  const WeatherPanel({
    super.key,
    this.service,
    this.locationService,
    this.speaker,
    this.store,
  });

  @override
  State<WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<WeatherPanel> {
  late final WeatherService _service = widget.service ?? WeatherService();
  late final CurrentLocationService _location =
      widget.locationService ?? const CurrentLocationService();
  late final WeatherSpeaker _speaker = widget.speaker ?? TtsWeatherSpeaker();
  late final WeatherPlaceStore _store = widget.store ?? WeatherPlaceStore();

  late final PlaceSearchController _search =
      PlaceSearchController(fetchSuggestions: _service.suggestions);

  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  WeatherLang _lang = WeatherLang.en;
  WeatherSuggestion? _place;
  bool _usingCurrentLocation = false;
  WeatherData? _data;
  bool _loading = false;
  String? _error;
  String? _notice;
  bool _speaking = false;

  WeatherStrings get _s => WeatherStrings(_lang);

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _focus.addListener(_onSearchChanged);
    _loadLang();
    _restore();
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    _focus.dispose();
    _queryCtrl.dispose();
    _speaker.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_langPrefKey);
    if (code == 'kn' && mounted) {
      setState(() => _lang = WeatherLang.kn);
    }
  }

  Future<void> _setLang(WeatherLang lang) async {
    if (lang == _lang) return;
    setState(() => _lang = lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langPrefKey, lang.code);
  }

  Future<void> _restore() async {
    final saved = await _store.load();
    if (!mounted) return;
    if (saved != null) {
      setState(() => _place = saved);
      await _refresh();
    } else {
      await _useCurrentLocation();
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _notice = null;
      _loading = true;
      _error = null;
    });
    final result = await _location.resolve();
    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _loading = false;
        _notice = switch (result.outcome) {
          LocationOutcome.denied => _s.locationPermissionDenied,
          LocationOutcome.deniedForever => _s.locationPermissionForever,
          LocationOutcome.serviceDisabled => _s.locationDisabled,
          _ => _s.locationError,
        };
      });
      return;
    }

    setState(() {
      _place = result.place;
      _usingCurrentLocation = true;
      _data = null;
    });
    await _store.save(result.place!);
    await _fetch();
  }

  Future<void> _refresh() async {
    if (_usingCurrentLocation) {
      await _useCurrentLocation();
      return;
    }
    await _fetch();
  }

  Future<void> _fetch() async {
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
        name: _usingCurrentLocation ? '' : place.name,
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

  Future<void> _selectPlace(WeatherSuggestion place) async {
    _queryCtrl.text = place.label;
    _search.select(place);
    _focus.unfocus();
    setState(() {
      _place = place;
      _usingCurrentLocation = false;
      _data = null;
      _notice = null;
      _error = null;
    });
    await _store.save(place);
    await _fetch();
  }

  Future<void> _submitQuery() async {
    if (_search.resolvable == null && _search.hasQuery) {
      await _search.retry();
    }
    final place = _search.resolvable;
    if (place != null) {
      await _selectPlace(place);
    }
  }

  void _clearQuery() {
    _queryCtrl.clear();
    _search.clear();
  }

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _speaker.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final data = _data;
    final place = _place;
    if (data == null || place == null) return;

    final recs = buildFarmRecommendations(data);
    final advice = recs.isEmpty ? '' : recs.first.message;
    final text = _s.speechSummary(
      place: _displayName(data),
      condition: _s.condition(data.condition.category),
      temp: data.tempC.round(),
      feels: data.feelsLikeC.round(),
      humidity: data.humidity.round(),
      windKph: data.windKph.round(),
      rainChance: data.todayRainChance.round(),
      advice: advice,
    );
    setState(() => _speaking = true);
    try {
      await _speaker.speak(text, locale: _lang.ttsLocale);
    } catch (_) {
      // Ignore TTS failures; the text is already on screen.
    }
    if (mounted) setState(() => _speaking = false);
  }

  String _displayName(WeatherData data) {
    if (_usingCurrentLocation) return _s.currentLocation;
    if (data.name.isNotEmpty) return data.name;
    return _place?.name ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions = _focus.hasFocus && _search.hasQuery;
    return Container(
      color: WeatherPalette.background,
      child: RefreshIndicator(
        color: WeatherPalette.primary,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            _topBar(),
            const SizedBox(height: 10),
            if (_place != null) _locationRow(),
            if (showSuggestions) _suggestions(),
            const SizedBox(height: 14),
            ..._body(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Expanded(child: _searchField()),
        const SizedBox(width: 10),
        _iconAction(
          icon: _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
          tooltip: _speaking ? _s.stop : _s.listen,
          enabled: _data != null,
          onTap: _toggleSpeak,
        ),
        const SizedBox(width: 8),
        _langButton(),
      ],
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _queryCtrl,
      focusNode: _focus,
      textInputAction: TextInputAction.search,
      onChanged: _search.onQueryChanged,
      onSubmitted: (_) => _submitQuery(),
      style: const TextStyle(
        fontSize: 14.5,
        color: WeatherPalette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: _s.searchHint,
        hintStyle: const TextStyle(
          fontSize: 14,
          color: WeatherPalette.textSecondary,
        ),
        prefixIcon: IconButton(
          icon: const Icon(Icons.search, color: WeatherPalette.primary),
          tooltip: 'Search',
          onPressed: () {
            _submitQuery();
          },
        ),
        suffixIcon: _search.hasQuery
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: WeatherPalette.textSecondary,
                onPressed: _clearQuery,
              )
            : null,
        filled: true,
        fillColor: WeatherPalette.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: WeatherPalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: WeatherPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: WeatherPalette.primary, width: 1.6),
        ),
      ),
    );
  }

  Widget _locationRow() {
    final label = _usingCurrentLocation
        ? _s.currentLocation
        : (_place?.label ?? '');
    return Row(
      children: [
        const Icon(Icons.location_on, size: 18, color: WeatherPalette.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: WeatherPalette.textPrimary,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _useCurrentLocation,
          icon: const Icon(Icons.my_location, size: 16),
          label: Text(_s.useMyLocation, style: const TextStyle(fontSize: 12.5)),
          style: TextButton.styleFrom(
            foregroundColor: WeatherPalette.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _langButton() {
    return Container(
      decoration: BoxDecoration(
        color: WeatherPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WeatherPalette.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<WeatherLang>(
          value: _lang,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.language, size: 18,
              color: WeatherPalette.primary),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: WeatherPalette.textPrimary,
          ),
          items: WeatherLang.values
              .map((l) => DropdownMenuItem(
                    value: l,
                    child: Text(l.code.toUpperCase()),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) _setLang(v);
          },
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? WeatherPalette.surface : WeatherPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WeatherPalette.border),
            ),
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? WeatherPalette.primary
                  : WeatherPalette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _suggestions() {
    final results = _search.suggestions;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: WeatherPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WeatherPalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: results.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_search.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.search_off,
                        size: 18, color: WeatherPalette.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _search.isLoading ? _s.loading : _s.noSuggestions,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: WeatherPalette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final place in results.take(6))
                  _suggestionTile(place),
              ],
            ),
    );
  }

  Widget _suggestionTile(WeatherSuggestion place) {
    return InkWell(
      onTap: () => _selectPlace(place),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.place_outlined,
                size: 18, color: WeatherPalette.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                place.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WeatherPalette.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body() {
    if (_data != null) return _dashboard(_data!);

    if (_loading) {
      return const [
        SizedBox(height: 60),
        Center(child: CircularProgressIndicator(strokeWidth: 2.8)),
      ];
    }

    if (_error != null) {
      return [_errorCard(_error!)];
    }

    return [_emptyCard()];
  }

  Widget _errorCard(String message) {
    return _panel(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 44, color: WeatherPalette.danger),
          const SizedBox(height: 12),
          Text(
            _s.weatherUnavailable,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: WeatherPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: WeatherPalette.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _button(
                  label: _s.retry,
                  icon: Icons.refresh,
                  onTap: _refresh,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _button(
                  label: _s.changePlace,
                  icon: Icons.search,
                  onTap: () => _focus.requestFocus(),
                  tonal: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return _panel(
      child: Column(
        children: [
          const Icon(Icons.wb_sunny_outlined,
              size: 46, color: WeatherPalette.primary),
          const SizedBox(height: 12),
          Text(
            _s.noLocationYet,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: WeatherPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _notice ?? _s.chooseLocationBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: WeatherPalette.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _button(
                  label: _s.useMyLocation,
                  icon: Icons.my_location,
                  onTap: _useCurrentLocation,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _button(
                  label: _s.chooseLocation,
                  icon: Icons.search,
                  onTap: () => _focus.requestFocus(),
                  tonal: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _dashboard(WeatherData data) {
    final recs = buildFarmRecommendations(data);
    return [
      _heroCard(data),
      const SizedBox(height: 18),
      _sectionTitle(_s.hourlyTitle),
      const SizedBox(height: 10),
      _hourlyStrip(data),
      const SizedBox(height: 20),
      _sectionTitle(_s.weeklyTitle),
      const SizedBox(height: 10),
      _weeklyList(data),
      const SizedBox(height: 20),
      _airAndAlerts(data),
      const SizedBox(height: 18),
      if (recs.isNotEmpty) _tipBanner(recs.first),
      const SizedBox(height: 16),
      Center(
        child: Text(
          '${_s.lastUpdated}: ${_timeLabel(data.lastUpdated)}',
          style: const TextStyle(
            fontSize: 12,
            color: WeatherPalette.textSecondary,
          ),
        ),
      ),
    ];
  }

  Widget _heroCard(WeatherData data) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WeatherPalette.gradientStart, WeatherPalette.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: WeatherPalette.primary.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HillsPainter())),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName(data),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: WeatherPalette.onPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _dateLabel(data.localtime),
                            style: TextStyle(
                              color: WeatherPalette.onPrimary
                                  .withValues(alpha: 0.9),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ConditionArt(
                      condition: data.condition,
                      size: 64,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${data.tempC.round()}\u00B0',
                      style: const TextStyle(
                        color: WeatherPalette.onPrimary,
                        fontSize: 66,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _s.condition(data.condition.category),
                            style: const TextStyle(
                              color: WeatherPalette.onPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_s.feelsLike} ${data.feelsLikeC.round()}\u00B0',
                            style: TextStyle(
                              color: WeatherPalette.onPrimary
                                  .withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _heroMetric(
                        Icons.water_drop_rounded,
                        _s.humidity,
                        '${data.humidity.round()}%',
                      ),
                    ),
                    Expanded(
                      child: _heroMetric(
                        Icons.air_rounded,
                        _s.wind,
                        data.windDir.isEmpty
                            ? '${data.windKph.round()} km/h'
                            : '${data.windKph.round()} km/h ${data.windDir}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _heroMetric(
                        Icons.visibility_rounded,
                        _s.visibility,
                        data.visibilityKm == null
                            ? '\u2014'
                            : '${data.visibilityKm!.toStringAsFixed(1)} km',
                      ),
                    ),
                    Expanded(
                      child: _heroMetric(
                        Icons.speed_rounded,
                        _s.pressure,
                        data.pressureMb == null
                            ? '\u2014'
                            : '${data.pressureMb!.round()} hPa',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: WeatherPalette.onPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WeatherPalette.onPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: WeatherPalette.onPrimary.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hourlyStrip(WeatherData data) {
    final hours = _upcomingHours(data);
    if (hours.isEmpty) {
      return _muted(_s.unavailable);
    }
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final hour = hours[i];
          return _hourCard(hour, isNow: i == 0);
        },
      ),
    );
  }

  Widget _hourCard(HourlyForecast hour, {required bool isNow}) {
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isNow ? WeatherPalette.infoSurface : WeatherPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNow ? WeatherPalette.primary : WeatherPalette.border,
          width: isNow ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            isNow ? _s.now : _hourLabel(hour.time),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isNow
                  ? WeatherPalette.primary
                  : WeatherPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            hour.condition.materialIcon,
            size: 26,
            color: WeatherPalette.forCategory(hour.condition.category),
          ),
          const SizedBox(height: 6),
          Text(
            '${hour.tempC.round()}\u00B0',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: WeatherPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.water_drop,
                  size: 11, color: WeatherPalette.rainy),
              const SizedBox(width: 2),
              Text(
                '${hour.chanceOfRain}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: WeatherPalette.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weeklyList(WeatherData data) {
    if (data.daily.isEmpty) return _muted(_s.unavailable);
    return Column(
      children: [
        for (var i = 0; i < data.daily.length; i++)
          _dailyRow(data.daily[i], isToday: i == 0),
      ],
    );
  }

  Widget _dailyRow(DailyForecast day, {required bool isToday}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: WeatherPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday ? WeatherPalette.primary : WeatherPalette.border,
          width: isToday ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              isToday ? _s.today : _weekday(day.date),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday
                    ? WeatherPalette.primary
                    : WeatherPalette.textPrimary,
              ),
            ),
          ),
          Icon(
            day.condition.materialIcon,
            size: 22,
            color: WeatherPalette.forCategory(day.condition.category),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              day.condition.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: WeatherPalette.textSecondary,
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.water_drop,
                  size: 12, color: WeatherPalette.rainy),
              const SizedBox(width: 3),
              SizedBox(
                width: 34,
                child: Text(
                  '${day.chanceOfRain}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: WeatherPalette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            '${day.minTempC.round()}\u00B0 / ${day.maxTempC.round()}\u00B0',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: WeatherPalette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _airAndAlerts(WeatherData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        final aqi = _airQualityCard(data);
        final alerts = _alertsCard(data);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: aqi),
              const SizedBox(width: 12),
              Expanded(child: alerts),
            ],
          );
        }
        return Column(
          children: [
            aqi,
            const SizedBox(height: 12),
            alerts,
          ],
        );
      },
    );
  }

  Widget _airQualityCard(WeatherData data) {
    final aq = data.airQuality;
    Widget content;
    if (aq == null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.blur_on_rounded,
              size: 30, color: WeatherPalette.textSecondary),
          const SizedBox(height: 10),
          Text(
            _s.aqiUnavailable,
            style: const TextStyle(
              fontSize: 13,
              color: WeatherPalette.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      );
    } else {
      final (color, _) = WeatherPalette.forAirQuality(aq.usEpaIndex, aq.category);
      final score = aq.aqi?.toString() ??
          (aq.pm2_5 != null ? aq.pm2_5!.round().toString() : '\u2014');
      content = Row(
        children: [
          SizedBox(
            width: 66,
            height: 66,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 66,
                  height: 66,
                  child: CircularProgressIndicator(
                    value: ((aq.usEpaIndex ?? 3) / 6).clamp(0.05, 1.0).toDouble(),
                    strokeWidth: 6,
                    backgroundColor: WeatherPalette.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Text(
                  score,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s.airQualityCategory(aq.category),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (aq.pm2_5 != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'PM2.5 ${aq.pm2_5!.toStringAsFixed(1)} \u00B5g/m\u00B3',
                    style: const TextStyle(
                      fontSize: 12,
                      color: WeatherPalette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    return _card(title: _s.airQuality, child: content);
  }

  Widget _alertsCard(WeatherData data) {
    Widget content;
    if (data.alerts.isEmpty) {
      content = Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: WeatherPalette.successSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline,
                color: WeatherPalette.good, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _s.noAlerts,
              style: const TextStyle(
                fontSize: 13.5,
                color: WeatherPalette.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    } else {
      content = _WeatherAlertView(alert: data.alerts.first, strings: _s);
    }
    return _card(title: _s.alertsTitle, child: content);
  }

  Widget _tipBanner(FarmRecommendation rec) {
    final (color, surface, icon) = switch (rec.level) {
      AdviceLevel.good => (
          WeatherPalette.good,
          WeatherPalette.successSurface,
          Icons.eco_rounded
        ),
      AdviceLevel.caution => (
          WeatherPalette.moderate,
          WeatherPalette.warnSurface,
          Icons.lightbulb_outline
        ),
      AdviceLevel.danger => (
          WeatherPalette.danger,
          WeatherPalette.dangerSurface,
          Icons.warning_amber_rounded
        ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s.farmingTip.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rec.message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: WeatherPalette.textPrimary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WeatherPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WeatherPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: WeatherPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: WeatherPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WeatherPalette.border),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: WeatherPalette.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _muted(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: WeatherPalette.textSecondary),
    );
  }

  Widget _button({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool tonal = false,
  }) {
    return SizedBox(
      height: 44,
      child: tonal
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: WeatherPalette.primary,
                side: const BorderSide(color: WeatherPalette.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: WeatherPalette.primary,
                foregroundColor: WeatherPalette.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }
}

/// First alert with an expandable "What should I do?" action.
class _WeatherAlertView extends StatefulWidget {
  final WeatherAlertData alert;
  final WeatherStrings strings;

  const _WeatherAlertView({required this.alert, required this.strings});

  @override
  State<_WeatherAlertView> createState() => _WeatherAlertViewState();
}

class _WeatherAlertViewState extends State<_WeatherAlertView> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final severe = alert.severity.toLowerCase().contains('severe') ||
        alert.severity.toLowerCase().contains('extreme');
    final color = severe ? WeatherPalette.danger : WeatherPalette.moderate;
    final title = alert.headline.isNotEmpty ? alert.headline : alert.event;
    final hasInstruction = alert.instruction.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: WeatherPalette.textPrimary,
                ),
              ),
            ),
          ],
        ),
        if (hasInstruction) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(
              _open ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(widget.strings.whatToDo),
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                alert.instruction,
                style: const TextStyle(
                  fontSize: 13,
                  color: WeatherPalette.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Weather drawn as a large icon over a soft halo — readable even without text.
class _ConditionArt extends StatelessWidget {
  final WeatherCondition condition;
  final double size;

  const _ConditionArt({required this.condition, required this.size});

  @override
  Widget build(BuildContext context) {
    if (condition.httpsIcon.isNotEmpty) {
      return Image.network(
        condition.httpsIcon,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _iconFallback(),
      );
    }
    return _iconFallback();
  }

  Widget _iconFallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: WeatherPalette.onPrimary.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(
        condition.materialIcon,
        size: size * 0.58,
        color: WeatherPalette.onPrimary,
      ),
    );
  }
}

/// Translucent rolling hills so the hero reads as a countryside scene.
class _HillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    final path = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.60,
        size.width * 0.46,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.90,
        size.width,
        size.height * 0.68,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);

    final paint2 = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final path2 = Path()
      ..moveTo(0, size.height * 0.88)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.74,
        size.width * 0.62,
        size.height * 0.88,
      )
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.97,
        size.width,
        size.height * 0.84,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Hourly entries from now on, capped so the strip stays scannable.
List<HourlyForecast> _upcomingHours(WeatherData data) {
  if (data.hourly.isEmpty) return const [];
  final now = DateTime.tryParse(data.localtime);
  if (now == null) return data.hourly.take(12).toList();
  final upcoming = data.hourly
      .where((h) => !h.time.isBefore(DateTime(now.year, now.month, now.day, now.hour)))
      .toList();
  final list = upcoming.isEmpty ? data.hourly : upcoming;
  return list.take(12).toList();
}

String _two(int n) => n.toString().padLeft(2, '0');

String _hourLabel(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$hour ${time.hour < 12 ? 'AM' : 'PM'}';
}

String _weekday(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[date.weekday - 1];
}

String _dateLabel(String iso) {
  final dt = DateTime.tryParse(iso) ?? DateTime.now();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${_weekday(dt)}, ${dt.day} ${months[dt.month - 1]}';
}

String _timeLabel(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  return '$hour:${_two(dt.minute)} ${dt.hour < 12 ? 'AM' : 'PM'}';
}
