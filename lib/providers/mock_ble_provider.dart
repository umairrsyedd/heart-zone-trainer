import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/services/mock_ble_service.dart';

part 'mock_ble_provider.g.dart';

/// Provider for MockBLEService instance (for testing without physical device)
/// Automatically disposes the service when the provider is disposed
@riverpod
MockBLEService mockBleService(MockBleServiceRef ref) {
  final service = MockBLEService();
  ref.onDispose(() => service.dispose());
  return service;
}

