import 'package:flutter/material.dart';

/// A full-screen vignette overlay that progressively turns red and pulses
/// when the dungeon expedition timer drops to 15 seconds or less.
class DungeonDangerVignetteOverlay extends StatefulWidget {
  final int secondsRemaining;
  final int triggerSeconds;

  const DungeonDangerVignetteOverlay({
    super.key,
    required this.secondsRemaining,
    this.triggerSeconds = 15,
  });

  @override
  State<DungeonDangerVignetteOverlay> createState() =>
      _DungeonDangerVignetteOverlayState();
}

class _DungeonDangerVignetteOverlayState
    extends State<DungeonDangerVignetteOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _adjustPulseSpeed();
  }

  @override
  void didUpdateWidget(covariant DungeonDangerVignetteOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.secondsRemaining != widget.secondsRemaining) {
      _adjustPulseSpeed();
    }
  }

  void _adjustPulseSpeed() {
    if (!mounted) return;
    final progress = _calculateProgress();
    // Pulse speeds up from 700ms down to 350ms as time runs out
    final newDurationMs = (700 - 350 * progress).round().clamp(300, 1000);
    if (_pulseController.duration?.inMilliseconds != newDurationMs) {
      _pulseController.duration = Duration(milliseconds: newDurationMs);
    }
  }

  double _calculateProgress() {
    if (widget.secondsRemaining > widget.triggerSeconds) return 0.0;
    if (widget.secondsRemaining <= 0) return 1.0;
    return ((widget.triggerSeconds - widget.secondsRemaining) /
            widget.triggerSeconds)
        .clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.secondsRemaining > widget.triggerSeconds) {
      return const SizedBox.shrink();
    }

    final progress = _calculateProgress();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = _pulseController.value;

          // Center alpha grows from 0.04 up to 0.24
          final centerAlpha = (0.04 + 0.16 * progress + 0.05 * pulse * (progress + 0.2))
              .clamp(0.0, 0.40);

          // Edge alpha grows from 0.22 up to 0.75
          final edgeAlpha = (0.22 + 0.43 * progress + 0.12 * pulse)
              .clamp(0.0, 0.85);

          // Screen edge border warning
          final borderAlpha = (0.25 + 0.50 * progress + 0.20 * pulse)
              .clamp(0.0, 0.95);
          final borderWidth = 2.0 + 3.5 * progress;

          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: borderAlpha),
                width: borderWidth,
              ),
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.88,
                colors: [
                  Colors.red.withValues(alpha: centerAlpha),
                  Colors.red.shade900.withValues(alpha: edgeAlpha),
                ],
                stops: const [0.25, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}
