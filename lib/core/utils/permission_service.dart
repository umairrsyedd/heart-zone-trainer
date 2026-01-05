import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling app permissions
/// Manages Bluetooth, location, and notification permissions
class PermissionService {
  PermissionService._(); // Private constructor

  /// Request all required permissions for the app
  /// Returns map of permission statuses
  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    final permissions = <Permission>[];
    
    // Bluetooth permissions (always needed)
    permissions.add(Permission.bluetoothScan);
    permissions.add(Permission.bluetoothConnect);
    
    // Location permission ONLY for Android 11 and below
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt <= 30) {
        // Android 11 (API 30) and below - need location for BLE scanning
        permissions.add(Permission.locationWhenInUse);
        if (kDebugMode) {
          print('PermissionService: Android $sdkInt detected - requesting location for BLE');
        }
      } else {
        // Android 12+ - no location needed with neverForLocation flag
        if (kDebugMode) {
          print('PermissionService: Android $sdkInt detected - no location needed for BLE');
        }
      }
    }
    
    // Notification permission (Android 13+)
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        permissions.add(Permission.notification);
      }
    }

    return await permissions.request();
  }

  /// Check if all required permissions are granted
  static Future<bool> hasAllPermissions() async {
    final permissions = <Permission>[];
    
    // Bluetooth permissions (always needed)
    permissions.add(Permission.bluetoothScan);
    permissions.add(Permission.bluetoothConnect);
    
    // Location permission check ONLY for Android 11 and below
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 30) {
        permissions.add(Permission.locationWhenInUse);
      }
    }
    
    // Notification permission (Android 13+)
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        permissions.add(Permission.notification);
      }
    }

    final statuses = await Future.wait(
      permissions.map((p) => p.status),
    );

    // All permissions should be granted
    return statuses.every((status) => status.isGranted);
  }

  /// Request Bluetooth permissions specifically
  static Future<Map<Permission, PermissionStatus>> requestBluetoothPermissions() async {
    return await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  }

  /// Request location permission (for BLE scanning on older Android)
  /// Only requests on Android 11 and below
  static Future<PermissionStatus> requestLocationPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 30) {
        return await Permission.locationWhenInUse.request();
      }
      // Android 12+ doesn't need location
      return PermissionStatus.granted;
    }
    return await Permission.locationWhenInUse.request();
  }

  /// Request notification permission
  static Future<PermissionStatus> requestNotificationPermission() async {
    return await Permission.notification.request();
  }

  /// Check if Bluetooth permissions are granted
  static Future<bool> hasBluetoothPermissions() async {
    final scanStatus = await Permission.bluetoothScan.status;
    final connectStatus = await Permission.bluetoothConnect.status;

    if (!scanStatus.isGranted || !connectStatus.isGranted) {
      return false;
    }
    
    // Check location only for Android 11 and below
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 30) {
        final locationStatus = await Permission.locationWhenInUse.status;
        if (!locationStatus.isGranted) {
          return false;
        }
      }
    }
    
    return true;
  }

  /// Check if location permission is granted
  /// Only relevant for Android 11 and below
  static Future<bool> hasLocationPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt > 30) {
        // Android 12+ doesn't need location
        return true;
      }
    }
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  /// Check if notification permission is granted
  static Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }
}

