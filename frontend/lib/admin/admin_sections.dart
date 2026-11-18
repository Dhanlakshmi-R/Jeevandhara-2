import 'package:flutter/material.dart';

import 'admin_strings.dart';

/// The ten console sections, in sidebar order.
///
/// Kept free of widget imports so screens can reference a section (e.g. the
/// dashboard's quick links) without importing the shell that builds them.
enum AdminSection {
  dashboard(
    AK.navDashboard,
    Icons.space_dashboard_outlined,
    Icons.space_dashboard,
  ),
  users(
    AK.navUsers,
    Icons.group_outlined,
    Icons.group,
  ),
  activity(
    AK.navActivity,
    Icons.history_outlined,
    Icons.history,
  ),
  weatherAlerts(
    AK.navWeather,
    Icons.warning_amber_outlined,
    Icons.warning_amber,
  ),
  cropAnalytics(
    AK.navCrops,
    Icons.insights_outlined,
    Icons.insights,
  ),
  market(
    AK.navMarket,
    Icons.storefront_outlined,
    Icons.storefront,
  ),
  reports(
    AK.navReports,
    Icons.description_outlined,
    Icons.description,
  ),
  settings(
    AK.navSettings,
    Icons.tune_outlined,
    Icons.tune,
  ),
  notifications(
    AK.navNotifications,
    Icons.notifications_none,
    Icons.notifications,
  ),
  profileSecurity(
    AK.navSecurity,
    Icons.shield_outlined,
    Icons.shield,
  );

  const AdminSection(this.labelKey, this.icon, this.selectedIcon);

  final String labelKey;
  final IconData icon;
  final IconData selectedIcon;

  String get label => AdminStrings.of(labelKey);
}
