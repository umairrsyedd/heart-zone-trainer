import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/constants/app_colors.dart';

/// Bottom sheet for selecting a BLE device to connect to
/// Shows paired devices at the top and scanned devices below
/// Updates in real-time as devices are discovered
class DeviceSelectionBottomSheet extends StatefulWidget {
  final List<BluetoothDevice> pairedDevices;
  final Function(BluetoothDevice) onDeviceSelected;
  final VoidCallback onCancel;
  final Stream<List<ScanResult>>? scanResultsStream;
  final Duration scanTimeout;

  const DeviceSelectionBottomSheet({
    super.key,
    required this.pairedDevices,
    required this.onDeviceSelected,
    required this.onCancel,
    this.scanResultsStream,
    this.scanTimeout = const Duration(seconds: 10),
  });

  @override
  State<DeviceSelectionBottomSheet> createState() => _DeviceSelectionBottomSheetState();
}

class _DeviceSelectionBottomSheetState extends State<DeviceSelectionBottomSheet> {
  final List<ScanResult> _scannedDevices = [];
  final Set<String> _deviceIds = {}; // Track device IDs to avoid duplicates
  bool _isScanning = true;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _scanTimeoutTimer;

  @override
  void initState() {
    super.initState();
    // Add paired device IDs to the tracking set to prevent duplicates
    for (final device in widget.pairedDevices) {
      _deviceIds.add(device.remoteId.toString());
      print('DeviceSelection: Added paired device to tracking: ${device.platformName} (${device.remoteId})');
    }
    _startListeningToScanResults();
  }

  void _startListeningToScanResults() {
    if (widget.scanResultsStream != null) {
      _scanSubscription = widget.scanResultsStream!.listen(
        (scanResults) {
          if (!mounted) return;
          
          setState(() {
            for (final result in scanResults) {
              final deviceId = result.device.remoteId.toString();
              
              // Check if device is already in paired devices
              final isPaired = widget.pairedDevices.any(
                (paired) => paired.remoteId.toString() == deviceId,
              );
              
              // Only add if not already tracked AND not in paired devices
              if (!_deviceIds.contains(deviceId) && !isPaired) {
                _deviceIds.add(deviceId);
                _scannedDevices.add(result);
                print('DeviceSelection: Added scanned device: ${result.device.platformName}');
              } else if (isPaired) {
                print('DeviceSelection: Skipping ${result.device.platformName} - already in paired devices');
              } else {
                print('DeviceSelection: Skipping ${result.device.platformName} - duplicate');
              }
            }
          });
        },
        onError: (error) {
          print('DeviceSelection: Scan stream error: $error');
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
          }
        },
        onDone: () {
          print('DeviceSelection: Scan stream completed');
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
          }
        },
      );

      // Set timeout timer
      _scanTimeoutTimer = Timer(widget.scanTimeout, () {
        print('DeviceSelection: Scan timeout reached');
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
        _scanSubscription?.cancel();
      });
    } else {
      // No stream provided, scanning already completed
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _scanTimeoutTimer?.cancel();
    // Stop scan when bottom sheet is dismissed
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDevices = widget.pairedDevices.isNotEmpty || _scannedDevices.isNotEmpty;
    
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Device',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onCancel();
                  },
                ),
              ],
            ),
          ),

          // Show scanning indicator at top if scanning, but still show devices below
          if (_isScanning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.zone2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Scanning for devices...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // Device list (shows devices as they're discovered)
          if (!hasDevices && !_isScanning)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    size: 48,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No devices found',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Make sure your heart rate device is powered on and nearby',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else if (hasDevices)
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Paired devices section
                  if (widget.pairedDevices.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.link,
                            size: 16,
                            color: AppColors.zone2,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Paired Devices',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...widget.pairedDevices.map((device) {
                      final deviceName = device.platformName.isNotEmpty
                          ? device.platformName
                          : 'Unknown Device';
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.zone2.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.bluetooth_connected,
                            color: AppColors.zone2,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          deviceName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              'Heart Rate Monitor',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Paired',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onDeviceSelected(device);
                        },
                      );
                    }),
                    if (_scannedDevices.isNotEmpty)
                      const Divider(
                        height: 32,
                        thickness: 1,
                        color: AppColors.textSecondary,
                      ),
                  ],

                  // Scanned devices section
                  if (_scannedDevices.isNotEmpty) ...[
                    if (widget.pairedDevices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bluetooth_searching,
                              size: 16,
                              color: AppColors.zone2,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Nearby Devices',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ..._scannedDevices.map((result) {
                      final device = result.device;
                      final deviceName = device.platformName.isNotEmpty
                          ? device.platformName
                          : 'Unknown Device';
                      final rssi = result.rssi;
                      return ListTile(
                        leading: Icon(
                          Icons.bluetooth,
                          color: AppColors.zone2,
                        ),
                        title: Text(
                          deviceName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Heart Rate Monitor',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Signal: ${rssi} dBm',
                              style: TextStyle(
                                color: AppColors.textSecondary.withOpacity(0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onDeviceSelected(device);
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
