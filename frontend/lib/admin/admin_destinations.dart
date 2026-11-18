import 'package:flutter/material.dart';

import 'admin_sections.dart';
import 'screens/admin_activity_screen.dart';
import 'screens/admin_crop_analytics_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_market_screen.dart';
import 'screens/admin_notifications_screen.dart';
import 'screens/admin_profile_security_screen.dart';
import 'screens/admin_reports_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/admin_weather_alerts_screen.dart';

/// Resolves an [AdminSection] to the widget the shell should show.
Widget buildAdminSection(AdminSection section, {
  void Function(AdminSection section)? onNavigate,
}) {
  switch (section) {
    case AdminSection.dashboard:
      return AdminDashboardScreen(onOpenSection: onNavigate);
    case AdminSection.users:
      return const AdminUsersScreen();
    case AdminSection.activity:
      return const AdminActivityScreen();
    case AdminSection.weatherAlerts:
      return const AdminWeatherAlertsScreen();
    case AdminSection.cropAnalytics:
      return const AdminCropAnalyticsScreen();
    case AdminSection.market:
      return const AdminMarketScreen();
    case AdminSection.reports:
      return const AdminReportsScreen();
    case AdminSection.settings:
      return const AdminSettingsScreen();
    case AdminSection.notifications:
      return const AdminNotificationsScreen();
    case AdminSection.profileSecurity:
      return const AdminProfileSecurityScreen();
  }
}
