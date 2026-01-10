import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

/// About Screen
/// Displays app information, version, and links
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          'ABOUT',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),

            // App Icon
            Image.asset(
              'assets/images/app_icon_128.png',
              width: 96,
              height: 96,
            ),

            const SizedBox(height: 24),

            // App Name
            Text(
              AppStrings.appName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Version
            Text(
              '${AppStrings.version} 1.0.0',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 32),

            // Description
            Text(
              'A real-time heart rate zone monitoring application designed to help you train smarter by staying in your optimal heart rate zones. Connect to your Bluetooth heart rate monitor and track your heart rate with precision.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 32),

            // Compatibility Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compatible Devices',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Heart Zone Trainer works with any Bluetooth Low Energy (BLE) heart rate monitor, including:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCompatibilityItem('• Whoop (4.0 and newer)'),
                  _buildCompatibilityItem('• Polar (H10, H9, OH1, Verity Sense)'),
                  _buildCompatibilityItem('• Garmin (HRM-Pro, HRM-Dual, HRM-Run)'),
                  _buildCompatibilityItem('• Wahoo (TICKR, TICKR X, TICKR FIT)'),
                  _buildCompatibilityItem('• Coospo & Magene monitors'),
                  _buildCompatibilityItem('• Any device with BLE Heart Rate Service'),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Links
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () async {
                    final uri = Uri.parse('https://umairrsyedd.github.io/heart-zone-trainer-privacy/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Unable to open Privacy Policy'),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: AppColors.zone0,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  ' | ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    // Create mailto URI with pre-filled subject and body
                    final email = 'umairrsyedd@gmail.com';
                    final subject = Uri.encodeComponent('Heart Zone Trainer - Feedback');
                    final body = Uri.encodeComponent(
                      'Hi,\n\n'
                      'App Version: 1.0.0\n\n'
                      'Please share your feedback, suggestions, or report any issues:\n\n'
                      '[Your feedback here]\n\n'
                      'Thank you!',
                    );
                    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
                    
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No email app found. Please contact umairrsyedd@gmail.com'),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    'Send Feedback',
                    style: TextStyle(
                      color: AppColors.zone0,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 64),

            // Credits
            Text(
              'Designed for optimal fitness training',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '© 2026 Heart Zone Trainer',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompatibilityItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }
}
