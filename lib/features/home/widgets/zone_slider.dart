import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/hr_zone_calculator.dart';
import '../../../../data/models/zone_boundary.dart';
import '../../../../providers/monitoring_provider.dart';
import '../../../../providers/preferences_provider.dart';
import '../../../../providers/zone_provider.dart';

/// Sleek zone slider widget with minimal design
/// Thin 8px bar with dimmed inactive zones and bright active zone
/// Small 12px white indicator with smooth animation
/// Minimal zone number labels (10px)
class ZoneSlider extends ConsumerWidget {
  const ZoneSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitoringState = ref.watch(monitoringNotifierProvider);
    final currentBPM = monitoringState.currentBPM;
    final currentZone = monitoringState.currentZone;
    final zones = ref.watch(zonesProvider);
    final prefsAsync = ref.watch(preferencesNotifierProvider);

    return prefsAsync.when(
      loading: () => const SizedBox(height: 40),
      error: (_, __) => const SizedBox(height: 40),
      data: (prefs) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zone Bar with Indicator
              SizedBox(
                height: 24, // Total height including indicator overflow
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    final segmentWidth = (totalWidth - (5 * 2)) / 6; // 6 segments, 5 gaps of 2px
                    
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Zone Segments
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (index) {
                            final isActive = currentZone == index;
                            final zoneColor = _getZoneColor(index);
                            
                            return Container(
                              width: segmentWidth,
                              height: 8, // Thin bar
                              margin: EdgeInsets.only(
                                right: index < 5 ? 2 : 0, // Gap between segments
                              ),
                              decoration: BoxDecoration(
                                color: isActive 
                                    ? zoneColor 
                                    : zoneColor.withOpacity(0.35), // Dimmed when inactive
                                borderRadius: BorderRadius.horizontal(
                                  left: index == 0 ? const Radius.circular(4) : Radius.zero,
                                  right: index == 5 ? const Radius.circular(4) : Radius.zero,
                                ),
                              ),
                            );
                          }),
                        ),
                        
                        // Position Indicator (white dot) with smooth animation
                        if (currentBPM != null && currentZone != null && zones.isNotEmpty)
                          Builder(
                            builder: (context) {
                              // Calculate accurate position based on zone boundaries
                              final accuratePosition = _calculateAccuratePosition(
                                bpm: currentBPM!,
                                zone: currentZone!,
                                zones: zones,
                                totalWidth: totalWidth,
                              );
                              
                              print('ZoneSlider: BPM=$currentBPM, Zone=$currentZone, Position=$accuratePosition, TotalWidth=$totalWidth');
                              
                              return AnimatedPositioned(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                left: (accuratePosition - 6).clamp(0.0, totalWidth - 12), // Center the 12px dot, clamp to bounds
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.8),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 4),
              
              // Zone Labels (small, subtle)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final isActive = currentZone == index;
                  final zoneColor = _getZoneColor(index);
                  
                  return SizedBox(
                    width: 40, // Fixed width for consistent spacing
                    child: Text(
                      'Zone $index', // Zone 0, Zone 1, etc.
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isActive 
                            ? zoneColor 
                            : zoneColor.withOpacity(0.5),
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getZoneColor(int zone) {
    switch (zone) {
      case 0:
        return AppColors.zone0;
      case 1:
        return AppColors.zone1;
      case 2:
        return AppColors.zone2;
      case 3:
        return AppColors.zone3;
      case 4:
        return AppColors.zone4;
      case 5:
        return AppColors.zone5;
      default:
        return Colors.grey;
    }
  }

  /// Calculate accurate position for the indicator based on zone boundaries
  /// Zones are evenly distributed visually (each takes 1/6 of the slider width)
  /// But the actual HR ranges are not evenly distributed
  /// This method positions the indicator correctly within the current zone
  double _calculateAccuratePosition({
    required int bpm,
    required int zone,
    required List<ZoneBoundary> zones,
    required double totalWidth,
  }) {
    // Find the zone boundary for the current zone
    final zoneBoundary = zones.firstWhere(
      (z) => z.zone == zone,
      orElse: () => zones.first,
    );

    // Calculate position within the zone (0.0 to 1.0)
    // This represents where the BPM is within the zone's BPM range
    double positionInZone;
    if (zoneBoundary.maxBPM == zoneBoundary.minBPM) {
      // Zone has no range (shouldn't happen, but handle it)
      positionInZone = 0.5;
    } else {
      // Clamp BPM to zone boundaries
      final clampedBPM = bpm.clamp(zoneBoundary.minBPM, zoneBoundary.maxBPM);
      positionInZone = (clampedBPM - zoneBoundary.minBPM) / 
                       (zoneBoundary.maxBPM - zoneBoundary.minBPM);
      // Clamp to valid range
      positionInZone = positionInZone.clamp(0.0, 1.0);
    }

    // Calculate visual position
    // Each zone takes up 1/6 of the slider width (evenly distributed visually)
    // Zone 0 is on the left, Zone 5 is on the right
    final segmentWidth = (totalWidth - (5 * 2)) / 6; // Account for 5 gaps of 2px each
    final zoneStart = zone * (segmentWidth + 2); // Start position of the zone (including gaps)
    final positionInZoneWidth = positionInZone * segmentWidth; // Position within zone segment
    
    // Final position = zone start + position within zone
    final finalPosition = zoneStart + positionInZoneWidth;
    
    print('ZoneSlider: Zone $zone, BPM=$bpm (${zoneBoundary.minBPM}-${zoneBoundary.maxBPM}), '
          'positionInZone=$positionInZone, zoneStart=$zoneStart, segmentWidth=$segmentWidth, finalPosition=$finalPosition');
    
    return finalPosition.clamp(0.0, totalWidth);
  }
}
