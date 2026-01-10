# Repeat Zone Reminders - Implementation Documentation

## Overview

This document provides a comprehensive explanation of how the **Repeat Zone Reminders** functionality is implemented in the Heart Zone Trainer app. This feature allows users to receive periodic alerts (sound, vibration, voice) while staying in the same heart rate zone.

## User Experience Flow

### 1. User Enables Repeat Reminders

**Location:** `lib/features/alert_management/alert_management_screen.dart`

1. User navigates to **Alert Management** screen
2. User toggles **"Repeat Reminders"** switch to `ON`
3. User adjusts **"Repeat Interval"** slider (default: 30 seconds, but should be 60 seconds)
4. Settings are **auto-saved** to `SharedPreferences` via `_autoSave()` method

**Key Code:**
```dart
// Line 311-319: Repeat Reminders Toggle
Switch(
  value: _repeatRemindersEnabled,
  onChanged: _alertsEnabled ? (value) {
    setState(() {
      _repeatRemindersEnabled = value;
    });
    _autoSave(); // Persists to SharedPreferences
  } : null,
)
```

**Default Values (from `user_preferences.dart`):**
- `repeatRemindersEnabled`: `false` (disabled by default)
- `repeatIntervalSeconds`: `30` (should be changed to `60`)

---

## Data Model

### UserPreferences Model

**Location:** `lib/data/models/user_preferences.dart`

```dart
@freezed
class UserPreferences {
  @Default(false) bool repeatRemindersEnabled,  // Master toggle
  @Default(30) int repeatIntervalSeconds,        // Interval in seconds
  @Default([0, 1, 2, 3, 4, 5]) List<int> enabledZones,  // Zones that have alerts
  @Default([AlertType.vibration, AlertType.voice]) List<AlertType> alertTypes,  // Alert types
}
```

**Storage:** Persisted to `SharedPreferences` as JSON via `PreferencesRepository`

---

## Core Implementation Logic

### Flow Diagram

```
User enters Zone 1
    ↓
_handleHeartRateUpdate() called
    ↓
Zone calculated: Zone 1
    ↓
Is this a zone change? (previousZone != currentZone)
    ↓ YES
_handleZoneChange() called
    ↓
Check: alertsEnabled && zone in enabledZones
    ↓ YES
Trigger zone change alert (one-time)
    ↓
_startRepeatRemindersIfEnabled() called
    ↓
Check: repeatRemindersEnabled && zone in enabledZones && not already running
    ↓ YES
AlertService.startRepeatReminders() called
    ↓
Timer.periodic() starts (every 30/60 seconds)
    ↓
Every interval: Calculate timeInZone → Trigger alerts
```

---

## Implementation Details

### 1. Monitoring Provider - Heart Rate Update Handler

**Location:** `lib/providers/monitoring_provider.dart`

**Method:** `_handleHeartRateUpdate(int bpm)`

**Purpose:** Called every time a new heart rate value is received from the BLE device.

**Key Logic:**

```dart
void _handleHeartRateUpdate(int bpm) {
  // ... filter out 0 BPM ...
  
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
}
```

**Critical Points:**
- ✅ Zone change detection: `previousZone != newZone`
- ✅ Zone entry time tracking: `zoneEntryTime` is set when entering a zone
- ✅ First-time zone entry: If `previousZone == null`, start reminders
- ⚠️ **POTENTIAL ISSUE:** If staying in the same zone, repeat reminders should continue, but the code comment says "Don't restart them" - this is correct, but we need to verify the timer is actually running

---

### 2. Monitoring Provider - Zone Change Handler

**Location:** `lib/providers/monitoring_provider.dart`

**Method:** `_handleZoneChange(int fromZone, int toZone, DateTime zoneEntryTime)`

**Purpose:** Handles zone transitions and triggers one-time alerts + starts repeat reminders.

**Key Logic:**

```dart
void _handleZoneChange(int fromZone, int toZone, DateTime zoneEntryTime) {
  // Double-check alerts are enabled
  if (!state.alertsEnabled) {
    return;
  }
  
  final prefs = ref.read(preferencesNotifierProvider).value;
  if (prefs == null) return;
  
  final alertService = ref.read(alertServiceProvider);
  
  // Check if this zone has alerts enabled
  if (prefs.enabledZones.contains(toZone)) {
    // Trigger one-time zone change alert
    alertService.triggerZoneChangeAlert(
      newZone: toZone,
      alertTypes: prefs.alertTypes,
      cooldownSeconds: prefs.alertCooldownSeconds,
    );
    
    // Start repeat reminders if enabled
    _currentRepeatReminderZone = null; // Reset so we can start new ones
    _startRepeatRemindersIfEnabled(toZone, zoneEntryTime);
  } else {
    // Zone changed but alerts not enabled for this zone - stop reminders
    alertService.stopRepeatReminders();
    _currentRepeatReminderZone = null;
  }
}
```

