import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:jeevandhara2/models/weather_data.dart';

/// Fetches place suggestions for a query. Injected so the controller is fully
/// testable without any HTTP.
typedef SuggestionFetcher = Future<List<WeatherSuggestion>> Function(
  String query, {
  String? state,
});

enum PlaceSearchStatus { idle, loading, results, empty, error }

/// Debounced, race-safe driver for the weather location search box.
///
/// Contract:
///  * fires the fetcher only [debounce] after the last keystroke, so typing
///    "Bengaluru" does not trigger seven requests;
///  * never runs two fetches concurrently — a query typed while a fetch is in
///    flight is remembered and served as soon as that fetch settles;
///  * drops responses that arrive after the controller is disposed;
///  * keeps the last known suggestion list visible while a new one loads, so
///    the list does not flash an empty spinner on every keystroke.
class PlaceSearchController extends ChangeNotifier {
  PlaceSearchController({
    required this.fetchSuggestions,
    this.debounce = const Duration(milliseconds: 300),
  });

  final SuggestionFetcher fetchSuggestions;
  final Duration debounce;

  Timer? _debounceTimer;
  bool _inFlight = false;
  bool _disposed = false;
  String? _pendingQuery;

  String _query = '';
  String? _state;
  PlaceSearchStatus _status = PlaceSearchStatus.idle;
  List<WeatherSuggestion> _suggestions = const [];
  String? _error;
  Object? _lastError;
  int _highlightIndex = -1;
  WeatherSuggestion? _selected;

  String get query => _query;
  String? get state => _state;
  PlaceSearchStatus get status => _status;
  List<WeatherSuggestion> get suggestions => _suggestions;
  String? get error => _error;

  /// The raw throwable behind [error], so the UI can distinguish a missing
  /// API key from an unreachable backend instead of showing one generic
  /// "try again" card for both.
  Object? get lastError => _lastError;
  int get highlightIndex => _highlightIndex;
  WeatherSuggestion? get selected => _selected;

  bool get isLoading => _status == PlaceSearchStatus.loading;
  bool get hasQuery => _query.trim().isNotEmpty;

  /// True when a "Show weather" press can resolve an exact location: either a
  /// suggestion was picked, or the provider returned matches for the text.
  bool get canSubmit => _selected != null || _suggestions.isNotEmpty;

  /// The place the Search button resolves to.
  WeatherSuggestion? get resolvable =>
      _selected ?? (_suggestions.isEmpty ? null : _suggestions.first);

  /// Narrows suggestions to a state/UT. Re-queries immediately when a query is
  /// already present so the list never contradicts the filter.
  void setStateFilter(String? state) {
    if (_state == state) return;
    _state = state;
    if (hasQuery) {
      schedule(immediate: true);
    } else {
      notifyListeners();
    }
  }

  void onQueryChanged(String value) {
    if (_query == value) return;
    _query = value;
    _selected = null;
    _highlightIndex = -1;

    if (value.trim().isEmpty) {
      _cancelTimer();
      _pendingQuery = null;
      _suggestions = const [];
      _error = null;
      _lastError = null;
      _status = PlaceSearchStatus.idle;
      notifyListeners();
      return;
    }

    if (_inFlight) {
      // Remember it; the in-flight pump serves it the moment it settles.
      _pendingQuery = value.trim();
      return;
    }
    schedule();
  }

  /// Debounces a fetch. [immediate] skips the wait (used by Retry and by a
  /// state-filter change, where the user has already committed the input).
  void schedule({bool immediate = false}) {
    _cancelTimer();
    if (immediate) {
      unawaited(_pump(_query.trim()));
    } else {
      _debounceTimer = Timer(debounce, () => unawaited(_pump(_query.trim())));
    }
  }

  Future<void> retry() => _pump(_query.trim());

  void clear() {
    _cancelTimer();
    _pendingQuery = null;
    _query = '';
    _selected = null;
    _suggestions = const [];
    _error = null;
    _lastError = null;
    _highlightIndex = -1;
    _status = PlaceSearchStatus.idle;
    notifyListeners();
  }

  void close() {
    _highlightIndex = -1;
    notifyListeners();
  }

  void moveHighlight(int delta) {
    if (_suggestions.isEmpty) return;
    final next = _highlightIndex + delta;
    _highlightIndex = next < 0
        ? 0
        : next >= _suggestions.length
            ? _suggestions.length - 1
            : next;
    notifyListeners();
  }

  void highlight(int index) {
    if (index < 0 || index >= _suggestions.length) return;
    _highlightIndex = index;
    notifyListeners();
  }

  void select(WeatherSuggestion place) {
    _selected = place;
    _query = place.label;
    _highlightIndex = _suggestions.indexOf(place);
    notifyListeners();
  }

  Future<void> _pump(String initialQuery) async {
    if (_disposed || _inFlight) return;
    var q = initialQuery;
    if (q.isEmpty) return;

    _inFlight = true;
    try {
      while (true) {
        _status = PlaceSearchStatus.loading;
        _error = null;
        _lastError = null;
        if (!_disposed) notifyListeners();

        try {
          final results = await fetchSuggestions(q, state: _state);
          if (_disposed) return;
          _suggestions = results;
          _error = null;
          _lastError = null;
          _highlightIndex = results.isEmpty ? -1 : 0;
          _status = results.isEmpty
              ? PlaceSearchStatus.empty
              : PlaceSearchStatus.results;
        } catch (e) {
          if (_disposed) return;
          _suggestions = const [];
          _highlightIndex = -1;
          _error = _clean(e);
          _lastError = e;
          _status = PlaceSearchStatus.error;
        }

        final next = _pendingQuery;
        _pendingQuery = null;
        if (next == null || next == q) break;
        q = next;
      }
    } finally {
      _inFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _cancelTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  static String _clean(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  @override
  void dispose() {
    _disposed = true;
    _cancelTimer();
    super.dispose();
  }
}
