import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';

/// Navigation drawer widget
/// Provides navigation to all app screens
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.divider,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/app_icon_32.png',
                  width: 32,
                  height: 32,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to icon if image not found
                    return const Icon(
                      Icons.favorite,
                      color: AppColors.zone0,
                      size: 32,
                    );
                  },
                ),
                const SizedBox(width: 12),
                Text(
                  AppStrings.appName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.settings,
                  label: AppStrings.settings,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
                _DrawerItem(
                  icon: Icons.tune,
                  label: AppStrings.zoneSettings,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/zone-settings');
                  },
                ),
                _DrawerItem(
                  icon: Icons.notifications,
                  label: AppStrings.alertSettings,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/alert-management');
                  },
                ),
                _DrawerItem(
                  icon: Icons.info,
                  label: AppStrings.about,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/about');
                  },
                ),
              ],
            ),
          ),

          // Version Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.divider,
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual drawer menu item
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppColors.textPrimary,
        size: 24,
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      hoverColor: AppColors.background,
    );
  }
}
