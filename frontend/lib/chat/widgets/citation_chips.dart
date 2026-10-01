import 'package:flutter/material.dart';

import 'package:jeevandhara2/ai/models/chat_message.dart';
import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/design/typography.dart';
import 'package:jeevandhara2/theme/colors.dart';

/// Where the answer came from.
///
/// The assistant is rule-based and reads live data, so being explicit about
/// the source is what makes its numbers trustworthy. A chip per citation
/// keeps that visible without a footer paragraph.
class CitationChips extends StatelessWidget {
  const CitationChips({super.key, required this.citations});

  final List<Citation> citations;

  @override
  Widget build(BuildContext context) {
    if (citations.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: Gap.xs,
      runSpacing: Gap.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final citation in citations) _Chip(citation: citation),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.citation});

  final Citation citation;

  (IconData, Color) _accent(BuildContext context) {
    final c = context.colors;
    return switch (citation.kind) {
      'weather' => (Icons.cloud_outlined, c.info),
      'price' => (Icons.trending_up_rounded, c.accent),
      'app' => (Icons.apps_rounded, c.textSecondary),
      _ => (Icons.link_rounded, c.textSecondary),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, accent) = _accent(context);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 5),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: Radii.pill,
        border: Border.all(color: c.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: Gap.xs),
          Flexible(
            child: Text(
              citation.detail.isEmpty ? citation.label : citation.label,
              style: AppType.meta(context).copyWith(color: c.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    // Tapping a citation is only meaningful when there is somewhere to go,
    // which is true for app tools but not for data sources.
    if (citation.kind == 'app') {
      return Tooltip(
        message: citation.detail,
        child: chip,
      );
    }
    return Tooltip(message: citation.label, child: chip);
  }
}
