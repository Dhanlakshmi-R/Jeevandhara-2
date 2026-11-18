import 'package:flutter/material.dart';

import 'admin_strings.dart';
import 'admin_theme.dart';

/// Human labels and colours for roles and account status, shared by the user
/// screens so a role/status always reads the same way.
String adminRoleLabel(String role) {
  switch (role) {
    case 'farmer':
      return AdminStrings.of(AK.roleFarmer);
    case 'trader':
      return AdminStrings.of(AK.roleTrader);
    case 'vendor':
      return AdminStrings.of(AK.roleVendor);
    case 'admin':
      return AdminStrings.of(AK.roleAdmin);
    default:
      return role.isEmpty ? '—' : role;
  }
}

Color adminRoleColor(String role) {
  switch (role) {
    case 'farmer':
      return AdminColors.primary;
    case 'trader':
      return AdminColors.info;
    case 'vendor':
      return AdminColors.purple;
    case 'admin':
      return AdminColors.warning;
    default:
      return AdminColors.textMuted;
  }
}

String adminStatusLabel(bool active) =>
    active ? AdminStrings.of(AK.active) : AdminStrings.of(AK.suspended);

Color adminStatusColor(bool active) =>
    active ? AdminColors.success : AdminColors.danger;
