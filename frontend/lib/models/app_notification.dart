enum NotificationType { weather, market, offer, tool }

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

  static List<AppNotification> sampleData() => const [
        AppNotification(
          type: NotificationType.weather,
          title: 'Heavy rain alert',
          message: 'Expect 40mm rainfall in Dharwad in the next 24 hours. Delay any spraying.',
          time: '2 hours ago',
          seen: false,
        ),
        AppNotification(
          type: NotificationType.market,
          title: 'Tomato price up 8%',
          message: 'Tomato is now selling at \u20B929/kg at Hubballi APMC.',
          time: '6 hours ago',
          seen: false,
        ),
        AppNotification(
          type: NotificationType.offer,
          title: 'New offer received',
          message: 'Patil Agro Traders offered \u20B930/kg for your 250 kg tomato lot.',
          time: 'Yesterday',
          seen: true,
        ),
        AppNotification(
          type: NotificationType.tool,
          title: 'Tractor rental confirmed',
          message: 'Your Mahindra tractor booking for 22 Sep has been confirmed.',
          time: '2 days ago',
          seen: true,
        ),
        AppNotification(
          type: NotificationType.market,
          title: 'Wheat price stable',
          message: 'Wheat steady at \u20B92,150/quintal in Belagavi market.',
          time: '3 days ago',
          seen: true,
        ),
      ];
}