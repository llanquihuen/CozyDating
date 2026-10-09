import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Idle motion for pixel art: whole steps on a timer, never smooth tweens or fractional scales
/// (they smear the pixels). Everything here stops when the system asks for reduced motion and
/// while its route is hidden (TickerMode off).

/// Moves [child] up by [step] logical pixels every other beat: a breathing or bobbing loop.
class StepBob extends StatefulWidget {
  const StepBob({
    super.key,
    required this.child,
    required this.step,
    this.period = const Duration(milliseconds: 700),
    this.delay = Duration.zero,
  });

  final Widget child;

  /// How far it moves: one sprite pixel at the current scale.
  final double step;
  final Duration period;

  /// Offsets this bob from others on the same screen.
  final Duration delay;

  @override
  State<StepBob> createState() => _StepBobState();
}

class _StepBobState extends State<StepBob> {
  Timer? _timer;
  Timer? _start;
  bool _up = false;

  void _sync(bool run) {
    if (run == (_timer != null || _start != null)) return;
    _timer?.cancel();
    _start?.cancel();
    _timer = _start = null;
    if (!run) {
      _up = false;
      return;
    }
    _start = Timer(widget.delay, () {
      _start = null;
      _timer = Timer.periodic(widget.period, (_) {
        if (mounted) setState(() => _up = !_up);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _start?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _sync(TickerMode.valuesOf(context).enabled && !MediaQuery.of(context).disableAnimations);
    return Transform.translate(offset: Offset(0, _up ? -widget.step : 0), child: widget.child);
  }
}

/// How a theme's particles behave.
enum ParticleKind {
  /// Blinking dots that drift a little (fireflies).
  fireflies,

  /// Twinkling sparks in place (stars, magic).
  sparkles,

  /// Small hearts rising.
  hearts,

  /// Leaves or petals falling and swaying.
  leaves,

  /// Slow dust motes in the light.
  dust,
}

/// Theme particles over a card scene, drawn as square pixels of the scene's [scale] at ~12 fps.
class SceneParticles extends StatefulWidget {
  const SceneParticles({super.key, required this.kind, required this.color, required this.scale, this.count = 14});

  final ParticleKind kind;
  final Color color;
  final int scale;
  final int count;

  /// The particles that suit each card theme.
  static ParticleKind kindFor(String themeId) => switch (themeId) {
        'forest' => ParticleKind.fireflies,
        'mystic' || 'arcade' || 'metal' => ParticleKind.sparkles,
        'coquette' => ParticleKind.hearts,
        'matcha' || 'coast' => ParticleKind.leaves,
        _ => ParticleKind.dust,
      };

  @override
  State<SceneParticles> createState() => _SceneParticlesState();
}

class _SceneParticlesState extends State<SceneParticles> {
  static const Duration _frame = Duration(milliseconds: 83);
  final ValueNotifier<int> _tick = ValueNotifier(0);
  Timer? _timer;

  void _sync(bool run) {
    if (run == (_timer != null)) return;
    _timer?.cancel();
    _timer = run ? Timer.periodic(_frame, (_) => _tick.value++) : null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = TickerMode.valuesOf(context).enabled && !MediaQuery.of(context).disableAnimations;
    _sync(run);
    if (!run) return const SizedBox.expand();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ParticlePainter(
          tick: _tick,
          kind: widget.kind,
          color: widget.color,
          scale: widget.scale.toDouble(),
          count: widget.count,
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(
      {required this.tick, required this.kind, required this.color, required this.scale, required this.count})
      : super(repaint: tick);

  final ValueNotifier<int> tick;
  final ParticleKind kind;
  final Color color;
  final double scale;
  final int count;

  static const List<String> _heart = ['.X.X.', 'XXXXX', '.XXX.', '..X..'];

  @override
  void paint(Canvas canvas, Size size) {
    final t = tick.value * 0.083; // seconds
    final rnd = math.Random(7);
    final paint = Paint();
    // Snap to the scene's pixel grid.
    double snap(double v) => (v / scale).floorToDouble() * scale;
    void dot(double x, double y, double alpha, [double cells = 1]) {
      paint.color = color.withValues(alpha: alpha.clamp(0, 1));
      canvas.drawRect(Rect.fromLTWH(snap(x), snap(y), scale * cells, scale * cells), paint);
    }

    for (var i = 0; i < count; i++) {
      final bx = rnd.nextDouble() * size.width;
      final by = rnd.nextDouble() * size.height;
      final phase = rnd.nextDouble() * 6.28;
      final speed = 0.6 + rnd.nextDouble() * 0.8;
      switch (kind) {
        case ParticleKind.fireflies:
          final x = bx + math.sin(t * 0.7 * speed + phase) * 10 * scale / 3;
          final y = by * 0.75 + size.height * 0.2 + math.cos(t * 0.9 * speed + phase) * 6 * scale / 3;
          final glow = math.sin(t * 2.6 * speed + phase);
          if (glow > -0.3) {
            dot(x - scale, y, 0.25 * (glow + 0.3));
            dot(x + scale, y, 0.25 * (glow + 0.3));
            dot(x, y - scale, 0.25 * (glow + 0.3));
            dot(x, y + scale, 0.25 * (glow + 0.3));
            dot(x, y, 0.55 + 0.45 * glow);
          }
        case ParticleKind.sparkles:
          final on = math.sin(t * 2.2 * speed + phase);
          if (on > 0.2) {
            final y = by * 0.7;
            dot(bx, y, on);
            if (on > 0.75) {
              dot(bx - scale, y, on * 0.5);
              dot(bx + scale, y, on * 0.5);
              dot(bx, y - scale, on * 0.5);
              dot(bx, y + scale, on * 0.5);
            }
          }
        case ParticleKind.hearts:
          final travel = size.height * 0.8;
          final y = size.height - ((t * 9 * speed * scale + by) % travel);
          final x = bx + math.sin(t * speed + phase) * 4 * scale;
          final alpha = (1 - (size.height - y) / travel) * 0.8;
          for (var row = 0; row < _heart.length; row++) {
            for (var col = 0; col < 5; col++) {
              if (_heart[row][col] == 'X') dot(x + col * scale, y + row * scale, alpha);
            }
          }
        case ParticleKind.leaves:
          final y = (t * 10 * speed * scale + by) % size.height;
          final x = bx + math.sin(t * 1.3 * speed + phase) * 6 * scale;
          dot(x, y, 0.75);
          dot(x + scale, y + scale, 0.55);
        case ParticleKind.dust:
          final y = by - ((t * 2.5 * speed * scale) % (size.height * 0.6));
          final x = bx + math.sin(t * 0.5 * speed + phase) * 5 * scale;
          dot(x, y < 0 ? y + size.height * 0.6 : y, 0.35 + 0.25 * math.sin(t * 1.7 + phase));
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.kind != kind || old.color != color || old.scale != scale || old.count != count;
}
