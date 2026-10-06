import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/avatar/editor/avatar_editor_controller.dart';
import 'package:frontend/features/avatar/widgets/avatar_editor.dart';

/// Set to a folder (--dart-define=AVATAR_RENDER_DIR=...) to also save phone-size screenshots.
const _dumpDir = String.fromEnvironment('AVATAR_RENDER_DIR');

const _look = AvatarConfig(
  hairStyle: 'bob',
  hairColor: Color(0xFF7F77DD),
  topStyle: 'hoodie',
  topColor: Color(0xFF10B981),
  bottomStyle: 'sweatpants',
  bottomColor: Color(0xFF334155),
  shoeStyle: 'sneakers',
  shoeColor: Color(0xFFF1F5F9),
  skinColor: Color(0xFFF5C49F),
);

Widget _app(AvatarEditorController controller, {GlobalKey? boundary}) => MaterialApp(
      theme: ThemeData(fontFamily: _dumpDir.isEmpty ? null : 'Editor'),
      home: Scaffold(
        body: RepaintBoundary(key: boundary, child: AvatarEditor(controller: controller)),
      ),
    );

/// Lets the thumbnails and the preview finish their real (non-fake) async work.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls [finder] into view (pills and swatches scroll sideways) and taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _loadRealFonts() async {
  Future<ByteData> bytes(String path) async => ByteData.sublistView(File(path).readAsBytesSync());
  final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  await (FontLoader('Editor')..addFont(bytes('C:/Windows/Fonts/segoeui.ttf'))).load();
  await (FontLoader('MaterialIcons')
        ..addFont(bytes('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')))
      .load();
}

Future<void> _screenshot(WidgetTester tester, GlobalKey boundary, String name) async {
  if (_dumpDir.isEmpty) return;
  await tester.runAsync(() async {
    final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dumpDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUp(() async {
    if (_dumpDir.isNotEmpty) await _loadRealFonts();
  });

  testWidgets('tabs, pills and thumbnails edit the avatar; undo and none work', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final controller = AvatarEditorController(initial: _look, gender: 'WOMAN');
    final boundary = GlobalKey();
    await tester.pumpWidget(_app(controller, boundary: boundary));
    await _settle(tester);
    await _screenshot(tester, boundary, 'editor_body');

    expect(find.text('Cuerpo'), findsOneWidget);
    expect(find.text('Accesorios'), findsOneWidget);
    expect(find.text('Complexión'), findsNothing, reason: 'body locked for women');

    await _tap(tester, find.text('Pelo'));
    await _settle(tester);
    expect(find.text('Peinado'), findsNothing, reason: 'one section: no pills');
    expect(find.text('Color del pelo'), findsOneWidget);
    await _screenshot(tester, boundary, 'editor_hair');

    await _tap(tester, find.text('Pixie'));
    await tester.pump();
    expect(controller.config.hairStyle, 'pixie');
    expect(controller.isDirty, isTrue);

    await tester.tap(find.byTooltip('Deshacer'));
    await tester.pump();
    expect(controller.config.hairStyle, 'bob');

    await _tap(tester, find.text('Ropa'));
    await _settle(tester);
    expect(find.text('Arriba'), findsOneWidget);
    expect(find.text('Calzado'), findsOneWidget);
    await _screenshot(tester, boundary, 'editor_clothes');

    await _tap(tester, find.text('Calzado'));
    await _settle(tester);
    expect(find.byIcon(Icons.block), findsOneWidget, reason: 'the none tile is an icon');
    await _tap(tester, find.text('Ninguno'));
    await tester.pump();
    expect(controller.config.shoeStyle, 'none');

    await _tap(tester, find.text('Cara'));
    await _settle(tester);
    await _screenshot(tester, boundary, 'editor_face');
  });

  testWidgets('a colour swatch recolours the avatar', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final controller = AvatarEditorController(initial: _look, gender: 'WOMAN');
    await tester.pumpWidget(_app(controller));
    await _tap(tester, find.text('Pelo'));
    await tester.pump();
    final colour = AvatarConfig.hairColors.first;
    await _tap(tester, find.bySemanticsLabel('Color #${colour.toARGB32().toRadixString(16).substring(2).toUpperCase()}'));
    await tester.pump();
    expect(controller.config.hairColor, colour);
  });

  testWidgets('the grid fits a large system text size without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final controller = AvatarEditorController(initial: _look, gender: 'NON_BINARY');
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(controller));
    expect(MediaQuery.textScalerOf(tester.element(find.text('Cuerpo'))).scale(10), 16);
    for (final tab in ['Cuerpo', 'Cara', 'Maquillaje', 'Pelo', 'Ropa', 'Accesorios']) {
      await _tap(tester, find.text(tab));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
}
