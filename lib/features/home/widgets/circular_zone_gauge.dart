import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Circular zone gauge widget that wraps content with a 270-degree arc
/// showing heart rate zones with active zone highlighting
class CircularZoneGauge extends StatelessWidget {
  final int? currentZone;
  final int? currentBPM;
  final int restingHR;
  final int maxHR;
  final Widget child; // The content inside (heart, BPM, etc.)

  const CircularZoneGauge({
    super.key,
    this.currentZone,
    this.currentBPM,
    required this.restingHR,
    required this.maxHR,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none, // Prevent clipping of content
          children: [
            // Draw the arc using CustomPaint - fills entire space
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: ZoneGaugePainter(
                currentZone: currentZone,
                currentBPM: currentBPM,
                restingHR: restingHR,
                maxHR: maxHR,
              ),
            ),
            // Position content precisely to center heart in the arc's visible area
            // Arc center is at (160, 160) in 320x320 container
            // Total content height: ~248px (heart 120px + spacing 8px + BPM ~80px + spacing 4px + pill ~36px)
            // Container height: 320px
            // To ensure zone pill is fully visible, we need: top + content height <= 320
            // With top: 60, content ends at 60 + 248 = 308px (fits with 12px margin)
            Positioned(
              top: 60, // Further reduced to ensure zone pill is fully visible with margin
              left: 0,
              right: 0,
              child: Center(
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter for drawing the circular zone gauge
class ZoneGaugePainter extends CustomPainter {
  final int? currentZone;
  final int? currentBPM;
  final int restingHR;
  final int maxHR;

  ZoneGaugePainter({
    this.currentZone,
    this.currentBPM,
    required this.restingHR,
    required this.maxHR,
  });

  static const List<Color> zoneColors = [
    Color(0xFF4A90A4), // Zone 0 - Teal
    Color(0xFF6B7280), // Zone 1 - Gray
    Color(0xFF3B5998), // Zone 2 - Blue
    Color(0xFF2D6A4F), // Zone 3 - Green
    Color(0xFF92400E), // Zone 4 - Brown/Orange
    Color(0xFFDC2626), // Zone 5 - Red
  ];

  // Zone boundaries as percentages of HRR (Karvonen)
  static const List<List<double>> zoneBoundaries = [
    [0.0, 0.49],   // Zone 0
    [0.50, 0.59],  // Zone 1
    [0.60, 0.69],  // Zone 2
    [0.70, 0.79],  // Zone 3
    [0.80, 0.89],  // Zone 4
    [0.90, 1.00],  // Zone 5
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Original radius - keep as before
    final radius = math.min(size.width, size.height) / 2 - 20;
    
    const strokeWidth = 12.0;
    const double startAngle = 135 * (math.pi / 180);  // Start from bottom-left (135°)
    const double totalSweep = 270 * (math.pi / 180);  // Total arc span (270°)
    const double gapAngle = 4 * (math.pi / 180);      // Gap between segments (4°)
    
    // Calculate segment sweep (total - gaps) / 6 zones
    final double segmentSweep = (totalSweep - (5 * gapAngle)) / 6;

    // ========== DRAW ZONE SEGMENTS ==========
    for (int i = 0; i < 6; i++) {
      final isActive = currentZone == i;
      final paint = Paint()
        ..color = isActive ? zoneColors[i] : zoneColors[i].withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final segmentStart = startAngle + (i * (segmentSweep + gapAngle));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        segmentStart,
        segmentSweep,
        false,
        paint,
      );
    }

    // ========== DRAW POSITION INDICATOR BALL ==========
    if (currentBPM != null && currentZone != null) {
      final indicatorAngle = _calculateIndicatorAngle(
        currentBPM: currentBPM!,
        restingHR: restingHR,
        maxHR: maxHR,
        currentZone: currentZone!,
        startAngle: startAngle,
        segmentSweep: segmentSweep,
        gapAngle: gapAngle,
      );

      if (indicatorAngle != null) {
        // Calculate position on the arc
        final indicatorX = center.dx + radius * math.cos(indicatorAngle);
        final indicatorY = center.dy + radius * math.sin(indicatorAngle);
        final indicatorPos = Offset(indicatorX, indicatorY);

        // Draw shadow
        final shadowPaint = Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(indicatorPos + const Offset(0, 2), 7, shadowPaint);

        // Draw white fill
        final fillPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(indicatorPos, 7, fillPaint);

        // Draw border
        final borderPaint = Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(indicatorPos, 7, borderPaint);
      }
    }
  }

  double? _calculateIndicatorAngle({
    required int currentBPM,
    required int restingHR,
    required int maxHR,
    required int currentZone,
    required double startAngle,
    required double segmentSweep,
    required double gapAngle,
  }) {
    final hrr = maxHR - restingHR;
    if (hrr <= 0) return null;

    // Current HR as percentage of HRR
    final hrPercent = (currentBPM - restingHR) / hrr;

    // Clamp zone to valid range
    final zone = currentZone.clamp(0, 5);

    // Get zone boundaries
    final zoneStart = zoneBoundaries[zone][0];
    final zoneEnd = zoneBoundaries[zone][1];
    final zoneRange = zoneEnd - zoneStart;

    // Calculate position within zone (0.0 to 1.0)
    double positionInZone;
    if (zoneRange > 0) {
      positionInZone = ((hrPercent - zoneStart) / zoneRange).clamp(0.0, 1.0);
    } else {
      positionInZone = 0.5;
    }

    // Calculate the angle
    final zoneStartAngle = startAngle + (zone * (segmentSweep + gapAngle));
    
    // Add edge padding so ball doesn't sit exactly on segment edges
    const edgePadding = 0.08;
    final paddedPosition = edgePadding + (positionInZone * (1.0 - 2 * edgePadding));

    return zoneStartAngle + (paddedPosition * segmentSweep);
  }

  @override
  bool shouldRepaint(ZoneGaugePainter oldDelegate) {
    return oldDelegate.currentZone != currentZone ||
           oldDelegate.currentBPM != currentBPM ||
           oldDelegate.restingHR != restingHR ||
           oldDelegate.maxHR != maxHR;
  }
}

