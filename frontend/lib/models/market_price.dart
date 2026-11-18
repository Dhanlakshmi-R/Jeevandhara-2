import 'package:jeevandhara2/design/provenance.dart';
import 'package:jeevandhara2/theme/locale.dart';

/// Turns a locale key into a sentence. Labels on this class default to
/// English (readers with no context, like the parser tests) but any screen
/// can hand in `context.str` so the same code reads correctly in Kannada.
typedef L10n = String Function(String key);

/// One quotation for one crop at one mandi, exactly as the backend served it.
///
/// There is deliberately no bundled list of example rows on this class. It
/// previously shipped six invented crops with invented 7-day trends, so the
/// app could render a confident, beautiful, false price table; this class now
/// carries only fields a source actually reported, and every row keeps the
/// [provenance] block that says where the number came from and how old it is.
class MarketPrice {
  final String commodity;
  final String? variety;
  final String? grade;
  final String? state;
  final String? district;
  final String? market;

  /// The market date this quotation is about. `null` when a source reported a
  /// price without dating it - such a row is never shown as today's rate.
  final DateTime? date;

  final double? minPrice;
  final double? modalPrice;
  final double? maxPrice;

  /// Unit the source used (`quintal`, `kg`, ...). Shown verbatim rather than
  /// converted: an unlabelled number is the easiest way to mislead a seller.
  final String? unit;
  final double? arrivalQuantity;

  final Provenance provenance;

  const MarketPrice({
    required this.commodity,
    this.variety,
    this.grade,
    this.state,
    this.district,
    this.market,
    this.date,
    this.minPrice,
    this.modalPrice,
    this.maxPrice,
    this.unit,
    this.arrivalQuantity,
    this.provenance = Provenance.none,
  });

  /// The single number a farmer reads first. Modal price is the right default
  /// (it is the rate most lots traded at); when a source publishes only a min
  /// and max we fall back to their mid-point and keep both visible below, so
  /// the number is never presented as more precise than its inputs.
  double? get headlinePrice {
    if (modalPrice != null) return modalPrice;
    if (minPrice != null && maxPrice != null) return (minPrice! + maxPrice!) / 2;
    return minPrice ?? maxPrice;
  }

  bool get isDated => date != null;

  /// `₹1,450/quintal`, or `Price not reported` when the source published no
  /// usable figure. Never a fabricated `₹0`.
  String get priceLabel => priceLabelOf(AppStrings.enOf);

  /// English when no reader is given, the caller's language otherwise.
  String priceLabelOf(L10n tr) {
    final p = headlinePrice;
    if (p == null) return tr(K.priceNotReported);
    final digits = p % 1 == 0 ? p.toStringAsFixed(0) : p.toStringAsFixed(2);
    final u = unit == null || unit!.isEmpty ? '' : '/${unit!}';
    return '\u20B9$digits$u';
  }

  /// Range shown under the headline, when the source gave one.
  String? get rangeLabel {
    if (minPrice == null || maxPrice == null) return null;
    return '${_money(minPrice!)}\u2013${_money(maxPrice!)}';
  }

  String _money(double v) {
    final digits = v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return '\u20B9$digits';
  }

  /// `2026-10-05 (2 day(s) ago)` - the observation's own age, which is what a
  /// seller needs, not how long ago we happened to poll.
  String get observedLabel => observedLabelOf(AppStrings.enOf);

  /// Same label in the reader's language.
  String observedLabelOf(L10n tr) {
    if (date == null) return tr(K.undatedObservation);
    final lag = provenance.lagDays;
    if (lag == null) return _isoDate(date!);
    final days = lag.round();
    if (days <= 0) return tr(K.observedToday).replaceFirst('{d}', _isoDate(date!));
    return tr(K.observedDaysAgo)
        .replaceFirst('{d}', _isoDate(date!))
        .replaceFirst('{n}', '$days');
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Merges a provenance block that arrived alongside the row (the backend
  /// keeps it under `_provenance`).
  factory MarketPrice.fromJson(Map<String, dynamic> json) {
    final prov = json['_provenance'];
    return MarketPrice(
      commodity: json['commodity']?.toString() ?? 'Unknown crop',
      variety: json['variety']?.toString(),
      grade: json['grade']?.toString(),
      state: json['state']?.toString(),
      district: json['district']?.toString(),
      market: json['market']?.toString(),
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      minPrice: (json['min_price'] as num?)?.toDouble(),
      modalPrice: (json['modal_price'] as num?)?.toDouble(),
      maxPrice: (json['max_price'] as num?)?.toDouble(),
      unit: json['unit']?.toString() ?? json['arrival_unit']?.toString(),
      arrivalQuantity: (json['arrival_quantity'] as num?)?.toDouble(),
      provenance: prov is Map
          ? Provenance.fromJson(Map<String, dynamic>.from(prov))
          : Provenance.none,
    );
  }
}
