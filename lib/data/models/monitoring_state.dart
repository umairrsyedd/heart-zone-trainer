import 'package:freezed_annotation/freezed_annotation.dart';

part 'monitoring_state.freezed.dart';

/// Connection state enum for BLE device connection status
enum ConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  reconnecting,
}

/// Monitoring state model representing the current monitoring session state
@freezed
class MonitoringState with _$MonitoringState {
  const factory MonitoringState({
    @Default(ConnectionState.disconnected) ConnectionState connectionState,
    @Default(false) bool isMonitoring,
    @Default(true) bool alertsEnabled, // Whether zone alerts are active
    int? currentBPM,
    int? currentZone,
    int? previousZone,
    DateTime? lastZoneChangeTime,
    DateTime? zoneEntryTime,
    DateTime? lastAppOpenTime,
    DateTime? lastHeartRateReceivedAt, // Track when last HR received
    String? connectedDeviceName,
  }) = _MonitoringState;

  const MonitoringState._();

  /// Check if device is currently connected
  bool get isConnected => connectionState == ConnectionState.connected;

  /// Check if device is in reconnecting state
  bool get shouldShowReconnecting =>
      connectionState == ConnectionState.reconnecting;

  /// Check if receiving heart rate data (within last 5 seconds)
  bool get isReceivingData =>
      currentBPM != null &&
      lastHeartRateReceivedAt != null &&
      DateTime.now().difference(lastHeartRateReceivedAt!) <
          const Duration(seconds: 5);

  /// Calculate time spent in current zone
  Duration? get timeInCurrentZone {
    if (zoneEntryTime == null) return null;
    return DateTime.now().difference(zoneEntryTime!);
  }
}
