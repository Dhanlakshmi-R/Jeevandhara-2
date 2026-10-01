import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:jeevandhara2/app/destinations.dart';
import 'package:jeevandhara2/design/palette.dart';
import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/design/typography.dart';
import 'package:jeevandhara2/theme/locale.dart';

/// Opens the command palette. Kept as a function so callers do not have to
/// care that it is a dialog rather than a route.
void showCommandPalette({
  required BuildContext context,
  required AppRole role,
  required void Function(AppDestination destination) onSelect,
  required VoidCallback onToggleTheme,
  required VoidCallback onNewChat,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: Motion.fast,
    pageBuilder: (context, _, __) => CommandPalette(
      role: role,
      onSelect: (d) {
        Navigator.of(context).pop();
        onSelect(d);
      },
      onToggleTheme: () {
        Navigator.of(context).pop();
        onToggleTheme();
      },
      onNewChat: () {
        Navigator.of(context).pop();
        onNewChat();
      },
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Motion.emphasized);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// A command palette entry. Destinations and actions are one list so a single
/// ranking pass covers both, which is what makes typing "no" find "New
/// conversation" and "Notifications" at once.
class _Command {
  const _Command({
    required this.label,
    required this.hint,
    required this.icon,
    required this.run,
  });

  final String label;
  final String hint;
  final IconData icon;
  final VoidCallback run;
}

/// Ctrl/Cmd-K palette: jump to a destination, start a new conversation, or
/// flip the theme.
///
/// Ranking is a plain subsequence match with a bonus for a word-prefix hit.
/// No dependency, and on a list this size it is indistinguishable from
/// anything fancier.
class CommandPalette extends StatefulWidget {
  const CommandPalette({
    super.key,
    required this.role,
    required this.onSelect,
    required this.onToggleTheme,
    required this.onNewChat,
  });

  final AppRole role;
  final ValueChanged<AppDestination> onSelect;
  final VoidCallback onToggleTheme;
  final VoidCallback onNewChat;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // The palette is useless without focus in the field.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<_Command> _commands() {
    return [
      _Command(
        label: 'New conversation',
        hint: 'Chat',
        icon: Icons.add_comment_outlined,
        run: widget.onNewChat,
      ),
      for (final destination in AppDestinations.forRole(widget.role))
        _Command(
          label: context.str(destination.labelKey),
          hint: context.str(destination.group.labelKey),
          icon: destination.icon,
          run: () => widget.onSelect(destination),
        ),
      _Command(
        label: 'Switch theme',
        hint: 'Appearance',
        icon: Icons.brightness_6_outlined,
        run: widget.onToggleTheme,
      ),
    ];
  }

  /// `null` scores, higher is better.
  static int? _score(String query, String label) {
    final q = query.toLowerCase();
    final l = label.toLowerCase();
    if (q.isEmpty) return 0;
    if (l == q) return 100;
    if (l.startsWith(q)) return 80 - l.length;
    if (l.contains(q)) return 60 - l.indexOf(q);

    // Subsequence: "mp" matches "market prices". A gap penalty keeps it below
    // any contiguous match.
    var at = 0;
    var score = 30;
    for (final ch in q.split('')) {
      final found = l.indexOf(ch, at);
      if (found == -1) return null;
      score -= found - at;
      at = found + 1;
    }
    return score - l.length ~/ 4;
  }

  List<_Command> _filtered() {
    final query = _controller.text.trim();
    final all = _commands();
    if (query.isEmpty) return all;

    final scored = <(int, _Command)>[];
    for (final command in all) {
      final byLabel = _score(query, command.label);
      final byHint = _score(query, command.hint);
      // A label hit always outranks a group hit, so "prices" finds Market
      // Prices rather than every tool in the marketplace group.
      int? best;
      if (byLabel != null) best = byLabel;
      if (byHint != null)
        best = best == null ? byHint - 20 : max(best, byHint - 20);
      if (best != null) scored.add((best, command));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return scored.map((e) => e.$2).toList();
  }

  void _move(int delta) {
    final results = _filtered();
    if (results.isEmpty) return;
    setState(() {
      _index = (_index + delta) % results.length;
      if (_index < 0) _index += results.length;
    });
  }

  void _run(_Command command) => command.run();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final results = _filtered();
    // Keep the selection inside the list after a query change.
    final safeIndex = results.isEmpty ? 0 : _index.clamp(0, results.length - 1);

    return Shortcuts(
      // The field owns the arrow keys for caret movement, so the palette has
      // to claim them explicitly or the list cannot be walked with the keyboard.
      shortcuts: const {
        // The field owns the arrow keys for caret movement, so the palette has
        // to claim them explicitly or the list cannot be walked with the
        // keyboard.
        //
        // Enter is claimed for the hardware-key case only. A soft keyboard
        // reports its own "go" action, which the field surfaces through
        // `onSubmitted`; a raw key event never reaches it, so leaving Enter
        // unclaimed means Return does nothing on a desktop keyboard. Handling
        // it here returns a handled result, which also stops the field
        // finalising a second time.
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.enter): _RunIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): _RunIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _DismissIntent(),
      },
      child: Actions(
        actions: {
          _MoveIntent: CallbackAction<_MoveIntent>(
            onInvoke: (intent) {
              _move(intent.delta);
              return null;
            },
          ),
          _RunIntent: CallbackAction<_RunIntent>(
            onInvoke: (_) {
              if (results.isNotEmpty) _run(results[safeIndex]);
              // Non-null marks the key handled so the field does not also
              // finalise and run the command a second time.
              return true;
            },
          ),
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop();
              return true;
            },
          ),
        },
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 460),
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.ai.glassStrong,
                          borderRadius: Radii.rLg,
                          border: Border.all(color: context.ai.hairline),
                          boxShadow: Elev.overlay(c.shadow),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SearchField(
                              controller: _controller,
                              focusNode: _focusNode,
                              onChanged: (_) => setState(() => _index = 0),
                              onSubmit: () {
                                if (results.isNotEmpty) {
                                  _run(results[safeIndex]);
                                }
                              },
                            ),
                            const Divider(height: 1),
                            Flexible(
                              child: results.isEmpty
                                  ? _NoResults(query: _controller.text)
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.all(Gap.xs),
                                      itemCount: results.length,
                                      itemBuilder: (context, i) => _CommandRow(
                                        command: results[i],
                                        selected: i == safeIndex,
                                        onTap: () => _run(results[i]),
                                        onHover: () =>
                                            setState(() => _index = i),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    const _Footer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);

  final int delta;
}

