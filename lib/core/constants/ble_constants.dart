/// Bluetooth Low Energy (BLE) constants for HR Zone Monitor
/// Standard BLE Heart Rate Service UUIDs as per Bluetooth SIG specification
class BLEConstants {
  BLEConstants._(); // Private constructor to prevent instantiation

  /// Heart Rate Service UUID (0x180D)
  /// Standard Bluetooth SIG-defined service for Heart Rate Profile
  static const String heartRateServiceUUID = "0000180d-0000-1000-8000-00805f9b34fb";

  /// Heart Rate Measurement Characteristic UUID (0x2A37)
  /// Used to receive heart rate measurements from the device
  static const String heartRateMeasurementUUID = "00002a37-0000-1000-8000-00805f9b34fb";
}
