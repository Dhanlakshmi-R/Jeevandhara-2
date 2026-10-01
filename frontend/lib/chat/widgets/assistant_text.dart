import 'package:flutter/material.dart';

import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/design/typography.dart';
import 'package:jeevandhara2/theme/colors.dart';

/// Minimal Markdown renderer for assistant answers.
///
/// The backend writes `**bold**`, `-` bullets and blank-line paragraphs, and
/// nothing else. A dependency-free inline parser is enough for that, and it
/// keeps the assistant answers visually distinct from the feature screens'
/// plain text without pulling in `flutter_markdown`.
class AssistantText extends StatelessWidget {
  const AssistantText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? AppType.answer(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _parse(context, text, base),
    );
  }

  List<Widget> _parse(BuildContext context, String source, TextStyle base) {
    final blocks = <Widget>[];

    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        // A blank line is a paragraph break, not a gap to render. Collapsing
        // runs of them keeps the spacing even when the stream emits extra
        // newlines between tokens.
        continue;
      }

      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        blocks.add(_Bullet(
          body: trimmed.substring(2),
          base: base,
        ));
      } else {
        blocks.add(Padding(
          padding: EdgeInsets.only(bottom: base.fontSize! * 0.55),
          child: _Inline(rich: trimmed, base: base),
        ));
      }
    }

    return blocks;
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.body, required this.base});

  final String body;
  final TextStyle base;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: base.fontSize! * 0.52, right: Gap.sm),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(child: _Inline(rich: body, base: base)),
        ],
      ),
    );
  }
}

/// Renders `**bold**` spans and nothing else.
///
/// `Text.rich` with a list of spans is used rather than a custom RenderObject
/// because it wraps, selects and scales for free.
class _Inline extends StatelessWidget {
  const _Inline({required this.rich, required this.base});

  final String rich;
  final TextStyle base;

  static final _bold = RegExp(r'\*\*(.+?)\*\*');

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var index = 0;

    for (final match in _bold.allMatches(rich)) {
      if (match.start > index) {
        spans.add(TextSpan(text: rich.substring(index, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      index = match.end;
    }
    if (index < rich.length) {
      spans.add(TextSpan(text: rich.substring(index)));
    }

    return Text.rich(TextSpan(style: base, children: spans));
  }
}
