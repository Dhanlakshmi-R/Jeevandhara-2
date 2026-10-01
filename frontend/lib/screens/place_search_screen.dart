import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:jeevandhara2/models/weather_data.dart';
import 'package:jeevandhara2/services/api_service.dart' show ApiException;
import 'package:jeevandhara2/services/place_search.dart';
import 'package:jeevandhara2/services/weather_service.dart'
    show WeatherNotConfiguredException, WeatherService;
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/ui/app_input.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'package:jeevandhara2/widgets/ui/states.dart';

/// Full-page wrapper around [PlaceSearchPane] for standalone navigation.
class PlaceSearchScreen extends StatelessWidget {
  final WeatherService? service;

  const PlaceSearchScreen({super.key, this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: const Text('Search a place')),
      body: PlaceSearchPane(
        service: service,
        onSelected: (place) => Navigator.of(context).pop(place),
      ),
    );
  }
}

/// Searchable Indian location picker.
///
/// Free-text entry backed by the backend's `/weather/suggestions` endpoint,
/// which proxies the provider's geocoding autocomplete and restricts results
/// to India. Suggestions are debounced, filterable by state/UT and fully
/// keyboard navigable. Reports the chosen place through [onSelected] so the
/// weather dashboard can fetch real conditions for those exact coordinates.
class PlaceSearchPane extends StatefulWidget {
  final WeatherService? service;
  final ValueChanged<WeatherSuggestion> onSelected;

  const PlaceSearchPane({super.key, this.service, required this.onSelected});

  @override
  State<PlaceSearchPane> createState() => _PlaceSearchPaneState();
}

class _PlaceSearchPaneState extends State<PlaceSearchPane> {
  static const _allStatesLabel = 'All states';

  late final WeatherService _service = widget.service ?? WeatherService();
  late final PlaceSearchController _search = PlaceSearchController(
    fetchSuggestions: (query, {state}) =>
        _service.suggestions(query, state: state),
  );

  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  List<IndianState> _states = const [];
  bool _statesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  @override
  void dispose() {
    _search.dispose();
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    setState(() => _statesLoading = true);
    try {
      final states = await _service.fetchStates();
      if (!mounted) return;
      setState(() {
        _states = states;
        _statesLoading = false;
      });
    } catch (_) {
      // A missing state list only costs the filter dropdown; free-text search
      // still works, so degrade quietly instead of blocking the screen.
      if (!mounted) return;
      setState(() => _statesLoading = false);
    }
  }

  void _clear() {
    _input.clear();
    _search.clear();
    _inputFocus.requestFocus();
  }

  void _choose(WeatherSuggestion place) {
    _search.select(place);
    _input.text = place.label;
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
  }

  void _submit() {
    final place = _search.resolvable;
    if (place == null) return;
    FocusScope.of(context).unfocus();
    widget.onSelected(place);
  }

