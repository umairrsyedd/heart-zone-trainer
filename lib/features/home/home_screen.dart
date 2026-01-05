import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/permission_service.dart';
import '../../data/models/monitoring_state.dart';
import '../../providers/ble_provider.dart';
import '../../providers/monitoring_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../widgets/app_drawer.dart';
import 'widgets/animated_heart.dart';
import 'widgets/bpm_display.dart';
import 'widgets/circular_zone_gauge.dart';
import 'widgets/connection_status.dart';
import 'widgets/zone_pill_label.dart';

/// Home screen - Main monitoring interface
/// Auto-starts monitoring on app open
/// Handles active monitoring, paused, and disconnected states
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Auto-start monitoring when app opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndStartMonitoring();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reset auto-pause timer when app comes to foreground
      ref.read(monitoringNotifierProvider.notifier).resetAutoPauseTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Optionally pause monitoring when app backgrounds
      // This is handled by auto-pause timer in monitoring provider
    }
  }

  Future<void> _initializeAndStartMonitoring() async {
    // Check permissions first
    await _requestPermissions();

    // Load preferences to get saved device info
    final prefs = await ref.read(preferencesNotifierProvider.future);
    final bleService = ref.read(bleServiceProvider);
    final monitoringNotifier = ref.read(monitoringNotifierProvider.notifier);

    // 1. Check if device is already connected
    if (bleService.isConnected) {
      // Already connected - ensure device name is set
      // Get device name from BLE service or preferences
      final deviceName = bleService.connectedDevice?.platformName.isNotEmpty == true
          ? bleService.connectedDevice!.platformName
          : (prefs.lastConnectedDeviceName ?? 'Unknown Device');
      
      monitoringNotifier.updateDeviceName(deviceName);
      
      // Small delay to ensure state is updated
      await Future.delayed(const Duration(milliseconds: 100));
      
      monitoringNotifier.startMonitoring();
    } else {
      // Try to auto-connect to last device
      if (prefs.lastConnectedDeviceId != null && prefs.lastConnectedDeviceId!.isNotEmpty) {
        final success = await bleService.reconnectToDevice(prefs.lastConnectedDeviceId!);
        if (success) {
          // CRITICAL: Get device name from BLE service or use saved name
          final deviceName = bleService.connectedDevice?.platformName.isNotEmpty == true
              ? bleService.connectedDevice!.platformName
              : (prefs.lastConnectedDeviceName ?? 'Unknown Device');
          
          monitoringNotifier.updateDeviceName(deviceName);
          
          // Small delay to ensure state is updated
          await Future.delayed(const Duration(milliseconds: 100));
          
          monitoringNotifier.startMonitoring();
        }
      }
    }
  }

  Future<void> _requestPermissions() async {
    // Request all required permissions
    await PermissionService.requestAllPermissions();
  }

  void _handleConnectDevice() {
    Navigator.of(context).pushNamed('/settings');
  }

  /// Alert toggle button for AppBar
  Widget _buildAlertToggle(BuildContext context, bool alertsEnabled) {
    return IconButton(
      onPressed: () {
        ref.read(monitoringNotifierProvider.notifier).toggleAlerts();
        // No SnackBar - the bottom status indicator provides visual feedback
      },
      icon: Icon(
        alertsEnabled ? Icons.notifications_active : Icons.notifications_off,
        color: alertsEnabled ? AppColors.success : AppColors.textSecondary,
      ),
      tooltip: alertsEnabled ? 'Mute alerts' : 'Enable alerts',
    );
  }

  /// Subtle alerts status indicator at bottom
  Widget _buildAlertsStatusIndicator(bool alertsEnabled) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => ref.read(monitoringNotifierProvider.notifier).toggleAlerts(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              alertsEnabled ? Icons.notifications_active : Icons.notifications_off,
              size: 16,
              color: alertsEnabled 
                  ? AppColors.success.withOpacity(0.7) 
                  : AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(width: 6),
            Text(
              alertsEnabled ? 'Zone alerts on' : 'Zone alerts muted',
              style: TextStyle(
                fontSize: 12,
                color: alertsEnabled 
                    ? AppColors.success.withOpacity(0.7) 
                    : AppColors.textSecondary.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monitoringState = ref.watch(monitoringNotifierProvider);
    final isConnected = monitoringState.isConnected;
    final alertsEnabled = monitoringState.alertsEnabled;
    final prefsAsync = ref.watch(preferencesNotifierProvider);

    return prefsAsync.when(
      loading: () {
        final monitoringState = ref.watch(monitoringNotifierProvider);
        final alertsEnabled = monitoringState.alertsEnabled;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
                tooltip: 'Menu',
              ),
            ),
            titleSpacing: 0,
            title: const ConnectionStatus(),
            actions: [
              _buildAlertToggle(context, alertsEnabled),
              const SizedBox(width: 8),
            ],
          ),
          drawer: const AppDrawer(),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stack) {
        final monitoringState = ref.watch(monitoringNotifierProvider);
        final alertsEnabled = monitoringState.alertsEnabled;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
                tooltip: 'Menu',
              ),
            ),
            titleSpacing: 0,
            title: const ConnectionStatus(),
            actions: [
              _buildAlertToggle(context, alertsEnabled),
              const SizedBox(width: 8),
            ],
          ),
          drawer: const AppDrawer(),
          body: Center(
            child: Text(
              'Error loading preferences: $error',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        );
      },
      data: (prefs) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          // LEFT: Hamburger menu button
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(
                Icons.menu,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu',
            ),
          ),
          // CENTER: Connection status pill as title
          centerTitle: true,
          titleSpacing: 0,
          title: const ConnectionStatus(),
          // RIGHT: Alert toggle button
          actions: [
            _buildAlertToggle(context, alertsEnabled),
            const SizedBox(width: 8),
          ],
        ),
        // CHANGED: Use 'drawer' instead of 'endDrawer' (slides from LEFT)
        drawer: const AppDrawer(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Main circular gauge - takes available space but doesn't push content to edges
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // The gauge
                      SizedBox(
                        width: 320,
                        height: 320,
                        child: CircularZoneGauge(
                          currentZone: monitoringState.currentZone,
                          currentBPM: monitoringState.currentBPM,
                          restingHR: prefs.restingHR,
                          maxHR: prefs.maxHR,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Animated heart
                              const AnimatedHeart(),
                              const SizedBox(height: 8),
                              // BPM display
                              const BPMDisplay(),
                              const SizedBox(height: 4),
                              // Zone pill label
                              ZonePillLabel(zone: monitoringState.currentZone),
                            ],
                          ),
                        ),
                      ),
                      
                      // Spacing between gauge and alert indicator
                      const SizedBox(height: 32),
                      
                      // Zone alerts indicator - positioned right below gauge
                      _buildAlertsStatusIndicator(alertsEnabled),
                    ],
                  ),
                ),
                
                // Connect Device button ONLY if not connected (at very bottom)
                if (!isConnected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: OutlinedButton.icon(
                      onPressed: _handleConnectDevice,
                      icon: const Icon(Icons.bluetooth, size: 18),
                      label: const Text('Connect Device'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