**Critical Points:**
- ✅ Resets `_currentRepeatReminderZone = null` before starting new reminders
- ✅ Only starts if zone is in `enabledZones` list
- ✅ Stops reminders if zone doesn't have alerts enabled

---

### 3. Monitoring Provider - Start Repeat Reminders

**Location:** `lib/providers/monitoring_provider.dart`

**Method:** `_startRepeatRemindersIfEnabled(int zone, DateTime zoneEntryTime)`

**Purpose:** Checks conditions and starts the repeat reminder timer if all conditions are met.

**Key Logic:**

```dart
void _startRepeatRemindersIfEnabled(int zone, DateTime zoneEntryTime) {
  final prefs = ref.read(preferencesNotifierProvider).value;
  if (prefs == null) return;
  
  // Only start if:
  // 1. Repeat reminders are enabled in preferences
  // 2. This zone has alerts enabled
  // 3. We're not already running reminders for this zone
  if (prefs.repeatRemindersEnabled && 
      prefs.enabledZones.contains(zone) &&
      _currentRepeatReminderZone != zone) {
    
    final alertService = ref.read(alertServiceProvider);
    
    alertService.startRepeatReminders(
      intervalSeconds: prefs.repeatIntervalSeconds,
      currentZone: zone,
      zoneEntryTime: zoneEntryTime,
      alertTypes: prefs.alertTypes,
    );
    
    _currentRepeatReminderZone = zone; // Track which zone has active reminders
  } else if (kDebugMode && _currentRepeatReminderZone == zone) {
    print('MonitoringProvider: ⏸️ Repeat reminders already running for Zone $zone, skipping restart');
  }
}
```

**Critical Points:**
- ✅ **Prevents duplicate timers:** Checks `_currentRepeatReminderZone != zone` before starting
- ✅ **Tracks active zone:** Sets `_currentRepeatReminderZone = zone` after starting
- ⚠️ **POTENTIAL ISSUE:** If `prefs.repeatRemindersEnabled` is `false`, reminders won't start even if user enabled them (but this should be correct behavior)

---

### 4. Alert Service - Start Repeat Reminders

**Location:** `lib/data/services/alert_service.dart`

**Method:** `startRepeatReminders({...})`

**Purpose:** Creates a periodic timer that triggers alerts at the specified interval.

**Key Logic:**

```dart
void startRepeatReminders({
  required int intervalSeconds,
  required int currentZone,
  required DateTime zoneEntryTime,
  required List<AlertType> alertTypes,
}) {
  stopRepeatReminders(); // Stop any existing timer first
  
  _repeatTimer = Timer.periodic(
    Duration(seconds: intervalSeconds),
    (_) async {
      final timeInZone = DateTime.now().difference(zoneEntryTime).inSeconds;
      
      // Execute all enabled alert types
      for (final type in alertTypes) {
        switch (type) {
          case AlertType.voice:
            await _announceZoneReminder(currentZone, timeInZone);
            break;
          case AlertType.vibration:
            await _vibrate(pattern: [0, 100, 100, 100]);
            break;
          case AlertType.sound:
            await _playSound();
            break;
        }
      }
    },
  );
}
```

**Critical Points:**
- ✅ **Stops existing timer:** Calls `stopRepeatReminders()` before creating new timer
- ✅ **Periodic execution:** Uses `Timer.periodic()` to fire every `intervalSeconds`
- ✅ **Calculates time in zone:** `timeInZone = DateTime.now().difference(zoneEntryTime).inSeconds`
- ✅ **Executes all alert types:** Loops through `alertTypes` and triggers each one
- ⚠️ **POTENTIAL ISSUE:** The `zoneEntryTime` is passed once when the timer starts. If the user stays in the zone for a long time, `timeInZone` will keep increasing (e.g., 30s, 60s, 90s, 120s...). This is correct behavior, but the announcement will say "Zone 1 for 120 seconds" which might be confusing.

---

