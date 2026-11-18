import 'package:flutter/material.dart';

import '../admin_sections.dart';
import '../admin_theme.dart';
import '../widgets/admin_states.dart';

/// Temporary body for console sections whose service is not wired up yet.
///
/// It states plainly that the section is still being built — it never shows
/// sample numbers — so the console stays honest while the remaining screens are
/// implemented. Each of these is replaced by a real screen in a later batch.
class AdminPlaceholderScreen extends StatelessWidget {
  final AdminSection section;

  const AdminPlaceholderScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AdminColors.primarySurface,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(section.selectedIcon,
                  size: 21, color: AdminColors.primary),
            ),
            const SizedBox(width: 12),
            Text(
              section.label,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AdminColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        adminUnavailableView(),
      ],
    );
  }
}
