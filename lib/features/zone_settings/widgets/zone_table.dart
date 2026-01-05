import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/zone_boundary.dart';

/// Zone table widget displaying zone boundaries
/// Shows editable inputs when manual mode is enabled
class ZoneTable extends StatelessWidget {
  final List<ZoneBoundary> zones;
  final bool manualMode;
  final ValueChanged<ZoneBoundary> onZoneChanged;

  const ZoneTable({
    super.key,
    required this.zones,
    required this.manualMode,
    required this.onZoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Sort zones descending (5 to 1, Zone 0 is implicit)
    final sortedZones = List<ZoneBoundary>.from(zones)
      ..sort((a, b) => b.zone.compareTo(a.zone));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'ZONE',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'ZONE MIN',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'ZONE MAX',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Zone rows (Zones 5-1, Zone 0 is implicit)
        ...sortedZones.where((z) => z.zone > 0).map((zone) {
          final zoneInfo = ZoneInfo.values.firstWhere(
            (z) => z.number == zone.zone,
            orElse: () => ZoneInfo.zone0,
          );

          return _ZoneRow(
            zone: zone,
            zoneInfo: zoneInfo,
            manualMode: manualMode,
            onChanged: (updatedZone) => onZoneChanged(updatedZone),
          );
        }),
      ],
    );
  }
}

/// Individual zone row widget
class _ZoneRow extends StatelessWidget {
  final ZoneBoundary zone;
  final ZoneInfo zoneInfo;
  final bool manualMode;
  final ValueChanged<ZoneBoundary> onChanged;

  const _ZoneRow({
    required this.zone,
    required this.zoneInfo,
    required this.manualMode,
    required this.onChanged,
  });

  void _updateMin(int? newMin) {
    if (newMin != null) {
      onChanged(zone.copyWith(minBPM: newMin));
    }
  }

  void _updateMax(int? newMax) {
    if (newMax != null) {
      onChanged(zone.copyWith(maxBPM: newMax));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Zone label with color indicator
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: zoneInfo.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zone ${zone.zone}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Zone Min input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      enabled: manualMode,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: manualMode
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      controller: TextEditingController(
                        text: zone.minBPM.toString(),
                      )..selection = TextSelection.collapsed(
                          offset: zone.minBPM.toString().length,
                        ),
                      onChanged: (text) {
                        final intValue = int.tryParse(text);
                        _updateMin(intValue);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'bpm',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Zone Max input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      enabled: manualMode,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: manualMode
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      controller: TextEditingController(
                        text: zone.maxBPM.toString(),
                      )..selection = TextSelection.collapsed(
                          offset: zone.maxBPM.toString().length,
                        ),
                      onChanged: (text) {
                        final intValue = int.tryParse(text);
                        _updateMax(intValue);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'bpm',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