### 5. Alert Service - Stop Repeat Reminders

**Location:** `lib/data/services/alert_service.dart`

**Method:** `stopRepeatReminders()`

**Purpose:** Cancels the periodic timer.

**Key Logic:**

```dart
void stopRepeatReminders() {
  _repeatTimer?.cancel();
  _repeatTimer = null;
}
```

**Called When:**
- User changes zones (old zone reminders stopped, new zone reminders started)
- User disables alerts (`setAlertsEnabled(false)`)
- User stops monitoring (`stopMonitoring()`)
- Zone doesn't have alerts enabled

---

## State Tracking

### Monitoring Provider State Variables

**Location:** `lib/providers/monitoring_provider.dart`

```dart
int? _currentRepeatReminderZone; // Tracks which zone has active repeat reminders
```

**Purpose:** Prevents starting duplicate timers for the same zone.

**Updated When:**
- ✅ Set to `zone` when reminders start: `_currentRepeatReminderZone = zone`
- ✅ Set to `null` when reminders stop: `_currentRepeatReminderZone = null`
- ✅ Set to `null` before starting new reminders (in `_handleZoneChange`)

---

## Alert Service State Variables

**Location:** `lib/data/services/alert_service.dart`

```dart
Timer? _repeatTimer; // The periodic timer instance
```

**Purpose:** Holds the active timer so it can be canceled.

**Lifecycle:**
- Created: `_repeatTimer = Timer.periodic(...)`
- Canceled: `_repeatTimer?.cancel(); _repeatTimer = null`

---

## Potential Issues & Debugging

### Issue 1: Repeat Reminders Not Starting

**Symptoms:**
- User enables repeat reminders
- User enters a zone
- No periodic alerts are received

**Possible Causes:**

1. **`repeatRemindersEnabled` is `false` in preferences**
   - Check: `prefs.repeatRemindersEnabled` in `_startRepeatRemindersIfEnabled()`
   - Debug: Add log: `print('Repeat reminders enabled? ${prefs.repeatRemindersEnabled}')`

2. **Zone not in `enabledZones` list**
   - Check: `prefs.enabledZones.contains(zone)`
   - Debug: Add log: `print('Zone $zone in enabledZones? ${prefs.enabledZones.contains(zone)}')`

3. **`_currentRepeatReminderZone` already set to this zone**
   - Check: `_currentRepeatReminderZone != zone` condition
   - Debug: Add log: `print('Current reminder zone: $_currentRepeatReminderZone, new zone: $zone')`

4. **`alertsEnabled` is `false` in monitoring state**
   - Check: `state.alertsEnabled` in `_handleHeartRateUpdate()`
   - Debug: Add log: `print('Alerts enabled? ${state.alertsEnabled}')`

5. **Timer not actually starting**
   - Check: `AlertService.startRepeatReminders()` is being called
   - Debug: Add log in `startRepeatReminders()`: `print('Timer started with interval: $intervalSeconds')`

---

### Issue 2: Repeat Reminders Stop Unexpectedly

**Symptoms:**
- Reminders start correctly
- After a few alerts, they stop

**Possible Causes:**

1. **Timer being canceled by another code path**
   - Check: All calls to `stopRepeatReminders()`
   - Debug: Add log in `stopRepeatReminders()`: `print('Stopping repeat reminders - called from: ${StackTrace.current}')`

2. **Zone change detection triggering stop**
   - Check: `_handleZoneChange()` might be called even when staying in same zone
   - Debug: Add log: `print('Zone change detected: $fromZone → $toZone')`

3. **AlertService being disposed/recreated**
   - Check: `alertServiceProvider` is `keepAlive: true` (it is)
   - Debug: Check if provider is being recreated

---

### Issue 3: Repeat Reminders Restart on Every Heart Rate Update

**Symptoms:**
- Timer restarts every time heart rate updates (even in same zone)
- Alerts fire more frequently than expected

**Possible Causes:**

1. **`_currentRepeatReminderZone` not being set correctly**
   - Check: `_currentRepeatReminderZone = zone` after starting
   - Debug: Add log: `print('Setting _currentRepeatReminderZone to $zone')`

2. **`_startRepeatRemindersIfEnabled()` called on every HR update**
   - Check: Logic in `_handleHeartRateUpdate()` - should only call on zone change
   - Debug: Add log: `print('isZoneChange: $isZoneChange, previousZone: $previousZone, newZone: $newZone')`

---

