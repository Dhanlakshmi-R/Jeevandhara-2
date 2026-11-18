import '../theme/locale.dart';

/// String keys for the administrator console.
class AK {
  const AK._();

  static const console = 'adminConsole';
  static const administrator = 'administrator';
  static const superAdmin = 'superAdmin';

  // Nav
  static const navDashboard = 'adminNavDashboard';
  static const navUsers = 'adminNavUsers';
  static const navActivity = 'adminNavActivity';
  static const navWeather = 'adminNavWeather';
  static const navCrops = 'adminNavCrops';
  static const navMarket = 'adminNavMarket';
  static const navReports = 'adminNavReports';
  static const navSettings = 'adminNavSettings';
  static const navNotifications = 'adminNavNotifications';
  static const navSecurity = 'adminNavSecurity';

  // Header / common
  static const search = 'adminSearch';
  static const lastUpdated = 'adminLastUpdated';
  static const refresh = 'adminRefresh';
  static const retry = 'adminRetry';
  static const dateRange = 'adminDateRange';
  static const range7d = 'adminRange7d';
  static const range30d = 'adminRange30d';
  static const range90d = 'adminRange90d';
  static const export = 'adminExport';
  static const signOut = 'adminSignOut';
  static const viewAll = 'adminViewAll';

  // States
  static const loading = 'adminLoading';
  static const errorTitle = 'adminErrorTitle';
  static const errorBody = 'adminErrorBody';
  static const emptyTitle = 'adminEmptyTitle';
  static const emptyBody = 'adminEmptyBody';
  static const unavailableTitle = 'adminUnavailableTitle';
  static const unavailableBody = 'adminUnavailableBody';
  static const noAccessTitle = 'adminNoAccessTitle';
  static const noAccessBody = 'adminNoAccessBody';

  // Dashboard
  static const totalUsers = 'adminTotalUsers';
  static const activeUsers = 'adminActiveUsers';
  static const suspendedUsers = 'adminSuspendedUsers';
  static const newThisPeriod = 'adminNewThisPeriod';
  static const totalActivity = 'adminTotalActivity';
  static const userGrowth = 'adminUserGrowth';
  static const roleDistribution = 'adminRoleDistribution';
  static const recentActivity = 'adminRecentActivity';
  static const quickLinks = 'adminQuickLinks';
  static const noActivity = 'adminNoActivity';
  static const noGrowth = 'adminNoGrowth';
  static const greetings = 'adminGreetings';

  // Roles / status
  static const roleFarmer = 'adminRoleFarmer';
  static const roleTrader = 'adminRoleTrader';
  static const roleVendor = 'adminRoleVendor';
  static const roleAdmin = 'adminRoleAdmin';
  static const users = 'adminUsers';
  static const active = 'adminActive';
  static const suspended = 'adminSuspended';
  static const all = 'adminAll';
}

class AdminStrings {
  const AdminStrings._();

