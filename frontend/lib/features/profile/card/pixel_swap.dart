import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Swaps [child] for its new version with a pixel dissolve whenever [swapKey] changes: the old
/// picture breaks into ever bigger pixels, turns into the new one at its coarsest, and the new one
/// sharpens back. Used at the reveal, where the pixel-art character becomes the real person.
///
/// Without a picture to work from (first build, reduced motion, a renderer that cannot snapshot)
/// the swap is immediate.
class PixelSwap extends StatefulWidget {
  const PixelSwap({super.key, required this.swapKey, required this.child, this.borderRadius = 18});

  final Object swapKey;
  final Widget child;
  final double borderRadius;

  /// Columns of each step, as a share of the width: coarser and coarser, then back.
  static const List<double> outSteps = [1 / 4, 1 / 8, 1 / 16, 1 / 30];
  static const Duration stepDuration = Duration(milliseconds: 95);

  /// Total length of the dissolve.
  static Duration get duration => stepDuration * (outSteps.length * 2 + 1);

  @override
  State<PixelSwap> createState() => _PixelSwapState();
}

class _PixelSwapState extends State<PixelSwap> {
  final GlobalKey _boundary = GlobalKey();
  ui.Image? _old;
  ui.Image? _new;

  /// Index into the step sequence while dissolving; null when idle.
  int? _step;
  Timer? _timer;

  ui.Image? _snapshot() {
    try {
      final box = _boundary.currentContext?.findRenderObject();
      if (box is! RenderRepaintBoundary || !box.hasSize || box.size.isEmpty) return null;
      return box.toImageSync(pixelRatio: 1);
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(PixelSwap old) {
    super.didUpdateWidget(old);
    if (old.swapKey == widget.swapKey || MediaQuery.of(context).disableAnimations) return;
    final snap = _snapshot();
    if (snap == null) return;
    _stop();
    _old = snap;
    _step = 0;
    _timer = Timer.periodic(PixelSwap.stepDuration, (_) => _advance());
  }

  void _advance() {
    if (!mounted) return;
    final steps = PixelSwap.outSteps.length;
    final next = _step! + 1;
    // At the coarsest step the new child has been painted under the overlay: take its picture.
    if (next == steps) _new = _snapshot();
    if (next > steps * 2) {
      _stop();
      setState(() {});
      return;
    }
    setState(() => _step = next);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _step = null;
    _old?.dispose();
    _new?.dispose();
    _old = _new = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final steps = PixelSwap.outSteps.length;
    ui.Image? image;
    double? share;
    if (step != null) {
      if (step < steps) {
        image = _old;
        share = PixelSwap.outSteps[step];
      } else if (_new != null && step < steps * 2) {
        image = _new;
        share = PixelSwap.outSteps[steps * 2 - 1 - step];
      } else if (_new == null) {
        image = _old;
        share = PixelSwap.outSteps.last;
      }
    }
    return Stack(
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        if (image != null && share != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: CustomPaint(painter: _PixelatedPainter(image: image, columnShare: share)),
              ),
            ),
          ),
      ],
    );
  }
}

/// [image] drawn as big square pixels: about [columnShare] of its width in columns.
class _PixelatedPainter extends CustomPainter {
  _PixelatedPainter({required this.image, required this.columnShare});

  final ui.Image image;
  final double columnShare;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = (image.width * columnShare).round().clamp(4, image.width);
    final rows = (cols * image.height / image.width).round().clamp(4, image.height);
    // Downsample with smoothing (averaging colours), then blow up without it (hard pixels).
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, cols.toDouble(), rows.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final small = recorder.endRecording().toImageSync(cols, rows);
    canvas.drawImageRect(
      small,
      Rect.fromLTWH(0, 0, cols.toDouble(), rows.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.none,
    );
    small.dispose();
  }

  @override
  bool shouldRepaint(_PixelatedPainter old) => old.image != image || old.columnShare != columnShare;
}
