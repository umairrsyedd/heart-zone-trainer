import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/services/ble_service.dart';

part 'ble_provider.g.dart';

/// Provider for BLEService instance
/// Keep alive to prevent disposal - BLE service must persist across widget rebuilds
/// to maintain connection state and stream controllers
@Riverpod(keepAlive: true)
BLEService bleService(BleServiceRef ref) {
  final service = BLEService();
  ref.onDispose(() {
    // Only dispose when app is truly shutting down
    // Don't dispose on hot reload or widget rebuilds
    service.dispose();
  });
  return service;
}
