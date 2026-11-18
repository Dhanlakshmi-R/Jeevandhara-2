import 'package:flutter/material.dart';

import 'package:jeevandhara2/design/provenance.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/theme/locale.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';

/// The freshness / feed-health strip shown above a market screen.
///
/// This replaces the previous practice of a silent banner saying "Prices are
/// indicative" while rendering invented rows. It reports exactly what
/// `/market/status` said: whether prices are live, which feeds are off, and
/// why - "no API key" and "upstream returned 500" are different situations for
/// a farmer waiting on a rate, so both are printed.
class DataSourceStatusBanner extends StatelessWidget {
  final MarketStatus status;

  /// Extra line shown under the feed summary - used by screens to explain
  /// what the state means for them (e.g. "no sell advice today").
  final String? implication;

  const DataSourceStatusBanner({
    super.key,
    required this.status,
    this.implication,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final broken = status.broken;
    final live = status.live && broken.isEmpty;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                live ? Icons.verified : Icons.warning_amber_rounded,
                size: 18,
                color: live ? c.positive : c.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _headline(context),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Text(
                _checkedAt(context),
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
            ],
          ),
          if (implication != null) ...[
            const SizedBox(height: 6),
            Text(
              implication!,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: c.textSecondary,
              ),
            ),
          ],
          if (broken.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final s in broken)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 2),
                    Icon(Icons.close, size: 14, color: c.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${s.name}: ${_reason(s)}',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (status.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final n in status.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  n,
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _headline(BuildContext context) {
    if (status.live && status.broken.isEmpty) {
      return '${context.str(K.liveMarketData)} \u2014 prices: ${status.prices}';
    }
    if (status.prices == 'stale') return context.str(K.storedRatesOnly);
    return '${context.str(K.marketDataUnavailable)} \u2014 '
        '${context.str(K.feedCountOff).replaceFirst('{n}', '${status.broken.length}')}';
  }

  String _checkedAt(BuildContext context) {
    final t = status.checkedAt;
    if (t == null) return context.str(K.checkedJustNow);
    return context
        .str(K.checkedAt)
        .replaceFirst('{t}', t.toLocal().toString().substring(11, 16));
  }

  /// The stated reason, verbatim when the backend gave one. Falling back to
  /// "disabled" keeps the row from vanishing - a missing reason is itself
  /// worth showing rather than hiding behind a generic apology.
  String _reason(SourceStatus s) =>
      s.disabledReason ?? s.lastError ?? (s.verified ? 'no recent success' : 'disabled');
}

/// Per-feed table, used on a "sources" detail screen.
class SourceListPanel extends StatelessWidget {
  final MarketStatus status;

  const SourceListPanel({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.str(K.dataSources),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (final s in status.sources) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TierDot(tier: s.tier, ok: s.trusted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              s.trusted
                                  ? context.str(K.serving)
                                  : context.str(K.notServing),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: s.trusted ? c.positive : c.danger,
                              ),
                            ),
                          ],
                        ),
                        if (s.attribution.isNotEmpty)
                          Text(
                            s.attribution,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: c.textSecondary,
                            ),
                          ),
                        if (!s.trusted)
                          Text(
                            _reason(s),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: c.danger,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (s != status.sources.last) const Divider(height: 12),
          ],
        ],
      ),
    );
  }

  String _reason(SourceStatus s) =>
      s.disabledReason ?? s.lastError ?? (s.verified ? 'no recent success' : 'disabled');
}

class _TierDot extends StatelessWidget {
  final DataTier tier;
  final bool ok;

  const _TierDot({required this.tier, required this.ok});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ok ? c.primary : c.textSecondary.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: Text(
        tier.code,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Amber strip summarising how old the rows below it are.
///
/// Shown above a list whenever *any* row is not fresh, because a table where
/// one mandi is three weeks behind and another is from today reads as one
/// number unless the banner says otherwise. When everything is fresh the
/// banner is not built at all - silence means "current", not "unknown".
class FreshnessBanner extends StatelessWidget {
  final List<Provenance> rows;
  final String? implication;

  const FreshnessBanner({super.key, required this.rows, this.implication});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (rows.isEmpty) return const SizedBox.shrink();

    final dated = rows.where((p) => p.observedAt != null).toList();
    if (dated.isEmpty && rows.every((p) => p.freshness != Freshness.unverified)) {
      return const SizedBox.shrink();
    }

    final worst = _worst(rows);
    if (worst == Freshness.fresh) return const SizedBox.shrink();

    final oldest = dated.isEmpty
        ? null
        : (dated.map((p) => p.lagDays ?? 0).reduce((a, b) => a > b ? a : b));
    final title = switch (worst) {
      Freshness.stale =>
        oldest == null
            ? context.str(K.someRatesOld)
            : context
                .str(K.oldestRateDays)
                .replaceFirst('{n}', '${oldest.round()}'),
      Freshness.unverified => context.str(K.feedNeverVerified),
      _ => context.str(K.ageOfRatesUnknown),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule, size: 16, color: c.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                if (implication != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    implication!,
                    style: TextStyle(fontSize: 11.5, height: 1.35, color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Most serious state in the window, so a single stale row is not masked by
  /// fresh ones: unverified > stale > fresh.
  Freshness _worst(List<Provenance> rows) {
    var worst = Freshness.fresh;
    for (final p in rows) {
      switch (p.freshness) {
        case Freshness.unverified:
          return Freshness.unverified;
        case Freshness.stale:
          worst = Freshness.stale;
        case Freshness.fresh:
        case Freshness.unknown:
          if (worst == Freshness.fresh && p.freshness == Freshness.unknown) {
            worst = Freshness.unknown;
          }
      }
    }
    return worst;
  }
}
