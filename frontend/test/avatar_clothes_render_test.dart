import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_catalog.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/avatar/components/modular_avatar_component.dart';

/// Set to a folder (--dart-define=AVATAR_RENDER_DIR=...) to also save the renders as PNGs.
const _dumpDir = String.fromEnvironment('AVATAR_RENDER_DIR');

Future<Uint8List> _render(AvatarConfig config, String name,
    {AvatarDirection direction = AvatarDirection.south, bool sitting = false, String? lyingView}) async {
  final avatar = ModularAvatarComponent(config: config, direction: direction, isSitting: sitting);
  await avatar.onLoad();
  final w = lyingView == null ? 64 : 160;
  if (lyingView != null) {
    avatar.lieDown(LyingPose(
      view: lyingView,
      mirror: false,
      under: false,
      barefoot: false, // lying off-bed keeps the shoes on
      canvasOrigin: ui.Offset.zero,
      bedWidth: 160,
      scale: 1,
    ));
  }
  final recorder = ui.PictureRecorder();
  avatar.render(ui.Canvas(recorder));
  final image = await recorder.endRecording().toImage(w, 128);
  if (_dumpDir.isNotEmpty) {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dumpDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  }
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return bytes!.buffer.asUint8List();
}

void main() {
  final garments = [
    for (final item in AvatarCatalog.items)
      if (const {AvatarCatalog.top, AvatarCatalog.bottom, AvatarCatalog.shoes}.contains(item.slot) &&
          !const {'jacket', 'jeans', 'boots'}.contains(item.id))
        item,
  ];

  test('every fitted garment ships its own lying views (else the jacket/jeans fallback is drawn)', () {
    for (final item in garments) {
      final folder = const {
        AvatarCatalog.top: 'tops',
        AvatarCatalog.bottom: 'bottoms',
        AvatarCatalog.shoes: 'shoes',
      }[item.slot];
      for (final body in item.fits) {
        for (final v in ['A', 'B']) {
          final path = 'assets/images/OCTOPLAYER/Avatar/lying/$folder/${item.id}_${body}_lie$v.png';
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
    }
  });

  testWidgets('every fitted garment is drawn on its bodies: standing, from behind, sitting and lying',
      (tester) async {
    await tester.runAsync(() async {
      for (final body in AvatarCatalog.bodyTypes) {
        final bare = AvatarConfig(bodyType: body, hairStyle: 'none', topStyle: 'none', bottomStyle: 'none');
        final poses = <String, Future<Uint8List> Function(AvatarConfig, String)>{
          'S': (c, n) => _render(c, n),
          'N': (c, n) => _render(c, n, direction: AvatarDirection.north),
          'SE_sit': (c, n) => _render(c, n, direction: AvatarDirection.southEast, sitting: true),
          'NW_sit': (c, n) => _render(c, n, direction: AvatarDirection.northWest, sitting: true),
          'lieA': (c, n) => _render(c, n, lyingView: 'A'),
        };
        final bareRenders = {
          for (final e in poses.entries) e.key: await e.value(bare, '${body}_bare_${e.key}'),
        };
        for (final item in garments.where((g) => g.fits.contains(body))) {
          final dressed = switch (item.slot) {
            AvatarCatalog.top => bare.copyWith(topStyle: item.id),
            AvatarCatalog.bottom => bare.copyWith(bottomStyle: item.id),
            _ => bare.copyWith(shoeStyle: item.id),
          };
          for (final e in poses.entries) {
            final render = await e.value(dressed, '${body}_${item.id}_${e.key}');
            expect(render, isNot(equals(bareRenders[e.key])), reason: '${item.id} on $body, ${e.key}');
          }
        }
      }
    });
  });
}
