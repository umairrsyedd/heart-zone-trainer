import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/hr_zone_calculator.dart';
import '../../data/models/zone_boundary.dart';
import '../../providers/preferences_provider.dart';
import 'widgets/hr_input_field.dart';
import 'widgets/zone_table.dart';

/// Heart Rate Zone Settings Screen
/// Allows users to configure resting HR, max HR, and zone boundaries
class ZoneSettingsScreen extends ConsumerStatefulWidget {
  const ZoneSettingsScreen({super.key});

  @override
  ConsumerState<ZoneSettingsScreen> createState() => _ZoneSettingsScreenState();
}

class _ZoneSettingsScreenState
    extends ConsumerState<ZoneSettingsScreen> {
  int? _restingHR;
  int? _maxHR;
  bool _manualZonesEnabled = false;
  List<ZoneBoundary> _zones = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    final prefs = ref.read(preferencesNotifierProvider).value;
    if (prefs != null) {
      setState(() {
        _restingHR = prefs.restingHR;
        _maxHR = prefs.maxHR;
        _manualZonesEnabled = prefs.manualZonesEnabled;
        _zones = prefs.manualZonesEnabled && prefs.customZones != null
            ? List.from(prefs.customZones!)
            : HRZoneCalculator.calculateZones(
                restingHR: prefs.restingHR,
                maxHR: prefs.maxHR,
              );
      });
    }
  }

  void _recalculateZones() {
    if (_restingHR != null && _maxHR != null && !_manualZonesEnabled) {
      setState(() {
        _zones = HRZoneCalculator.calculateZones(
          restingHR: _restingHR!,
          maxHR: _maxHR!,
        );
      });
    }
  }

  Future<void> _autoSave() async {
    // Validate before saving
    if (_restingHR == null || _maxHR == null) return;
    if (_restingHR! < 30 || _restingHR! > 100) return;
    if (_maxHR! < 150 || _maxHR! > 220) return;
    if (_maxHR! <= _restingHR!) return;

    try {
      await ref.read(preferencesNotifierProvider.notifier).updateZoneSettings(
            restingHR: _restingHR!,
            maxHR: _maxHR!,
            customZones: _manualZonesEnabled ? _zones : null,
            manualZonesEnabled: _manualZonesEnabled,
          );
      print('ZoneSettings: Auto-saved successfully');
    } catch (e) {
      print('ZoneSettings: Auto-save failed: $e');
      // Don't show error to user for auto-save, just log it
    }
  }

  void _onRestingHRChanged(int? value) {
    setState(() {
      _restingHR = value;
    });
    _recalculateZones();
    // Auto-save after a short delay to debounce rapid changes
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _autoSave();
    });
  }

  void _onMaxHRChanged(int? value) {
    setState(() {
      _maxHR = value;
    });
    _recalculateZones();
    // Auto-save after a short delay to debounce rapid changes
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _autoSave();
    });
  }

  void _onManualZonesToggled(bool value) {
    setState(() {
      _manualZonesEnabled = value;
      if (!value) {
        // Recalculate zones when disabling manual mode
        _recalculateZones();
      }
    });
    // Auto-save immediately for toggle
    _autoSave();
  }

  void _onZoneChanged(ZoneBoundary updatedZone) {
    setState(() {
      final index = _zones.indexWhere((z) => z.zone == updatedZone.zone);
      if (index != -1) {
        _zones[index] = updatedZone;
      }
    });
    // Auto-save after a short delay to debounce rapid changes
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _autoSave();
    });
  }


  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesNotifierProvider).value;

    // Load settings if not already loaded
    if (prefs != null && _restingHR == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCurrentSettings();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: prefs == null
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.zone2,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and description
                  const SizedBox(height: 8),
                  Text(
                    'Zone Settings',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Calculated using the scientifically validated heart rate reserve formula, your heart rate (HR) zones are personalized using your baseline resting HR and maximum HR.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // HR Input Fields
                  Row(
                    children: [
                      HRInputField(
                        label: 'RESTING HR',
                        value: _restingHR,
                        onChanged: _onRestingHRChanged,
                        tooltip:
                            'Your heart rate when fully at rest. Best measured first thing in the morning.',
                      ),
                      const SizedBox(width: 16),
                      HRInputField(
                        label: 'MAX HR',
                        value: _maxHR,
                        onChanged: _onMaxHRChanged,
                        tooltip:
                            'The highest heart rate you can achieve. Can be estimated as 220 minus your age, or measured during max effort test.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Manual Zones Toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Manual Heart Rate Zones',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Switch(
                              value: _manualZonesEnabled,
                              onChanged: _onManualZonesToggled,
                              activeColor: AppColors.zone2,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The zones are calculated based on your resting HR and maximum HR. As your fitness and RHR change, you can manually update them if they don\'t feel normal to you.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Zone Table
                  ZoneTable(
                    zones: _zones,
                    manualMode: _manualZonesEnabled,
                    onZoneChanged: _onZoneChanged,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
