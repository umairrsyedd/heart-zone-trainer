import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/zone_boundary.dart';

/// Pill-shaped zone label widget with tinted background
class ZonePillLabel extends StatelessWidget {
  final int? zone;

  const ZonePillLabel({super.key, this.zone});

  @override
  Widget build(BuildContext context) {
    if (zone == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Waiting for data...',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
          ),
        ),
      );
    }

    final zoneInfo = ZoneInfo.values.firstWhere(
      (z) => z.number == zone,
      orElse: () => ZoneInfo.zone0,
    );
    final zoneColor = zoneInfo.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: zoneColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: zoneColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        'Zone $zone - ${zoneInfo.name}',
        style: TextStyle(
          color: zoneColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

