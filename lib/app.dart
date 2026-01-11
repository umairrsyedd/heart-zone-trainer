import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/about/about_screen.dart';
import 'features/alert_management/alert_management_screen.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/zone_settings/zone_settings_screen.dart';
import 'providers/monitoring_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/preferences_provider.dart';

/// Main app widget with routing
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  bool _wasMonitoringBeforeBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // App went to background - check if background monitoring is enabled
      _handleAppPaused();
    } else if (state == AppLifecycleState.detached) {
      // App is being terminated - always remove notification
      _handleAppTerminated();
    } else if (state == AppLifecycleState.resumed) {
      // App came back to foreground - restart monitoring if needed
      _handleAppResumed();
    }
  }

  void _handleAppPaused() {
    // Get user preferences to check background monitoring setting
    final prefsAsync = ref.read(preferencesNotifierProvider);
    final prefs = prefsAsync.value;
    
    // Get current monitoring state
    final monitoringState = ref.read(monitoringNotifierProvider);
    
    // Track if monitoring was active before going to background
    _wasMonitoringBeforeBackground = monitoringState.isMonitoring && monitoringState.isConnected;
    
    // If background monitoring is disabled, stop monitoring and notification
    if (prefs != null && 
        !prefs.backgroundMonitoringEnabled && 
        monitoringState.isMonitoring && 
        monitoringState.isConnected) {
      // Stop monitoring (this will also stop the notification)
      final monitoringNotifier = ref.read(monitoringNotifierProvider.notifier);
      monitoringNotifier.stopMonitoring();
      
      if (kDebugMode) {
        print('App: Background monitoring disabled - stopped monitoring and notification');
      }
    }
    // If background monitoring is enabled, keep monitoring and notification active
  }

  void _handleAppTerminated() {
    // Always remove notification when app is terminated
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.stopNotification();
  }

  void _handleAppResumed() {
    // App came back to foreground
    final monitoringState = ref.read(monitoringNotifierProvider);
    final prefsAsync = ref.read(preferencesNotifierProvider);
    final prefs = prefsAsync.value;
    
    // If monitoring was stopped due to background monitoring being disabled,
    // restart it now that we're back in foreground
    if (_wasMonitoringBeforeBackground && 
        monitoringState.isConnected && 
        !monitoringState.isMonitoring) {
      // Restart monitoring (fire and forget - it's async but we don't need to wait)
      final monitoringNotifier = ref.read(monitoringNotifierProvider.notifier);
      monitoringNotifier.startMonitoring();
      
      if (kDebugMode) {
        print('App: Resumed - restarted monitoring (was active before background)');
      }
    } else if (monitoringState.isMonitoring && monitoringState.isConnected) {
      // Monitoring is still active - refresh notification
      final notificationService = ref.read(notificationServiceProvider);
      if (monitoringState.currentBPM != null && monitoringState.currentZone != null) {
        // Re-show with current data
        notificationService.refreshNotification(
          bpm: monitoringState.currentBPM!,
          zone: monitoringState.currentZone!,
          zoneName: _getZoneName(monitoringState.currentZone!),
          deviceName: monitoringState.connectedDeviceName ?? 'HR Monitor',
        );
      } else {
        // Connected but no HR data yet
        notificationService.updateConnectedNoData(
          deviceName: monitoringState.connectedDeviceName ?? 'HR Monitor',
        );
      }
    }
    
    // Reset flag
    _wasMonitoringBeforeBackground = false;
  }

  String _getZoneName(int zone) {
    return AppStrings.getZoneName(zone);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heart Zone Trainer',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/zone-settings': (context) => const ZoneSettingsScreen(),
        '/alert-management': (context) => const AlertManagementScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/about': (context) => const AboutScreen(),
      },
    );
  }
}