  /// Arrow keys move the highlight, Enter picks + submits, Escape closes the
  /// list. Consuming the event stops a single-line TextField from moving its
  /// caret while the user is browsing suggestions.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final items = _search.suggestions;
    if (key == LogicalKeyboardKey.arrowDown) {
      _search.moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _search.moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _search.close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (items.isNotEmpty) {
        _choose(items[_search.highlightIndex.clamp(0, items.length - 1)]);
        _submit();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // The Focus must wrap the whole pane — including the text field — so
      // arrow/Enter/Escape typed in the input reach the suggestion list.
      child: Focus(
        onKeyEvent: _onKey,
        child: ListenableBuilder(
          listenable: _search,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _buildControls(context.colors),
              ),
              Expanded(child: _buildResults(context.colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(ThemeColors c) {
    if (_statesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
        ),
      );
    }

    return AppCardFlat(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDropdownField(
            label: 'Filter by state',
            icon: Icons.map_outlined,
            value: _search.state ?? _allStatesLabel,
            items: [_allStatesLabel, ..._states.map((s) => s.name)],
            onChanged: (value) =>
                _search.setStateFilter(value == _allStatesLabel ? null : value),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _input,
            focusNode: _inputFocus,
            onChanged: _search.onQueryChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            style: TextStyle(color: c.textPrimary, fontSize: 15),
            cursorColor: c.primary,
            decoration: InputDecoration(
              labelText: 'Place or city',
              hintText: 'Start typing — e.g. Bengaluru',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.hasQuery
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: _clear,
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeColors c) {
    switch (_search.status) {
      case PlaceSearchStatus.idle:
        return const _HintCard(
          icon: Icons.travel_explore_rounded,
          title: 'Search for your village, town or city',
          subtitle:
              'Results are limited to India. Pick a state to narrow them down.',
        );

      case PlaceSearchStatus.loading:
        if (_search.suggestions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: LoadingSkeleton(rows: 3),
          );
        }
        return _list(c);

      case PlaceSearchStatus.error:
        return _errorCard();

      case PlaceSearchStatus.empty:
        return _MessageCard(
          icon: Icons.search_off_rounded,
          title: 'No matching places in India',
          message: _search.state == null
              ? 'Try a different spelling, or pick a nearby town.'
              : 'Nothing found in ${_search.state}. Clear the filter to search all of India.',
        );

      case PlaceSearchStatus.results:
        return _list(c);
    }
  }

  /// Distinguishes the three failure modes instead of showing one generic
  /// "try again" card, so the user (or whoever is testing) knows whether the
  /// problem is their network, the backend, or a missing server-side key.
  Widget _errorCard() {
    final error = _search.lastError;
    if (error is WeatherNotConfiguredException) {
      return const _MessageCard(
        icon: Icons.key_rounded,
        title: 'Weather is not set up yet',
        message:
            'The server has no WEATHER_API_KEY configured, so place search is '
            'unavailable. Add the key to backend/.env and restart the server.',
      );
    }
    if (error is ApiException) {
      final detail = error.message;
      final offline = detail.toLowerCase().contains('cannot reach');
      return _MessageCard(
        icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
        title: offline ? 'Cannot reach the server' : 'Weather service error',
        message: offline
            ? 'The app could not connect to the backend. Make sure it is '
                'running on port 8000, then try again.'
            : (detail.isEmpty
                ? 'The weather service returned an error. Try again shortly.'
                : detail),
        actionLabel: 'Retry',
        onAction: () {
          _inputFocus.requestFocus();
          _search.retry();
        },
      );
    }
    return _MessageCard(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load place suggestions',
      message: _search.error ?? 'Check your connection and try again.',
      actionLabel: 'Retry',
      onAction: () {
        _inputFocus.requestFocus();
        _search.retry();
      },
    );
  }

  Widget _list(ThemeColors c) {
    final items = _search.suggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: Text(
            _search.isLoading
                ? 'Searching…'
                : '${items.length} match${items.length == 1 ? '' : 'es'} in India',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: c.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final place = items[i];
              return _SuggestionTile(
                place: place,
                highlighted: _search.highlightIndex == i,
                onTap: () {
                  _choose(place);
                  _submit();
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: AppPrimaryButton(
              label: 'Show weather',
              icon: Icons.wb_sunny_outlined,
              onPressed: _search.canSubmit ? _submit : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final WeatherSuggestion place;
  final bool highlighted;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.place,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final subtitle =
        [place.region, place.country].where((p) => p.isNotEmpty).join(', ');
    return Semantics(
      button: true,
      selected: highlighted,
      label: subtitle.isEmpty ? place.name : '${place.name}, $subtitle',
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: highlighted ? c.primaryLight : c.surface,
        radius: 12,
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: c.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (highlighted)
              Icon(Icons.arrow_forward_rounded, size: 18, color: c.primary),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HintCard(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: c.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, height: 1.5, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.danger),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, height: 1.5, color: c.textSecondary),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 180,
                child: AppTonalButton(
                  label: actionLabel!,
                  icon: Icons.refresh,
                  onPressed: onAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