### Issue 4: Default Interval is 30 Seconds (Should be 60)

**Location:** `lib/data/models/user_preferences.dart`

**Current:**
```dart
@Default(30) int repeatIntervalSeconds,
```

**Should be:**
```dart
@Default(60) int repeatIntervalSeconds,
```

**Also update in `alert_management_screen.dart`:**
```dart
int _repeatIntervalSeconds = 30; // Should be 60
```

---

## Code Flow Summary

### When User Enters Zone 1 (First Time)

1. `_handleHeartRateUpdate(160)` called
2. Zone calculated: `newZone = 1`, `previousZone = null`
3. `isZoneChange = false` (no previous zone)
4. `previousZone == null && newZone != null` → **TRUE**
5. `_startRepeatRemindersIfEnabled(1, zoneEntryTime)` called
6. Check: `repeatRemindersEnabled && enabledZones.contains(1) && _currentRepeatReminderZone != 1`
7. If all true → `AlertService.startRepeatReminders()` called
8. Timer starts: `Timer.periodic(Duration(seconds: 60), ...)`
9. Every 60 seconds: Calculate `timeInZone`, trigger alerts

### When User Stays in Zone 1 (Subsequent Heart Rate Updates)

1. `_handleHeartRateUpdate(165)` called
2. Zone calculated: `newZone = 1`, `previousZone = 1`
3. `isZoneChange = false` (same zone)
4. Code comment: "Don't restart them on every heart rate update"
5. **Timer continues running** (should not restart)

### When User Changes from Zone 1 to Zone 2

1. `_handleHeartRateUpdate(175)` called
2. Zone calculated: `newZone = 2`, `previousZone = 1`
3. `isZoneChange = true`
4. `_handleZoneChange(1, 2, zoneEntryTime)` called
5. One-time alert triggered for Zone 2
6. `_currentRepeatReminderZone = null` (reset)
7. `_startRepeatRemindersIfEnabled(2, zoneEntryTime)` called
8. Old timer stopped (via `stopRepeatReminders()` in `startRepeatReminders()`)
9. New timer started for Zone 2

---

## Key Files & Line Numbers

| File | Purpose | Key Methods |
|------|---------|-------------|
| `lib/providers/monitoring_provider.dart` | Main logic for starting/stopping reminders | `_handleHeartRateUpdate()`, `_handleZoneChange()`, `_startRepeatRemindersIfEnabled()` |
| `lib/data/services/alert_service.dart` | Timer management and alert execution | `startRepeatReminders()`, `stopRepeatReminders()`, `_announceZoneReminder()` |
| `lib/data/models/user_preferences.dart` | Data model for settings | `repeatRemindersEnabled`, `repeatIntervalSeconds` |
| `lib/features/alert_management/alert_management_screen.dart` | UI for enabling/disabling | Toggle switch, interval slider |

---

## Testing Checklist

- [ ] Enable repeat reminders in Alert Management
- [ ] Set interval to 60 seconds
- [ ] Enter Zone 1
- [ ] Verify one-time alert fires (zone change alert)
- [ ] Wait 60 seconds
- [ ] Verify repeat reminder fires (voice: "Zone 1 for 60 seconds")
- [ ] Wait another 60 seconds
- [ ] Verify second reminder fires (voice: "Zone 1 for 120 seconds")
- [ ] Change to Zone 2
- [ ] Verify old reminders stop, new reminders start for Zone 2
- [ ] Disable repeat reminders toggle
- [ ] Verify reminders stop immediately
- [ ] Re-enable repeat reminders
- [ ] Verify reminders start again

---

## Conclusion

The repeat reminders functionality is implemented with the following architecture:

1. **State Tracking:** `_currentRepeatReminderZone` prevents duplicate timers
2. **Timer Management:** `AlertService` manages the periodic timer
3. **Zone Entry Time:** Tracked to calculate time spent in zone
4. **Conditional Start:** Only starts if all conditions are met (enabled, zone in list, not already running)

**Known Issues:**
- Default interval is 30 seconds (should be 60)
- Need to verify timer is not being restarted on every HR update
- Need to verify timer is not being stopped unexpectedly

**Next Steps for Debugging:**
1. Add comprehensive logging at each step
2. Verify `_currentRepeatReminderZone` is being set/cleared correctly
3. Verify `Timer.periodic()` is actually firing
4. Check if `AlertService` instance is being recreated (shouldn't be, as it's `keepAlive: true`)

