import 'package:flutter/material.dart';

import 'package:jeevandhara2/models/weather_data.dart';
import 'package:jeevandhara2/services/weather_service.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/ui/app_input.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'place_search_screen.dart';

/// Location picker with two ways in:
///
///  * **Search by name** — free-text autocomplete against the weather
///    provider's gazetteer (any state/UT, town or city).
///  * **Browse district** — the offline GeoNames gazetteer cascade
///    (State → District → Taluk → Village) covering all of India.
///
/// Either path pops with a [WeatherSuggestion] so the weather dashboard can
/// load real conditions for the chosen coordinates.
///
/// In the browse path **any level is a complete answer**: stop at a state,
/// district or taluk and you get that area's own coordinates. Only when the
/// gazetteer genuinely has no record for a chosen village do we offer the
/// parent taluk — and the user has to accept it, so taluk weather is never
/// presented silently as village weather.
class FindPlaceScreen extends StatefulWidget {
  final WeatherService? service;

  const FindPlaceScreen({super.key, this.service});

  @override
  State<FindPlaceScreen> createState() => _FindPlaceScreenState();
}

class _FindPlaceScreenState extends State<FindPlaceScreen> {
  static const _modeSearch = 0;
  static const _modeBrowse = 1;

  late final WeatherService _service = widget.service ?? WeatherService();

  int _mode = _modeBrowse;

  List<IndianState> _states = const [];
  bool _statesLoading = true;
  String? _statesError;

  String? _state;
  String? _district;
  String? _taluk;
  String? _village;

  List<PlaceOption> _districts = const [];
  List<PlaceOption> _taluks = const [];
  List<PlaceOption> _villages = const [];

  bool _districtsLoading = false;
  bool _taluksLoading = false;
  bool _villagesLoading = false;

  String? _districtsError;
  String? _taluksError;
  String? _villagesError;

  bool _resolving = false;
  String? _resolveError;

  /// Set when the gazetteer had no record for the chosen village, so the
  /// picker can offer the coarser point explicitly instead of quietly
  /// substituting it.
  ResolvedPlace? _pendingFallback;

  /// The deepest level chosen — what the action button will act on.
  String? get _deepestLabel {
    if (_village != null) return _village;
    if (_taluk != null) return _taluk;
    if (_district != null) return _district;
    return _state;
  }

  /// A state alone is enough — weather is fetched for whatever level the user
  /// settled on rather than requiring the full four-deep cascade.
  bool get _ready => !_resolving && _state != null;

