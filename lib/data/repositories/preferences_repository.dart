import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preferences.dart';

/// Repository for managing user preferences in local storage
/// Uses SharedPreferences to persist UserPreferences as JSON
class PreferencesRepository {
  static const String _preferencesKey = 'user_preferences';

  /// Load user preferences from SharedPreferences
  /// Returns default UserPreferences if no saved preferences exist
  Future<UserPreferences> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_preferencesKey);

      if (jsonString == null) {
        // First-time user, return defaults
        return const UserPreferences();
      }

      // Parse JSON and create UserPreferences
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserPreferences.fromJson(json);
    } catch (e) {
      // If parsing fails, return defaults
      return const UserPreferences();
    }
  }

  /// Save user preferences to SharedPreferences
  /// Serializes UserPreferences to JSON and stores it
  Future<void> savePreferences(UserPreferences preferences) async {
    try {
      print('PreferencesRepository: Saving to SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final json = preferences.toJson();
      print('PreferencesRepository: JSON to save - alertTypes: ${json['alertTypes']}, enabledZones: ${json['enabledZones']}');
      final jsonString = jsonEncode(json);
      await prefs.setString(_preferencesKey, jsonString);
      print('PreferencesRepository: ✅ Successfully saved to SharedPreferences');
      
      // Verify it was saved
      final savedString = prefs.getString(_preferencesKey);
      if (savedString != null) {
        final savedJson = jsonDecode(savedString) as Map<String, dynamic>;
        print('PreferencesRepository: Verification - saved alertTypes: ${savedJson['alertTypes']}, enabledZones: ${savedJson['enabledZones']}');
      }
    } catch (e) {
      print('PreferencesRepository: ❌ Failed to save preferences: $e');
      // If saving fails, throw error
      throw Exception('Failed to save preferences: $e');
    }
  }

  /// Clear all saved preferences
  /// Returns preferences to default values
  Future<void> clearPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_preferencesKey);
    } catch (e) {
      throw Exception('Failed to clear preferences: $e');
    }
  }
}
