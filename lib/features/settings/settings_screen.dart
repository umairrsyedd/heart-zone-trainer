import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/permission_service.dart';
import '../../data/models/monitoring_state.dart';
import '../../data/models/user_preferences.dart';
import '../../providers/ble_provider.dart';
import '../../providers/monitoring_provider.dart';
import '../../providers/preferences_provider.dart';
import 'widgets/device_selection_bottom_sheet.dart';

/// Settings Screen
/// Configure background monitoring, display, and device management
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _backgroundMonitoringEnabled = true;
  int _autoPauseMinutes = 60;
  bool _keepScreenOn = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
    
    // Scroll to top when navigating from Home screen (to connect device)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(0);
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadCurrentSettings() {
    final prefs = ref.read(preferencesNotifierProvider).value;
    if (prefs != null) {
      setState(() {
      _backgroundMonitoringEnabled = prefs.backgroundMonitoringEnabled;
      _autoPauseMinutes = prefs.autoPauseMinutes;
      _keepScreenOn = prefs.keepScreenOn;
      });
    }
  }

  Future<void> _autoSave() async {
    try {
      final current = ref.read(preferencesNotifierProvider).value ??
          const UserPreferences();
      await ref.read(preferencesNotifierProvider.notifier).updatePreferences(
            current.copyWith(
              backgroundMonitoringEnabled: _backgroundMonitoringEnabled,
              autoPauseMinutes: _autoPauseMinutes,
              keepScreenOn: _keepScreenOn,
            ),
          );
      print('Settings: Auto-saved successfully');
    } catch (e) {
      print('Settings: Auto-save failed: $e');
      // Don't show error to user for auto-save, just log it
    }
  }

  Future<void> _handleDisconnect() async {
    final bleService = ref.read(bleServiceProvider);
    final monitoringNotifier = ref.read(monitoringNotifierProvider.notifier);
    
    // Stop monitoring first
    await monitoringNotifier.stopMonitoring();
    
    // Disconnect the BLE device
    await bleService.disconnect();
    
    // Force sync to update connection state immediately
    // This should update the state to disconnected
    monitoringNotifier.forceSync();
    
    // Verify the state updated by reading it
    final updatedState = ref.read(monitoringNotifierProvider);
    if (kDebugMode) {
      print('Settings: After disconnect - isConnected: ${updatedState.isConnected}, connectionState: ${updatedState.connectionState}');
    }
    
    // Small delay to ensure state propagates
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (mounted) {
      // Force rebuild of this widget to reflect disconnected state
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device disconnected'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleScanForDevices() async {
    print('Settings: Scan for Devices button tapped');
    
    // Check Bluetooth is enabled
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      print('Settings: ERROR - Bluetooth is not enabled');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Bluetooth Disabled',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: const Text(
              'Please enable Bluetooth in your device settings to scan for devices.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: TextStyle(color: AppColors.zone2),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Show scanning bottom sheet immediately
    if (!mounted) return;

    print('Settings: Starting real-time device discovery...');
    final bleService = ref.read(bleServiceProvider);
    
    // Get bonded devices immediately (they're available synchronously)
    final bondedDevices = await bleService.getBondedDevices();
    print('Settings: Found ${bondedDevices.length} bonded device(s)');

    // Start scanning and create a stream of filtered scan results
    Stream<List<ScanResult>>? scanResultsStream;
    
    try {
      // Request permissions first
      if (Platform.isAndroid) {
        await Permission.bluetoothScan.request();
        await Permission.bluetoothConnect.request();
        
        // Location permission ONLY for Android 11 and below
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt <= 30) {
          await Permission.locationWhenInUse.request();
        }
      }

      // Stop any existing scan
      await FlutterBluePlus.stopScan();
      
      // Start scan
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      print('Settings: Scan started, listening for devices in real-time...');

      // Create a stream that filters scan results for HR devices
      scanResultsStream = FlutterBluePlus.scanResults
          .map((results) {
            // Filter for HR devices
            final filtered = <ScanResult>[];
            final deviceIds = <String>{};
            
            for (final result in results) {
              final deviceName = result.device.platformName.toUpperCase();
              final deviceId = result.device.remoteId.toString();
              
              // Filter for HR monitors - accept common brands and generic HR keywords
              final isHRDevice = deviceName.contains('WHOOP') ||
                  deviceName.contains('POLAR') ||
                  deviceName.contains('GARMIN') ||
                  deviceName.contains('WAHOO') ||
                  deviceName.contains('TICKR') ||
                  deviceName.contains('COOSPO') ||
                  deviceName.contains('MAGENE') ||
                  deviceName.contains('HEART') ||
                  deviceName.contains('HR') ||
                  deviceName.contains('HRM') ||
                  deviceName.contains('FITNESS') ||
                  deviceName.contains('PULSE');
              
              if (isHRDevice && !deviceIds.contains(deviceId)) {
                deviceIds.add(deviceId);
                filtered.add(result);
                print('Settings: Found HR device: ${result.device.platformName}');
              }
            }
            
            return filtered;
          })
          .timeout(
            const Duration(seconds: 12),
            onTimeout: (sink) {
              print('Settings: Scan timeout reached');
              sink.close();
            },
          );
    } catch (e) {
      print('Settings: Error starting scan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start scan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    // Show bottom sheet with real-time updates
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DeviceSelectionBottomSheet(
        pairedDevices: bondedDevices,
        scanResultsStream: scanResultsStream,
        scanTimeout: const Duration(seconds: 10),
        onDeviceSelected: (device) {
          // Stop scan when device is selected
          FlutterBluePlus.stopScan();
          _handleDeviceSelected(device);
        },
        onCancel: () {
          print('Settings: Scan cancelled by user');
          FlutterBluePlus.stopScan();
        },
      ),
    );
  }

  Future<void> _handleConnectToLastDevice(String deviceId, String deviceName) async {
    print('Settings: Connect to last device tapped: $deviceName (ID: $deviceId)');
    final bleService = ref.read(bleServiceProvider);

    // Show connecting dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.zone2,
              ),
              const SizedBox(height: 16),
              Text(
                'Connecting to $deviceName...',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      print('Settings: Attempting direct connection to paired device...');
      final success = await bleService.connectToDeviceById(deviceId, deviceName: deviceName);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close connecting dialog

      if (success && mounted) {
        print('Settings: Direct connection successful - updating device name in monitoring state');
        // CRITICAL: Explicitly update device name in monitoring state
        final monitoringNotifier = ref.read(monitoringNotifierProvider.notifier);
        monitoringNotifier.updateDeviceName(deviceName);
        monitoringNotifier.forceSync();
        
        // CRITICAL: Start monitoring to subscribe to heart rate stream
        monitoringNotifier.startMonitoring();
        
        // Small delay to ensure state propagates
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verify the state updated
        final updatedState = ref.read(monitoringNotifierProvider);
        print('Settings: After update - isConnected: ${updatedState.isConnected}, deviceName: ${updatedState.connectedDeviceName}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to $deviceName'),
              backgroundColor: AppColors.success,
            ),
          );
          
          // Force rebuild of this widget
          setState(() {});
          
          // Automatically navigate back to home screen after successful connection
          Navigator.of(context).pop();
        }
      } else if (mounted) {
        print('Settings: ERROR - Direct connection failed, trying scan...');
        // If direct connection fails, try scanning
        final scanSuccess = await bleService.scanAndReconnectToDevice(deviceId, scanTimeout: const Duration(seconds: 10));
        
        if (scanSuccess && mounted) {
          final monitoringNotifier = ref.read(monitoringNotifierProvider.notifier);
          monitoringNotifier.updateDeviceName(deviceName);
          monitoringNotifier.forceSync();
          
          // CRITICAL: Start monitoring to subscribe to heart rate stream
          monitoringNotifier.startMonitoring();
          
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connected to $deviceName'),
                backgroundColor: AppColors.success,
              ),
            );
            setState(() {});
            
            // Automatically navigate back to home screen after successful connection
            Navigator.of(context).pop();
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect. Try scanning for devices.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close connecting dialog
      print('Settings: ERROR - Connection exception: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleDeviceSelected(BluetoothDevice device) async {
    print('Settings: Device selected: ${device.platformName} (ID: ${device.remoteId})');
    final bleService = ref.read(bleServiceProvider);

    // Show connecting dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.zone2,
              ),
              const SizedBox(height: 16),
              Text(
                'Connecting to ${device.platformName}...',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      print('Settings: Attempting connection...');
      final success = await bleService.connectToDevice(device);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close connecting dialog

      if (success && mounted) {
        print('Settings: Connection successful - saving device to preferences');
        // Save device to preferences
        final current = ref.read(preferencesNotifierProvider).value ??
            const UserPreferences();
        await ref.read(preferencesNotifierProvider.notifier).updatePreferences(
              current.copyWith(
                lastConnectedDeviceId: device.remoteId.toString(),
                lastConnectedDeviceName: device.platformName,
              ),
            );
        print('Settings: Device saved - ID: ${device.remoteId}, Name: ${device.platformName}');

        // CRITICAL: Force sync the monitoring state
        final monitoringNotifier = ref.read(monitoringNotifierProvider.notifier);
        monitoringNotifier.updateDeviceName(device.platformName);
        monitoringNotifier.forceSync();
        
        // CRITICAL: Start monitoring to subscribe to heart rate stream
        monitoringNotifier.startMonitoring();
        
        // Small delay to ensure state propagates
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verify the state updated
        final updatedState = ref.read(monitoringNotifierProvider);
        print('Settings: After forceSync - isConnected: ${updatedState.isConnected}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${device.platformName}'),
              backgroundColor: AppColors.success,
            ),
          );
          
          // Force rebuild of this widget
          setState(() {});
          
          // Automatically navigate back to home screen after successful connection
          Navigator.of(context).pop();
        }
      } else if (mounted) {
        print('Settings: ERROR - Connection failed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to device'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close connecting dialog
      print('Settings: ERROR - Connection exception: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use ref.watch() to rebuild when state changes
    final prefs = ref.watch(preferencesNotifierProvider).value;
    final monitoringState = ref.watch(monitoringNotifierProvider);
    final isConnected = monitoringState.isConnected;
    final connectedDeviceName = monitoringState.connectedDeviceName ??
        prefs?.lastConnectedDeviceName;
    
    print('Settings BUILD: isConnected=$isConnected, device=$connectedDeviceName, connectionState=${monitoringState.connectionState}');

    // Load settings if not already loaded
    if (prefs != null && _autoPauseMinutes == 60 && prefs.autoPauseMinutes != 60) {
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
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const SizedBox(height: 8),
                  Text(
                    'Settings',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Connected Device Section - MOVED TO TOP
                  Text(
                    'Connected Device',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isConnected
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                connectedDeviceName ?? 'Unknown Device',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Connected',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: isConnected ? _handleDisconnect : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                  minimumSize: const Size(double.infinity, 40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Disconnect'),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No device connected',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _handleScanForDevices,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.zone2,
                                  foregroundColor: AppColors.textPrimary,
                                  minimumSize: const Size(double.infinity, 40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Scan for Devices'),
                              ),
                              // Add button to connect to last paired device if available
                              if (prefs?.lastConnectedDeviceId != null && prefs!.lastConnectedDeviceId!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () => _handleConnectToLastDevice(prefs.lastConnectedDeviceId!, prefs.lastConnectedDeviceName ?? 'Unknown'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.zone2,
                                    side: BorderSide(color: AppColors.zone2),
                                    minimumSize: const Size(double.infinity, 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text('Connect to ${prefs.lastConnectedDeviceName ?? "Last Device"}'),
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Background Monitoring Section
                  Text(
                    'Background Monitoring',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Enable Background Monitoring',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Continue monitoring heart rate when the app is in the background or screen is off.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Switch(
                              value: _backgroundMonitoringEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _backgroundMonitoringEnabled = value;
                                });
                                // Auto-save immediately
                                _autoSave();
                              },
                              activeColor: AppColors.zone2,
                            ),
                          ],
                        ),
                        if (_backgroundMonitoringEnabled) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Auto-pause after inactivity',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _autoPauseMinutes,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.input,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 30,
                                child: Text('30 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 60,
                                child: Text('1 hour'),
                              ),
                              DropdownMenuItem(
                                value: 120,
                                child: Text('2 hours'),
                              ),
                              DropdownMenuItem(
                                value: 240,
                                child: Text('4 hours'),
                              ),
                              DropdownMenuItem(
                                value: 0,
                                child: Text('Never'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _autoPauseMinutes = value;
                                });
                                // Auto-save immediately
                                _autoSave();
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Automatically pause monitoring if the app hasn\'t been opened for a period of time. Saves battery.',
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

                  // Display Section
                  Text(
                    'Display',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Keep Screen On During Monitoring',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Prevents screen from turning off while actively monitoring. Uses more battery.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Switch(
                              value: _keepScreenOn,
                              onChanged: (value) {
                                setState(() {
                                  _keepScreenOn = value;
                                });
                                // Auto-save immediately
                                _autoSave();
                              },
                              activeColor: AppColors.zone2,
                            ),
                          ],
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
