import 'package:freezed_annotation/freezed_annotation.dart';
import 'zone_boundary.dart';

part 'user_preferences.freezed.dart';
part 'user_preferences.g.dart';

/// User preferences model for app settings and configuration
/// Persisted to local storage using SharedPreferences
@freezed
class UserPreferences with _$UserPreferences {
  const factory UserPreferences({
    // HR Zone Settings
    @Default(60) int restingHR,
    @Default(190) int maxHR,
    @Default(false) bool manualZonesEnabled,
    List<ZoneBoundary>? customZones, // Only used if manualZonesEnabled

    // Alert Settings
    @Default(true) bool alertsEnabled,
    @Default([AlertType.vibration, AlertType.voice]) List<AlertType> alertTypes,
    @Default(false) bool repeatRemindersEnabled,
    @Default(30) int repeatIntervalSeconds,
    @Default([0, 1, 2, 3, 4, 5]) List<int> enabledZones,
    @Default(5) int alertCooldownSeconds,

    // General Settings
    @Default(true) bool backgroundMonitoringEnabled,
    @Default(60) int autoPauseMinutes,
    @Default(false) bool keepScreenOn,

    // Device
    String? lastConnectedDeviceId,
    String? lastConnectedDeviceName,

    // Development/Testing
    @Default(false) bool mockModeEnabled, // Use mock BLE service for testing
  }) = _UserPreferences;

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);
}

/// Alert type enum for zone change notifications
enum AlertType {
  sound,
  vibration,
  voice,
}
