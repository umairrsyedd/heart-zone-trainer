import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/services/notification_service.dart';

part 'notification_provider.g.dart';

/// Provider for NotificationService instance
/// Initializes the service on first access
@Riverpod(keepAlive: true)
NotificationService notificationService(NotificationServiceRef ref) {
  final service = NotificationService();
  // Initialize asynchronously - don't await to avoid blocking
  service.initialize();
  return service;
}
