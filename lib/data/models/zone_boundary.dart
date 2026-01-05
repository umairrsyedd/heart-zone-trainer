import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'zone_boundary.freezed.dart';
part 'zone_boundary.g.dart';

/// Zone boundary model representing the BPM range for a heart rate zone
@freezed
class ZoneBoundary with _$ZoneBoundary {
  const factory ZoneBoundary({
    required int zone, // 0-5
    required int minBPM,
    required int maxBPM,
  }) = _ZoneBoundary;

  factory ZoneBoundary.fromJson(Map<String, dynamic> json) =>
      _$ZoneBoundaryFromJson(json);
}

/// Zone metadata enum with zone information
enum ZoneInfo {
  zone0(0, 'Rest', 'Below training threshold', 0xFF4A90A4),
  zone1(1, 'Warm Up', 'Light activity, recovery', 0xFF6B7280),
  zone2(2, 'Fat Burn', 'Aerobic base building', 0xFF3B5998),
  zone3(3, 'Cardio', 'Aerobic endurance', 0xFF2D6A4F),
  zone4(4, 'Hard', 'Anaerobic threshold', 0xFF92400E),
  zone5(5, 'Max', 'Maximum effort', 0xFFDC2626);

  final int number;
  final String name;
  final String description;
  final int colorValue;

  const ZoneInfo(this.number, this.name, this.description, this.colorValue);

  Color get color => Color(colorValue);
}
