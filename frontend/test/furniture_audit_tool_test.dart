// Furniture audit tool, skipped unless AUDIT_DIR is set: every catalog item in its 4 rotations
// (rot0 top, rot1 right, rot2 left, rot3 bottom; wall items north, west and north-high), placed by
// the real game on an empty room with its footprint outlined. Writes AUDIT_DIR/<id>.png and
// _meta.tsv (read by CreateSprites/furniture_gen/audit_files.py). AUDIT_ONLY=id,id limits the run.
//
//   AUDIT_DIR=/tmp/audit flutter test test/furniture_audit_tool_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/furniture_item.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/core/services/furniture_catalog_service.dart';
import 'package:frontend/features/lobby/games/cozy_room_game.dart';
import 'package:frontend/features/lobby/utils/isometric_coords.dart';

const _spots = [(1.0, 1.0), (5.0, 1.0), (1.0, 5.0), (5.0, 5.0)];

(double, double) _size(FurnitureCatalogItem item) {
  final f = item.footprint;
  if (f == '0.5x0.5') return (0.5, 0.5);
  final m = RegExp(r'^(\d)x(\d)$').firstMatch(f);
  if (m == null) return (1, 1);
  return (double.parse(m.group(1)!), double.parse(m.group(2)!));
}

List<PlacedFurnitureConfig> _placements(FurnitureCatalogItem item) {
  final out = <PlacedFurnitureConfig>[];
  if (item.isWallItem || item.footprint.startsWith('wall')) {
    out.add(PlacedFurnitureConfig(id: '${item.id}_n', typeName: item.id, gridX: 3, gridY: 0, gridWidth: 1, gridHeight: 1));
    out.add(PlacedFurnitureConfig(id: '${item.id}_w', typeName: item.id, gridX: 0, gridY: 3, gridWidth: 1, gridHeight: 1));
    out.add(PlacedFurnitureConfig(
        id: '${item.id}_hn', typeName: item.id, gridX: 5, gridY: 0, gridWidth: 1, gridHeight: 1, wallHeightLevel: 'high'));
    return out;
  }
  final surface = item.isSurfaceItem || item.footprint == 'surface';
  final (w, h) = _size(item);
  for (var r = 0; r < 4; r++) {
    final (gx, gy) = _spots[r];
    if (surface) {
      out.add(PlacedFurnitureConfig(id: 'parent_$r', typeName: 'cube_1x1', gridX: gx, gridY: gy, gridWidth: 1, gridHeight: 1));
      out.add(PlacedFurnitureConfig(
          id: '${item.id}_$r', typeName: item.id, gridX: gx, gridY: gy, gridWidth: 1, gridHeight: 1, rotation: r,
          parentId: 'parent_$r'));
    } else {
      out.add(PlacedFurnitureConfig(
          id: '${item.id}_$r', typeName: item.id, gridX: gx, gridY: gy,
          gridWidth: r.isOdd ? h : w, gridHeight: r.isOdd ? w : h, rotation: r));
    }
  }
  return out;
}

void _outline(Canvas canvas, CozyRoomGame game, double gx, double gy, double w, double h) {
  Offset p(double x, double y) {
    final v = IsometricCoords.gridToScreen(x, y);
    final s = game.camera.localToGlobal(Vector2(v.x, v.y - IsometricCoords.tileHeight / 2));
    return Offset(s.x, s.y);
  }

  final path = Path()
    ..moveTo(p(gx, gy).dx, p(gx, gy).dy)
    ..lineTo(p(gx + w, gy).dx, p(gx + w, gy).dy)
    ..lineTo(p(gx + w, gy + h).dx, p(gx + w, gy + h).dy)
    ..lineTo(p(gx, gy + h).dx, p(gx, gy + h).dy)
    ..close();
  canvas.drawPath(path, Paint()..color = const Color(0x33FF2D9A));
  canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF2D9A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = Platform.environment['AUDIT_DIR'];

  test('audit', () async {
    final orig = FlutterError.onError;
    FlutterError.onError = (_) {};
    await FurnitureCatalogService.initialize(forceReload: true);
    final only = Platform.environment['AUDIT_ONLY']?.split(',');
    final items = FurnitureCatalogService.items.values.where((i) => only == null || only.contains(i.id)).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final meta = StringBuffer();
    for (final item in items) {
      try {
        final game = CozyRoomGame(
          avatarConfig: const AvatarConfig(),
          roomConfig: RoomConfig(
            floor: 'solid_white_tiles',
            wallpaper: 'solid_white_plaster',
            floorOverrides: const {},
            wallOverrides: const {},
            interiorWalls: const [],
            furniture: _placements(item),
          ),
        );
        game.onGameResize(Vector2(1200, 900));
        // ignore: invalid_use_of_internal_member
        await game.load();
        // ignore: invalid_use_of_internal_member
        game.mount();
        for (var i = 0; i < 12; i++) {
          game.update(0.05);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xFF16141D), BlendMode.src);
        game.render(canvas);
        if (!(item.isWallItem || item.footprint.startsWith('wall') || item.isSurfaceItem || item.footprint == 'surface')) {
          final (w, h) = _size(item);
          for (var r = 0; r < 4; r++) {
            final (gx, gy) = _spots[r];
            _outline(canvas, game, gx, gy, r.isOdd ? h : w, r.isOdd ? w : h);
          }
        }
        final image = await recorder.endRecording().toImage(1200, 900);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/${item.id}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        meta.writeln('${item.id}\t${item.name}\t${item.zone}\t${item.footprint}\t${item.canvasSize}\t'
            '${item.spriteOffset}\t${item.surfaceHeight}\t${item.rotations.keys.toList()}');
        game.onRemove();
      } catch (e) {
        meta.writeln('${item.id}\tERROR $e');
      }
    }
    File('$dir/_meta.tsv').writeAsStringSync(meta.toString());
    FlutterError.onError = orig;
  }, timeout: const Timeout(Duration(minutes: 20)), skip: dir == null ? 'set AUDIT_DIR to run the audit' : false);
}
