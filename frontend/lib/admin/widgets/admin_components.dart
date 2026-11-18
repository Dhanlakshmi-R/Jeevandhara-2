import 'package:flutter/material.dart';

import '../admin_theme.dart';

/// Bordered panel used to group content across the console.
class AdminPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final bool dense;

  const AdminPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.title,
    this.subtitle,
    this.trailing,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AdminColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: dense ? 12 : 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// Pill badge with a semantic or brand colour.
class AdminBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool solid;

  const AdminBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = solid ? AdminColors.textOnPrimary : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: solid ? null : Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// KPI tile: label, big value, optional delta and icon.
class AdminMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? hint;
  final bool loading;

  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AdminColors.primary,
    this.hint,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            loading ? '—' : value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AdminColors.textSecondary,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(
              hint!,
              style: const TextStyle(fontSize: 11.5, color: AdminColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Simple horizontal progress bar for a labelled proportion.
class AdminDistributionBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const AdminDistributionBar({
    super.key,
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final frac = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AdminColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: AdminColors.panelAlt,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight column chart drawn with plain widgets (no chart dependency).
class AdminBarChart extends StatelessWidget {
  final List<AdminBar> bars;
  final double height;
  final Color color;

  const AdminBarChart({
    super.key,
    required this.bars,
    this.height = 160,
    this.color = AdminColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = bars.fold<int>(0, (m, b) => b.value > m ? b.value : m);
    if (bars.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No data',
            style: TextStyle(color: AdminColors.textMuted, fontSize: 12.5),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: '${b.label}: ${b.value}',
                      child: Container(
                        height: maxV <= 0
                            ? 4
                            : (b.value / maxV) * (height - 34) + 2,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.85),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminBar {
  final String label;
  final int value;
  const AdminBar(this.label, this.value);
}

/// Table shell: a header row, divider, then the body rows.
class AdminTable extends StatelessWidget {
  final List<AdminTableColumn> columns;
  final List<Widget> rows;
  final String? emptyMessage;

  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            emptyMessage ?? 'No rows',
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              for (final c in columns)
                Expanded(
                  flex: c.flex,
                  child: Text(
                    c.label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: AdminColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(),
        ...rows,
      ],
    );
  }
}

class AdminTableColumn {
  final String label;
  final int flex;
  const AdminTableColumn(this.label, {this.flex = 1});
}
