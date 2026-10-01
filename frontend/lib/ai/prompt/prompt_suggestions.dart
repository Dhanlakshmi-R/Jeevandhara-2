import 'package:flutter/material.dart';

import 'package:jeevandhara2/ai/prompt/tool_registry.dart';

/// One tap-to-ask example shown on the empty chat surface.
///
/// These are the first thing a new user sees, so they are written as
/// questions a farmer would actually type, not as feature names.
class PromptSuggestion {
  const PromptSuggestion({
    required this.label,
    required this.prompt,
    required this.icon,
  });

  final String label;
  final String prompt;
  final IconData icon;

  static const _weather = PromptSuggestion(
    label: 'Weather',
    prompt: 'Will it rain in my area in the next 3 days?',
    icon: Icons.cloud_outlined,
  );

  static const _price = PromptSuggestion(
    label: 'Crop prices',
    prompt: 'What are the current market prices for my crops?',
    icon: Icons.trending_up_rounded,
  );

  static const _buyer = PromptSuggestion(
    label: 'Find buyers',
    prompt: 'Find traders near me who buy my crop.',
    icon: Icons.handshake_outlined,
  );

  static const _cropCare = PromptSuggestion(
    label: 'Crop care',
    prompt: 'What should I do for my crops this week?',
    icon: Icons.grass_rounded,
  );

  static const _default = <PromptSuggestion>[
    _weather,
    _price,
    _buyer,
    _cropCare,
  ];

  /// Weather leads only when a location is already known. Without one the
  /// weather chip would produce the "where are you" reply, so the buyers
  /// question is promoted instead.
  static List<PromptSuggestion> forContext({required bool hasLocation}) {
    if (hasLocation) return _default;
    return const [_price, _buyer, _cropCare, _weather];
  }

  AiTool? get tool => switch (label) {
        'Weather' => AiTool.weather,
        'Crop prices' => AiTool.prices,
        'Find buyers' => AiTool.traders,
        'Crop care' => AiTool.crops,
        _ => null,
      };
}
