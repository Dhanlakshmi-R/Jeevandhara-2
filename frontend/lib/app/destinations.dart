import 'package:flutter/material.dart';

import '../screens/find_traders_screen.dart';
import '../screens/home_screen.dart';
import '../screens/market_prices_screen.dart';
import '../screens/marketplace_screen.dart';
import '../screens/my_crops_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/quality_analysis_screen.dart';
import '../screens/tool_rental_screen.dart';
import '../screens/trader_dashboard_screen.dart';
import '../screens/weather_screen.dart';
import '../theme/locale.dart';

/// Which side of the app the signed-in user is on.
///
/// The shell is role-aware rather than duplicating itself: one shell, one
/// destination registry, and each role gets a different slice of it.
enum AppRole { farmer, trader }

const _bothRoles = <AppRole>[AppRole.farmer, AppRole.trader];
const _farmerOnly = <AppRole>[AppRole.farmer];
const _traderOnly = <AppRole>[AppRole.trader];

/// A titled run of destinations in the sidebar.
///
/// Labels come from [K] rather than being written inline so the sidebar follows
/// the app language.
enum NavGroup {
  assistant(K.groupAssistant),
  tools(K.groupTools),
  marketplace(K.groupMarketplace),
  account(K.groupAccount);

  const NavGroup(this.labelKey);

  final String labelKey;
}

/// Builds a destination's page.
///
/// The shell passes the role through because two destinations legitimately
/// render different pages per role (the dashboard is the only one today).
typedef DestinationBuilder = Widget Function(AppRole role);

/// Everything the shell can show.
///
/// [roles] is the single source of truth for visibility. The per-role lists in
/// [AppDestinations] define *order* only; if a destination is absent from a
/// role's list it is unreachable, and the shell treats that list — not
/// [isVisibleTo] — as the authority when resolving a deep link.
enum AppDestination {
  chat(
    K.chat,
    Icons.auto_awesome_outlined,
    Icons.auto_awesome,
    NavGroup.assistant,
    roles: _bothRoles,
  ),
  dashboard(
    K.dashboard,
    Icons.space_dashboard_outlined,
    Icons.space_dashboard,
    NavGroup.tools,
    roles: _bothRoles,
    builder: _dashboard,
  ),
  weather(
    K.weather,
    Icons.wb_sunny_outlined,
    Icons.wb_sunny,
    NavGroup.tools,
    roles: _bothRoles,
    builder: _weather,
  ),
  myCrops(
    K.myCrops,
    Icons.eco_outlined,
    Icons.eco,
    NavGroup.tools,
    roles: _farmerOnly,
    builder: _myCrops,
  ),
  marketPrices(
    K.marketPrices,
    Icons.trending_up,
    Icons.trending_up,
    NavGroup.tools,
    roles: _bothRoles,
    builder: _marketPrices,
  ),
  qualityAnalysis(
    K.qualityAnalysis,
    Icons.fact_check_outlined,
    Icons.fact_check,
    NavGroup.tools,
    roles: _farmerOnly,
    builder: _qualityAnalysis,
  ),
  traders(
    K.traders,
    Icons.handshake_outlined,
    Icons.handshake,
    NavGroup.tools,
    roles: _bothRoles,
    builder: _traders,
  ),
  toolRental(
    K.toolRental,
    Icons.agriculture_outlined,
    Icons.agriculture,
    NavGroup.tools,
    roles: _farmerOnly,
    builder: _toolRental,
  ),
  deals(
    K.deals,
    Icons.receipt_long_outlined,
    Icons.receipt_long,
    NavGroup.tools,
    roles: _traderOnly,
    builder: _deals,
  ),
  postOffer(
    K.postOffer,
    Icons.add_business_outlined,
    Icons.add_business,
    NavGroup.tools,
    roles: _traderOnly,
    builder: _postOffer,
  ),
  marketplace(
    K.marketplace,
    Icons.storefront_outlined,
    Icons.storefront,
    NavGroup.marketplace,
    roles: _bothRoles,
    builder: _marketplace,
  ),
  notifications(
    K.notifications,
    Icons.notifications_none,
    Icons.notifications,
    NavGroup.account,
    roles: _bothRoles,
    builder: _notifications,
  ),
  profile(
    K.profile,
    Icons.person_outline,
    Icons.person,
    NavGroup.account,
    roles: _bothRoles,
    builder: _profile,
  );

