import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/utils/hr_zone_calculator.dart';
import '../data/models/monitoring_state.dart';
import '../data/services/alert_service.dart';
import '../data/services/ble_service.dart';
import 'alert_provider.dart';
import 'ble_provider.dart';
import 'preferences_provider.dart';
import 'zone_provider.dart';

part 'monitoring_provider.g.dart';

/// Provider for current BPM value from monitoring state
@riverpod
int? currentBPM(CurrentBPMRef ref) {
  final monitoringState = ref.watch(monitoringNotifierProvider);
  return monitoringState.currentBPM;
}

/// Notifier for managing monitoring state and heart rate data
/// Handles BLE connection, heart rate updates, zone changes, and alerts
@riverpod
class MonitoringNotifier extends _$MonitoringNotifier {
  StreamSubscription? _heartRateSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _autoPauseTimer;
  Timer? _heartRateTimeoutTimer;
  DateTime? _lastHeartRateTime;
  int? _lastValidBPM; // Store last valid (non-zero) BPM
  int? _currentRepeatReminderZone; // Track which zone has active repeat reminders

  @override
  MonitoringState build() {
    final bleService = ref.watch(bleServiceProvider);
    
    // Get initial state synchronously
    final initialConnectionState = bleService.currentConnectionState;
    final initialDevice = bleService.connectedDevice;
    
    // Load alertsEnabled from preferences (default to true if not loaded yet)
    final prefs = ref.read(preferencesNotifierProvider).value;
    final initialAlertsEnabled = prefs?.alertsEnabled ?? true;
    
    if (kDebugMode) {
      print('MonitoringProvider: 🏗️ Building with initial state: $initialConnectionState, alertsEnabled: $initialAlertsEnabled');
    }
    
    // Watch preferences to sync alertsEnabled when preferences change
    ref.listen(preferencesNotifierProvider, (previous, next) {
      next.whenData((prefs) {
        if (state.alertsEnabled != prefs.alertsEnabled) {
          state = state.copyWith(alertsEnabled: prefs.alertsEnabled);
        }
      });
    });
    
    // Return initial state with connection info and alertsEnabled from preferences
    return MonitoringState(
      connectionState: initialConnectionState,
      connectedDeviceName: initialDevice?.platformName,
      alertsEnabled: initialAlertsEnabled,
    );
    
    // Subscribe to connection state changes
    _connectionSubscription?.cancel(); // Cancel any existing subscription
    _connectionSubscription = bleService.connectionStateStream.listen(
      (connectionState) {
        if (kDebugMode) {
          print('MonitoringProvider: 📥 Received connection state: $connectionState');
        }
        
        // Update state when stream emits
        final currentState = state;
        String? deviceName;
        if (connectionState == ConnectionState.connected) {
          // Get device name from BLE service
          deviceName = bleService.connectedDevice?.platformName;
          // If platformName is empty, keep the existing name (might have been set explicitly)
          if (deviceName == null || deviceName.isEmpty) {
            deviceName = currentState.connectedDeviceName;
          }
          if (kDebugMode) {
            print('MonitoringProvider: Device name from BLE: ${bleService.connectedDevice?.platformName}, using: $deviceName');
          }
        } else if (connectionState == ConnectionState.disconnected) {
          deviceName = null;
        } else {
          // Keep existing name for other states
          deviceName = currentState.connectedDeviceName;
        }
        
        final newState = currentState.copyWith(
          connectionState: connectionState,
          connectedDeviceName: deviceName,
        );
        
        // Update if connection state changed OR device name changed
        if (currentState.connectionState != connectionState || 
            currentState.connectedDeviceName != deviceName) {
          if (kDebugMode) {
            print('MonitoringProvider: ✅ Updating state to: $connectionState, device: $deviceName');
          }
          state = newState;
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('MonitoringProvider: ❌ Stream error: $error');
        }
      },
    );
    
    // Clean up subscription when provider is disposed
    ref.onDispose(() {
      if (kDebugMode) {
        print('MonitoringProvider: 🧹 Disposing stream subscription');
      }
      _connectionSubscription?.cancel();
      _heartRateSubscription?.cancel();
      _autoPauseTimer?.cancel();
      _heartRateTimeoutTimer?.cancel();
    });
    
    // Return initial state
    return MonitoringState(
      connectionState: initialConnectionState,
      connectedDeviceName: initialDevice?.platformName,
    );
  }