  static const _en = <String, String>{
    AK.console: 'Admin Console',
    AK.administrator: 'Administrator',
    AK.superAdmin: 'Super Admin',
    AK.navDashboard: 'Dashboard',
    AK.navUsers: 'User Management',
    AK.navActivity: 'Activity Logs',
    AK.navWeather: 'Weather & Alerts',
    AK.navCrops: 'Crop Analytics',
    AK.navMarket: 'Market Management',
    AK.navReports: 'Reports',
    AK.navSettings: 'Settings',
    AK.navNotifications: 'Notifications',
    AK.navSecurity: 'Profile & Security',
    AK.search: 'Search',
    AK.lastUpdated: 'Updated {t}',
    AK.refresh: 'Refresh',
    AK.retry: 'Try again',
    AK.dateRange: 'Period',
    AK.range7d: '7 days',
    AK.range30d: '30 days',
    AK.range90d: '90 days',
    AK.export: 'Export',
    AK.signOut: 'Sign out',
    AK.viewAll: 'View all',
    AK.loading: 'Loading…',
    AK.errorTitle: 'Could not load',
    AK.errorBody: 'The admin service did not respond. Nothing is shown rather than stale or invented values.',
    AK.emptyTitle: 'Nothing here yet',
    AK.emptyBody: 'There is no data to show for this period.',
    AK.unavailableTitle: 'Not available yet',
    AK.unavailableBody: 'This section is still being built. It will show live data once its service is connected.',
    AK.noAccessTitle: 'Administrator access required',
    AK.noAccessBody: 'This account is not an administrator. Sign in with an admin account to continue.',
    AK.totalUsers: 'Total users',
    AK.activeUsers: 'Active users',
    AK.suspendedUsers: 'Suspended',
    AK.newThisPeriod: 'New this period',
    AK.totalActivity: 'Activity events',
    AK.userGrowth: 'User growth',
    AK.roleDistribution: 'Role distribution',
    AK.recentActivity: 'Recent activity',
    AK.quickLinks: 'Quick links',
    AK.noActivity: 'No activity recorded in this period.',
    AK.noGrowth: 'No sign-ups recorded in this period.',
    AK.greetings: 'Welcome back',
    AK.roleFarmer: 'Farmer',
    AK.roleTrader: 'Trader',
    AK.roleVendor: 'Vendor',
    AK.roleAdmin: 'Admin',
    AK.users: 'Users',
    AK.active: 'Active',
    AK.suspended: 'Suspended',
    AK.all: 'All',
  };

