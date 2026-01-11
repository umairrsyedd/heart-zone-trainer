/// Notification constants for heart rate monitoring
/// Defines channel IDs, notification IDs, and action IDs
class NotificationConstants {
  NotificationConstants._(); // Private constructor to prevent instantiation

  // Notification Channel
  static const String channelId = 'hr_monitoring_channel';
  static const String channelName = 'Heart Rate Monitoring';
  static const String channelDescription =
      'Shows real-time heart rate and zone during workouts';

  // Notification ID
  static const int foregroundNotificationId = 1001;

  // Action IDs (for future use - action buttons in notification)
  static const String actionOpenApp = 'open_app';
  static const String actionDisconnect = 'disconnect';
  static const String actionPauseAlerts = 'pause_alerts';
}
