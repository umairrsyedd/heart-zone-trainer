import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/constants/app_strings.dart';
import '../core/utils/hr_zone_calculator.dart';
import '../core/utils/permission_service.dart';
import '../data/models/monitoring_state.dart';
import '../data/services/alert_service.dart';
import '../data/services/ble_service.dart';
import 'alert_provider.dart';
import 'ble_provider.dart';
import 'notification_provider.dart';
import 'preferences_provider.dart';
import 'zone_provider.dart';

part 'monitoring_provider.g.dart';

// ============================================
// TEMPORARY: Screenshot Mode - Set to true to force 160 BPM for Zone 3 screenshot
// TODO: Set back to false after taking screenshot
const bool _SCREENSHOT_MODE = false;
const int _SCREENSHOT_BPM = 184;
// ============================================

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
  Timer? _screenshotMockTimer; // Timer for screenshot mode mock BPM injection
  DateTime? _lastHeartRateTime;
  int? _lastValidBPM; // Store last valid (non-zero) BPM
  int? _currentRepeatReminderZone; // Track which zone has active repeat reminders
  int? _currentRepeatReminderInterval; // Track the interval being used by active timer

  @override
  MonitoringState build() {
    final bleService = ref.watch(bleServiceProvider);
    
    // Get initial state synchronously
    ConnectionState initialConnectionState = bleService.currentConnectionState;
    String? initialDeviceName = bleService.connectedDevice?.platformName;
    
    // ============================================
    // TEMPORARY: Screenshot Mode - Force connected state
    if (_SCREENSHOT_MODE) {
      initialConnectionState = ConnectionState.connected;
      initialDeviceName = initialDeviceName ?? 'Mock Device';
      if (kDebugMode) {
        print('MonitoringProvider: 📸 Screenshot mode enabled - forcing connected state');
      }
    }
    // ============================================
    
    // Load alertsEnabled from preferences (default to true if not loaded yet)
    final prefs = ref.read(preferencesNotifierProvider).value;
    final initialAlertsEnabled = prefs?.alertsEnabled ?? true;
    
    if (kDebugMode) {
      print('MonitoringProvider: 🏗️ Building with initial state: $initialConnectionState, alertsEnabled: $initialAlertsEnabled');
    }
    
    // Watch preferences to sync alertsEnabled and repeat reminder settings when preferences change
    ref.listen(preferencesNotifierProvider, (previous, next) {
      next.whenData((prefs) {
        // Sync alertsEnabled
        if (state.alertsEnabled != prefs.alertsEnabled) {
          state = state.copyWith(alertsEnabled: prefs.alertsEnabled);
        }
        
        // If repeat reminder interval changed and reminders are active, restart with new interval
        if (_currentRepeatReminderZone != null && prefs.repeatRemindersEnabled) {
          // Check if interval changed by comparing with current active interval
          // This is the most reliable check since we track the actual interval being used
          final intervalChanged = _currentRepeatReminderInterval != null && 
                                  _currentRepeatReminderInterval != prefs.repeatIntervalSeconds;
          
          // Also check previous value if available (backup check)
          final previousPrefs = previous?.value;
          final previousIntervalChanged = previousPrefs != null && 
                                         previousPrefs.repeatIntervalSeconds != prefs.repeatIntervalSeconds;
          
          if (kDebugMode) {
            print('MonitoringProvider: 🔍 Checking interval change:');
            print('  - Current active interval: $_currentRepeatReminderInterval');
            print('  - New interval from prefs: ${prefs.repeatIntervalSeconds}');
            if (previousPrefs != null) {
              print('  - Previous interval: ${previousPrefs.repeatIntervalSeconds}');
            }
            print('  - Interval changed (tracked): $intervalChanged');
            print('  - Interval changed (previous): $previousIntervalChanged');
          }
          
          if (intervalChanged || previousIntervalChanged) {
            if (kDebugMode) {
              print('MonitoringProvider: 🔄 Repeat reminder interval changed - restarting timer with fresh start time');
            }
            // Restart reminders with new interval AND reset zone entry time to now
            // This ensures the timer starts fresh from the moment of change, not from original entry
            final currentZone = _currentRepeatReminderZone!;
            final freshZoneEntryTime = DateTime.now();
            // Update state with fresh entry time
            state = state.copyWith(zoneEntryTime: freshZoneEntryTime);
            _startRepeatRemindersIfEnabled(currentZone, freshZoneEntryTime);
          }
          
          // If repeat reminders were disabled, stop them and reset zone entry time
          if (previousPrefs != null && 
              previousPrefs.repeatRemindersEnabled && 
              !prefs.repeatRemindersEnabled) {
            if (kDebugMode) {
              print('MonitoringProvider: 🛑 Repeat reminders disabled in preferences - stopping and resetting timer');
            }
            ref.read(alertServiceProvider).stopRepeatReminders();
            _currentRepeatReminderZone = null;
            _currentRepeatReminderInterval = null;
            // Reset zone entry time so timer starts fresh when re-enabled
            if (state.currentZone != null) {
              state = state.copyWith(zoneEntryTime: DateTime.now());
            }
          }
          
          // If repeat reminders were re-enabled, restart with fresh timer
          if (previousPrefs != null && 
              !previousPrefs.repeatRemindersEnabled && 
              prefs.repeatRemindersEnabled &&
              state.currentZone != null &&
              state.currentZone != 0 &&
              prefs.enabledZones.contains(state.currentZone)) {
            if (kDebugMode) {
              print('MonitoringProvider: 🔄 Repeat reminders re-enabled - restarting with fresh timer');
            }
            // Reset zone entry time to now so timer starts from 0
            final freshZoneEntryTime = DateTime.now();
            state = state.copyWith(zoneEntryTime: freshZoneEntryTime);
            _currentRepeatReminderZone = null; // Reset to allow restart
            _currentRepeatReminderInterval = null;
            _startRepeatRemindersIfEnabled(state.currentZone!, freshZoneEntryTime);
          }
          
          // If zone is no longer in enabledZones, stop reminders
          if (!prefs.enabledZones.contains(_currentRepeatReminderZone)) {
            if (kDebugMode) {
              print('MonitoringProvider: 🛑 Zone $_currentRepeatReminderZone no longer in enabledZones - stopping reminders');
            }
            ref.read(alertServiceProvider).stopRepeatReminders();
            _currentRepeatReminderZone = null;
            _currentRepeatReminderInterval = null;
          }
        }
      });
    });
    
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

          // Update notification based on connection state (fire and forget)
          final notificationService = ref.read(notificationServiceProvider);
          final finalDeviceName = deviceName ?? 'HR Monitor';
          
          if (state.isMonitoring) {
            switch (connectionState) {
              case ConnectionState.connecting:
                notificationService.updateConnecting(deviceName: finalDeviceName);
                break;
              case ConnectionState.connected:
                // If we have HR data, updateWithHeartRate will be called from _handleHeartRateUpdate
                // Otherwise, show waiting message
                if (state.currentBPM == null) {
                  notificationService.updateConnectedNoData(deviceName: finalDeviceName);
                }
                break;
              case ConnectionState.reconnecting:
                notificationService.updateReconnecting(deviceName: finalDeviceName);
                break;
              case ConnectionState.disconnected:
                notificationService.updateDeviceDisconnected(deviceName: finalDeviceName);
                break;
              case ConnectionState.scanning:
                // No notification update for scanning
                break;
            }
          }
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
      _screenshotMockTimer?.cancel(); // Cancel screenshot mock timer
    });
    
    // Return initial state with connection info and alertsEnabled from preferences
    return MonitoringState(
      connectionState: initialConnectionState,
      connectedDeviceName: initialDeviceName,
      alertsEnabled: initialAlertsEnabled,
    );
  }

  /// Start monitoring heart rate
  /// Subscribes to BLE heart rate stream and connection state
  /// Uses mock service if mock mode is enabled
  /// For real BLE, device must be connected (checked by UI before calling)
  void startMonitoring() async {
    // Request notification permission if needed (Android 13+)
    final hasPermission = await PermissionService.hasNotificationPermission();
    if (!hasPermission) {
      await PermissionService.requestNotificationPermission();
    }

    // Start notification service
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.startNotification();
    final deviceName = state.connectedDeviceName ?? 'HR Monitor';
    notificationService.updateConnecting(deviceName: deviceName);

    // Cancel any existing subscriptions first
    _heartRateSubscription?.cancel();

    // ============================================
    // TEMPORARY: Screenshot Mode - Bypass connection check
    if (_SCREENSHOT_MODE) {
      // Force connection state and start mock timer
      state = state.copyWith(
        connectionState: ConnectionState.connected,
        connectedDeviceName: state.connectedDeviceName ?? 'Mock Device',
        isMonitoring: true,
        lastAppOpenTime: DateTime.now(),
      );
      _startScreenshotMockTimer();
      _handleHeartRateUpdate(_SCREENSHOT_BPM);
      return; // Skip BLE connection logic
    }
    // ============================================

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

    // Update notification - connected but waiting for HR data
    final finalDeviceName = state.connectedDeviceName ?? 'HR Monitor';
    notificationService.updateConnectedNoData(deviceName: finalDeviceName);

    // ============================================
    // TEMPORARY: Screenshot Mode - Start mock BPM injection timer
    if (_SCREENSHOT_MODE) {
      _startScreenshotMockTimer();
      // Immediately inject mock BPM
      _handleHeartRateUpdate(_SCREENSHOT_BPM);
    }
    // ============================================

    _startAutoPauseTimer();
    _startHeartRateTimeoutCheck();
  }

  /// Handle incoming heart rate update
  /// Updates state and triggers zone change alerts if needed
  /// Filters out 0 BPM values and uses last valid BPM instead
  void _handleHeartRateUpdate(int bpm) {
    // ============================================
    // TEMPORARY: Screenshot Mode - Override BPM to 160 for Zone 3 screenshot
    if (_SCREENSHOT_MODE) {
      bpm = _SCREENSHOT_BPM;
      // Ensure connection state is connected for screenshot
      if (state.connectionState != ConnectionState.connected) {
        state = state.copyWith(
          connectionState: ConnectionState.connected,
          connectedDeviceName: state.connectedDeviceName ?? 'Mock Device',
        );
      }
    }
    // ============================================
    
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
    
    if (kDebugMode) {
      print('MonitoringProvider: 💓 HR Update - BPM: $bpm, Zone: $newZone, Previous: $previousZone, isZoneChange: $isZoneChange');
    }

    // Check if we have active reminders for a zone that no longer matches current zone
    // This handles cases where zone boundaries changed and user is no longer in that zone
    if (_currentRepeatReminderZone != null && _currentRepeatReminderZone != newZone) {
      if (kDebugMode) {
        print('MonitoringProvider: ⚠️ Active reminders for Zone $_currentRepeatReminderZone but current zone is $newZone - stopping reminders');
      }
      ref.read(alertServiceProvider).stopRepeatReminders();
      _currentRepeatReminderZone = null;
      _currentRepeatReminderInterval = null;
    }
    
    // Check for zone change - only trigger alert if alerts are enabled
    if (isZoneChange) {
      if (state.alertsEnabled) {
        _handleZoneChange(previousZone!, newZone, zoneEntryTime);
      }
    } else if (previousZone == null && newZone != null) {
      // First time entering a zone (app just started monitoring)
      if (kDebugMode) {
        print('MonitoringProvider: 🆕 First zone entry detected - Zone $newZone');
      }
      
      // Reset the tracking variable to ensure reminders can start
      _currentRepeatReminderZone = null;
      _currentRepeatReminderInterval = null;
      
      if (state.alertsEnabled) {
        // Trigger one-time zone announcement (first-time detection, not a zone change)
        final prefs = ref.read(preferencesNotifierProvider).value;
        if (prefs != null && prefs.enabledZones.contains(newZone)) {
          final alertService = ref.read(alertServiceProvider);
          alertService.triggerZoneChangeAlert(
            newZone: newZone,
            alertTypes: prefs.alertTypes,
            cooldownSeconds: prefs.alertCooldownSeconds,
            isFirstTime: true, // This is first-time detection, not an actual zone change
          );
        }
        
        // Start repeat reminders
        _startRepeatRemindersIfEnabled(newZone, zoneEntryTime);
      }
    } else if (previousZone == newZone && newZone != null) {
      // Staying in the same zone - verify reminders are still valid
      // This handles cases where zone boundaries changed but we're still in the same zone number
      // or where preferences changed (interval, enabled status, etc.)
      if (_currentRepeatReminderZone == newZone && state.alertsEnabled) {
        final prefs = ref.read(preferencesNotifierProvider).value;
        if (prefs != null) {
          // Check if reminders should still be running
          final shouldHaveReminders = prefs.repeatRemindersEnabled && 
                                      prefs.enabledZones.contains(newZone) &&
                                      newZone != 0;
          
          if (!shouldHaveReminders) {
            // Reminders should not be running - stop them
            if (kDebugMode) {
              print('MonitoringProvider: 🛑 Reminders should not be running for Zone $newZone - stopping');
            }
            ref.read(alertServiceProvider).stopRepeatReminders();
            _currentRepeatReminderZone = null;
            _currentRepeatReminderInterval = null;
          } else {
            // Reminders should be running - check if interval changed
            if (_currentRepeatReminderInterval != null && 
                _currentRepeatReminderInterval != prefs.repeatIntervalSeconds) {
              if (kDebugMode) {
                print('MonitoringProvider: 🔄 Interval changed from ${_currentRepeatReminderInterval}s to ${prefs.repeatIntervalSeconds}s - restarting timer with fresh start time');
              }
              // Restart with new interval AND reset zone entry time to now
              // This ensures the timer starts fresh from the moment of change
              final freshZoneEntryTime = DateTime.now();
              state = state.copyWith(zoneEntryTime: freshZoneEntryTime);
              _startRepeatRemindersIfEnabled(newZone, freshZoneEntryTime);
            }
          }
        }
      } else if (_currentRepeatReminderZone == null && state.alertsEnabled) {
        // No reminders running but we should have them - start them
        final prefs = ref.read(preferencesNotifierProvider).value;
        if (prefs != null && 
            prefs.repeatRemindersEnabled && 
            prefs.enabledZones.contains(newZone) &&
            newZone != 0) {
          if (kDebugMode) {
            print('MonitoringProvider: 🔄 Reminders should be running for Zone $newZone but are not - starting them');
          }
          _startRepeatRemindersIfEnabled(newZone, zoneEntryTime);
        }
      }
    }
    // Note: If staying in the same zone and reminders are running correctly, do nothing

    final newState = state.copyWith(
      currentBPM: bpm,
      currentZone: newZone,
      previousZone: previousZone ?? newZone,
      zoneEntryTime: zoneEntryTime,
      lastHeartRateReceivedAt: DateTime.now(),
    );
    
    state = newState;

    // Update notification with heart rate data
    if (newZone != null && state.isMonitoring) {
      final notificationService = ref.read(notificationServiceProvider);
      final zoneName = AppStrings.getZoneName(newZone);
      final deviceName = state.connectedDeviceName ?? 'HR Monitor';
      notificationService.updateWithHeartRate(
        bpm: bpm,
        zone: newZone,
        zoneName: zoneName,
        deviceName: deviceName,
      );
    }
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

  /// ============================================
  /// TEMPORARY: Screenshot Mode - Start mock BPM injection timer
  /// Periodically injects mock BPM value for screenshot purposes
  void _startScreenshotMockTimer() {
    _screenshotMockTimer?.cancel();
    
    // Inject mock BPM every 1 second to keep it active
    _screenshotMockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_SCREENSHOT_MODE) {
        _handleHeartRateUpdate(_SCREENSHOT_BPM);
      } else {
        // Screenshot mode disabled, cancel timer
        timer.cancel();
        _screenshotMockTimer = null;
      }
    });
  }
  /// ============================================

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
      _currentRepeatReminderInterval = null;
      _startRepeatRemindersIfEnabled(toZone, zoneEntryTime);
    } else {
      // Zone changed but alerts not enabled for this zone - stop any existing reminders
      alertService.stopRepeatReminders();
      _currentRepeatReminderZone = null;
      _currentRepeatReminderInterval = null;
    }

    state = state.copyWith(
      lastZoneChangeTime: DateTime.now(),
    );
  }

  /// Start repeat reminders if enabled in preferences
  /// Checks preferences and zone enablement before starting
  /// Only starts if not already running for this zone
  /// Zone 0 (Rest) is explicitly excluded from repeat reminders
  void _startRepeatRemindersIfEnabled(int zone, DateTime zoneEntryTime) {
    // Zone 0 (Rest) should never have repeat reminders
    if (zone == 0) {
      if (kDebugMode) {
        print('MonitoringProvider: ⏸️ Zone 0 - Repeat reminders disabled for Rest zone');
      }
      return;
    }

    final prefs = ref.read(preferencesNotifierProvider).value;
    if (prefs == null) {
      if (kDebugMode) {
        print('MonitoringProvider: ❌ Cannot start repeat reminders - preferences not loaded');
      }
      return;
    }

    if (kDebugMode) {
      print('MonitoringProvider: 🔍 Checking repeat reminder conditions:');
      print('  - repeatRemindersEnabled: ${prefs.repeatRemindersEnabled}');
      print('  - zone $zone in enabledZones: ${prefs.enabledZones.contains(zone)}');
      print('  - _currentRepeatReminderZone: $_currentRepeatReminderZone');
      print('  - _currentRepeatReminderInterval: $_currentRepeatReminderInterval');
      print('  - new interval: ${prefs.repeatIntervalSeconds}');
    }

    // Check if we should start/restart reminders
    final isNewZone = _currentRepeatReminderZone != zone;
    final intervalChanged = _currentRepeatReminderInterval != null && 
                            _currentRepeatReminderInterval != prefs.repeatIntervalSeconds;
    
    // Start if repeat reminders are enabled AND this zone has alerts enabled
    // AND either it's a new zone OR the interval changed (need to restart)
    if (prefs.repeatRemindersEnabled && 
        prefs.enabledZones.contains(zone) &&
        (isNewZone || intervalChanged)) {
      
      // If already running for this zone but interval changed, stop first
      if (!isNewZone && intervalChanged) {
        if (kDebugMode) {
          print('MonitoringProvider: 🔄 Stopping existing timer to restart with new interval');
        }
        ref.read(alertServiceProvider).stopRepeatReminders();
      }
      final alertService = ref.read(alertServiceProvider);
      
      if (kDebugMode) {
        if (isNewZone) {
          print('MonitoringProvider: ✅ Starting repeat reminders for Zone $zone');
        } else {
          print('MonitoringProvider: ✅ Restarting repeat reminders for Zone $zone with new interval');
        }
        print('  - Interval: ${prefs.repeatIntervalSeconds} seconds');
        print('  - Alert types: ${prefs.alertTypes}');
      }
      
      alertService.startRepeatReminders(
        intervalSeconds: prefs.repeatIntervalSeconds,
        currentZone: zone,
        zoneEntryTime: zoneEntryTime,
        alertTypes: prefs.alertTypes,
      );
      
      _currentRepeatReminderZone = zone;
      _currentRepeatReminderInterval = prefs.repeatIntervalSeconds; // Track the interval
    } else {
      if (kDebugMode) {
        print('MonitoringProvider: ⏸️ Repeat reminders NOT started - conditions not met');
        final intervalChanged = _currentRepeatReminderInterval != null && 
                                _currentRepeatReminderInterval != prefs.repeatIntervalSeconds;
        if (_currentRepeatReminderZone == zone && !intervalChanged) {
          print('  - Reason: Already running for Zone $zone with same interval');
        } else if (!prefs.repeatRemindersEnabled) {
          print('  - Reason: Repeat reminders disabled in preferences');
        } else if (!prefs.enabledZones.contains(zone)) {
          print('  - Reason: Zone $zone not in enabledZones list');
        }
      }
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
    
    // Stop notification service
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.stopNotification();
    
    // Cancel heart rate subscription (stop listening to data)
    // This stops receiving heart rate updates, but BLE connection stays active
    _heartRateSubscription?.cancel();
    _heartRateSubscription = null;
    
    // Cancel auto-pause timer
    _autoPauseTimer?.cancel();
    
    // Cancel heart rate timeout timer
    _heartRateTimeoutTimer?.cancel();
    _heartRateTimeoutTimer = null;
    
    // ============================================
    // TEMPORARY: Screenshot Mode - Cancel mock timer
    _screenshotMockTimer?.cancel();
    _screenshotMockTimer = null;
    // ============================================
    
    // Reset heart rate tracking
    _lastHeartRateTime = null;
    
    // Stop repeat reminders
    ref.read(alertServiceProvider).stopRepeatReminders();
    _currentRepeatReminderZone = null;
    _currentRepeatReminderInterval = null;

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
    
    // If disabling alerts, stop any active repeat reminders and reset timer
    if (!newState) {
      ref.read(alertServiceProvider).stopRepeatReminders();
      _currentRepeatReminderZone = null;
      _currentRepeatReminderInterval = null;
      // Reset zone entry time so timer starts fresh when alerts are re-enabled
      if (state.currentZone != null) {
        state = state.copyWith(zoneEntryTime: DateTime.now());
      }
    } else {
      // Alerts re-enabled - restart reminders with fresh timer if in a valid zone
      final prefs = ref.read(preferencesNotifierProvider).value;
      if (prefs != null && 
          state.currentZone != null &&
          state.currentZone != 0 &&
          prefs.repeatRemindersEnabled &&
          prefs.enabledZones.contains(state.currentZone)) {
        if (kDebugMode) {
          print('MonitoringProvider: 🔄 Alerts re-enabled - restarting reminders with fresh timer');
        }
        // Reset zone entry time to now so timer starts from 0
        final freshZoneEntryTime = DateTime.now();
        state = state.copyWith(zoneEntryTime: freshZoneEntryTime);
        _currentRepeatReminderZone = null; // Reset to allow restart
        _currentRepeatReminderInterval = null;
        _startRepeatRemindersIfEnabled(state.currentZone!, freshZoneEntryTime);
      }
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
    
    // If disabling alerts, stop any active repeat reminders and reset timer
    if (!enabled) {
      ref.read(alertServiceProvider).stopRepeatReminders();
      _currentRepeatReminderZone = null;
      _currentRepeatReminderInterval = null;
      // Reset zone entry time so timer starts fresh when alerts are re-enabled
      if (state.currentZone != null) {
        state = state.copyWith(zoneEntryTime: DateTime.now());
      }
    } else {
      // Alerts re-enabled - restart reminders with fresh timer if in a valid zone
      final prefs = ref.read(preferencesNotifierProvider).value;
      if (prefs != null && 
          state.currentZone != null &&
          state.currentZone != 0 &&
          prefs.repeatRemindersEnabled &&
          prefs.enabledZones.contains(state.currentZone)) {
        if (kDebugMode) {
          print('MonitoringProvider: 🔄 Alerts re-enabled - restarting reminders with fresh timer');
        }
        // Reset zone entry time to now so timer starts from 0
        final freshZoneEntryTime = DateTime.now();
        state = state.copyWith(zoneEntryTime: freshZoneEntryTime);
        _currentRepeatReminderZone = null; // Reset to allow restart
        _currentRepeatReminderInterval = null;
        _startRepeatRemindersIfEnabled(state.currentZone!, freshZoneEntryTime);
      }
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
