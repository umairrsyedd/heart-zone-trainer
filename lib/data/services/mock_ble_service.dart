import 'dart:async';
import 'dart:math';
import '../../data/models/monitoring_state.dart';

/// Mock BLE Service for testing without a physical device
/// Generates simulated heart rate data
class MockBLEService {
  final _heartRateController = StreamController<int>.broadcast();
  final _connectionStateController =
      StreamController<ConnectionState>.broadcast();

  Timer? _heartRateTimer;
  bool _isConnected = false;
  bool _isScanning = false;
  final Random _random = Random();

  // Simulated heart rate parameters
  int _baseBPM = 70;
  int _targetZone = 2; // Start in zone 2
  int _bpmVariation = 5; // ±5 BPM variation

  /// Stream of heart rate measurements (BPM values)
  Stream<int> get heartRateStream => _heartRateController.stream;

  /// Stream of connection state changes
  Stream<ConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// Simulate scanning for devices
  Future<List<Map<String, dynamic>>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _connectionStateController.add(ConnectionState.scanning);
    _isScanning = true;

    // Simulate scan delay
    await Future.delayed(const Duration(seconds: 2));

    _isScanning = false;
    _connectionStateController.add(ConnectionState.disconnected);

    // Return mock device
    return [
      {
        'id': 'mock-whoop-device-001',
        'name': 'WHOOP 4.0-MOCK',
        'rssi': -60,
      }
    ];
  }

  /// Simulate connecting to a device
  Future<bool> connectToDevice(Map<String, dynamic> device) async {
    try {
      _connectionStateController.add(ConnectionState.connecting);

      // Simulate connection delay
      await Future.delayed(const Duration(seconds: 1));

      _isConnected = true;
      _connectionStateController.add(ConnectionState.connected);

      // Start generating heart rate data
      _startHeartRateGeneration();

      return true;
    } catch (e) {
      _connectionStateController.add(ConnectionState.disconnected);
      return false;
    }
  }

  /// Start generating simulated heart rate data
  void _startHeartRateGeneration() {
    _heartRateTimer?.cancel();

    // Generate heart rate every second
    _heartRateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }

      // Simulate realistic heart rate variation
      // Gradually change target zone every 30-60 seconds
      if (_random.nextDouble() < 0.02) {
        // 2% chance to change zone each second
        _targetZone = _random.nextInt(6); // Zones 0-5
        _updateBaseBPMForZone(_targetZone);
      }

      // Add small random variation
      final variation = _random.nextInt(_bpmVariation * 2 + 1) - _bpmVariation;
      final currentBPM = (_baseBPM + variation).clamp(40, 220);

      _heartRateController.add(currentBPM);
    });
  }

  /// Update base BPM to match target zone
  /// Uses typical zone ranges for a 30-year-old (max HR ~190, resting ~60)
  void _updateBaseBPMForZone(int zone) {
    switch (zone) {
      case 0: // Rest
        _baseBPM = 60 + _random.nextInt(10); // 60-70
        break;
      case 1: // Warm Up
        _baseBPM = 100 + _random.nextInt(15); // 100-115
        break;
      case 2: // Fat Burn
        _baseBPM = 120 + _random.nextInt(15); // 120-135
        break;
      case 3: // Cardio
        _baseBPM = 140 + _random.nextInt(15); // 140-155
        break;
      case 4: // Hard
        _baseBPM = 160 + _random.nextInt(15); // 160-175
        break;
      case 5: // Max
        _baseBPM = 180 + _random.nextInt(10); // 180-190
        break;
      default:
        _baseBPM = 70;
    }
  }

  /// Simulate disconnecting from device
  Future<void> disconnect() async {
    _heartRateTimer?.cancel();
    _isConnected = false;
    _connectionStateController.add(ConnectionState.disconnected);
  }

  /// Get the currently connected device
  Map<String, dynamic>? get connectedDevice =>
      _isConnected ? {'id': 'mock-device', 'name': 'WHOOP 4.0-MOCK'} : null;

  /// Check if currently connected to a device
  bool get isConnected => _isConnected;

  /// Clean up resources
  void dispose() {
    _heartRateTimer?.cancel();
    _heartRateController.close();
    _connectionStateController.close();
  }
}

