import 'package:flutter/material.dart';

/// A new card arriving: it is dealt in from below with a spring (scaling up and straightening),
/// then a holographic shine crosses it once. Plays once when first built; nothing moves when the
/// system asks for reduced motion.
class CardEntrance extends StatefulWidget {
  const CardEntrance({super.key, required this.child, this.shineColor = Colors.white, this.borderRadius = 18});

  final Widget child;

  /// Tint of the shine band (the card's accent).
  final Color shineColor;
  final double borderRadius;

  static const Duration dealDuration = Duration(milliseconds: 800);
  static const Duration shineDuration = Duration(milliseconds: 900);

  @override
  State<CardEntrance> createState() => _CardEntranceState();
}

class _CardEntranceState extends State<CardEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CardEntrance.dealDuration + CardEntrance.shineDuration,
  );

  late final Animation<double> _deal = CurvedAnimation(
    parent: _controller,
    curve: Interval(0, _dealShare, curve: Curves.easeOutBack),
  );
  late final Animation<double> _shine = CurvedAnimation(
    parent: _controller,
    curve: Interval(_dealShare, 1, curve: Curves.easeInOut),
  );

  static final double _dealShare = CardEntrance.dealDuration.inMilliseconds /
      (CardEntrance.dealDuration + CardEntrance.shineDuration).inMilliseconds;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward();
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
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final d = _deal.value;
        final s = _shine.value;
        final showShine = _controller.isAnimating && s > 0 && s < 1;
        return Opacity(
          opacity: (0.2 + d * 0.8).clamp(0, 1),
          child: FractionalTranslation(
            translation: Offset(0, (1 - d) * 0.6),
            child: Transform.rotate(
              angle: (1 - d) * -0.17,
              child: Transform.scale(
                scale: 0.82 + 0.18 * d,
                child: Stack(
                  children: [
                    child!,
                    if (showShine)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(widget.borderRadius),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1.0 + s * 3.2 - 1.0, -1),
                                  end: Alignment(-1.0 + s * 3.2, 1),
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.38),
                                    widget.shineColor.withValues(alpha: 0.32),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                  stops: const [0.3, 0.48, 0.55, 0.72],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
