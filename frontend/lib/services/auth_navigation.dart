import 'package:flutter/material.dart';
import 'package:jeevandhara2/admin/admin_shell.dart';
import 'package:jeevandhara2/models/user.dart';
import 'package:jeevandhara2/screens/complete_profile_screen.dart';
import 'package:jeevandhara2/screens/home_screen.dart';
import 'package:jeevandhara2/screens/trader_dashboard_screen.dart';

/// The screen a signed-in user should land on.
///
/// New Google/phone users land on [CompleteProfileScreen] to finish their
/// profile (name/role/location); administrators go to the console; everyone
/// else goes to their dashboard based on role. Shared by the post-login
/// navigation and the splash screen's silent session restore.
Widget screenForUser(AppUser user) {
  if (!user.profileComplete) {
    return CompleteProfileScreen(user: user);
  }
  if (user.role == 'admin') {
    return const AdminShell();
  }
  return user.role != 'farmer'
      ? TraderDashboardScreen(user: user)
      : HomeScreen(user: user);
}

/// Routes a freshly signed-in user to the right screen.
void navigateAfterAuth(BuildContext context, AppUser user) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => screenForUser(user)),
  );
}