  static const _kn = <String, String>{
    AK.console: 'ನಿರ್ವಾಹಕ ಕನ್ಸೋಲ್',
    AK.administrator: 'ನಿರ್ವಾಹಕ',
    AK.superAdmin: 'ಸೂಪರ್ ಅಡ್ಮಿನ್',
    AK.navDashboard: 'ಡ್ಯಾಶ್‌ಬೋರ್ಡ್',
    AK.navUsers: 'ಬಳಕೆದಾರ ನಿರ್ವಹಣೆ',
    AK.navActivity: 'ಚಟುವಟಿಕೆ ದಾಖಲೆಗಳು',
    AK.navWeather: 'ಹವಾಮಾನ ಮತ್ತು ಎಚ್ಚರಿಕೆಗಳು',
    AK.navCrops: 'ಬೆಳೆ ವಿಶ್ಲೇಷಣೆ',
    AK.navMarket: 'ಮಾರುಕಟ್ಟೆ ನಿರ್ವಹಣೆ',
    AK.navReports: 'ವರದಿಗಳು',
    AK.navSettings: 'ಸೆಟ್ಟಿಂಗ್‌ಗಳು',
    AK.navNotifications: 'ಅಧಿಸೂಚನೆಗಳು',
    AK.navSecurity: 'ಪ್ರೊಫೈಲ್ ಮತ್ತು ಭದ್ರತೆ',
    AK.search: 'ಹುಡುಕಿ',
    AK.lastUpdated: 'ನವೀಕರಿಸಲಾಗಿದೆ {t}',
    AK.refresh: 'ರಿಫ್ರೆಶ್',
    AK.retry: 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
    AK.dateRange: 'ಅವಧಿ',
    AK.range7d: '7 ದಿನ',
    AK.range30d: '30 ದಿನ',
    AK.range90d: '90 ದಿನ',
    AK.export: 'ರಫ್ತು',
    AK.signOut: 'ಸೈನ್ ಔಟ್',
    AK.viewAll: 'ಎಲ್ಲವನ್ನೂ ನೋಡಿ',
    AK.loading: 'ಲೋಡ್ ಆಗುತ್ತಿದೆ…',
    AK.errorTitle: 'ಲೋಡ್ ಮಾಡಲಾಗಲಿಲ್ಲ',
    AK.errorBody: 'ನಿರ್ವಾಹಕ ಸೇವೆ ಪ್ರತಿಕ್ರಿಯಿಸಲಿಲ್ಲ. ಹಳೆಯ ಅಥವಾ ಕಲ್ಪಿತ ಮೌಲ್ಯಗಳ ಬದಲು ಏನೂ ತೋರಿಸಲಾಗಿಲ್ಲ.',
    AK.emptyTitle: 'ಇನ್ನೂ ಏನೂ ಇಲ್ಲ',
    AK.emptyBody: 'ಈ ಅವಧಿಗೆ ತೋರಿಸಲು ಯಾವುದೇ ದತ್ತಾಂಶವಿಲ್ಲ.',
    AK.unavailableTitle: 'ಇನ್ನೂ ಲಭ್ಯವಿಲ್ಲ',
    AK.unavailableBody: 'ಈ ವಿಭಾಗವನ್ನು ಇನ್ನೂ ನಿರ್ಮಿಸಲಾಗುತ್ತಿದೆ. ಸೇವೆ ಸಂಪರ್ಕಗೊಂಡ ನಂತರ ಲೈವ್ ದತ್ತಾಂಶ ತೋರಿಸುತ್ತದೆ.',
    AK.noAccessTitle: 'ನಿರ್ವಾಹಕ ಪ್ರವೇಶ ಅಗತ್ಯ',
    AK.noAccessBody: 'ಈ ಖಾತೆ ನಿರ್ವಾಹಕ ಅಲ್ಲ. ಮುಂದುವರಿಯಲು ನಿರ್ವಾಹಕ ಖಾತೆಯಿಂದ ಸೈನ್ ಇನ್ ಮಾಡಿ.',
    AK.totalUsers: 'ಒಟ್ಟು ಬಳಕೆದಾರರು',
    AK.activeUsers: 'ಸಕ್ರಿಯ ಬಳಕೆದಾರರು',
    AK.suspendedUsers: 'ಅಮಾನತುಗೊಳಿಸಲಾಗಿದೆ',
    AK.newThisPeriod: 'ಈ ಅವಧಿಯಲ್ಲಿ ಹೊಸದು',
    AK.totalActivity: 'ಚಟುವಟಿಕೆ ಘಟನೆಗಳು',
    AK.userGrowth: 'ಬಳಕೆದಾರ ಬೆಳವಣಿಗೆ',
    AK.roleDistribution: 'ಪಾತ್ರ ಹಂಚಿಕೆ',
    AK.recentActivity: 'ಇತ್ತೀಚಿನ ಚಟುವಟಿಕೆ',
    AK.quickLinks: 'ತ್ವರಿತ ಲಿಂಕ್‌ಗಳು',
    AK.noActivity: 'ಈ ಅವಧಿಯಲ್ಲಿ ಯಾವುದೇ ಚಟುವಟಿಕೆ ದಾಖಲಾಗಿಲ್ಲ.',
    AK.noGrowth: 'ಈ ಅವಧಿಯಲ್ಲಿ ಯಾವುದೇ ನೋಂದಣಿ ದಾಖಲಾಗಿಲ್ಲ.',
    AK.greetings: 'ಮರಳಿ ಸ್ವಾಗತ',
    AK.roleFarmer: 'ರೈತ',
    AK.roleTrader: 'ವ್ಯಾಪಾರಿ',
    AK.roleVendor: 'ಮಾರಾಟಗಾರ',
    AK.roleAdmin: 'ನಿರ್ವಾಹಕ',
    AK.users: 'ಬಳಕೆದಾರರು',
    AK.active: 'ಸಕ್ರಿಯ',
    AK.suspended: 'ಅಮಾನತು',
    AK.all: 'ಎಲ್ಲಾ',
  };

  static String of(String key, {String? fallback}) {
    final map = LanguageController.instance.isKannada ? _kn : _en;
    return map[key] ?? fallback ?? key;
  }
}
