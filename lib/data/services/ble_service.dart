import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/constants/ble_constants.dart';
import '../../data/models/monitoring_state.dart';

/// Bluetooth Low Energy service for connecting to heart rate monitors
/// Handles device scanning, connection, heart rate data streaming, and auto-reconnection
class BLEService {
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _heartRateSubscription;
  StreamSubscription? _connectionSubscription;

  StreamController<int>? _heartRateController;
  
  // Use a broadcast stream controller that persists
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  
  StreamController<int> get _heartRateControllerInstance {
    _heartRateController ??= StreamController<int>.broadcast();
    return _heartRateController!;
  }

  /// Current connection state (cached)
  ConnectionState _currentConnectionState = ConnectionState.disconnected;

  /// Stream of heart rate measurements (BPM values)
  Stream<int> get heartRateStream => _heartRateControllerInstance.stream;

  /// Stream of connection state changes
  /// Simple broadcast stream that always works
  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;
  
  /// Getter for current state (synchronous)
  ConnectionState get currentConnectionState => _currentConnectionState;

  Timer? _reconnectionTimer;
  int _reconnectionAttempts = 0;
  static const int maxReconnectionAttempts = 30;
  static const Duration reconnectionInterval = Duration(seconds: 2);

  /// Safely add value to heart rate stream
  /// Auto-recreates controller if closed (e.g., during hot reload)
  void _safeAddHeartRate(int bpm) {
    // Always ensure controller exists and is open
    if (_heartRateController == null || _heartRateController!.isClosed) {
      // Controller is closed or null - recreate it silently
      // This can happen during hot reload when service is recreated
      // but BLE subscription at platform level is still active
      _heartRateController?.close(); // Clean up old one if it exists
      _heartRateController = StreamController<int>.broadcast();
    }
    
    try {
      _heartRateController!.add(bpm);
    } catch (e) {
      // If add fails, recreate controller
      _heartRateController?.close();
      _heartRateController = StreamController<int>.broadcast();
      try {
        _heartRateController!.add(bpm);
      } catch (e2) {
        // Silently handle error
      }
    }
  }

