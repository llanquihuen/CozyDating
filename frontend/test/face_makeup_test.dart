import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/avatar/components/face_makeup.dart';

/// Builds a premultiplied RGBA buffer from rows of codes: '.' transparent, 'K' black line,
/// 'G' brow green, 'W' white, 'M' mouth inside (dark red).
Uint8List grid(List<String> rows) {
  const colors = {
    'K': [12, 10, 14, 255],
    'G': [40, 215, 40, 255],
    'W': [245, 245, 240, 255],
    'M': [110, 40, 50, 255],
  };
  final out = Uint8List(rows.length * rows[0].length * 4);
  for (int y = 0; y < rows.length; y++) {
    for (int x = 0; x < rows[0].length; x++) {
      final c = colors[rows[y][x]];
      if (c != null) out.setRange((y * rows[0].length + x) * 4, (y * rows[0].length + x) * 4 + 4, c);
    }
  }
  return out;
}

int alphaAt(Uint8List rgba, int width, int x, int y) => rgba[(y * width + x) * 4 + 3];

void main() {
  const up = FaceMakeup.standingUp;

  test('eyeshadow sits right above the lid and never comes from the brow', () {
    final eye = grid([
      'GGG..',
      '.....',
      '.....',
      '.KKK.',
      '.KWK.',
    ]);
    final soft = FaceMakeup.eyeshadowTargets(eye, 5, 5, up: up, smoky: false);
    expect(soft.keys.map((i) => i ~/ 4).toSet(), {2 * 5 + 1, 2 * 5 + 2, 2 * 5 + 3});

    final smoky = FaceMakeup.eyeshadowTargets(eye, 5, 5, up: up, smoky: true);
    expect(smoky.keys.map((i) => i ~/ 4), contains(1 * 5 + 2)); // one pixel further up
    expect(smoky.keys.map((i) => i ~/ 4), isNot(contains(0 * 5 + 1))); // stops at the brow
  });

  test('a brow resting on the lid gets the shadow blended over its bottom row', () {
    final eye = grid([
      'GGG',
      'KKK',
    ]);
    final targets = FaceMakeup.eyeshadowTargets(eye, 3, 2, up: up, smoky: false);
    expect(targets.keys.map((i) => i ~/ 4).toSet(), {0, 1, 2});
    FaceMakeup.paint(eye, targets, const Color(0xFF9D5C8F));
    expect(alphaAt(eye, 3, 1, 0), 255); // still opaque: blended, not replaced
    expect(eye[1 * 4], greaterThan(40)); // red channel pulled toward the shadow colour
  });

  test('lipstick colours the outline, leaves the mouth inside, and bold adds a lower lip', () {
    final natural = grid(['KKKK', 'KMMK', '....']);
    FaceMakeup.paintLipstick(natural, 4, 3, up: up, color: const Color(0xFFC0304A), bold: false);
    expect(natural[0], greaterThan(100)); // outline turned red
    expect(natural.sublist((1 * 4 + 1) * 4, (1 * 4 + 1) * 4 + 3), [110, 40, 50]); // inside untouched
    expect(alphaAt(natural, 4, 0, 2), 0);

    final bold = grid(['KKKK', 'KMMK', '....']);
    FaceMakeup.paintLipstick(bold, 4, 3, up: up, color: const Color(0xFFC0304A), bold: true);
    expect(alphaAt(bold, 4, 0, 2), 255); // lower lip under the outline
  });

  test('mouths drawn with coloured lips and no outline get recoloured whole', () {
    final lips = Uint8List.fromList([232, 116, 101, 255]);
    FaceMakeup.paintLipstick(lips, 1, 1, up: up, color: const Color(0xFF5B8FD9), bold: false);
    expect(lips[2], greaterThan(101)); // pulled toward blue
  });
}
