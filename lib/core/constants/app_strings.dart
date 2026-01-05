/// App-wide string constants for HR Zone Monitor
/// Centralized UI strings for consistency and localization support
class AppStrings {
  AppStrings._(); // Private constructor to prevent instantiation

  // App Name
  static const String appName = 'Heart Zone Trainer';

  // Zone Names and Descriptions
  static const Map<int, String> zoneNames = {
    0: 'Rest',
    1: 'Warm Up',
    2: 'Fat Burn',
    3: 'Cardio',
    4: 'Hard',
    5: 'Max',
  };

  static const Map<int, String> zoneDescriptions = {
    0: 'Below training threshold',
    1: 'Light activity, recovery',
    2: 'Aerobic base building',
    3: 'Aerobic endurance',
    4: 'Anaerobic threshold',
    5: 'Maximum effort',
  };

  /// Get zone name by zone number
  static String getZoneName(int zone) {
    return zoneNames[zone] ?? 'Unknown';
  }

  /// Get zone description by zone number
  static String getZoneDescription(int zone) {
    return zoneDescriptions[zone] ?? '';
  }

  /// Get full zone label (e.g., "Zone 0 - Rest")
  static String getZoneLabel(int zone) {
    return 'Zone $zone - ${getZoneName(zone)}';
  }

  // Connection Status
  static const String disconnected = 'Disconnected';
  static const String scanning = 'Scanning...';
  static const String connecting = 'Connecting...';
  static const String connected = 'Connected';
  static const String reconnecting = 'Reconnecting...';

  // Home Screen
  static const String monitoringPaused = 'Monitoring Paused';
  static const String noHeartRate = 'No heart rate data';
  static const String tapToPause = 'Tap to pause/resume';

  // Settings
  static const String settings = 'Settings';
  static const String zoneSettings = 'Zone Settings';
  static const String alertSettings = 'Alert Management';
  static const String about = 'About';

  // Zone Settings
  static const String restingHeartRate = 'Resting Heart Rate';
  static const String maxHeartRate = 'Max Heart Rate';
  static const String manualZones = 'Manual Zones';
  static const String calculateZones = 'Calculate Zones';

  // Alert Settings
  static const String alertsEnabled = 'Alerts Enabled';
  static const String alertTypes = 'Alert Types';
  static const String sound = 'Sound';
  static const String vibration = 'Vibration';
  static const String voice = 'Voice';
  static const String repeatReminders = 'Repeat Reminders';
  static const String repeatInterval = 'Repeat Interval (seconds)';
  static const String alertCooldown = 'Alert Cooldown (seconds)';
  static const String enabledZones = 'Enabled Zones';

  // General Settings
  static const String backgroundMonitoring = 'Background Monitoring';
  static const String autoPause = 'Auto Pause';
  static const String autoPauseMinutes = 'Auto Pause (minutes)';
  static const String keepScreenOn = 'Keep Screen On';

  // Device
  static const String connectDevice = 'Connect Device';
  static const String disconnectDevice = 'Disconnect';
  static const String scanForDevices = 'Scan for Devices';
  static const String noDevicesFound = 'No devices found';
  static const String selectDevice = 'Select Device';

  // Errors
  static const String errorBluetoothDisabled = 'Bluetooth is disabled';
  static const String errorPermissionDenied = 'Permission denied';
  static const String errorConnectionFailed = 'Connection failed';
  static const String errorDeviceNotFound = 'Device not found';

  // About
  static const String aboutDescription =
      'Heart Zone Trainer is a real-time heart rate zone monitoring app that connects to Bluetooth Low Energy heart rate monitors.';
  static const String version = 'Version';
}
