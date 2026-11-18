import 'package:flutter/foundation.dart';

import 'package:jeevandhara2/models/trader.dart';

/// Carries the signed-in trader's own buying card between the dashboard and
/// the Post Offer page.
///
/// The shell keeps every destination alive in an `IndexedStack`, so saving on
/// the Post Offer page does not rebuild the dashboard. This notifier tells the
/// dashboard that the card changed without a second navigation.
///
/// The server stays the source of truth: every dashboard visit re-reads
/// `/traders/me`, and this store is intentionally in-memory only.
class TraderOfferStore extends ChangeNotifier {
  TraderOfferStore._();

  static final TraderOfferStore instance = TraderOfferStore._();

  Trader? _offer;
  bool _hasLoaded = false;

  Trader? get offer => _offer;

  /// Whether a fetch has completed at least once. A null [offer] after this is
  /// a real "no card yet", not an unknown.
  bool get hasLoaded => _hasLoaded;

  void set(Trader offer) {
    _offer = offer;
    _hasLoaded = true;
    notifyListeners();
  }

  void clear() {
    _offer = null;
    _hasLoaded = true;
    notifyListeners();
  }

  /// Test seam: forget any card carried over from an earlier test.
  @visibleForTesting
  void reset() {
    _offer = null;
    _hasLoaded = false;
  }
}
