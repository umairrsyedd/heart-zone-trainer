import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/zone_boundary.dart';
import '../../../../providers/monitoring_provider.dart';

/// Animated heart widget that pulses with heart rate
/// Changes color based on current zone
/// Always displays when connected - no pause functionality
class AnimatedHeart extends ConsumerWidget {
  const AnimatedHeart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitoringState = ref.watch(monitoringNotifierProvider);
    final bpm = monitoringState.currentBPM;
    final zone = monitoringState.currentZone;
    final isConnected = monitoringState.isConnected;

    // Calculate animation duration based on BPM
    // 60 BPM = 1 beat per second = 1000ms duration
    final beatDuration = bpm != null && bpm > 0
        ? Duration(milliseconds: (60000 / bpm).round())
        : const Duration(seconds: 1);

    // Determine heart color based on state
    Color heartColor;
    if (zone != null) {
      heartColor = ZoneInfo.values.firstWhere(
        (z) => z.number == zone,
        orElse: () => ZoneInfo.zone0,
      ).color;
    } else if (isConnected) {
      heartColor = ZoneInfo.zone0.color; // Default color while waiting for data
    } else {
      heartColor = AppColors.textSecondary; // Grey when disconnected
    }

    // Heart animates when connected and receiving data
    final shouldAnimate = isConnected && bpm != null && bpm > 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Heart icon with beat animation
        if (shouldAnimate)
          _PulsingHeart(
            color: heartColor,
            duration: beatDuration,
          )
        else
          Icon(
            Icons.favorite,
            size: 100, // Slightly smaller for better fit
            color: heartColor.withOpacity(isConnected ? 0.5 : 0.3),
          ),

        // Reconnecting indicator
        if (monitoringState.shouldShowReconnecting)
          Positioned(
            bottom: 0,
            child: Text(
              'Reconnecting...',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// Internal widget for pulsing heart animation
class _PulsingHeart extends StatefulWidget {
  final Color color;
  final Duration duration;

  const _PulsingHeart({
    required this.color,
    required this.duration,
  });

  @override
  State<_PulsingHeart> createState() => _PulsingHeartState();
}

class _PulsingHeartState extends State<_PulsingHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(_PulsingHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  void _setupAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 80,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Icon(
            Icons.favorite,
            size: 100, // Slightly smaller for better fit
            color: widget.color,
          ),
        );
      },
    );
  }
}
