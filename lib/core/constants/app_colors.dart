import 'package:flutter/material.dart';

/// App color constants for HR Zone Monitor
/// Colors match the design spec from figma-make-code
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Zone Colors (0-5)
  static const Color zone0 = Color(0xFF4A90A4); // Light Blue - Rest
  static const Color zone1 = Color(0xFF6B7280); // Gray - Warm Up
  static const Color zone2 = Color(0xFF3B5998); // Blue - Fat Burn
  static const Color zone3 = Color(0xFF2D6A4F); // Green - Cardio
  static const Color zone4 = Color(0xFF92400E); // Brown - Hard
  static const Color zone5 = Color(0xFFDC2626); // Red - Max

  /// Get zone color by zone number (0-5)
  static Color getZoneColor(int zone) {
    switch (zone) {
      case 0:
        return zone0;
      case 1:
        return zone1;
      case 2:
        return zone2;
      case 3:
        return zone3;
      case 4:
        return zone4;
      case 5:
        return zone5;
      default:
        return zone0;
    }
  }

  // Background Colors
  static const Color background = Color(0xFF1A1D21); // Primary background
  static const Color surface = Color(0xFF252A31); // Surface/card background
  static const Color input = Color(0xFF2D3339); // Input field background

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF); // Primary text
  static const Color textSecondary = Color(0xFF9CA3AF); // Secondary text
  static const Color textDisabled = Color(0xFF4B5563); // Disabled text

  // Status Colors
  static const Color success = Color(0xFF22C55E); // Success/connected
  static const Color warning = Color(0xFFF59E0B); // Warning/paused
  static const Color error = Color(0xFFEF4444); // Error/disconnected

  // Additional UI Colors
  static const Color border = Color(0xFF3A3F47); // Border color
  static const Color divider = Color(0xFF2D3339); // Divider color
}