class _RunIntent extends Intent {
  const _RunIntent();
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 19, color: c.textSecondary),
          const SizedBox(width: Gap.md),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmit(),
              textInputAction: TextInputAction.go,
              style: AppType.composer(context),
              cursorColor: c.primary,
              decoration: InputDecoration(
                hintText: 'Search tools, or type a command',
                hintStyle: AppType.composer(context)
                    .copyWith(color: c.textSecondary.withValues(alpha: 0.7)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isCollapsed: true,
              ),
            ),
          ),
          const _EscCap(),
        ],
      ),
    );
  }
}

class _EscCap extends StatelessWidget {
  const _EscCap();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: Radii.rXs,
        border: Border.all(color: context.ai.hairline),
      ),
      child: Text('Esc', style: AppType.meta(context).copyWith(fontSize: 10.5)),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.command,
    required this.selected,
    required this.onTap,
    required this.onHover,
  });

  final _Command command;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Material(
        color: selected ? c.primaryLight : Colors.transparent,
        borderRadius: Radii.rMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.rMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.md,
            ),
            child: Row(
              children: [
                Icon(
                  command.icon,
                  size: 17,
                  color: selected ? c.primary : c.textSecondary,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    command.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.navItem(context, selected: selected),
                  ),
                ),
                Text(command.hint, style: AppType.meta(context)),
                if (selected) ...[
                  const SizedBox(width: Gap.sm),
                  Icon(Icons.north_east_rounded, size: 13, color: c.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(Gap.huge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 26, color: c.textSecondary),
          const SizedBox(height: Gap.md),
          Text('No matches for "$query"',
              style: AppType.answer(context).copyWith(fontSize: 14)),
          const SizedBox(height: Gap.xs),
          Text('Try a tool name, or start a new conversation.',
              style: AppType.meta(context), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.keyboard_arrow_up_rounded, size: 14, color: c.textSecondary),
        Icon(Icons.keyboard_arrow_down_rounded,
            size: 14, color: c.textSecondary),
        const SizedBox(width: Gap.xs),
        Text('navigate', style: AppType.meta(context).copyWith(fontSize: 10.5)),
        const SizedBox(width: Gap.lg),
        Icon(Icons.keyboard_return_rounded, size: 14, color: c.textSecondary),
        const SizedBox(width: Gap.xs),
        Text('open', style: AppType.meta(context).copyWith(fontSize: 10.5)),
        const SizedBox(width: Gap.lg),
        Icon(Icons.close_rounded, size: 13, color: c.textSecondary),
        const SizedBox(width: Gap.xs),
        Text('dismiss', style: AppType.meta(context).copyWith(fontSize: 10.5)),
      ],
    );
  }
}
