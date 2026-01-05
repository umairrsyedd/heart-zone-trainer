import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/about/about_screen.dart';
import 'features/alert_management/alert_management_screen.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/zone_settings/zone_settings_screen.dart';

/// Main app widget with routing
class App extends StatelessWidget {
  const App({super.key});

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