  /// Start monitoring heart rate
  /// Subscribes to BLE heart rate stream and connection state
  /// Uses mock service if mock mode is enabled
  /// For real BLE, device must be connected (checked by UI before calling)
  void startMonitoring() async {
    // Cancel any existing subscriptions first
    _heartRateSubscription?.cancel();

    // Always use real BLE service (mock mode removed for production)
    final bleService = ref.read(bleServiceProvider);

    // For real BLE, device should already be connected (UI checks this)
    // Verify connection state - prioritize service connection status
    final isStateConnected = state.connectionState == ConnectionState.connected;
    final isServiceConnected = bleService.isConnected;
    
    // If service is NOT connected, we can't monitor - return early
    if (!isServiceConnected) {
      return;
    }
    
    // If service is connected but state isn't, update state first
    if (isServiceConnected && !isStateConnected) {
      // Get device name from BLE service or preferences
      String? deviceName = bleService.connectedDevice?.platformName;
      if (deviceName == null || deviceName.isEmpty) {
        final prefs = ref.read(preferencesNotifierProvider).value;
        deviceName = prefs?.lastConnectedDeviceName;
      }
      
      state = state.copyWith(
        connectionState: ConnectionState.connected,
        connectedDeviceName: deviceName,
      );
    }
    
    // Also ensure device name is set even if state is already connected
    if (isServiceConnected && (state.connectedDeviceName == null || state.connectedDeviceName!.isEmpty)) {
      String? deviceName = bleService.connectedDevice?.platformName;
      if (deviceName == null || deviceName.isEmpty) {
        final prefs = ref.read(preferencesNotifierProvider).value;
        deviceName = prefs?.lastConnectedDeviceName;
      }
      if (deviceName != null && deviceName.isNotEmpty) {
        state = state.copyWith(connectedDeviceName: deviceName);
      }
    }

    // Subscribe to heart rate updates - service is connected at this point
    // Cancel any existing subscription first to avoid duplicates
    _heartRateSubscription?.cancel();
    _heartRateSubscription = null;
    
    // Create new subscription
    _heartRateSubscription = bleService.heartRateStream.listen(
      (bpm) {
        _handleHeartRateUpdate(bpm);
      },
      onError: (error) {
        // Silently handle errors
      },
      onDone: () {
        // Stream closed
      },
    );

    // Connection state subscription is already set up in build()
    // No need to create another one here

    // Update monitoring state - monitoring is always on when connected
    state = state.copyWith(
      isMonitoring: true,
      lastAppOpenTime: DateTime.now(),
    );

    _startAutoPauseTimer();
    _startHeartRateTimeoutCheck();
  }

  /// Handle incoming heart rate update
  /// Updates state and triggers zone change alerts if needed
  /// Filters out 0 BPM values and uses last valid BPM instead
  void _handleHeartRateUpdate(int bpm) {
    // Filter out 0 BPM - use last valid BPM instead
    if (bpm == 0) {
      if (_lastValidBPM != null) {
        // Keep showing last valid BPM, don't update
        return;
      } else {
        // No valid BPM yet, just return without updating
        return;
      }
    }

    // Update last valid BPM and timestamp
    _lastValidBPM = bpm;
    _lastHeartRateTime = DateTime.now();
    
    // Reset timeout timer since we received data
    _heartRateTimeoutTimer?.cancel();
    _startHeartRateTimeoutCheck();

    final zones = ref.read(zonesProvider);
    if (zones.isEmpty) {
      // Still update BPM even if zones aren't ready
      state = state.copyWith(
        currentBPM: bpm,
        lastHeartRateReceivedAt: DateTime.now(),
      );
      return;
    }
    
    final newZone = HRZoneCalculator.getZoneForBPM(bpm, zones);
    final previousZone = state.currentZone;

    // Determine if this is a zone change
    final isZoneChange = previousZone != null && newZone != previousZone;
    final zoneEntryTime = isZoneChange ? DateTime.now() : (state.zoneEntryTime ?? DateTime.now());

    // Check for zone change - only trigger alert if alerts are enabled
    if (isZoneChange) {
      if (state.alertsEnabled) {
        _handleZoneChange(previousZone!, newZone, zoneEntryTime);
      }
    } else if (previousZone == null && newZone != null) {
      // First time entering a zone - start repeat reminders if enabled
      if (state.alertsEnabled) {
        _startRepeatRemindersIfEnabled(newZone, zoneEntryTime);
      }
    }
    // Note: If staying in the same zone, repeat reminders should already be running
    // Don't restart them on every heart rate update - that would reset the timer

    final newState = state.copyWith(
      currentBPM: bpm,
      currentZone: newZone,
      previousZone: previousZone ?? newZone,
      zoneEntryTime: zoneEntryTime,
      lastHeartRateReceivedAt: DateTime.now(),
    );
    
    state = newState;
  }

