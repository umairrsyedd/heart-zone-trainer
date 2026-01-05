import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/utils/hr_zone_calculator.dart';
import '../data/models/zone_boundary.dart';
import 'monitoring_provider.dart';
import 'preferences_provider.dart';

part 'zone_provider.g.dart';

/// Provider for calculated zone boundaries
/// Returns custom zones if enabled, otherwise calculates zones from HR settings
@riverpod
List<ZoneBoundary> zones(ZonesRef ref) {
  final prefs = ref.watch(preferencesNotifierProvider).value;
  if (prefs == null) return [];

  if (prefs.manualZonesEnabled && prefs.customZones != null) {
    return prefs.customZones!;
  }

  return HRZoneCalculator.calculateZones(
    restingHR: prefs.restingHR,
    maxHR: prefs.maxHR,
  );
}

/// Provider for current heart rate zone based on current BPM
/// Returns null if no BPM data or zones are available
@riverpod
int? currentZone(CurrentZoneRef ref) {
  final bpm = ref.watch(currentBPMProvider);
  final zones = ref.watch(zonesProvider);

  if (bpm == null || zones.isEmpty) return null;

  return HRZoneCalculator.getZoneForBPM(bpm, zones);
}
