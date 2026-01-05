import '../../data/models/zone_boundary.dart';

/// Heart Rate Zone Calculator using Karvonen (Heart Rate Reserve) formula
/// Calculates zone boundaries based on resting and maximum heart rate
class HRZoneCalculator {
  HRZoneCalculator._(); // Private constructor to prevent instantiation

  /// Calculate zones using Karvonen (Heart Rate Reserve) formula
  /// Zone boundaries as percentages of HRR
  static const Map<int, (double, double)> zonePercentages = {
    5: (0.90, 1.00), // Zone 5: 90-100%
    4: (0.80, 0.89), // Zone 4: 80-89%
    3: (0.70, 0.79), // Zone 3: 70-79%
    2: (0.60, 0.69), // Zone 2: 60-69%
    1: (0.50, 0.59), // Zone 1: 50-59%
    0: (0.00, 0.49), // Zone 0: 0-49%
  };

  /// Calculate all zone boundaries from resting and max HR
  /// Returns a list of ZoneBoundary objects sorted by zone (descending: 5 to 0)
  static List<ZoneBoundary> calculateZones({
    required int restingHR,
    required int maxHR,
  }) {
    final hrr = maxHR - restingHR; // Heart Rate Reserve

    return zonePercentages.entries.map((entry) {
      final zone = entry.key;
      final (lowerPct, upperPct) = entry.value;

      final minBPM = (restingHR + (hrr * lowerPct)).round();
      final maxBPM = (restingHR + (hrr * upperPct)).round();

      return ZoneBoundary(
        zone: zone,
        minBPM: minBPM,
        maxBPM: maxBPM,
      );
    }).toList()
      ..sort((a, b) => b.zone.compareTo(a.zone)); // Sort descending
  }

  /// Determine which zone a given BPM falls into
  /// Checks zones from highest to lowest and returns the first match
  /// Returns 0 if BPM is below all zone thresholds
  static int getZoneForBPM(int bpm, List<ZoneBoundary> zones) {
    // Create a sorted copy to avoid modifying the original list
    final sortedZones = List<ZoneBoundary>.from(zones)
      ..sort((a, b) => b.zone.compareTo(a.zone));

    // Check from highest zone to lowest
    for (final zone in sortedZones) {
      if (bpm >= zone.minBPM) {
        return zone.zone;
      }
    }
    return 0; // Default to zone 0 if below all thresholds
  }

  /// Calculate max HR from age using standard formula: 220 - age
  static int estimateMaxHRFromAge(int age) {
    if (age <= 0) {
      throw ArgumentError('Age must be greater than 0');
    }
    return 220 - age;
  }

  /// Get the percentage position within the full HR range (for slider)
  /// Returns a value between 0.0 and 1.0 representing the position
  /// 0.0 = at resting HR, 1.0 = at max HR
  static double getPositionInRange({
    required int bpm,
    required int restingHR,
    required int maxHR,
  }) {
    if (restingHR >= maxHR) {
      throw ArgumentError('Resting HR must be less than max HR');
    }

    if (bpm <= restingHR) return 0.0;
    if (bpm >= maxHR) return 1.0;
    return (bpm - restingHR) / (maxHR - restingHR);
  }
}
