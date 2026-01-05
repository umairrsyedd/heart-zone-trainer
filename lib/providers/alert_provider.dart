import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/services/alert_service.dart';

part 'alert_provider.g.dart';

/// Provider for AlertService instance
/// Keep-alive provider to prevent disposal during app lifecycle
/// Similar to bleServiceProvider - service should persist
@Riverpod(keepAlive: true)
AlertService alertService(AlertServiceRef ref) {
  final service = AlertService();
  // Only dispose when app is truly shutting down
  // Don't dispose on hot reload or widget rebuilds
  ref.onDispose(() {
    // Service will be disposed when app closes
    service.dispose();
  });
  return service;
}
