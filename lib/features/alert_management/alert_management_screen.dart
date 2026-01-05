import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../data/models/user_preferences.dart';
import '../../data/models/zone_boundary.dart';
import '../../providers/preferences_provider.dart';
import 'widgets/alert_option_tile.dart';

/// Alert Management Screen
/// Configure zone change alerts, types, and settings
class AlertManagementScreen extends ConsumerStatefulWidget {
  const AlertManagementScreen({super.key});

  @override
  ConsumerState<AlertManagementScreen> createState() =>
      _AlertManagementScreenState();
}

class _AlertManagementScreenState
    extends ConsumerState<AlertManagementScreen> {
  bool _alertsEnabled = true;
  List<AlertType> _alertTypes = [AlertType.vibration, AlertType.voice];
  bool _repeatRemindersEnabled = false;
  int _repeatIntervalSeconds = 30;
  List<int> _enabledZones = [0, 1, 2, 3, 4, 5];
  int _alertCooldownSeconds = 5;

  @override
  void initState() {
    super.initState();
    print('AlertManagement: ===============================');
    print('AlertManagement: Screen INIT');
    print('AlertManagement: ===============================');
    
    // Use post frame callback to ensure provider is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('AlertManagement: Post frame callback - loading settings');
      await _loadCurrentSettings();
      
      // Verify what we loaded
      print('AlertManagement: After load - local state:');
      print('  - _alertsEnabled: $_alertsEnabled');
      print('  - _alertTypes: $_alertTypes');
      print('  - _enabledZones: $_enabledZones');
    });
  }

  @override
  void dispose() {
    print('AlertManagement: ===============================');
    print('AlertManagement: Screen DISPOSE');
    print('AlertManagement: ===============================');
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    try {
      // CRITICAL: Wait for the provider to have data using .future
      // This ensures we wait for SharedPreferences to load before reading values
      final prefs = await ref.read(preferencesNotifierProvider.future);
      
      print('AlertManagement: 📥 Loading settings from provider:');
      print('  - alertsEnabled: ${prefs.alertsEnabled}');
      print('  - alertTypes: ${prefs.alertTypes}');
      print('  - enabledZones: ${prefs.enabledZones}');
      print('  - repeatRemindersEnabled: ${prefs.repeatRemindersEnabled}');
      print('  - repeatIntervalSeconds: ${prefs.repeatIntervalSeconds}');
      print('  - alertCooldownSeconds: ${prefs.alertCooldownSeconds}');
      
      if (mounted) {
        setState(() {
          _alertsEnabled = prefs.alertsEnabled;
          // IMPORTANT: Create new list instances
          _alertTypes = List<AlertType>.from(prefs.alertTypes);
          _repeatRemindersEnabled = prefs.repeatRemindersEnabled;
          _repeatIntervalSeconds = prefs.repeatIntervalSeconds;
          _enabledZones = List<int>.from(prefs.enabledZones);
          _alertCooldownSeconds = prefs.alertCooldownSeconds;
        });
        print('AlertManagement: ✅ Settings loaded and applied to UI');
      }
    } catch (e) {
      print('AlertManagement: ❌ Error loading settings: $e');
      // Keep defaults if error
    }
  }

  Future<void> _autoSave() async {
    try {
      final current = ref.read(preferencesNotifierProvider).value ??
          const UserPreferences();
      
      // Create new list instances to ensure Freezed detects changes
      final newAlertTypes = List<AlertType>.from(_alertTypes);
      final newEnabledZones = List<int>.from(_enabledZones);
      
      print('AlertManagement: Auto-saving - alertsEnabled: $_alertsEnabled, alertTypes: $newAlertTypes, enabledZones: $newEnabledZones');
      
      await ref.read(preferencesNotifierProvider.notifier).updatePreferences(
            current.copyWith(
              alertsEnabled: _alertsEnabled,
              alertTypes: newAlertTypes,
              repeatRemindersEnabled: _repeatRemindersEnabled,
              repeatIntervalSeconds: _repeatIntervalSeconds,
              enabledZones: newEnabledZones,
              alertCooldownSeconds: _alertCooldownSeconds,
            ),
          );
      print('AlertManagement: ✅ Auto-saved successfully');
    } catch (e) {
      print('AlertManagement: ❌ Auto-save failed: $e');
      // Don't show error to user for auto-save, just log it
    }
  }

  void _toggleAlertType(AlertType type, bool enabled) {
    setState(() {
      // Create a completely new list instance
      if (enabled) {
        if (!_alertTypes.contains(type)) {
          _alertTypes = [..._alertTypes, type];
        }
      } else {
        _alertTypes = _alertTypes.where((t) => t != type).toList();
      }
    });
    print('AlertManagement: Toggled alert type $type to $enabled, new list: $_alertTypes');
    // Auto-save immediately
    _autoSave();
  }

  void _toggleZone(int zone, bool enabled) {
    setState(() {
      // Create a completely new list instance
      if (enabled) {
        if (!_enabledZones.contains(zone)) {
          _enabledZones = [..._enabledZones, zone];
        }
      } else {
        _enabledZones = _enabledZones.where((z) => z != zone).toList();
      }
    });
    print('AlertManagement: Toggled zone $zone to $enabled, new list: $_enabledZones');
    // Auto-save immediately
    _autoSave();
  }


  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesNotifierProvider).value;

    // Load settings if not already loaded
    if (prefs != null && _alertTypes.isEmpty && prefs.alertTypes.isNotEmpty) {
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
                  // Title
                  const SizedBox(height: 8),
                  Text(
                    'Alert Management',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Master Toggle
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
                              'Enable Zone Alerts',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Switch(
                              value: _alertsEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _alertsEnabled = value;
                                });
                                // Auto-save immediately
                                _autoSave();
                              },
                              activeColor: AppColors.zone2,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When enabled, you will receive notifications when your heart rate crosses into a new zone.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Alert Type Section
                  Text(
                    'Alert Type',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: _alertsEnabled ? 1.0 : 0.5,
                    child: Column(
                      children: [
                        AlertOptionTile(
                          title: 'Sound',
                          description: 'Play an audible tone when zone changes',
                          value: _alertTypes.contains(AlertType.sound),
                          onChanged: (value) =>
                              _toggleAlertType(AlertType.sound, value),
                          enabled: _alertsEnabled,
                        ),
                        const SizedBox(height: 12),
                        AlertOptionTile(
                          title: 'Vibration',
                          description: 'Vibrate your device when zone changes',
                          value: _alertTypes.contains(AlertType.vibration),
                          onChanged: (value) =>
                              _toggleAlertType(AlertType.vibration, value),
                          enabled: _alertsEnabled,
                        ),
                        const SizedBox(height: 12),
                        AlertOptionTile(
                          title: 'Voice Announcement',
                          description:
                              'Announce the new zone verbally (e.g., \'Entering Zone 4\')',
                          value: _alertTypes.contains(AlertType.voice),
                          onChanged: (value) =>
                              _toggleAlertType(AlertType.voice, value),
                          enabled: _alertsEnabled,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Repeat Reminders
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
                              'Repeat Zone Reminders',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Switch(
                              value: _repeatRemindersEnabled,
                              onChanged: _alertsEnabled
                                  ? (value) {
                                      setState(() {
                                        _repeatRemindersEnabled = value;
                                      });
                                      // Auto-save immediately
                                      _autoSave();
                                    }
                                  : null,
                              activeColor: AppColors.zone2,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Periodically remind you which zone you\'re in while training.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        if (_repeatRemindersEnabled && _alertsEnabled) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Remind every:',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '$_repeatIntervalSeconds seconds',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _repeatIntervalSeconds.toDouble(),
                            min: 10,
                            max: 120,
                            divisions: 22, // 5-second steps
                            label: '$_repeatIntervalSeconds seconds',
                                onChanged: _alertsEnabled
                                    ? (value) {
                                        setState(() {
                                          _repeatIntervalSeconds = value.round();
                                        });
                                        // Auto-save after a short delay to debounce slider changes
                                        Future.delayed(const Duration(milliseconds: 500), () {
                                          if (mounted) _autoSave();
                                        });
                                      }
                                    : null,
                            activeColor: AppColors.zone2,
                          ),
                          Text(
                            'You will hear "Zone 2 for $_repeatIntervalSeconds seconds" at your selected interval',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Zone-Specific Alerts
                  Text(
                    'Alert for Specific Zones',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose which zones trigger alerts. Useful if you only care about staying in certain training zones.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: _alertsEnabled ? 1.0 : 0.5,
                    child: Column(
                      children: List.generate(6, (index) {
                        final zone = 5 - index; // Zones 5 to 0
                        final zoneInfo = ZoneInfo.values.firstWhere(
                          (z) => z.number == zone,
                          orElse: () => ZoneInfo.zone0,
                        );
                        final zoneName = zoneInfo.name;
                        final zoneDescription = zoneInfo.description;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                // Color indicator
                                Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: zoneInfo.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Zone label
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Zone $zone ($zoneName)',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        zoneDescription,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Toggle
                                Switch(
                                  value: _enabledZones.contains(zone),
                                  onChanged: _alertsEnabled
                                      ? (value) => _toggleZone(zone, value)
                                      : null,
                                  activeColor: AppColors.zone2,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Alert Cooldown
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Alert Cooldown',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Minimum time between zone change alerts. Prevents rapid repeated alerts when your heart rate hovers near a zone boundary.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Opacity(
                          opacity: _alertsEnabled ? 1.0 : 0.5,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Cooldown:',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '$_alertCooldownSeconds seconds',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _alertCooldownSeconds.toDouble(),
                                min: 0,
                                max: 30,
                                divisions: 30,
                                label: '$_alertCooldownSeconds seconds',
                                onChanged: _alertsEnabled
                                    ? (value) {
                                        setState(() {
                                          _alertCooldownSeconds = value.round();
                                        });
                                        // Auto-save after a short delay to debounce slider changes
                                        Future.delayed(const Duration(milliseconds: 500), () {
                                          if (mounted) _autoSave();
                                        });
                                      }
                                    : null,
                                activeColor: AppColors.zone2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
