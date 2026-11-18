import 'package:flutter/material.dart';

import 'package:jeevandhara2/models/app_notification.dart';
import 'package:jeevandhara2/services/notifications_service.dart';
import 'package:jeevandhara2/theme/app_theme.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/ui/states.dart';

class NotificationsScreen extends StatefulWidget {
  final NotificationsService? service;

  const NotificationsScreen({super.key, this.service});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsService _service =
      widget.service ?? NotificationsService();

  List<AppNotification> _notifications = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = _notifications.isEmpty;
      _error = null;
    });
    try {
      final items = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _markAllRead() => setState(() => _notifications = _notifications
      .map((n) => AppNotification(
          type: n.type,
          title: n.title,
          message: n.message,
          time: n.time,
          seen: true))
      .toList());

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingSkeleton(rows: 3),
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load notifications',
        subtitle: _error!,
        actionLabel: 'Try again',
        onAction: _reload,
      );
    }
    final unread = _notifications.where((n) => !n.seen).length;
    return RefreshIndicator(
      onRefresh: _reload,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Notifications',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textSecondary,
                            letterSpacing: 0.4)),
                    Text(
                        unread == 0
                            ? 'All caught up'
                            : '$unread unread updates',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary))
                  ])),
              TextButton(
                  onPressed: unread == 0 ? null : _markAllRead,
                  child: const Text('Mark all read')),
            ])),
        Expanded(
            child: _notifications.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_none,
                    title: 'No notifications yet',
                    subtitle:
                        'Weather, market, and offer alerts will show up here once they are sent.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _NotificationCard(notification: _notifications[i]))),
      ]),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  const _NotificationCard({required this.notification});

  (IconData, Color) get _meta {
    switch (notification.type) {
      case NotificationType.weather:
        return (Icons.wb_sunny_outlined, const Color(0xFF2E86AB));
      case NotificationType.market:
        return (Icons.trending_up, const Color(0xFF1F6B45));
      case NotificationType.offer:
        return (Icons.handshake_outlined, const Color(0xFFF4B942));
      case NotificationType.tool:
        return (Icons.agriculture_outlined, const Color(0xFF8B5E3C));
      case NotificationType.system:
        return (Icons.notifications_outlined, const Color(0xFF6B7280));
    }
  }

  String get _categoryLabel {
    switch (notification.type) {
      case NotificationType.weather:
        return 'Weather';
      case NotificationType.market:
        return 'Market Price';
      case NotificationType.offer:
        return 'Trade Offer';
      case NotificationType.tool:
        return 'Tool Rental';
      case NotificationType.system:
        return 'Update';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color) = _meta;
    final unread = !notification.seen;
    return AnimatedContainer(
      duration: ThemeController.animDuration,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unread ? color.withValues(alpha: 0.5) : c.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _categoryLabel,
                      style: TextStyle(fontSize: 10.5, color: c.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notification.time,
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
