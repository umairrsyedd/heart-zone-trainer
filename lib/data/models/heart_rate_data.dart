import 'package:freezed_annotation/freezed_annotation.dart';

part 'heart_rate_data.freezed.dart';

/// Heart rate measurement data model
/// Represents a single heart rate reading from the BLE device
@freezed
class HeartRateData with _$HeartRateData {
  const factory HeartRateData({
    required int bpm,
    required DateTime timestamp,
    int? rrInterval, // Optional RR interval data
  }) = _HeartRateData;
}