  const AppDestination(
    this.labelKey,
    this.icon,
    this.selectedIcon,
    this.group, {
    this.roles = const <AppRole>[],
    this.builder,
  });

  final String labelKey;
  final IconData icon;
  final IconData selectedIcon;
  final NavGroup group;
  final List<AppRole> roles;

  /// Null for [chat], which the shell owns so that exactly one chat survives
  /// across every destination.
  final DestinationBuilder? builder;

  bool isVisibleTo(AppRole role) => roles.contains(role);

  /// The page for this destination. Throws for [chat], which has no builder
  /// because the shell supplies it.
  Widget build(AppRole role) {
    final build_ = builder;
    if (build_ == null) {
      throw StateError(
        'AppDestination.$name is owned by AppShell and has no page builder.',
      );
    }
    return build_(role);
  }
}

// ---------------------------------------------------------------- builders

Widget _dashboard(AppRole role) => role == AppRole.trader
    ? const TraderOverviewPage()
    : const FarmerDashboardPage();

Widget _weather(AppRole role) => const WeatherScreen();
Widget _myCrops(AppRole role) => const MyCropsScreen();
Widget _marketPrices(AppRole role) => const MarketPricesScreen();
Widget _qualityAnalysis(AppRole role) => const QualityAnalysisScreen();
Widget _traders(AppRole role) => const FindTradersScreen();
Widget _toolRental(AppRole role) => const ToolRentalScreen();
Widget _deals(AppRole role) => const TraderDealsPage();
Widget _postOffer(AppRole role) => const TraderPostOfferPage();
Widget _marketplace(AppRole role) => const MarketplaceScreen();
Widget _notifications(AppRole role) => const NotificationsScreen();
Widget _profile(AppRole role) => const ProfileScreen();

// -------------------------------------------------------------- registry

/// The role slices and cross-cutting queries the shell navigates with.
class AppDestinations {
  const AppDestinations._();

  /// The chat is the landing surface for both roles: an assistant-first app
  /// should open on the assistant. The trader entry screen overrides this with
  /// [AppDestination.dashboard].
  static const landing = AppDestination.chat;

  static const _farmerOrder = <AppDestination>[
    AppDestination.chat,
    AppDestination.dashboard,
    AppDestination.weather,
    AppDestination.myCrops,
    AppDestination.marketPrices,
    AppDestination.qualityAnalysis,
    AppDestination.traders,
    AppDestination.toolRental,
    AppDestination.marketplace,
    AppDestination.notifications,
    AppDestination.profile,
  ];

  static const _traderOrder = <AppDestination>[
    AppDestination.chat,
    AppDestination.dashboard,
    AppDestination.deals,
    AppDestination.postOffer,
    AppDestination.marketPrices,
    AppDestination.traders,
    AppDestination.marketplace,
    AppDestination.notifications,
    AppDestination.profile,
  ];

  /// Bottom-bar candidates, in bar order. The shell intersects this with the
  /// role's own list so a trader never gets a farmer-only tab.
  static const mobile = <AppDestination>[
    AppDestination.chat,
    AppDestination.dashboard,
    AppDestination.marketPrices,
    AppDestination.marketplace,
    AppDestination.notifications,
  ];

  static List<AppDestination> forRole(AppRole role) {
    final order = role == AppRole.trader ? _traderOrder : _farmerOrder;
    return order.where((d) => d.isVisibleTo(role)).toList(growable: false);
  }

  /// Groups that have at least one destination this role can reach, so the
  /// sidebar never prints an empty heading.
  static List<NavGroup> groupsFor(AppRole role) => [
        for (final group in NavGroup.values)
          if (inGroup(role, group).isNotEmpty) group,
      ];

  static List<AppDestination> inGroup(AppRole role, NavGroup group) =>
      forRole(role).where((d) => d.group == group).toList(growable: false);
}