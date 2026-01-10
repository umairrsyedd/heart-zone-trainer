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
  Future<void> triggerZoneChangeAlert({
    required int newZone,
    required List<AlertType> alertTypes,
    required int cooldownSeconds,
    bool isFirstTime = false,
  }) async {
    if (kDebugMode) {
      print('AlertService: 🔔 triggerZoneChangeAlert called - Zone: $newZone, Types: $alertTypes');
    }

    // Check cooldown
    if (_lastAlertTime != null) {
      final elapsed = DateTime.now().difference(_lastAlertTime!);
      if (elapsed.inSeconds < cooldownSeconds) {
        if (kDebugMode) {
          print('AlertService: ⏸️ Still in cooldown (${elapsed.inSeconds}s < ${cooldownSeconds}s)');
        }
        return; // Still in cooldown
      }
    }

    _lastAlertTime = DateTime.now();

    // Execute alerts based on type
    for (final type in alertTypes) {
      if (kDebugMode) {
        print('AlertService: Executing alert type: $type');
      }
      switch (type) {
        case AlertType.vibration:
          await _vibrate();
          break;
        case AlertType.voice:
          await _announceZone(newZone, isEntry: !isFirstTime);
          break;
      }
    }
  }

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
  Future<void> _announceZone(int zone, {required bool isEntry}) async {
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
    _tts.stop();
  }
}
