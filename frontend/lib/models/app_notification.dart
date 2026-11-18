enum NotificationType { weather, market, offer, tool, system }

class AppNotification {
  final NotificationType type;
  final String title;
  final String message;
  final String time;
  final bool seen;

  const AppNotification({
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    required this.seen,
  });
}
