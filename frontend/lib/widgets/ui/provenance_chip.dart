import 'package:flutter/material.dart';

import 'package:jeevandhara2/design/provenance.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/theme/locale.dart';

/// A compact badge for "where this number came from".
///
/// Shows the tier letter and the feed name. When the tier is unknown the chip
/// says so rather than falling back to a neutral-looking A: an absent tier is
/// the one case where the UI must not look confident.
class ProvenanceChip extends StatelessWidget {
  final Provenance provenance;
  final bool dense;

  const ProvenanceChip({super.key, required this.provenance, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tier = provenance.tier;
    return Tooltip(
      message: _tooltip(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 6 : 8,
          vertical: dense ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: tier.isKnown ? c.primaryLight : c.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: tier.isKnown
                ? c.primary.withValues(alpha: 0.35)
                : c.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: dense ? 14 : 16,
              height: dense ? 14 : 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tier.isKnown ? c.primary : c.textSecondary,
                shape: BoxShape.circle,
              ),
              child: Text(
                tier.code,
                style: TextStyle(
                  fontSize: dense ? 8 : 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              provenance.source,
              style: TextStyle(
                fontSize: dense ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tooltip(BuildContext context) {
    final tier = provenance.tier;
    final parts = [
      'Tier ${tier.code}: ${tierLabel(context, tier)}',
      'Source: ${provenance.source}',
      if (provenance.attribution.isNotEmpty) provenance.attribution,
      'Confidence: ${provenance.confidence}',
      if (!provenance.verified) 'Not yet verified',
      if (provenance.observedAt != null)
        'Observed ${provenance.observedAt!.toIso8601String().substring(0, 10)}',
      if (provenance.note != null) provenance.note!,
    ];
    return parts.join('\n');
  }
}

/// Human label for each tier, matching the legend in `data_sources.yaml`.
String tierLabel(BuildContext context, DataTier tier) {
  final key = switch (tier) {
    DataTier.a => K.tierA,
    DataTier.b => K.tierB,
    DataTier.c => K.tierC,
    DataTier.d => K.tierD,
    DataTier.unknown => K.tierUnknown,
  };
  return context.str(key);
}

/// Freshness badge: `Fresh`, `2 days old`, `Stale`, `Unverified`.
///
/// Age always comes from the observation's own market date. A rate fetched a
/// second ago about last week still reads "days old" here - that is the point.
class FreshnessBadge extends StatelessWidget {
  final Provenance provenance;
  final bool dense;

  const FreshnessBadge({
    super.key,
    required this.provenance,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = _state(context, c);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            provenance.freshness == Freshness.fresh
                ? Icons.fiber_manual_record
                : Icons.history,
            size: dense ? 9 : 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _state(BuildContext context, dynamic c) {
    final p = provenance;
    String days(int n) =>
        context.str(K.daysOld).replaceFirst('{n}', '$n');
    switch (p.freshness) {
      case Freshness.fresh:
        final lag = p.lagDays;
        if (lag == null) return (context.str(K.fresh), c.positive);
        if (lag < 1) return (context.str(K.today), c.positive);
        return (days(lag.round()), c.positive);
      case Freshness.stale:
        final lag = p.lagDays;
        return (
          lag == null
              ? context.str(K.stale)
              : '${context.str(K.stale)} \u2022 ${days(lag.round())}',
          c.warning,
        );
      case Freshness.unverified:
        return (context.str(K.unverifiedFeed), c.warning);
      case Freshness.unknown:
        return (context.str(K.ageUnknown), c.textSecondary);
    }
  }
}
