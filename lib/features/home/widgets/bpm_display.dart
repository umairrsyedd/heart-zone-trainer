import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/monitoring_provider.dart';

/// BPM display widget showing current heart rate
/// Shows "--" when no data is available
class BPMDisplay extends ConsumerWidget {
  const BPMDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitoringState = ref.watch(monitoringNotifierProvider);
    final bpm = monitoringState.currentBPM;
    final isReconnecting = monitoringState.shouldShowReconnecting;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // BPM Number
        Text(
          isReconnecting
              ? '--'
              : bpm != null
                  ? bpm.toString()
                  : '--',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        // BPM Label
        Text(
          'BPM',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
        // Reconnecting message
        if (isReconnecting) ...[
          const SizedBox(height: 8),
          Text(
            'Reconnecting...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
