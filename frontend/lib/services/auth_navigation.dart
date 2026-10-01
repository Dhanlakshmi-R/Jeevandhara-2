import 'package:flutter/material.dart';
import 'package:jeevandhara2/models/user.dart';
import 'package:jeevandhara2/screens/complete_profile_screen.dart';
import 'package:jeevandhara2/screens/home_screen.dart';
import 'package:jeevandhara2/screens/trader_dashboard_screen.dart';

/// Routes a freshly signed-in user to the right screen.
///
/// New Google/phone users land on [CompleteProfileScreen] to finish their
/// profile (name/role/location); everyone else goes straight to their
/// dashboard based on role.
void navigateAfterAuth(BuildContext context, AppUser user) {
  if (!user.profileComplete) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => CompleteProfileScreen(user: user)),
    );
    return;
  }
  final next = user.role != 'farmer'
      ? TraderDashboardScreen(user: user)
      : HomeScreen(user: user);
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => next),
  );
}