  bool get _stateAvailable {
    for (final s in _states) {
      if (s.name == _state) return s.available;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _loadStates() async {
    setState(() {
      _statesLoading = true;
      _statesError = null;
    });
    try {
      final states = await _service.fetchStates();
      if (!mounted) return;
      setState(() {
        _states = states;
        _statesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statesLoading = false;
        _statesError = _clean(e);
      });
    }
  }

  void _onStateChanged(String? value) {
    setState(() {
      _state = value;
      _district = null;
      _taluk = null;
      _village = null;
      _districts = const [];
      _taluks = const [];
      _villages = const [];
      _districtsError = null;
      _taluksError = null;
      _villagesError = null;
      _resolveError = null;
      _pendingFallback = null;
    });
    if (value != null && _stateAvailable) _loadDistricts();
  }

  void _onDistrictChanged(String? value) {
    setState(() {
      _district = value;
      _taluk = null;
      _village = null;
      _taluks = const [];
      _villages = const [];
      _taluksError = null;
      _villagesError = null;
      _resolveError = null;
      _pendingFallback = null;
    });
    if (value != null) _loadTaluks();
  }

  void _onTalukChanged(String? value) {
    setState(() {
      _taluk = value;
      _village = null;
      _villages = const [];
      _villagesError = null;
      _resolveError = null;
      _pendingFallback = null;
    });
    if (value != null) _loadVillages();
  }

  void _onVillageChanged(String? value) {
    setState(() {
      _village = value;
      _resolveError = null;
      _pendingFallback = null;
    });
  }

  Future<void> _loadDistricts() async {
    final state = _state;
    if (state == null) return;
    setState(() {
      _districtsLoading = true;
      _districtsError = null;
    });
    try {
      final list = await _service.fetchDistricts(state);
      if (!mounted || _state != state) return;
      setState(() {
        _districts = list;
        _districtsLoading = false;
      });
    } catch (e) {
      if (!mounted || _state != state) return;
      setState(() {
        _districtsLoading = false;
        _districtsError = _clean(e);
      });
    }
  }

  Future<void> _loadTaluks() async {
    final state = _state;
    final district = _district;
    if (state == null || district == null) return;
    setState(() {
      _taluksLoading = true;
      _taluksError = null;
    });
    try {
      final list = await _service.fetchTaluks(state, district);
      if (!mounted || _state != state || _district != district) return;
      setState(() {
        _taluks = list;
        _taluksLoading = false;
      });
    } catch (e) {
      if (!mounted || _state != state || _district != district) return;
      setState(() {
        _taluksLoading = false;
        _taluksError = _clean(e);
      });
    }
  }

  Future<void> _loadVillages() async {
    final state = _state;
    final district = _district;
    final taluk = _taluk;
    if (state == null || district == null || taluk == null) return;
    setState(() {
      _villagesLoading = true;
      _villagesError = null;
    });
    try {
      final list = await _service.fetchVillages(state, district, taluk);
      if (!mounted ||
          _state != state ||
          _district != district ||
          _taluk != taluk) {
        return;
      }
      setState(() {
        _villages = list;
        _villagesLoading = false;
      });
    } catch (e) {
      if (!mounted ||
          _state != state ||
          _district != district ||
          _taluk != taluk) {
        return;
      }
      setState(() {
        _villagesLoading = false;
        _villagesError = _clean(e);
      });
    }
  }

  Future<void> _showWeather() async {
    final state = _state;
    if (state == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _resolving = true;
      _resolveError = null;
      _pendingFallback = null;
    });
    try {
      // Resolved against the local gazetteer — no geocoding round-trip, so
      // this is instant and gives every listed place its true coordinates.
      final resolved = await _service.resolvePlace(
        state: state,
        district: _district,
        taluk: _taluk,
        village: _village,
      );
      if (!mounted) return;
      if (!resolved.fallback) {
        Navigator.of(context).pop(resolved.suggestion);
        return;
      }
      // Only a village can miss. Keep the picker open and make the user accept
      // the coarser point so taluk weather is never shown under a village name.
      setState(() {
        _resolving = false;
        _pendingFallback = resolved;
        _resolveError =
            'The gazetteer has no coordinates for "$_village". The closest '
            'weather point is the ${resolved.level} at ${resolved.matched}.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _resolveError = _clean(e);
      });
    }
  }

  /// The user read the precision note and accepts the coarser point.
  void _acceptFallback() {
    final resolved = _pendingFallback;
    if (resolved == null) return;
    Navigator.of(context).pop(resolved.suggestion);
  }

  void _dismissFallback() {
    setState(() {
      _pendingFallback = null;
      _resolveError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Choose a place')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _ModeToggle(
              selected: _mode,
              onChanged: (value) => setState(() => _mode = value),
            ),
          ),
          Expanded(
            child: _mode == _modeSearch
                ? PlaceSearchPane(
                    service: widget.service,
                    onSelected: (place) => Navigator.of(context).pop(place),
                  )
                : _buildBrowse(),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowse() {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_statesLoading)
          const _LoadingCard()
        else if (_statesError != null)
          _ErrorCard(message: _statesError!, onRetry: _loadStates)
        else
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppDropdownField(
                  label: 'State / UT',
                  icon: Icons.map_outlined,
                  hint: 'Select state',
                  value: _state,
                  items: _states.map((s) => s.name).toList(),
                  onChanged: _onStateChanged,
                ),
                if (_state != null && !_stateAvailable) ...[
                  const SizedBox(height: 12),
                  _UnavailableNote(state: _state!),
                ],
                if (_state != null && _stateAvailable) ...[
                  const SizedBox(height: 14),
                  _Level(
                    label: 'District',
                    icon: Icons.location_city_outlined,
                    value: _district,
                    hint: 'Select district',
                    options: _districts,
                    loading: _districtsLoading,
                    error: _districtsError,
                    onChanged: _onDistrictChanged,
                    onRetry: _loadDistricts,
                  ),
                  const SizedBox(height: 14),
                  _Level(
                    label: 'Taluk',
                    icon: Icons.account_balance_outlined,
                    value: _taluk,
                    hint: 'Select taluk',
                    options: _taluks,
                    loading: _taluksLoading,
                    error: _taluksError,
                    onChanged: _onTalukChanged,
                    onRetry: _loadTaluks,
                  ),
                  const SizedBox(height: 14),
                  _Level(
                    label: 'Village',
                    icon: Icons.location_on_outlined,
                    value: _village,
                    hint: 'Select village',
                    options: _villages,
                    loading: _villagesLoading,
                    error: _villagesError,
                    onChanged: _onVillageChanged,
                    onRetry: _loadVillages,
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        if (_pendingFallback != null) ...[
          _FallbackCard(
            resolved: _pendingFallback!,
            onAccept: _acceptFallback,
            onDismiss: _dismissFallback,
          ),
          const SizedBox(height: 12),
        ] else if (_resolveError != null) ...[
          _ErrorCard(message: _resolveError!, onRetry: _showWeather),
          const SizedBox(height: 12),
        ],
        AppPrimaryButton(
          label: _deepestLabel == null
              ? 'Show weather'
              : 'Show weather for ${_short(_deepestLabel!)}',
          icon: Icons.wb_sunny_outlined,
          loading: _resolving,
          onPressed: _ready ? _showWeather : null,
        ),
        const SizedBox(height: 10),
        Text(
          'Stop at any level — a state, district, taluk or village each has '
          'its own coordinates. Villages use their exact location; if one is '
          'missing we ask before using the taluk point.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.5),
        ),
      ],
    );
  }

  String _short(String value, [int max = 26]) =>
      value.length <= max ? value : '${value.substring(0, max)}…';
}

/// Two-way switch between name search and the district cascade. Rendered as a
/// segmented control so the active path is always obvious.
class _ModeToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _ModeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _segment(context, 1, 'Browse district', Icons.account_tree_outlined),
          _segment(context, 0, 'Search by name', Icons.search),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    int value,
    String label,
    IconData icon,
  ) {
    final c = context.colors;
    final active = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? c.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? c.onPrimary : c.textSecondary,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? c.onPrimary : c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One cascade row: a dropdown, or an inline failure with a retry button.
/// A static placeholder is used while loading rather than a spinner so the
/// row never animates forever.
class _Level extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final String hint;
  final List<PlaceOption> options;
  final bool loading;
  final String? error;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRetry;

  const _Level({
    required this.label,
    required this.icon,
    required this.value,
    required this.hint,
    required this.options,
    required this.loading,
    required this.error,
    required this.onChanged,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  error!,
                  style: TextStyle(fontSize: 12.5, color: c.danger),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      );
    }
    if (loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loading $label…',
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          const SizedBox(height: 8),
          const _SkeletonBox(height: 52),
        ],
      );
    }
    return AppDropdownField(
      label: label,
      icon: icon,
      hint: hint,
      value: value,
      items: options.map((o) => o.name).toList(),
      onChanged: onChanged,
    );
  }
}

/// Shown when the gazetteer has no record for a village. The coarser point is
/// never applied behind the user's back.
class _FallbackCard extends StatelessWidget {
  final ResolvedPlace resolved;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const _FallbackCard({
    required this.resolved,
    required this.onAccept,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      color: c.warnSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: c.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Showing ${resolved.level} coordinates',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            // Non-null for any fallback; this card only renders in that case.
            resolved.precisionNote ?? '',
            style:
                TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  child: const Text('Pick another'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('Use it anyway'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      color: c.dangerSurface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: c.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                      fontSize: 12.5, color: c.textPrimary, height: 1.5),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: EdgeInsets.zero,
                    foregroundColor: c.danger,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Defensive: the bundled gazetteer covers all of India, but if a state ever
/// arrives flagged unavailable we say so instead of showing empty dropdowns.
class _UnavailableNote extends StatelessWidget {
  final String state;

  const _UnavailableNote({required this.state});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.warnSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: c.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$state isn’t bundled yet. Try Search by name for weather in '
              'this state.',
              style:
                  TextStyle(fontSize: 12.5, color: c.textPrimary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Loading states…',
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          const SizedBox(height: 10),
          const _SkeletonBox(height: 52),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;

  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
    );
  }
}
