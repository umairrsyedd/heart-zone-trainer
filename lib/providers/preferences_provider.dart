import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/user_preferences.dart';
import '../data/models/zone_boundary.dart';
import '../data/repositories/preferences_repository.dart';

part 'preferences_provider.g.dart';

/// Provider for PreferencesRepository instance
@riverpod
PreferencesRepository preferencesRepository(PreferencesRepositoryRef ref) {
  return PreferencesRepository();
}

/// Notifier for managing user preferences
/// Loads preferences from local storage and provides methods to update them
@riverpod
class PreferencesNotifier extends _$PreferencesNotifier {
  @override
  Future<UserPreferences> build() async {
    final repo = ref.watch(preferencesRepositoryProvider);
    return await repo.loadPreferences();
  }

  /// Update all preferences
  Future<void> updatePreferences(UserPreferences prefs) async {
    final repo = ref.read(preferencesRepositoryProvider);
    
    print('PreferencesProvider: Saving preferences...');
    print('  - alertsEnabled: ${prefs.alertsEnabled}');
    print('  - alertTypes: ${prefs.alertTypes}');
    print('  - enabledZones: ${prefs.enabledZones}');
    print('  - repeatRemindersEnabled: ${prefs.repeatRemindersEnabled}');
    print('  - repeatIntervalSeconds: ${prefs.repeatIntervalSeconds}');
    print('  - alertCooldownSeconds: ${prefs.alertCooldownSeconds}');
    print('  - restingHR: ${prefs.restingHR}, maxHR: ${prefs.maxHR}');
    
    // Save to SharedPreferences - this persists to disk
    await repo.savePreferences(prefs);
    
    // Update the state immediately so UI reflects changes
    state = AsyncData(prefs);
    
    print('PreferencesProvider: ✅ Preferences saved and state updated');
    
    // Verify it was saved by reloading
    final saved = await repo.loadPreferences();
    print('PreferencesProvider: Verification - loaded alertTypes: ${saved.alertTypes}, enabledZones: ${saved.enabledZones}');
  }

  /// Update zone settings (resting HR, max HR, custom zones)
  Future<void> updateZoneSettings({
    required int restingHR,
    required int maxHR,
    List<ZoneBoundary>? customZones,
    bool? manualZonesEnabled,
  }) async {
    final current = state.value ?? const UserPreferences();
    await updatePreferences(current.copyWith(
      restingHR: restingHR,
      maxHR: maxHR,
      customZones: customZones,
      manualZonesEnabled: manualZonesEnabled ?? current.manualZonesEnabled,
    ));
  }
}
