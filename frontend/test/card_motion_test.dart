import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/profile/card/card_entrance.dart';
import 'package:frontend/features/profile/card/pixel_swap.dart';
import 'package:frontend/features/profile/view/pixel_motion.dart';

final _pixelated =
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_PixelatedPainter');

Widget _face(bool real) => SizedBox(
      width: 120,
      height: 180,
      child: ColoredBox(color: real ? Colors.blue : Colors.green, child: Text(real ? 'real' : 'personaje')),
    );

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Center(child: child),
      ),
    );

void main() {
  testWidgets('the reveal dissolves the character into the real face through big pixels', (tester) async {
    await tester.pumpWidget(_host(PixelSwap(swapKey: false, child: _face(false))));
    expect(_pixelated, findsNothing);

    await tester.pumpWidget(_host(PixelSwap(swapKey: true, child: _face(true))));
    expect(find.text('real'), findsOneWidget, reason: 'the new face is there at once, under the pixels');
    expect(_pixelated, findsOneWidget);

    await tester.pump(PixelSwap.duration + const Duration(milliseconds: 200));
    expect(_pixelated, findsNothing, reason: 'sharp again at the end');
  });

  testWidgets('with reduced motion the swap is immediate', (tester) async {
    await tester.pumpWidget(_host(PixelSwap(swapKey: false, child: _face(false)), reduceMotion: true));
    await tester.pumpWidget(_host(PixelSwap(swapKey: true, child: _face(true)), reduceMotion: true));
    expect(_pixelated, findsNothing);
    expect(find.text('real'), findsOneWidget);
  });

  testWidgets('a new card is dealt in and settles; reduced motion shows it still', (tester) async {
    await tester.pumpWidget(_host(CardEntrance(child: _face(false))));
    final start =
        tester.widget<Opacity>(find.descendant(of: find.byType(CardEntrance), matching: find.byType(Opacity)));
    expect(start.opacity, lessThan(0.5));
    await tester.pumpAndSettle();
    final end = tester.widget<Opacity>(find.descendant(of: find.byType(CardEntrance), matching: find.byType(Opacity)));
    expect(end.opacity, 1);

    await tester.pumpWidget(_host(CardEntrance(key: UniqueKey(), child: _face(false)), reduceMotion: true));
    final still =
        tester.widget<Opacity>(find.descendant(of: find.byType(CardEntrance), matching: find.byType(Opacity)));
    expect(still.opacity, 1);
  });

  testWidgets('idle motion steps by whole pixels and stops with reduced motion', (tester) async {
    Offset offset() {
      final v = tester
          .widget<Transform>(find.descendant(of: find.byType(StepBob), matching: find.byType(Transform)))
          .transform
          .getTranslation();
      return Offset(v.x, v.y);
    }

    await tester.pumpWidget(_host(const StepBob(step: 3, period: Duration(milliseconds: 500), child: Text('bob'))));
    expect(offset(), Offset.zero);
    await tester.pump(const Duration(milliseconds: 520));
    expect(offset(), const Offset(0, -3));

    await tester.pumpWidget(_host(
      const Column(children: [
        StepBob(step: 3, child: Text('bob')),
        SizedBox(
            width: 100,
            height: 100,
            child: SceneParticles(kind: ParticleKind.fireflies, color: Colors.amber, scale: 3)),
      ]),
      reduceMotion: true,
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(offset(), Offset.zero);
    expect(find.byType(CustomPaint).evaluate().where((e) => (e.widget as CustomPaint).painter != null), isEmpty,
        reason: 'no particles');
  });
}
