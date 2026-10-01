import 'package:jeevandhara2/models/weather_data.dart';
import 'package:jeevandhara2/services/weather_place_store.dart';

/// Where the assistant's location context comes from.
///
/// Weather is the only tool that needs coordinates, and the app already has a
/// place-selection flow that persists its result. This reads that same store
/// rather than keeping a second copy of the user's location, so picking a
/// village once serves both the Weather screen and the assistant.
class AiContext {
  AiContext({WeatherPlaceStore? store}) : _store = store ?? WeatherPlaceStore();

  final WeatherPlaceStore _store;

  String _placeName = '';
  double? _lat;
  double? _lon;

  String get placeName => _placeName;
  double? get lat => _lat;
  double? get lon => _lon;

  /// Both coordinates plus a name are required. A suggestion whose coordinates
  /// both resolved to 0 is treated as unset, since that is a failed lookup
  /// rather than a position in the Gulf of Guinea.
  bool get hasLocation =>
      _lat != null &&
      _lon != null &&
      _lat != 0 &&
      _lon != 0 &&
      _placeName.isNotEmpty;

  /// Reads the stored place.
  ///
  /// Deliberately re-reads on every call rather than caching. The place is
  /// chosen on the Weather screen, which writes it through the same store, so a
  /// cached copy would keep answering about a village the user has just left.
  /// It is a single preferences read, cheap enough to do whenever the assistant
  /// becomes visible.
  Future<void> load() async {
    final place = await _store.load();
    _placeName = place?.name ?? '';
    _lat = place?.lat;
    _lon = place?.lon;
  }

  /// Adopts a location chosen anywhere in the app so the next assistant turn
  /// can answer a weather question without another round trip.
  Future<void> adopt(WeatherSuggestion place) async {
    _placeName = place.name;
    _lat = place.lat;
    _lon = place.lon;
    await _store.save(place);
  }

  /// Clears the location. The assistant then asks again rather than answering
  /// about a village the user has moved away from.
  Future<void> clear() async {
    _placeName = '';
    _lat = null;
    _lon = null;
    await _store.clear();
  }
}
