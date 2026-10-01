import 'package:flutter/material.dart';

import 'package:jeevandhara2/ai/models/chat_message.dart';
import 'package:jeevandhara2/ai/prompt/tool_registry.dart';
import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/design/typography.dart';
import 'package:jeevandhara2/theme/colors.dart';

/// An inline result card inside an assistant answer.
///
/// The backend decides which card to send by naming a tool; this switches on
/// that name. An unknown tool falls back to a neutral card rather than
/// crashing, so a backend that adds a tool before the app knows about it still
/// renders.
class ToolResultCard extends StatelessWidget {
  const ToolResultCard({super.key, required this.tool, this.onOpen});

  final ToolResult tool;
  final void Function(AiTool tool)? onOpen;

  @override
  Widget build(BuildContext context) {
    return switch (tool.tool) {
      'weather.get' => _WeatherCard(tool: tool, onOpen: onOpen),
      _ => _GenericCard(tool: tool, onOpen: onOpen),
    };
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    required this.accent,
    this.trailing,
  });

  final Widget child;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.rLg,
        border: Border.all(color: c.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A left rail rather than a full border: it reads as a quote from
          // the data layer without adding another box inside a box.
          Container(
            width: 3,
            height: 42,
            margin: const EdgeInsets.only(right: Gap.lg),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: Radii.pill,
            ),
          ),
          Expanded(child: child),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.tool, this.onOpen});

  final ToolResult tool;
  final void Function(AiTool tool)? onOpen;

  String _str(String key) => (tool.payload[key] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final temp = _str('temp_c');
    final condition = _str('condition');
    final feels = _str('feelslike_c');
    final humidity = _str('humidity');
    final wind = _str('wind_kph');
    final windDir = _str('wind_dir');
    final max = _str('max_c');
    final min = _str('min_c');
    final source = _str('source');

    return _CardShell(
      accent: c.info,
      trailing: onOpen == null
          ? null
          : IconButton(
              onPressed: () => onOpen!(AiTool.weather),
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              tooltip: 'Open Weather',
              visualDensity: VisualDensity.compact,
              color: c.textSecondary,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined, size: 14, color: c.info),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Text(
                  tool.title,
                  style: AppType.label(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                temp.isEmpty ? '--' : '$temp°',
                style: AppType.numeric(context, size: 30),
              ),
              const SizedBox(width: Gap.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (condition.isNotEmpty)
                      Text(condition,
                          style:
                              AppType.answer(context).copyWith(fontSize: 13)),
                    if (min.isNotEmpty && max.isNotEmpty)
                      Text('$min° – $max°', style: AppType.meta(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.md,
            runSpacing: Gap.xs,
            children: [
              if (feels.isNotEmpty)
                _Fact(icon: Icons.thermostat_rounded, text: 'Feels $feels°'),
              if (humidity.isNotEmpty)
                _Fact(icon: Icons.water_drop_outlined, text: '$humidity% RH'),
              if (wind.isNotEmpty)
                _Fact(
                  icon: Icons.air_rounded,
                  text: '$wind km/h ${windDir.toUpperCase()}'.trim(),
                ),
              if (source.isNotEmpty)
                _Fact(icon: Icons.verified_outlined, text: source),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: context.colors.textSecondary),
        const SizedBox(width: 5),
        Text(text, style: AppType.meta(context)),
      ],
    );
  }
}

class _GenericCard extends StatelessWidget {
  const _GenericCard({required this.tool, this.onOpen});

  final ToolResult tool;
  final void Function(AiTool tool)? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final resolved = ToolRegistry.fromBackendName(tool.tool);

    return _CardShell(
      accent: c.accent,
      trailing: (resolved == null || onOpen == null)
          ? null
          : IconButton(
              onPressed: () => onOpen!(resolved),
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              tooltip: 'Open ${resolved.label}',
              visualDensity: VisualDensity.compact,
              color: c.textSecondary,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(resolved?.icon ?? Icons.insights_rounded,
                  size: 14, color: c.accent),
              const SizedBox(width: Gap.xs),
              Expanded(child: Text(tool.title, style: AppType.label(context))),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            tool.payload.isEmpty
                ? resolved?.promptHint ?? 'Open this tool to see the details.'
                : tool.payload.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('   '),
            style: AppType.meta(context),
          ),
        ],
      ),
    );
  }
}

/// Fades a card in once it arrives with the answer, so streaming text does not
/// pop cards into existence mid-read.
class AnimatedToolCard extends StatefulWidget {
  const AnimatedToolCard({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedToolCard> createState() => _AnimatedToolCardState();
}

class _AnimatedToolCardState extends State<AnimatedToolCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.fast,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SizeTransition(
        sizeFactor: _controller,
        axisAlignment: -1,
        child: widget.child,
      ),
    );
  }
}
