import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Notification service for persistent heart rate monitoring notifications
/// Uses native Android Foreground Service for reliable notification management
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const MethodChannel _channel = MethodChannel('com.umair.hrzmonitor/notification');
  bool _isServiceRunning = false;

  /// Initialize the notification service
  /// No-op for native service (channel created in native code)
  Future<void> initialize() async {
    // Native service handles initialization
    if (kDebugMode) {
      print('NotificationService: ✅ Initialized (using native service)');
    }
  }

  /// Start the foreground service with notification
  Future<void> startNotification() async {
    if (_isServiceRunning) return;
    
    try {
      await _channel.invokeMethod('startService');
      _isServiceRunning = true;
      if (kDebugMode) {
        print('NotificationService: ✅ Service started');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: ❌ Failed to start service: $e');
      }
    }
  }

  /// Update notification with heart rate data
  /// Shows current BPM and zone information
  Future<void> updateWithHeartRate({
    required int bpm,
    required int zone,
    required String zoneName,
    required String deviceName,
  }) async {
    if (!_isServiceRunning) {
      await startNotification();
    }

    try {
      final String title = '💓 $bpm BPM  •  Zone $zone - $zoneName';
      final String body = 'Connected to $deviceName';
      
      await _channel.invokeMethod('updateNotification', {
        'title': title,
        'text': body,
      });
      
      if (kDebugMode) {
        print('NotificationService: 📱 Notification updated - "$title"');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: ❌ Failed to update notification: $e');
      }
    }
  }

  /// Update notification - connected but no HR data yet
  Future<void> updateConnectedNoData({required String deviceName}) async {
    if (!_isServiceRunning) {
      await startNotification();
    }

    try {
      await _channel.invokeMethod('updateNotification', {
        'title': '⏳ Waiting for heart rate data...',
        'text': 'Connected to $deviceName',
      });
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: ❌ Failed to update notification: $e');
      }
    }
  }

  /// Update notification - connecting to device
  Future<void> updateConnecting({required String deviceName}) async {
    if (!_isServiceRunning) {
      await startNotification();
    }

    try {
      await _channel.invokeMethod('updateNotification', {
        'title': '🔄 Connecting to $deviceName...',
        'text': 'Please wait',
      });
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: ❌ Failed to update notification: $e');
      }
    }
  }

  /// Update notification - reconnecting after disconnect
  Future<void> updateReconnecting({required String deviceName}) async {
    if (!_isServiceRunning) {
      await startNotification();
    }

    try {
      await _channel.invokeMethod('updateNotification', {
        'title': '🔄 Reconnecting to $deviceName...',
        'text': 'Connection lost, attempting to reconnect',
      });
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: ❌ Failed to update notification: $e');
      }
    }
  }

  /// Update notification - Bluetooth disabled
  Future<void> updateBluetoothDisabled() async {
    if (!_isServiceRunning) {
      await startNotification();
    }

    try {
      await _channel.invokeMethod('updateNotification', {
        'title': '⚠️ Bluetooth is disabled',
        'text': 'Tap to enable and reconnect',
      });
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: ❌ Failed to update notification: $e');
      }
    }
  }

  /// Update notification - device disconnected
  Future<void> updateDeviceDisconnected({required String deviceName}) async {
    if (!_isServiceRunning) {
      await startNotification();
    }

    try {
      await _channel.invokeMethod('updateNotification', {
        'title': '🔴 Disconnected from $deviceName',
        'text': 'Tap to reconnect',
      });
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: ❌ Failed to update notification: $e');
      }
    }
  }

  /// Stop and remove the notification
  Future<void> stopNotification() async {
    if (!_isServiceRunning) return;
    
    try {
      await _channel.invokeMethod('stopService');
      _isServiceRunning = false;
      if (kDebugMode) {
        print('NotificationService: ✅ Service stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService: ❌ Failed to stop service: $e');
      }
    }
  }

  /// Refresh notification with current state (call when app resumes)
  /// Re-shows notification if it should be visible but was removed
  Future<void> refreshNotification({
    required int bpm,
    required int zone,
    required String zoneName,
    required String deviceName,
  }) async {
    // Re-show notification with current data
    await updateWithHeartRate(
      bpm: bpm,
      zone: zone,
      zoneName: zoneName,
      deviceName: deviceName,
    );
  }

  /// Check if service is running
  bool get isNotificationShowing => _isServiceRunning;
  
  /// Check if service is running (alias for consistency)
  bool get isRunning => _isServiceRunning;
}