  /// Start periodic check for heart rate timeout
  /// If no data received for 10 seconds, clear BPM and update status
  void _startHeartRateTimeoutCheck() {
    _heartRateTimeoutTimer?.cancel();
    
    _heartRateTimeoutTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_lastHeartRateTime == null) {
        // No data received yet, keep checking
        return;
      }
      
      final timeSinceLastUpdate = DateTime.now().difference(_lastHeartRateTime!);
      
      // If no data received for 10 seconds, clear the BPM
      if (timeSinceLastUpdate.inSeconds >= 10) {
        if (kDebugMode) {
          print('MonitoringProvider: ⚠️ No heart rate data for ${timeSinceLastUpdate.inSeconds}s, clearing BPM');
        }
        
        // Clear BPM and zone, but keep connection state
        state = state.copyWith(
          currentBPM: null,
          currentZone: null,
        );
        
        // Cancel timer since we've handled the timeout
        timer.cancel();
        _heartRateTimeoutTimer = null;
      }
    });
  }

  /// Handle zone change event
  /// Triggers alerts and starts repeat reminders if configured
  /// Only triggers if alerts are enabled in monitoring state
  void _handleZoneChange(int fromZone, int toZone, DateTime zoneEntryTime) {
    // Double-check alerts are enabled in monitoring state
    if (!state.alertsEnabled) {
      if (kDebugMode) {
        print('MonitoringProvider: Zone changed but alerts are disabled');
      }
      return;
    }

    final prefs = ref.read(preferencesNotifierProvider).value;
    if (prefs == null) return;

    final alertService = ref.read(alertServiceProvider);

    // Check if this zone has alerts enabled in preferences
    if (prefs.enabledZones.contains(toZone)) {
      if (kDebugMode) {
        print('MonitoringProvider: 🔔 Zone change alert: $fromZone → $toZone');
      }
      
      alertService.triggerZoneChangeAlert(
        newZone: toZone,
        alertTypes: prefs.alertTypes,
        cooldownSeconds: prefs.alertCooldownSeconds,
      );

      // Start repeat reminders if enabled (will stop old ones automatically)
      _currentRepeatReminderZone = null; // Reset so we can start new ones
      _startRepeatRemindersIfEnabled(toZone, zoneEntryTime);
    } else {
      // Zone changed but alerts not enabled for this zone - stop any existing reminders
      alertService.stopRepeatReminders();
      _currentRepeatReminderZone = null;
    }

    state = state.copyWith(
      lastZoneChangeTime: DateTime.now(),
    );
  }

  /// Start repeat reminders if enabled in preferences
  /// Checks preferences and zone enablement before starting
  /// Only starts if not already running for this zone
  void _startRepeatRemindersIfEnabled(int zone, DateTime zoneEntryTime) {
    final prefs = ref.read(preferencesNotifierProvider).value;
    if (prefs == null) return;

    // Only start if repeat reminders are enabled AND this zone has alerts enabled
    // AND we're not already running reminders for this zone
    if (prefs.repeatRemindersEnabled && 
        prefs.enabledZones.contains(zone) &&
        _currentRepeatReminderZone != zone) {
      final alertService = ref.read(alertServiceProvider);
      if (kDebugMode) {
        print('MonitoringProvider: 🔔 Starting repeat reminders for Zone $zone (interval: ${prefs.repeatIntervalSeconds}s)');
      }
      alertService.startRepeatReminders(
        intervalSeconds: prefs.repeatIntervalSeconds,
        currentZone: zone,
        zoneEntryTime: zoneEntryTime,
        alertTypes: prefs.alertTypes,
      );
      _currentRepeatReminderZone = zone;
    } else if (kDebugMode && _currentRepeatReminderZone == zone) {
      print('MonitoringProvider: ⏸️ Repeat reminders already running for Zone $zone, skipping restart');
    }
  }

  /// Stop monitoring heart rate
  /// Stops listening to heart rate data but KEEPS the BLE connection alive
  /// The device should remain connected so user can start another workout without reconnecting
  /// 
  /// Note: Connection subscription (_connectionSubscription) is NOT canceled here
  /// because it's set up in build() and should persist for the provider's lifetime
  /// to continue receiving connection state updates even when not monitoring.
  Future<void> stopMonitoring() async {
    if (kDebugMode) {
      print('Provider: Stop monitoring called');
    }
    
    // Cancel heart rate subscription (stop listening to data)
    // This stops receiving heart rate updates, but BLE connection stays active
    _heartRateSubscription?.cancel();
    _heartRateSubscription = null;
    
    // Cancel auto-pause timer
    _autoPauseTimer?.cancel();
    
    // Cancel heart rate timeout timer
    _heartRateTimeoutTimer?.cancel();
    _heartRateTimeoutTimer = null;
    
    // Reset heart rate tracking
    _lastHeartRateTime = null;
    
    // Stop repeat reminders
    ref.read(alertServiceProvider).stopRepeatReminders();
    _currentRepeatReminderZone = null;

    // IMPORTANT: Do NOT disconnect the BLE device
    // Keep the connection alive so user can start another workout
    // Only cancel the heart rate subscription to stop receiving data
    // Connection subscription (_connectionSubscription) remains active to track connection state
    
    // Reset monitoring state but keep connection state
    state = state.copyWith(
      isMonitoring: false,
      currentBPM: null,
      currentZone: null,
      previousZone: null,
      // DO NOT change connectionState - keep it as connected
      // connectionState should remain as it was (likely ConnectionState.connected)
    );
    if (kDebugMode) {
      print('Provider: Monitoring stopped - isMonitoring: false, connectionState: ${state.connectionState}');
      print('Provider: BLE device remains connected - ready for next workout');
    }
  }

  /// Toggle pause/resume monitoring
  /// Stops repeat reminders when pausing
  /// Toggle alerts on/off (not monitoring - monitoring is always on when connected)
  void toggleAlerts() {
    final newState = !state.alertsEnabled;
    state = state.copyWith(alertsEnabled: newState);
    
    // Sync with preferences
    final prefs = ref.read(preferencesNotifierProvider).value;
    if (prefs != null) {
      ref.read(preferencesNotifierProvider.notifier).updatePreferences(
        prefs.copyWith(alertsEnabled: newState),
      );
    }
    
    if (kDebugMode) {
      print('MonitoringProvider: ${newState ? "🔔 Alerts ENABLED" : "🔕 Alerts DISABLED"}');
    }
    
    // If disabling alerts, stop any active repeat reminders
    if (!newState) {
      ref.read(alertServiceProvider).stopRepeatReminders();
      _currentRepeatReminderZone = null;
    }
  }

  /// Explicitly set alerts state
  void setAlertsEnabled(bool enabled) {
    state = state.copyWith(alertsEnabled: enabled);
    
    // Sync with preferences
    final prefs = ref.read(preferencesNotifierProvider).value;
    if (prefs != null) {
      ref.read(preferencesNotifierProvider.notifier).updatePreferences(
        prefs.copyWith(alertsEnabled: enabled),
      );
    }
    
    if (kDebugMode) {
      print('MonitoringProvider: Alerts ${enabled ? "ENABLED" : "DISABLED"}');
    }
    
    // If disabling alerts, stop any active repeat reminders
    if (!enabled) {
      ref.read(alertServiceProvider).stopRepeatReminders();
      _currentRepeatReminderZone = null;
    }
  }

  /// Start auto-pause timer
  /// Note: With always-on monitoring, this timer is kept for potential future use
  /// but doesn't pause monitoring anymore - monitoring is always active when connected
  void _startAutoPauseTimer() {
    // Timer kept for compatibility but doesn't pause monitoring
    // Monitoring is always on when connected
    final prefs = ref.read(preferencesNotifierProvider).value;
    if (prefs == null || !prefs.backgroundMonitoringEnabled) return;

    _autoPauseTimer?.cancel();
    // Timer can be used for other purposes in the future if needed
  }

  /// Reset auto-pause timer
  /// Called when app comes to foreground or user interacts
  void resetAutoPauseTimer() {
    state = state.copyWith(lastAppOpenTime: DateTime.now());
    _startAutoPauseTimer();
  }

  /// Update connected device name and connection state
  /// Called when a device is successfully connected
  /// This ensures the monitoring state reflects the connection even if stream update is delayed
  void updateDeviceName(String deviceName) {
    if (kDebugMode) {
      print('Provider: updateDeviceName called with: $deviceName');
      print('Provider: Current state before update - connectionState: ${state.connectionState}, isConnected: ${state.isConnected}');
    }
    
    // Force update to connected state
    state = state.copyWith(
      connectedDeviceName: deviceName,
      connectionState: ConnectionState.connected, // Explicitly set to connected
    );
    
    if (kDebugMode) {
      print('Provider: ✅ State after updateDeviceName - connectionState: ${state.connectionState}, isConnected: ${state.isConnected}');
    }
  }
  
  /// Force sync connection state with BLE service
  /// Called to ensure monitoring state matches BLE service state
  void syncConnectionState() {
    final bleService = ref.read(bleServiceProvider);
    final isConnected = bleService.isConnected;
    final device = bleService.connectedDevice;
    
    if (kDebugMode) {
      print('Provider: syncConnectionState - BLE isConnected: $isConnected, device: ${device?.platformName}');
    }
    
    if (isConnected && device != null) {
      final prefs = ref.read(preferencesNotifierProvider).value;
      final deviceName = device.platformName.isNotEmpty 
          ? device.platformName 
          : prefs?.lastConnectedDeviceName;
      
      if (kDebugMode) {
        print('Provider: Syncing to connected state with device: $deviceName');
      }
      state = state.copyWith(
        connectionState: ConnectionState.connected,
        connectedDeviceName: deviceName,
      );
      if (kDebugMode) {
        print('Provider: ✅ Synced - connectionState: ${state.connectionState}, isConnected: ${state.isConnected}');
      }
    } else {
      if (kDebugMode) {
        print('Provider: Syncing to disconnected state');
      }
      state = state.copyWith(
        connectionState: ConnectionState.disconnected,
        connectedDeviceName: null,
      );
    }
  }
  
  /// Force sync connection state with BLE service
  /// Creates a completely new state object to ensure Riverpod detects the change
  void forceSync() {
    final bleService = ref.read(bleServiceProvider);
    
    final newConnectionState = bleService.currentConnectionState;
    
    // Get device name from BLE service
    // Only use saved name from preferences if actually connected
    String? deviceName;
    if (newConnectionState == ConnectionState.connected) {
      deviceName = bleService.connectedDevice?.platformName;
      if (deviceName == null || deviceName.isEmpty) {
        final prefs = ref.read(preferencesNotifierProvider).value;
        deviceName = prefs?.lastConnectedDeviceName;
        if (kDebugMode) {
          print('MonitoringProvider: forceSync - BLE device name empty, using saved name: $deviceName');
        }
      }
    } else {
      // When disconnected, device name should be null
      deviceName = null;
    }
    
    if (kDebugMode) {
      print('MonitoringProvider: 🔄 Force sync - BLE state: $newConnectionState, device: $deviceName');
    }
    
    // Force a new state object to ensure Riverpod detects the change
    state = MonitoringState(
      connectionState: newConnectionState,
      connectedDeviceName: deviceName,
      isMonitoring: state.isMonitoring,
      alertsEnabled: state.alertsEnabled,
      currentBPM: state.currentBPM,
      currentZone: state.currentZone,
      previousZone: state.previousZone,
      lastZoneChangeTime: state.lastZoneChangeTime,
      zoneEntryTime: state.zoneEntryTime,
      lastAppOpenTime: state.lastAppOpenTime,
      lastHeartRateReceivedAt: state.lastHeartRateReceivedAt,
    );
    
    if (kDebugMode) {
      print('MonitoringProvider: ✅ Force synced - isConnected: ${state.isConnected}, device: ${state.connectedDeviceName}');
    }
  }
}
