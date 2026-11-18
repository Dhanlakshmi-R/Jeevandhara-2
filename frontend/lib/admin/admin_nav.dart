import 'package:flutter/material.dart';

import 'admin_theme.dart';

/// Pushes an admin sub-page (e.g. user detail) under the console theme.
///
/// The console theme is applied inside [AdminShell], so a pushed route would
/// otherwise inherit the personal app's light/dark theme. Wrapping here keeps
/// every console page dark green.
Future<T?> openAdminPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => Theme(
        data: buildAdminTheme(),
        child: page,
      ),
    ),
  );
}

/// yyyy-MM-dd, or a dash when the value is missing. Never invents a date.
String formatDay(DateTime? d) {
  if (d == null) return '—';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// yyyy-MM-dd HH:mm.
String formatDateTime(DateTime? d) {
  if (d == null) return '—';
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${formatDay(d)} $hh:$mm';
}
