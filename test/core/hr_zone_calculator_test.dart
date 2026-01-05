import 'package:flutter_test/flutter_test.dart';
import 'package:hr_zone_monitor/core/utils/hr_zone_calculator.dart';
import 'package:hr_zone_monitor/data/models/zone_boundary.dart';

void main() {
  group('HRZoneCalculator', () {
    group('calculateZones', () {
      test('calculates zones correctly with standard values', () {
        final zones = HRZoneCalculator.calculateZones(
          restingHR: 61,
          maxHR: 197,
        );

        expect(zones.length, 6);

        // Zone 5: 90-100% of HRR
        // HRR = 197 - 61 = 136
        // minBPM = 61 + (136 * 0.90) = 61 + 122.4 = 183.4 ≈ 183
        // maxBPM = 61 + (136 * 1.00) = 61 + 136 = 197
        final zone5 = zones.firstWhere((z) => z.zone == 5);
        expect(zone5.minBPM, 183);
        expect(zone5.maxBPM, 197);

        // Zone 4: 80-89% of HRR
        // minBPM = 61 + (136 * 0.80) = 61 + 108.8 = 169.8 ≈ 170
        // maxBPM = 61 + (136 * 0.89) = 61 + 121.04 = 182.04 ≈ 182
        final zone4 = zones.firstWhere((z) => z.zone == 4);
        expect(zone4.minBPM, 170);
        expect(zone4.maxBPM, 182);

        // Zone 3: 70-79% of HRR
        // minBPM = 61 + (136 * 0.70) = 61 + 95.2 = 156.2 ≈ 156
        // maxBPM = 61 + (136 * 0.79) = 61 + 107.44 = 168.44 ≈ 168
        final zone3 = zones.firstWhere((z) => z.zone == 3);
        expect(zone3.minBPM, 156);
        expect(zone3.maxBPM, 168);

        // Zone 2: 60-69% of HRR
        // minBPM = 61 + (136 * 0.60) = 61 + 81.6 = 142.6 ≈ 143
        // maxBPM = 61 + (136 * 0.69) = 61 + 93.84 = 154.84 ≈ 155
        final zone2 = zones.firstWhere((z) => z.zone == 2);
        expect(zone2.minBPM, 143);
        expect(zone2.maxBPM, 155);

        // Zone 1: 50-59% of HRR
        // minBPM = 61 + (136 * 0.50) = 61 + 68 = 129
        // maxBPM = 61 + (136 * 0.59) = 61 + 80.24 = 141.24 ≈ 141
        final zone1 = zones.firstWhere((z) => z.zone == 1);
        expect(zone1.minBPM, 129);
        expect(zone1.maxBPM, 141);

        // Zone 0: 0-49% of HRR
        // minBPM = 61 + (136 * 0.00) = 61
        // maxBPM = 61 + (136 * 0.49) = 61 + 66.64 = 127.64 ≈ 128
        final zone0 = zones.firstWhere((z) => z.zone == 0);
        expect(zone0.minBPM, 61);
        expect(zone0.maxBPM, 128);

        // Verify zones are sorted descending (5 to 0)
        expect(zones[0].zone, 5);
        expect(zones[5].zone, 0);
      });

      test('handles edge case with small HRR', () {
        final zones = HRZoneCalculator.calculateZones(
          restingHR: 60,
          maxHR: 70,
        );

        expect(zones.length, 6);
        // HRR = 10, so zones will be very narrow
        final zone5 = zones.firstWhere((z) => z.zone == 5);
        expect(zone5.minBPM, 69); // 60 + (10 * 0.90) = 69
        expect(zone5.maxBPM, 70); // 60 + (10 * 1.00) = 70
      });

      test('handles edge case with large HRR', () {
        final zones = HRZoneCalculator.calculateZones(
          restingHR: 50,
          maxHR: 200,
        );

        expect(zones.length, 6);
        // HRR = 150
        final zone5 = zones.firstWhere((z) => z.zone == 5);
        expect(zone5.minBPM, 185); // 50 + (150 * 0.90) = 185
        expect(zone5.maxBPM, 200); // 50 + (150 * 1.00) = 200
      });
    });

    group('getZoneForBPM', () {
      test('returns correct zone for given BPM', () {
        final zones = HRZoneCalculator.calculateZones(
          restingHR: 61,
          maxHR: 197,
        );

        expect(HRZoneCalculator.getZoneForBPM(150, zones), 2);
        expect(HRZoneCalculator.getZoneForBPM(175, zones), 4);
        expect(HRZoneCalculator.getZoneForBPM(190, zones), 5);
        expect(HRZoneCalculator.getZoneForBPM(100, zones), 0);
        expect(HRZoneCalculator.getZoneForBPM(140, zones), 1);
        expect(HRZoneCalculator.getZoneForBPM(160, zones), 3);
      });

      test('returns zone 0 for BPM below all thresholds', () {
        final zones = HRZoneCalculator.calculateZones(
          restingHR: 60,
          maxHR: 200,
        );

        expect(HRZoneCalculator.getZoneForBPM(50, zones), 0);
        expect(HRZoneCalculator.getZoneForBPM(59, zones), 0);
      });

      test('returns highest zone for BPM at max HR', () {
        final zones = HRZoneCalculator.calculateZones(
          restingHR: 60,
          maxHR: 200,
        );

        expect(HRZoneCalculator.getZoneForBPM(200, zones), 5);
        expect(HRZoneCalculator.getZoneForBPM(201, zones), 5);
      });

      test('handles boundary values correctly', () {
        final zones = HRZoneCalculator.calculateZones(
          restingHR: 60,
          maxHR: 200,
        );

        // Test at zone boundaries
        final zone5 = zones.firstWhere((z) => z.zone == 5);
        expect(HRZoneCalculator.getZoneForBPM(zone5.minBPM, zones), 5);
        expect(HRZoneCalculator.getZoneForBPM(zone5.maxBPM, zones), 5);

        final zone4 = zones.firstWhere((z) => z.zone == 4);
        expect(HRZoneCalculator.getZoneForBPM(zone4.minBPM, zones), 4);
        expect(HRZoneCalculator.getZoneForBPM(zone4.maxBPM, zones), 4);
      });
    });

    group('estimateMaxHRFromAge', () {
      test('uses 220-age formula', () {
        expect(HRZoneCalculator.estimateMaxHRFromAge(30), 190);
        expect(HRZoneCalculator.estimateMaxHRFromAge(40), 180);
        expect(HRZoneCalculator.estimateMaxHRFromAge(25), 195);
        expect(HRZoneCalculator.estimateMaxHRFromAge(50), 170);
      });

      test('throws ArgumentError for invalid age', () {
        expect(
          () => HRZoneCalculator.estimateMaxHRFromAge(0),
          throwsArgumentError,
        );
        expect(
          () => HRZoneCalculator.estimateMaxHRFromAge(-5),
          throwsArgumentError,
        );
      });
    });

    group('getPositionInRange', () {
      test('returns 0.0 for BPM at or below resting HR', () {
        expect(
          HRZoneCalculator.getPositionInRange(
            bpm: 60,
            restingHR: 60,
            maxHR: 200,
          ),
          0.0,
        );
        expect(
          HRZoneCalculator.getPositionInRange(
            bpm: 50,
            restingHR: 60,
            maxHR: 200,
          ),
          0.0,
        );
      });

      test('returns 1.0 for BPM at or above max HR', () {
        expect(
          HRZoneCalculator.getPositionInRange(
            bpm: 200,
            restingHR: 60,
            maxHR: 200,
          ),
          1.0,
        );
        expect(
          HRZoneCalculator.getPositionInRange(
            bpm: 210,
            restingHR: 60,
            maxHR: 200,
          ),
          1.0,
        );
      });

      test('returns correct position for BPM in range', () {
        // At midpoint: (130 - 60) / (200 - 60) = 70 / 140 = 0.5
        expect(
          HRZoneCalculator.getPositionInRange(
            bpm: 130,
            restingHR: 60,
            maxHR: 200,
          ),
          0.5,
        );

        // At 25%: (95 - 60) / (200 - 60) = 35 / 140 = 0.25
        expect(
          HRZoneCalculator.getPositionInRange(
            bpm: 95,
            restingHR: 60,
            maxHR: 200,
          ),
          0.25,
        );

        // At 75%: (165 - 60) / (200 - 60) = 105 / 140 = 0.75
        expect(
          HRZoneCalculator.getPositionInRange(
            bpm: 165,
            restingHR: 60,
            maxHR: 200,
          ),
          0.75,
        );
      });

      test('throws ArgumentError for invalid HR values', () {
        expect(
          () => HRZoneCalculator.getPositionInRange(
            bpm: 100,
            restingHR: 200,
            maxHR: 100,
          ),
          throwsArgumentError,
        );
      });
    });
  });
}

