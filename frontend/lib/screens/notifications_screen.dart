import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/ui/states.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = AppNotification.sampleData();

  void _restore() => setState(() => _notifications = AppNotification.sampleData());
  void _markAllRead() => setState(() => _notifications = _notifications.map((n) => AppNotification(type: n.type, title: n.title, message: n.message, time: n.time, seen: true)).toList());

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unread = _notifications.where((n) => !n.seen).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Notifications', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: 0.4)), Text(unread == 0 ? 'All caught up' : '$unread unread updates', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary))])),
        TextButton(onPressed: unread == 0 ? null : _markAllRead, child: const Text('Mark all read')),
      ])),
      Expanded(child: _notifications.isEmpty ? EmptyState(icon: Icons.notifications_none, title: "You're all caught up", subtitle: 'Weather, market, and offer alerts will show up here.', actionLabel: 'Load sample alerts', onAction: _restore) : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _notifications.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (context, i) => _NotificationCard(notification: _notifications[i]))),
    ]);
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  const _NotificationCard({required this.notification});

  (IconData, Color) get _meta {
    switch (notification.type) {
      case NotificationType.weather: return (Icons.wb_sunny_outlined, const Color(0xFF2E86AB));
      case NotificationType.market: return (Icons.trending_up, const Color(0xFF1F6B45));
      case NotificationType.offer: return (Icons.handshake_outlined, const Color(0xFFF4B942));
      case NotificationType.tool: return (Icons.agriculture_outlined, const Color(0xFF8B5E3C));
    }
  }

  String get _categoryLabel {
    switch (notification.type) {
      case NotificationType.weather: return 'Weather';
      case NotificationType.market: return 'Market Price';
      case NotificationType.offer: return 'Trade Offer';
      case NotificationType.tool: return 'Tool Rental';
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
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: unread ? color.withValues(alpha: 0.5) : c.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(notification.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary))), if (unread) Container(margin: const EdgeInsets.only(left: 6), width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle))]),
          const SizedBox(height: 6),
          Text(notification.message, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4)),
          const SizedBox(height: 8),
          Row(children: [Text(_categoryLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)), const SizedBox(width: 8), Text('\u2022 ${notification.time}', style: TextStyle(fontSize: 11, color: c.textSecondary))]),
        ])),
      ]),
    );
  }
}