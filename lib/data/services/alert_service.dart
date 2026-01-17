import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import '../models/user_preferences.dart';
import '../models/zone_boundary.dart';

/// Alert service for zone change notifications
/// Handles vibration and voice alerts with cooldown management
class AlertService {
  final FlutterTts _tts = FlutterTts();

  DateTime? _lastAlertTime;
  Timer? _repeatTimer;
  bool _ttsInitialized = false;
  
  // Cooldown state tracking
  bool _isInCooldown = false;
  Timer? _cooldownTimer;
  int? _lastAnnouncedZone;
  int? _pendingZone; // Track the most recent zone during cooldown
  String? _pendingZoneName;
  DateTime? _cooldownStartTime;

  AlertService() {
    _initTTS();
  }

  /// Initialize text-to-speech settings
  Future<void> _initTTS() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ttsInitialized = true;
      if (kDebugMode) {
        print('AlertService: ✅ TTS initialized successfully');
      }
    } catch (e) {
      _ttsInitialized = false;
      if (kDebugMode) {
        print('AlertService: ⚠️ TTS initialization failed: $e');
      }
    }
  }

  /// Trigger zone change alert
  /// Respects cooldown period to prevent alert spam
  /// Executes alerts based on the provided alert types
  /// [isFirstTime] indicates if this is the first zone detection (app just opened)
  /// vs an actual zone change (user transitioned from one zone to another)
  /// [cooldownEnabled] determines if cooldown logic should be applied
  /// [zoneName] is the name of the zone (e.g., "Cardio", "Threshold")
  Future<void> triggerZoneChangeAlert({
    required int newZone,
    required List<AlertType> alertTypes,
    required bool cooldownEnabled,
    required int cooldownSeconds,
    String? zoneName,
    bool isFirstTime = false,
  }) async {
    if (kDebugMode) {
      print('AlertService: 🔔 triggerZoneChangeAlert called - Zone: $newZone, Types: $alertTypes, CooldownEnabled: $cooldownEnabled');
    }

    // If cooldown is disabled, always announce immediately
    if (!cooldownEnabled) {
      await _announceZoneChange(newZone, zoneName ?? 'Zone $newZone', alertTypes, isFirstTime);
      _lastAnnouncedZone = newZone;
      _lastAlertTime = DateTime.now();
      return;
    }

    // Cooldown is enabled
    if (_isInCooldown) {
      // We're in cooldown - suppress this alert but track the zone
      _pendingZone = newZone;
      _pendingZoneName = zoneName ?? 'Zone $newZone';
      
      if (kDebugMode) {
        print('AlertService: 🔇 Zone change to $newZone suppressed (cooldown active). Pending zone updated.');
      }
      return;
    }

    // Not in cooldown - announce and start cooldown
    await _announceZoneChange(newZone, zoneName ?? 'Zone $newZone', alertTypes, isFirstTime);
    _lastAnnouncedZone = newZone;
    _lastAlertTime = DateTime.now();
    
    // Start cooldown
    _startCooldown(
      cooldownSeconds: cooldownSeconds,
      alertTypes: alertTypes,
    );
  }
  
  /// Start the cooldown timer
  void _startCooldown({
    required int cooldownSeconds,
    required List<AlertType> alertTypes,
  }) {
    _isInCooldown = true;
    _cooldownStartTime = DateTime.now();
    _pendingZone = null;
    _pendingZoneName = null;
    
    // Cancel any existing timer
    _cooldownTimer?.cancel();
    
    _cooldownTimer = Timer(Duration(seconds: cooldownSeconds), () async {
      // Cooldown ended
      _isInCooldown = false;
      _cooldownStartTime = null;
      
      if (kDebugMode) {
        print('AlertService: ⏰ Cooldown ended. Pending zone: $_pendingZone, Last announced: $_lastAnnouncedZone');
      }
      
      // Check if we need to announce "Currently in Zone X"
      if (_pendingZone != null && _pendingZone != _lastAnnouncedZone) {
        // User ended up in a different zone than last announced
        await _announceCurrentZone(_pendingZone!, _pendingZoneName ?? 'Zone $_pendingZone', alertTypes);
        _lastAnnouncedZone = _pendingZone;
        _lastAlertTime = DateTime.now();
      }
      
      // Clear pending zone
      _pendingZone = null;
      _pendingZoneName = null;
    });
    
    if (kDebugMode) {
      print('AlertService: ⏱️ Cooldown started (${cooldownSeconds}s)');
    }
  }
  
  /// Announce zone change (existing method, refactored)
  Future<void> _announceZoneChange(
    int zone,
    String zoneName,
    List<AlertType> alertTypes,
    bool isFirstTime,
  ) async {
    for (final type in alertTypes) {
      switch (type) {
        case AlertType.vibration:
          await _vibrate();
          break;
        case AlertType.voice:
          await _announceZone(zone, isEntry: !isFirstTime);
          break;
      }
    }
    
    if (kDebugMode) {
      print('AlertService: 🔔 Announced zone change: Zone $zone - $zoneName');
    }
  }
  
  /// Announce current zone after cooldown (NEW)
  Future<void> _announceCurrentZone(
    int zone,
    String zoneName,
    List<AlertType> alertTypes,
  ) async {
    for (final type in alertTypes) {
      switch (type) {
        case AlertType.voice:
          // Different announcement for "currently in" vs zone change
          await _announceVoice('Currently in Zone $zone');
          break;
        case AlertType.vibration:
          // Shorter/different vibration pattern for "current zone" announcement
          await _vibrate(pattern: [0, 100, 50, 100]); // Double short buzz
          break;
      }
    }
    
    if (kDebugMode) {
      print('AlertService: 📍 Announced current zone after cooldown: Zone $zone - $zoneName');
    }
  }
  
  /// Announce voice message (helper method)
  Future<void> _announceVoice(String message) async {
    try {
      // Ensure TTS is initialized
      if (!_ttsInitialized) {
        if (kDebugMode) {
          print('AlertService: ⚠️ TTS not initialized, initializing now...');
        }
        await _initTTS();
      }
      
      if (!_ttsInitialized) {
        if (kDebugMode) {
          print('AlertService: ❌ TTS initialization failed, cannot speak');
        }
        return;
      }
      
      if (kDebugMode) {
        print('AlertService: 🗣️ Speaking: "$message"');
      }
      
      // Stop any ongoing speech first
      await _tts.stop();
      
      // Wait a brief moment to ensure stop completes
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Speak the message
      final result = await _tts.speak(message);
      
      if (kDebugMode) {
        if (result == 1) {
          print('AlertService: ✅ Voice announcement started successfully');
        } else {
          print('AlertService: ⚠️ TTS speak returned: $result (1 = success)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlertService: ❌ Voice announcement failed: $e');
      }
    }
  }
  
  /// Cancel cooldown (call when monitoring stops or alerts disabled)
  void cancelCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _isInCooldown = false;
    _pendingZone = null;
    _pendingZoneName = null;
    _cooldownStartTime = null;
    
    if (kDebugMode) {
      print('AlertService: 🛑 Cooldown cancelled');
    }
  }
  
  /// Reset cooldown state (call when device disconnects)
  void resetCooldownState() {
    cancelCooldown();
    _lastAnnouncedZone = null;
    _lastAlertTime = null;
    
    if (kDebugMode) {
      print('AlertService: 🔄 Cooldown state reset');
    }
  }
  
  /// Check if currently in cooldown
  bool get isInCooldown => _isInCooldown;

  /// Start repeat reminders
  /// Sends periodic alerts while in a zone
  /// Stops any existing repeat reminders before starting new ones
  void startRepeatReminders({
    required int intervalSeconds,
    required int currentZone,
    required DateTime zoneEntryTime,
    required List<AlertType> alertTypes,
  }) {
    if (kDebugMode) {
      print('AlertService: 🔔 startRepeatReminders called');
      print('  - Zone: $currentZone');
      print('  - Interval: $intervalSeconds seconds');
      print('  - Alert types: $alertTypes');
    }
    
    // Stop any existing timer first
    stopRepeatReminders();
    
    // Validate interval
    if (intervalSeconds <= 0) {
      if (kDebugMode) {
        print('AlertService: ❌ Invalid interval: $intervalSeconds');
      }
      return;
    }
    
    _repeatTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) async {
        final timeInZone = DateTime.now().difference(zoneEntryTime).inSeconds;
        
        if (kDebugMode) {
          print('AlertService: ⏰ Repeat reminder firing - Zone $currentZone, Time in zone: ${timeInZone}s');
        }
        
        // Execute all enabled alert types for repeat reminders
        for (final type in alertTypes) {
          switch (type) {
            case AlertType.voice:
              await _announceZoneReminder(currentZone, timeInZone);
              break;
            case AlertType.vibration:
              await _vibrate(pattern: [0, 100, 100, 100]); // Short double vibration
              break;
          }
        }
      },
    );
    
    if (kDebugMode) {
      print('AlertService: ✅ Timer created - _repeatTimer is ${_repeatTimer != null ? "NOT NULL" : "NULL"}');
    }
  }

  /// Stop repeat reminders
  /// Cancels the periodic reminder timer
  void stopRepeatReminders() {
    if (kDebugMode) {
      print('AlertService: 🛑 stopRepeatReminders called - Timer was ${_repeatTimer != null ? "running" : "not running"}');
    }
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }
  
  /// Check if repeat reminders are currently active
  bool get isRepeatReminderActive => _repeatTimer != null;

  /// Trigger haptic feedback
  /// Supports both single vibration and pattern-based vibration
  /// Checks if device has vibrator before attempting
  Future<void> _vibrate({List<int>? pattern}) async {
    if (await Vibration.hasVibrator() ?? false) {
      if (pattern != null) {
        await Vibration.vibrate(pattern: pattern);
      } else {
        await Vibration.vibrate(duration: 500);
      }
    }
  }

  /// Announce zone using text-to-speech
  /// Provides zone entry announcements
  Future<void> _announceZone(int zone, {required bool isEntry, String? zoneName}) async {
    try {
      // Ensure TTS is initialized
      if (!_ttsInitialized) {
        if (kDebugMode) {
          print('AlertService: ⚠️ TTS not initialized, initializing now...');
        }
        await _initTTS();
      }
      
      if (!_ttsInitialized) {
        if (kDebugMode) {
          print('AlertService: ❌ TTS initialization failed, cannot speak');
        }
        return;
      }
      
      // Build message - only zone number, no zone name
      final message = isEntry
          ? 'Entering Zone $zone'
          : 'Currently in Zone $zone';
      
      if (kDebugMode) {
        print('AlertService: 🗣️ Speaking: "$message"');
      }
      
      // Stop any ongoing speech first
      await _tts.stop();
      
      // Wait a brief moment to ensure stop completes
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Speak the message
      final result = await _tts.speak(message);
      
      if (kDebugMode) {
        if (result == 1) {
          print('AlertService: ✅ Voice announcement started successfully');
        } else {
          print('AlertService: ⚠️ TTS speak returned: $result (1 = success)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlertService: ❌ Voice announcement failed: $e');
        print('AlertService: ⚠️ Troubleshooting:');
        print('AlertService:   1. Check device has TTS engine installed');
        print('AlertService:   2. Check app has audio/notification permissions');
        print('AlertService:   3. Check device volume is not muted');
        print('AlertService:   4. Try enabling TTS in device settings');
      }
    }
  }

  /// Announce zone reminder with time spent in zone
  /// Used for periodic reminders while in a zone
  Future<void> _announceZoneReminder(int zone, int seconds) async {
    try {
      // Ensure TTS is initialized
      if (!_ttsInitialized) {
        if (kDebugMode) {
          print('AlertService: ⚠️ TTS not initialized, initializing now...');
        }
        await _initTTS();
      }
      
      if (!_ttsInitialized) {
        if (kDebugMode) {
          print('AlertService: ❌ TTS initialization failed, cannot speak');
        }
        return;
      }
      
      // Format message based on duration
      // Up to 60 seconds: "Zone X for X seconds"
      // After 60 seconds: "Zone X for X minutes and Y seconds"
      String message;
      if (seconds <= 60) {
        message = 'Zone $zone for $seconds seconds';
      } else {
        final minutes = seconds ~/ 60;
        final remainingSeconds = seconds % 60;
        
        if (remainingSeconds == 0) {
          // Exactly on minute boundary (e.g., 60, 120, 180)
          message = 'Zone $zone for $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
        } else {
          // Has both minutes and seconds
          final minutesText = minutes == 1 ? 'minute' : 'minutes';
          final secondsText = remainingSeconds == 1 ? 'second' : 'seconds';
          message = 'Zone $zone for $minutes $minutesText and $remainingSeconds $secondsText';
        }
      }
      
      if (kDebugMode) {
        print('AlertService: 🗣️ Repeat reminder: "$message"');
      }
      
      // Stop any ongoing speech first
      await _tts.stop();
      
      // Wait a brief moment to ensure stop completes
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Speak the message
      final result = await _tts.speak(message);
      
      if (kDebugMode) {
        if (result == 1) {
          print('AlertService: ✅ Repeat reminder announcement started successfully');
        } else {
          print('AlertService: ⚠️ TTS speak returned: $result (1 = success)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AlertService: ❌ Repeat reminder announcement failed: $e');
      }
    }
  }

  /// Clean up resources
  /// Call this when the service is no longer needed
  void dispose() {
    _repeatTimer?.cancel();
    _cooldownTimer?.cancel();
    _tts.stop();
  }
}
