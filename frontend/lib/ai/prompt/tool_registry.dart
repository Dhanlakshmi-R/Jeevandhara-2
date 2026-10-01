import 'package:flutter/material.dart';

/// Tools the assistant can invoke, and the in-app destination each opens.
///
/// The list is intentionally static rather than fetched: the command palette
/// and the composer suggestions must render instantly and work offline, and
/// the set of navigable screens is a build-time fact. `AiCapabilities` from
/// the backend is used to show *availability* (e.g. weather needs a location)
/// and to detect a configured LLM, not to build the list.
enum AiTool {
  weather,
  prices,
  crops,
  traders,
  quality,
  rental,
  marketplace,
  notifications;

  String get label => switch (this) {
        AiTool.weather => 'Live weather',
        AiTool.prices => 'Market prices',
        AiTool.crops => 'My crops',
        AiTool.traders => 'Find traders',
        AiTool.quality => 'Quality analysis',
        AiTool.rental => 'Tool rental',
        AiTool.marketplace => 'Marketplace',
        AiTool.notifications => 'Alerts',
      };

  IconData get icon => switch (this) {
        AiTool.weather => Icons.cloud_outlined,
        AiTool.prices => Icons.trending_up_rounded,
        AiTool.crops => Icons.grass_rounded,
        AiTool.traders => Icons.handshake_outlined,
        AiTool.quality => Icons.fact_check_outlined,
        AiTool.rental => Icons.precision_manufacturing_outlined,
        AiTool.marketplace => Icons.storefront_outlined,
        AiTool.notifications => Icons.notifications_none_rounded,
      };

  /// Placeholder shown in the composer when a tool is attached, so the user
  /// can see what they are about to ask about.
  String get promptHint => switch (this) {
        AiTool.weather => 'Ask about weather in my area',
        AiTool.prices => 'Ask about crop prices',
        AiTool.crops => 'Ask about my crops',
        AiTool.traders => 'Find traders for my crop',
        AiTool.quality => 'Check produce quality',
        AiTool.rental => 'Find equipment to rent',
        AiTool.marketplace => 'Browse the marketplace',
        AiTool.notifications => 'Summarise my alerts',
      };
}

/// Registry lookup used by the tool-result widgets to turn a backend `tool`
/// name back into something renderable, and by the shell to open a
/// destination.
class ToolRegistry {
  ToolRegistry._();

  static AiTool? fromBackendName(String name) {
    final head = name.split('.').first;
    for (final tool in AiTool.values) {
      if (tool.name == head) return tool;
    }
    return null;
  }

  /// All tools that make sense as empty-state suggestions, in the order a
  /// first-time user is most likely to need them.
  static const suggestions = <AiTool>[
    AiTool.weather,
    AiTool.prices,
    AiTool.traders,
    AiTool.crops,
  ];

  /// Command-palette entries, phrased as actions rather than nouns.
  static const commands = <({String label, IconData icon, AiTool tool})>[
    (label: 'Check weather', icon: Icons.cloud_outlined, tool: AiTool.weather),
    (
      label: 'View market prices',
      icon: Icons.trending_up_rounded,
      tool: AiTool.prices
    ),
    (label: 'My crop listings', icon: Icons.grass_rounded, tool: AiTool.crops),
    (
      label: 'Find traders',
      icon: Icons.handshake_outlined,
      tool: AiTool.traders
    ),
    (
      label: 'Quality analysis',
      icon: Icons.fact_check_outlined,
      tool: AiTool.quality
    ),
    (
      label: 'Rent a tool',
      icon: Icons.precision_manufacturing_outlined,
      tool: AiTool.rental
    ),
    (
      label: 'Open marketplace',
      icon: Icons.storefront_outlined,
      tool: AiTool.marketplace
    ),
    (
      label: 'View alerts',
      icon: Icons.notifications_none_rounded,
      tool: AiTool.notifications
    ),
  ];
}
