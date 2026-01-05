import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../data/models/monitoring_state.dart' as monitoring;
import '../../../../providers/monitoring_provider.dart';

/// Connection status indicator widget with pill/chip design
/// Shows colored dot with connection state text in a tappable pill
class ConnectionStatus extends ConsumerWidget {
  const ConnectionStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitoringState = ref.watch(monitoringNotifierProvider);
    final connectionState = monitoringState.connectionState;
    final deviceName = monitoringState.connectedDeviceName;
    final isConnected = connectionState == monitoring.ConnectionState.connected;
    final isReceivingData = monitoringState.currentBPM != null;

    Color statusColor;
    String statusText;
    Color backgroundColor;

    switch (connectionState) {
      case monitoring.ConnectionState.connected:
        if (isReceivingData) {
          statusColor = AppColors.success;
          backgroundColor = AppColors.success.withOpacity(0.15);
          // Show just device name when connected and receiving data
          statusText = deviceName != null && deviceName.isNotEmpty
              ? deviceName
              : AppStrings.connected;
        } else {
          statusColor = AppColors.warning;
          backgroundColor = AppColors.warning.withOpacity(0.15);
          statusText = 'No HR Data';
        }
        break;
      case monitoring.ConnectionState.reconnecting:
        statusColor = AppColors.warning;
        backgroundColor = AppColors.warning.withOpacity(0.15);
        statusText = AppStrings.reconnecting;
        break;
      case monitoring.ConnectionState.connecting:
        statusColor = AppColors.warning;
        backgroundColor = AppColors.warning.withOpacity(0.15);
        statusText = AppStrings.connecting;
        break;
      case monitoring.ConnectionState.scanning:
        statusColor = Colors.blue;
        backgroundColor = Colors.blue.withOpacity(0.15);
        statusText = AppStrings.scanning;
        break;
      case monitoring.ConnectionState.disconnected:
      default:
        statusColor = AppColors.error;
        backgroundColor = AppColors.error.withOpacity(0.15);
        statusText = AppStrings.disconnected;
        break;
    }

    // Build the pill content
    Widget pillContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status dot with optional pulsing animation
          _StatusDot(
            color: statusColor,
            isConnected: isConnected && isReceivingData,
          ),
          const SizedBox(width: 8),
          // Status text - centered with ellipsis for long text
          Flexible(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          // Show chevron icon to indicate clickability in all states
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 16,
            color: statusColor.withOpacity(0.7),
          ),
        ],
      ),
    );

    // Make it clickable in all states - users can always navigate to Settings
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/settings'),
        borderRadius: BorderRadius.circular(20),
        splashColor: statusColor.withOpacity(0.2),
        highlightColor: statusColor.withOpacity(0.1),
        child: pillContent,
      ),
    );
  }
}

/// Status dot widget with optional pulsing animation for connected state
class _StatusDot extends StatefulWidget {
  final Color color;
  final bool isConnected;

  const _StatusDot({
    required this.color,
    required this.isConnected,
  });

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isConnected) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isConnected && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: widget.isConnected
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(_animation.value * 0.6),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: widget.color.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
          ),
        );
      },
    );
  }
}
