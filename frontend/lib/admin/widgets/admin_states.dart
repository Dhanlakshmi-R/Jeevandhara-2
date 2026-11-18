import 'package:flutter/material.dart';

import '../admin_strings.dart';
import '../admin_theme.dart';

/// Page title bar used at the top of every console screen's body.
class AdminPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AdminColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty)
            Wrap(spacing: 10, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

/// Full-body loading indicator with a label.
class AdminLoading extends StatelessWidget {
  final String? label;
  const AdminLoading({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      ),
    );
  }
}

/// Centered state block (error / empty / unavailable / no-access) with an
/// optional retry action. All four share one visual language.
class AdminStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AdminStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.accent = AdminColors.info,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: accent),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AdminColors.textSecondary,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

AdminStateView adminErrorView(VoidCallback retry) => AdminStateView(
      icon: Icons.cloud_off_outlined,
      title: AdminStrings.of(AK.errorTitle),
      body: AdminStrings.of(AK.errorBody),
      accent: AdminColors.danger,
      actionLabel: AdminStrings.of(AK.retry),
      onAction: retry,
    );

AdminStateView adminEmptyView({String? title, String? body, IconData? icon}) =>
    AdminStateView(
      icon: icon ?? Icons.inbox_outlined,
      title: title ?? AdminStrings.of(AK.emptyTitle),
      body: body ?? AdminStrings.of(AK.emptyBody),
      accent: AdminColors.mint,
    );

AdminStateView adminUnavailableView() => AdminStateView(
      icon: Icons.construction_outlined,
      title: AdminStrings.of(AK.unavailableTitle),
      body: AdminStrings.of(AK.unavailableBody),
      accent: AdminColors.warning,
    );

AdminStateView adminNoAccessView() => AdminStateView(
      icon: Icons.lock_outline,
      title: AdminStrings.of(AK.noAccessTitle),
      body: AdminStrings.of(AK.noAccessBody),
      accent: AdminColors.info,
    );
