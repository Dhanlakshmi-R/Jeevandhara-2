import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:jeevandhara2/ai/prompt/ai_context.dart';
import 'package:jeevandhara2/ai/prompt/tool_registry.dart';
import 'package:jeevandhara2/app/destinations.dart';
import 'package:jeevandhara2/app/shell/command_palette.dart';
import 'package:jeevandhara2/app/shell/mobile_shell.dart';
import 'package:jeevandhara2/app/shell/sidebar.dart';
import 'package:jeevandhara2/app/shell/top_bar.dart';
import 'package:jeevandhara2/chat/screens/chat_screen.dart';
import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/models/app_notification.dart';
import 'package:jeevandhara2/models/user.dart';
import 'package:jeevandhara2/services/api_service.dart';
import 'package:jeevandhara2/theme/app_theme.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/theme/locale.dart';

/// The application frame.
///
/// Layout rules by width:
/// - >= [Layout.desktopBreakpoint]: a fixed sidebar plus a top bar.
/// - [Layout.tabletBreakpoint] to desktop: a drawer sidebar, no persistent rail.
/// - Below tablet: a drawer plus a bottom bar.
///
/// Destinations are built once and held in an [IndexedStack] so switching
/// between the chat and a tool does not discard the conversation, and a
/// half-typed question survives a trip to the weather screen.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.role,
    this.initialDestination = AppDestinations.landing,
    this.initialUser,
  });

  final AppRole role;
  final AppDestination initialDestination;

  /// Seeded by the login flow so the avatar is correct on the first frame
  /// instead of popping in after the profile request returns.
  final AppUser? initialUser;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _apiService = ApiService();
  final _aiContext = AiContext();

  late AppDestination _current;
  late final List<AppDestination> _destinations;

  /// Destinations that have been visited, in visit order.
  ///
  /// A page is built the first time it is opened and then kept in the list, so
  /// a half-typed question survives a trip to the weather screen. Building
  /// lazily rather than up front matters: each screen issues its own requests,
  /// and opening the app should not fire ten of them at once.
  final List<AppDestination> _built = [AppDestination.chat];

  /// Bumped whenever the chat becomes the visible destination, so the chat can
  /// re-read the place the user may have picked elsewhere.
  int _chatEpoch = 0;

  final Map<AppDestination, Widget> _pages = {};

  AppUser? _user;
  String _locationLabel = '';
  int _unread = 0;

  /// Membership of the role's own list, not [AppDestination.isVisibleTo]: the
  /// role's list is what the sidebar and palette offer, so a deep link to
  /// anything outside it has to land on the default rather than open a screen
  /// the user has no way back to.
  AppDestination _resolveInitial() {
    if (_destinations.contains(widget.initialDestination)) {
      return widget.initialDestination;
    }
    return AppDestinations.landing;
  }

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    _destinations = AppDestinations.forRole(widget.role);
    _current = _resolveInitial();
    _materialize(_current);
    _bootstrap();
  }

  /// Builds a destination's page unless it is the chat, which the shell owns,
  /// or it has already been built.
  void _materialize(AppDestination destination) {
    if (destination == AppDestination.chat) return;
    if (_pages.containsKey(destination)) return;
    _pages[destination] = destination.build(widget.role);
    if (!_built.contains(destination)) _built.add(destination);
  }

  Widget _pageFor(AppDestination destination) =>
      destination == AppDestination.chat
          ? ChatScreen(onOpenTool: _openTool, visibleEpoch: _chatEpoch)
          : _pages[destination]!;

  void _bootstrap() async {
    await _loadUser();
    await _loadLocation();
    if (mounted) setState(() {});
  }

  Future<void> _loadUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      if (mounted) {
        setState(() {
          _user = user;
          _unread = AppNotification.sampleData().where((n) => !n.seen).length;
        });
      }
    } catch (_) {
      // Signed out or offline. The shell still works; the avatar just shows
      // its default and profile will send the user to login.
    }
  }

  /// The assistant's location context is whatever was last chosen in the
  /// Weather flow, so the shell header and the chat agree on one place.
  Future<void> _loadLocation() async {
    await _aiContext.load();
    if (!mounted) return;
    setState(() {
      _locationLabel = _aiContext.hasLocation ? _aiContext.placeName : '';
    });
  }

  // ------------------------------------------------------------- navigation

  void select(AppDestination destination) {
    if (!_destinations.contains(destination)) return;
    if (destination == _current) return;
    _materialize(destination);
    if (destination == AppDestination.chat) _chatEpoch++;
    setState(() => _current = destination);
  }

  /// Opens a tool from an assistant answer or suggestion.
  void _openTool(AiTool tool) {
    final target = switch (tool) {
      AiTool.weather => AppDestination.weather,
      AiTool.prices => AppDestination.marketPrices,
      AiTool.crops => AppDestination.myCrops,
      AiTool.traders => AppDestination.traders,
      AiTool.quality => AppDestination.marketPrices,
      AiTool.rental => AppDestination.toolRental,
      AiTool.marketplace => AppDestination.marketplace,
      AiTool.notifications => AppDestination.notifications,
    };
    if (_destinations.contains(target)) select(target);
  }

  void _openPalette() {
    showCommandPalette(
      context: context,
      role: widget.role,
      onSelect: (destination) {
        select(destination);
        if (destination != AppDestination.chat) _loadLocation();
      },
      onToggleTheme: () {
        final isDark =
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        ThemeController.instance
            .setMode(isDark ? ThemeMode.light : ThemeMode.dark);
      },
      onNewChat: () {
        select(AppDestination.chat);
        _loadLocation();
      },
    );
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final width = MediaQuery.sizeOf(context).width;

    if (width < Layout.tabletBreakpoint) {
      return MobileShell(
        role: widget.role,
        destinations: _destinations,
        current: _current,
        onSelect: select,
        user: _user,
        unread: _unread,
        locationLabel: _locationLabel,
        onOpenPalette: _openPalette,
        onOpenNotifications: () => select(AppDestination.notifications),
        onOpenProfile: () => select(AppDestination.profile),
        built: _built,
        pageFor: _pageFor,
      );
    }

    final wide = width >= Layout.desktopBreakpoint;

    return Scaffold(
      backgroundColor: c.background,
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: Colors.transparent,
              child: SafeArea(
                child: Sidebar(
                  role: widget.role,
                  current: _current,
                  onSelect: (d) {
                    Navigator.of(context).pop();
                    select(d);
                  },
                  user: _user,
                  unread: _unread,
                  onOpenPalette: () {
                    Navigator.of(context).pop();
                    _openPalette();
                  },
                  collapsible: false,
                ),
              ),
            ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          // Ctrl+K or Cmd+K opens the command palette.
          if (event is KeyDownEvent) {
            final isMeta = event.logicalKey == LogicalKeyboardKey.metaLeft ||
                event.logicalKey == LogicalKeyboardKey.metaRight;
            final isCtrl = event.logicalKey == LogicalKeyboardKey.controlLeft ||
                event.logicalKey == LogicalKeyboardKey.controlRight;
            if (event.logicalKey == LogicalKeyboardKey.keyK &&
                (isMeta || isCtrl)) {
              _openPalette();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Sidebar(
                role: widget.role,
                current: _current,
                onSelect: select,
                user: _user,
                unread: _unread,
                onOpenPalette: _openPalette,
                collapsible: true,
              ),
            Expanded(
              child: Column(
                children: [
                  // `Builder` puts the menu button's context below the Scaffold
                  // so `Scaffold.of` can reach the drawer.
                  Builder(
                    builder: (inner) => TopBar(
                      title: context.str(_current.labelKey),
                      subtitle: _todayLabel(context),
                      locationLabel: _locationLabel,
                      unread: _unread,
                      onMenu:
                          wide ? null : () => Scaffold.of(inner).openDrawer(),
                      onOpenPalette: _openPalette,
                      onOpenNotifications: () =>
                          select(AppDestination.notifications),
                      onOpenProfile: () => select(AppDestination.profile),
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _built.indexOf(_current),
                      children: [
                        for (final d in _built)
                          KeyedSubtree(
                            key: ValueKey(d),
                            child: _pageFor(d),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Localised through [MaterialLocalizations] so the header reads correctly in
  /// Kannada without a second date table here.
  String _todayLabel(BuildContext context) =>
      MaterialLocalizations.of(context).formatMediumDate(DateTime.now());
}