  /// Method to update state - ALWAYS emits to stream
  void _updateConnectionState(ConnectionState newState) {
    _currentConnectionState = newState;
    
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(newState);
    }
  }
  
  /// Safely add connection state to stream (legacy method, redirects to _updateConnectionState)
  void _safeAddConnectionState(ConnectionState state) {
    _updateConnectionState(state);
  }

  /// Get bonded (paired) devices from Android Bluetooth settings
  /// These are devices that have been paired in system settings
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      // Get all bonded devices from Android
      final bondedDevices = await FlutterBluePlus.bondedDevices;
      
      // Filter for HR monitors by name pattern
      // Accept common HR monitor brands and generic HR keywords
      final hrDevices = bondedDevices.where((device) {
        final name = device.platformName.toUpperCase();
        return name.contains('WHOOP') || 
               name.contains('POLAR') || 
               name.contains('GARMIN') ||
               name.contains('WAHOO') ||
               name.contains('TICKR') ||
               name.contains('COOSPO') ||
               name.contains('MAGENE') ||
               name.contains('HEART') ||
               name.contains('HR') ||
               name.contains('HRM') ||
               name.contains('FITNESS') ||
               name.contains('PULSE');
      }).toList();
      
      return hrDevices;
    } catch (e) {
      return [];
    }
  }

  /// Scan for devices advertising BLE (without service filter)
  /// Many HR devices don't advertise their service UUIDs in advertisements
  /// Returns list of ScanResult objects
  Future<List<ScanResult>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    
    // 1. Check Bluetooth adapter state
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      throw Exception('Bluetooth is not enabled. Please turn on Bluetooth.');
    }

    // 2. Check and request permissions (Android)
    if (Platform.isAndroid) {
      final scanStatus = await Permission.bluetoothScan.status;
      if (!scanStatus.isGranted) {
        final scanResult = await Permission.bluetoothScan.request();
        if (!scanResult.isGranted) {
          throw Exception('Bluetooth scan permission denied. Please grant permission in settings.');
        }
      }

      final connectStatus = await Permission.bluetoothConnect.status;
      if (!connectStatus.isGranted) {
        await Permission.bluetoothConnect.request();
      }

      // Location permission required for BLE ONLY on Android 11 and below
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt <= 30) {
          final locationStatus = await Permission.locationWhenInUse.status;
          if (!locationStatus.isGranted) {
            await Permission.locationWhenInUse.request();
          }
        }
      }
    }

    _safeAddConnectionState(ConnectionState.scanning);

    // 3. Stop any existing scan
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore if no scan was running
    }

    // 4. Scan for ALL devices (NO service filter - this is the key fix!)
    final results = <ScanResult>[];
    final deviceIds = <String>{};

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        // DO NOT filter by services - many devices don't advertise services
        // Leaving withServices empty or omitting it scans all devices
      );

      // 5. Listen to scan results
      try {
        await for (final scanResults in FlutterBluePlus.scanResults.timeout(
          timeout + const Duration(seconds: 2),
          onTimeout: (sink) {
            sink.close();
          },
        )) {
          for (final result in scanResults) {
            final deviceName = result.device.platformName;
            final deviceNameUpper = deviceName.toUpperCase();
            final deviceId = result.device.remoteId.toString();

            // Filter for heart rate monitors
            // Check if device advertises Heart Rate Service (UUID: 0x180D)
            final hasHRService = result.advertisementData.serviceUuids.any((uuid) =>
                uuid.toString().toUpperCase().contains('180D'));
            
            // Also check device name for HR-related keywords
            final hasHRName = deviceNameUpper.contains('WHOOP') ||
                deviceNameUpper.contains('POLAR') ||
                deviceNameUpper.contains('GARMIN') ||
                deviceNameUpper.contains('WAHOO') ||
                deviceNameUpper.contains('TICKR') ||
                deviceNameUpper.contains('COOSPO') ||
                deviceNameUpper.contains('MAGENE') ||
                deviceNameUpper.contains('HEART') ||
                deviceNameUpper.contains('HR') ||
                deviceNameUpper.contains('HRM') ||
                deviceNameUpper.contains('FITNESS') ||
                deviceNameUpper.contains('PULSE');
            
            final isHRDevice = hasHRService || hasHRName;

            if (isHRDevice) {
              // Avoid duplicates
              if (!deviceIds.contains(deviceId)) {
                deviceIds.add(deviceId);
                results.add(result);
              }
            }
          }
        }
      } on TimeoutException {
        // Timeout is expected, continue to stop scan
      }

      await FlutterBluePlus.stopScan();
    } catch (e) {
      await FlutterBluePlus.stopScan();
      _safeAddConnectionState(ConnectionState.disconnected);
      rethrow;
    }

    _safeAddConnectionState(ConnectionState.disconnected);

    return results;
  }

  /// Combined device discovery: gets both bonded and scanned devices
  /// Returns a map with 'bonded' and 'scanned' device lists
  Future<Map<String, dynamic>> discoverDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // 1. Get bonded (paired) devices first
    final bondedDevices = await getBondedDevices();

    // 2. Scan for nearby advertising devices
    List<ScanResult> scannedDevices;
    try {
      scannedDevices = await scanForDevices(timeout: timeout);
    } catch (e) {
      scannedDevices = [];
    }

    // 3. Remove duplicates (devices that appear in both lists)
    final scannedFiltered = scannedDevices.where((scanned) {
      return !bondedDevices.any((bonded) =>
          bonded.remoteId.toString() == scanned.device.remoteId.toString());
    }).toList();

    return {
      'bonded': bondedDevices,
      'scanned': scannedFiltered,
    };
  }

  /// Connect to a specific BLE device
  /// Discovers services AFTER connecting (key fix for devices that don't advertise services)
  /// Returns true if connection successful, false otherwise
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _safeAddConnectionState(ConnectionState.connecting);

      // Connect with timeout
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = device;

      // IMPORTANT: Discover services AFTER connecting
      // This is when we find the Heart Rate Service
      // Many devices don't advertise services in scan, only after connection
      final services = await device.discoverServices();

      // Find and subscribe to Heart Rate Service
      bool hrServiceFound = false;
      for (final service in services) {
        final serviceUuid = service.uuid.toString().toUpperCase();
        
        // Check for Heart Rate Service UUID (0x180D)
        if (serviceUuid.contains('180D') || 
            serviceUuid == BLEConstants.heartRateServiceUUID.toUpperCase()) {
          for (final characteristic in service.characteristics) {
            final charUuid = characteristic.uuid.toString().toUpperCase();
            
            // Check for Heart Rate Measurement Characteristic UUID (0x2A37)
            if (charUuid.contains('2A37') ||
                charUuid == BLEConstants.heartRateMeasurementUUID.toUpperCase()) {
              // Enable notifications
              await characteristic.setNotifyValue(true);

              // Listen to value updates
              _heartRateSubscription = characteristic.onValueReceived.listen((value) {
                final bpm = _parseHeartRateData(value);
                if (bpm != null) {
                  _safeAddHeartRate(bpm);
                }
              });

              hrServiceFound = true;
              break;
            }
          }
        }
        if (hrServiceFound) break;
      }

      // Listen for disconnection
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      _safeAddConnectionState(ConnectionState.connected);
      _reconnectionAttempts = 0;

      return true;
    } catch (e) {
      _safeAddConnectionState(ConnectionState.disconnected);
      return false;
    }
  }

  /// Parse HR measurement data according to BLE Heart Rate Profile specification
  /// Supports both 8-bit and 16-bit heart rate values
  /// Returns null if data is invalid
  int? _parseHeartRateData(List<int> data) {
    if (data.isEmpty) return null;

    final flags = data[0];
    final isUint16 = (flags & 0x01) != 0;

    if (isUint16 && data.length >= 3) {
      // 16-bit HR value (little-endian)
      return data[1] | (data[2] << 8);
    } else if (data.length >= 2) {
      // 8-bit HR value
      return data[1];
    }

    return null;
  }

  /// Handle unexpected disconnection
  /// Starts automatic reconnection attempts
  void _handleDisconnection() {
    _safeAddConnectionState(ConnectionState.reconnecting);
    _startReconnection();
  }

  /// Attempt to reconnect to last connected device
  /// Stops after maxReconnectionAttempts (30) attempts
  void _startReconnection() {
    _reconnectionTimer?.cancel();

    _reconnectionTimer = Timer.periodic(reconnectionInterval, (timer) async {
      if (_reconnectionAttempts >= maxReconnectionAttempts) {
        timer.cancel();
        _safeAddConnectionState(ConnectionState.disconnected);
        return;
      }

      _reconnectionAttempts++;

      if (_connectedDevice != null) {
        final success = await connectToDevice(_connectedDevice!);
        if (success) {
          timer.cancel();
        }
      } else {
        // No device to reconnect to
        timer.cancel();
        _safeAddConnectionState(ConnectionState.disconnected);
      }
    });
  }

  /// Disconnect from current device
  /// Cancels all subscriptions and stops reconnection attempts
  Future<void> disconnect() async {
    print('BLE: Disconnecting from device...');
    
    // Cancel subscriptions FIRST to stop receiving data
    _reconnectionTimer?.cancel();
    _heartRateSubscription?.cancel();
    _connectionSubscription?.cancel();
    _heartRateSubscription = null;
    _connectionSubscription = null;

    await _connectedDevice?.disconnect();
    _connectedDevice = null;

    _safeAddConnectionState(ConnectionState.disconnected);
    print('BLE: ✓ Disconnected');
  }

  /// Get the currently connected device
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Check if currently connected to a device
  /// Returns true if device is set AND connection state is connected
  bool get isConnected => 
      _connectedDevice != null && 
      _currentConnectionState == ConnectionState.connected;

  /// Attempt to reconnect to a device by its ID
  /// Used for auto-reconnecting to last connected device on app start
  /// Returns true if connection successful, false otherwise
  Future<bool> reconnectToDevice(String deviceId) async {
    return await scanAndReconnectToDevice(deviceId, scanTimeout: const Duration(seconds: 5));
  }

  /// Try to connect directly to a device by ID (for already-paired devices)
  /// Attempts to create a BluetoothDevice from the ID and connect
  /// Works for both paired and unpaired devices (if device ID is known)
  /// Optionally accepts deviceName to ensure it's set even if platformName is empty
  /// Returns true if connection successful, false otherwise
  Future<bool> connectToDeviceById(String deviceId, {String? deviceName}) async {
    try {
      // Try to create device from ID and connect directly
      // This works for already-paired devices and can also work for unpaired
      // devices if the device ID is known (e.g., from previous connection)
      final device = BluetoothDevice.fromId(deviceId);
      
      final success = await connectToDevice(device);
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Scan and reconnect to a device by ID
  /// Scans for devices and attempts to connect to the one matching the ID
  /// Returns true if connection successful, false otherwise
  Future<bool> scanAndReconnectToDevice(String deviceId, {Duration scanTimeout = const Duration(seconds: 5)}) async {
    // First try direct connection (for paired devices)
    // Try to get device name from preferences if available
    final directConnected = await connectToDeviceById(deviceId);
    if (directConnected) {
      return true;
    }

    try {
      _safeAddConnectionState(ConnectionState.scanning);

      // Start scan
      await FlutterBluePlus.startScan(
        timeout: scanTimeout,
      );
      print('BLE: Scan started for reconnect (timeout: ${scanTimeout.inSeconds}s)');

      BluetoothDevice? targetDevice;

      // Listen for scan results
      try {
        await for (final results in FlutterBluePlus.scanResults.timeout(scanTimeout + const Duration(seconds: 1))) {
          for (final result in results) {
            if (result.device.remoteId.toString() == deviceId) {
              targetDevice = result.device;
              break;
            }
          }
          if (targetDevice != null) break;
        }
      } on TimeoutException {
        // Timeout is expected
      }

      await FlutterBluePlus.stopScan();

      if (targetDevice == null) {
        _safeAddConnectionState(ConnectionState.disconnected);
        return false;
      }

      // Connect to found device
      return await connectToDevice(targetDevice);
    } catch (e) {
      await FlutterBluePlus.stopScan();
      _safeAddConnectionState(ConnectionState.disconnected);
      return false;
    }
  }

  /// Clean up resources
  /// Call this when the service is no longer needed
  /// NOTE: This should rarely be called - the service should persist for app lifetime
  void dispose() {
    // Cancel all subscriptions FIRST to stop receiving data
    // This prevents the "controller is closed" warnings
    _reconnectionTimer?.cancel();
    _heartRateSubscription?.cancel();
    _connectionSubscription?.cancel();
    _heartRateSubscription = null;
    _connectionSubscription = null;
    
    // Disconnect device if still connected
    if (_connectedDevice != null) {
      _connectedDevice?.disconnect();
      _connectedDevice = null;
    }
    
    // Close controllers (check if already closed to avoid errors)
    if (_heartRateController != null && !_heartRateController!.isClosed) {
      _heartRateController!.close();
      _heartRateController = null;
    }
    if (!_connectionStateController.isClosed) {
      _connectionStateController.close();
    }
    
    _currentConnectionState = ConnectionState.disconnected;
  }
}
