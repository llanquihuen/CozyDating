import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/lobby/components/isometric_avatar_component.dart';
import 'package:frontend/features/lobby/components/isometric_furniture_component.dart';
import 'package:frontend/features/lobby/data/bed_sleep_config.dart';

Future<Sprite> _blankSprite(int w, int h) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint());
  final image = await recorder.endRecording().toImage(w, h);
  return Sprite(image);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BedSleepConfig', () {
    test('every rotation of the supported beds has a sleep spot', () {
      for (final bed in ['single_bed', 'single_high_bed']) {
        for (var rot = 0; rot < 4; rot++) {
          expect(BedSleepConfig.spotFor(bed, bed, rot), isNotNull, reason: '$bed rot$rot');
        }
      }
    });

    test('rotations 1 and 3 are drawn mirrored; single_bed uses view B with the headboard in front', () {
      expect(BedSleepConfig.spotFor('single_bed', 'single_bed', 0)!.mirror, isFalse);
      expect(BedSleepConfig.spotFor('single_bed', 'single_bed', 1)!.mirror, isTrue);
      expect(BedSleepConfig.spotFor('single_bed', 'single_bed', 2)!.view, LieView.b);
      expect(BedSleepConfig.spotFor('single_bed', 'single_bed', 3)!.mirror, isTrue);
      // single_high_bed has its own front-headboard rot2/rot3 sprites now.
      expect(BedSleepConfig.spotFor('single_high_bed', 'single_high_bed', 2)!.view, LieView.b);
      expect(BedSleepConfig.spotFor('single_high_bed', 'single_high_bed', 3)!.mirror, isTrue);
    });

    test('placed bed ids with a suffix still match; unsupported beds do not', () {
      expect(BedSleepConfig.supports('single_bed_7', 'single_bed_7'), isTrue);
      expect(BedSleepConfig.supports('single_high_bed_2', 'single_high_bed_2'), isTrue);
      expect(BedSleepConfig.spotFor('single_high_bed_2', 'single_high_bed_2', 0)!.baseHead,
          BedSleepConfig.spotFor('single_high_bed', 'single_high_bed', 0)!.baseHead);
      // Rooms place the high bed with id 'single_bed': the type must win over the instance id.
      expect(BedSleepConfig.spotFor('single_bed', 'single_high_bed', 0)!.baseHead,
          BedSleepConfig.spotFor('single_high_bed', 'single_high_bed', 0)!.baseHead);
      expect(BedSleepConfig.blanketOverlayPath('single_bed', 'single_high_bed', 2, {0}),
          'furniture/sleep_overlays/single_high_bed_rot2_blanket.png');
      expect(BedSleepConfig.supports('king_bed_3', 'king_bed_3'), isTrue);
      expect(BedSleepConfig.supports('pet_dog_bed', 'pet_dog_bed'), isFalse);
    });

    test('all bed overlay sprites (front frame + every blanket variant) exist as assets', () {
      for (final bed in ['single_bed', 'single_high_bed', 'king_bed']) {
        final sides = BedSleepConfig.sideCount(bed, bed);
        for (var rot = 0; rot < 4; rot++) {
          final paths = [
            BedSleepConfig.frontOverlayPath(bed, bed, rot)!,
            for (var s = 0; s < sides; s++) BedSleepConfig.blanketOverlayPath(bed, bed, rot, {s})!,
            BedSleepConfig.blanketOverlayPath(bed, bed, rot, {for (var s = 0; s < sides; s++) s})!,
          ];
          for (final path in paths) {
            expect(File('assets/images/$path').existsSync(), isTrue, reason: path);
          }
        }
      }
    });

    test('the king bed sleeps two: one spot per side, side 1 nearer the camera', () {
      expect(BedSleepConfig.sideCount('king_bed', 'king_bed'), 2);
      expect(BedSleepConfig.sideCount('single_bed', 'single_bed'), 1);
      expect(BedSleepConfig.sideCount('pet_dog_bed', 'pet_dog_bed'), 0);
      for (var rot = 0; rot < 4; rot++) {
        final a = BedSleepConfig.spotFor('king_bed', 'king_bed', rot)!;
        final b = BedSleepConfig.spotFor('king_bed', 'king_bed', rot, side: 1)!;
        expect(b.view, a.view);
        expect(b.mirror, a.mirror);
        // Side 1 lies one tile over along the bed's width (2, 1), i.e. lower on screen.
        expect(b.baseHead.dy, greaterThan(a.baseHead.dy));
        expect(b.baseHead.dx - a.baseHead.dx, closeTo(2 * (b.baseHead.dy - a.baseHead.dy), 1e-9));
      }
      expect(BedSleepConfig.spotFor('single_bed', 'single_bed', 0, side: 1), isNull);
    });

    test('tapping a half of the king bed picks that side, mirrored rotations included', () {
      for (var rot = 0; rot < 4; rot++) {
        for (var side = 0; side < 2; side++) {
          final spot = BedSleepConfig.spotFor('king_bed', 'king_bed', rot, side: side)!;
          final head = spot.mirror ? Offset(256 - spot.baseHead.dx, spot.baseHead.dy) : spot.baseHead;
          // A bit down the body from the head, toward the feet.
          final body = head + Offset((spot.view == LieView.a) != spot.mirror ? -20 : 20, spot.view == LieView.a ? 10 : -10);
          expect(BedSleepConfig.sideAt('king_bed', 'king_bed', rot, body, 256), side, reason: 'rot$rot side$side');
        }
      }
    });

    test('the king bed blanket: one half per sleeper under the covers, the full one for both', () {
      expect(BedSleepConfig.blanketOverlayPath('king_bed', 'king_bed', 1, {}), isNull);
      expect(BedSleepConfig.blanketOverlayPath('king_bed', 'king_bed', 1, {0}),
          'furniture/sleep_overlays/king_bed_rot1_blanket0.png');
      expect(BedSleepConfig.blanketOverlayPath('king_bed', 'king_bed', 1, {1}),
          'furniture/sleep_overlays/king_bed_rot1_blanket1.png');
      expect(BedSleepConfig.blanketOverlayPath('king_bed', 'king_bed', 1, {0, 1}),
          'furniture/sleep_overlays/king_bed_rot1_blanket.png');
    });

    test('blanket edge: view A covers toward the camera, view B toward the back', () {
      expect(BedSleepConfig.spotFor('single_bed', 'single_bed', 0)!.coveredBelow, isTrue);
      expect(BedSleepConfig.spotFor('single_bed', 'single_bed', 2)!.coveredBelow, isFalse);
      expect(BedSleepConfig.spotFor('single_high_bed', 'single_high_bed', 3)!.coveredBelow, isFalse);
    });

    test('lying layers exist for every body, face and hair style in both views', () {
      const base = 'assets/images/OCTOPLAYER/Avatar/lying';
      final files = <String>[
        for (final v in ['A', 'B']) ...[
          '$base/body/male_lie$v.png',
          '$base/body/female_lie$v.png',
          '$base/tops/jacket_lie$v.png',
          '$base/bottoms/jeans_lie$v.png',
          for (final b in ['male', 'female']) ...[
            '$base/tops/jacket_${b}_lie$v.png',
            '$base/bottoms/jeans_${b}_lie$v.png',
          ],
          for (final s in ['cateyes', 'relax', 'closedeyes']) '$base/eyes/${s}_lie$v.png',
          for (final s in ['biglips', 'catmouth', 'smile', 'smirk']) '$base/mouth/${s}_lie$v.png',
          for (final s in ['small', 'standard']) '$base/nose/${s}_lie$v.png',
          for (final s in ['bangs', 'braids', 'comb_over', 'flow', 'long_flow', 'twintails']) '$base/hair/$s/${s}_lie$v.png',
        ],
      ];
      for (final f in files) {
        expect(File(f).existsSync(), isTrue, reason: f);
      }
    });
  });

  group('Avatar lying on a bed', () {
    test('lieOnBed places the avatar on the bed sprite above the bed; standUp puts it back on the floor', () async {
      final bed = IsometricFurnitureComponent(
        id: 'single_bed',
        typeName: 'single_bed',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 1.0,
        gridHeight: 2.0,
        rotation: 0,
        footprint: '1x2',
        type: FurnitureType.bed,
        sprite: await _blankSprite(192, 144),
      );
      final avatar = IsometricAvatarComponent(gridX: 2, gridY: 2, config: AvatarConfig());

      avatar.lieOnBed(bed);
      expect(avatar.isLying, isTrue);
      expect(avatar.lyingUnder, isFalse);
      expect(avatar.avatarRenderer.isLying, isTrue);
      expect(avatar.position, bed.position + bed.spriteOffset);
      expect(avatar.size, bed.renderSize);
      expect(avatar.priority, greaterThan(bed.priority));
      expect(avatar.avatarRenderer.lyingPose!.view, 'A');
      expect(avatar.avatarRenderer.lyingPose!.scale, closeTo(0.5, 1e-9));

      expect(bed.sleepersUnder, isEmpty);
      avatar.lieOnBed(bed, under: true);
      expect(avatar.lyingUnder, isTrue);
      expect(avatar.avatarRenderer.lyingPose!.under, isTrue);
      expect(avatar.avatarRenderer.lyingPose!.blanketEdge, isNotNull);
      // The bed now draws its blanket overlay over the sleeper.
      expect(bed.sleepersUnder, containsPair(avatar, 0));

      avatar.standUp(obstacles: bed.occupiedSubCells.toSet(), blockedEdges: const {});
      expect(avatar.isLying, isFalse);
      expect(avatar.avatarRenderer.isLying, isFalse);
      expect(bed.sleepersUnder, isEmpty);
      expect(avatar.size, Vector2(IsometricAvatarComponent.avatarWidth, IsometricAvatarComponent.avatarHeight));
      // Back on a free floor cell beside the bed, not inside its footprint.
      final cell = (avatar.gridX.round(), avatar.gridY.round());
      expect(bed.occupiedSubCells.any((c) => (c.x, c.y) == cell), isFalse);
    });

    test('mirrored rotation flips the drawing; view B is used for the front-headboard rotation', () async {
      final sprite = await _blankSprite(192, 144);
      IsometricFurnitureComponent bedAt(int rot) => IsometricFurnitureComponent(
            id: 'single_bed',
            typeName: 'single_bed',
            gridX: 4.0,
            gridY: 4.0,
            gridWidth: rot.isEven ? 1.0 : 2.0,
            gridHeight: rot.isEven ? 2.0 : 1.0,
            rotation: rot,
            footprint: rot.isEven ? '1x2' : '2x1',
            type: FurnitureType.bed,
            sprite: sprite,
          );
      final avatar = IsometricAvatarComponent(gridX: 2, gridY: 2, config: AvatarConfig());

      avatar.lieOnBed(bedAt(1));
      expect(avatar.avatarRenderer.lyingPose!.mirror, isTrue);
      avatar.lieOnBed(bedAt(2));
      expect(avatar.avatarRenderer.lyingPose!.view, 'B');
      expect(avatar.avatarRenderer.lyingPose!.mirror, isFalse);
    });

    test('lying down on arrival after walking to the bed keeps the avatar on the bed sprite', () async {
      for (final (id, w, h, footprint) in [('single_bed', 192, 144, '1x2'), ('king_bed', 256, 192, '2x2')]) {
        final bed = IsometricFurnitureComponent(
          id: id,
          typeName: id,
          gridX: 4.0,
          gridY: 4.0,
          gridWidth: footprint == '2x2' ? 2.0 : 1.0,
          gridHeight: 2.0,
          rotation: 0,
          footprint: footprint,
          type: FurnitureType.bed,
          sprite: await _blankSprite(w, h),
        );
        late IsometricAvatarComponent avatar;
        // Same as CozyRoomGame._handleDestinationReached with a pending bed.
        avatar = IsometricAvatarComponent(
          gridX: 0,
          gridY: 0,
          config: AvatarConfig(),
          onReachedDestination: (_) => avatar.lieOnBed(bed, side: id == 'king_bed' ? 1 : 0),
        );
        avatar.setPath(const [Point(1, 0), Point(2, 0)], const Point(2, 0));
        for (var i = 0; i < 200 && !avatar.isLying; i++) {
          avatar.update(0.05);
        }
        expect(avatar.isLying, isTrue, reason: id);
        expect(avatar.position, bed.position + bed.spriteOffset, reason: '$id: not moved back to the floor cell');
        expect(avatar.size, bed.renderSize, reason: id);
        expect(avatar.priority, bed.priority + 10 + avatar.lyingSide, reason: id);
        // Later frames leave it there too.
        avatar.update(0.05);
        expect(avatar.position, bed.position + bed.spriteOffset, reason: id);
      }
    });

    test('two avatars share the king bed: each on its side, side 1 drawn in front', () async {
      final bed = IsometricFurnitureComponent(
        id: 'king_bed',
        typeName: 'king_bed',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 2.0,
        gridHeight: 2.0,
        rotation: 0,
        footprint: '2x2',
        type: FurnitureType.bed,
        sprite: await _blankSprite(256, 192),
      );
      final me = IsometricAvatarComponent(gridX: 2, gridY: 2, config: AvatarConfig());
      final partner = IsometricAvatarComponent(gridX: 2, gridY: 3, config: AvatarConfig());

      me.lieOnBed(bed, side: 1, under: true);
      partner.lieOnBed(bed, side: 0);
      expect(me.lyingSide, 1);
      expect(partner.lyingSide, 0);
      expect(me.priority, greaterThan(partner.priority));
      expect(me.avatarRenderer.lyingPose!.canvasOrigin, isNot(partner.avatarRenderer.lyingPose!.canvasOrigin));
      expect(bed.sleepersUnder, {me: 1});

      me.standUp(obstacles: bed.occupiedSubCells.toSet(), blockedEdges: const {});
      expect(me.lyingSide, 0);
      expect(bed.sleepersUnder, isEmpty);
      expect(partner.isLying, isTrue);
    });
  });
}
