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
      expect(BedSleepConfig.overlayPath('single_bed', 'single_high_bed', 2, blanket: true),
          'furniture/sleep_overlays/single_high_bed_rot2_blanket.png');
      expect(BedSleepConfig.supports('king_bed', 'king_bed'), isFalse);
      expect(BedSleepConfig.supports('pet_dog_bed', 'pet_dog_bed'), isFalse);
    });

    test('all bed overlay sprites (front wood + blanket) exist as assets', () {
      for (final bed in ['single_bed', 'single_high_bed']) {
        for (var rot = 0; rot < 4; rot++) {
          for (final blanket in [false, true]) {
            final path = BedSleepConfig.overlayPath(bed, bed, rot, blanket: blanket)!;
            expect(File('assets/images/$path').existsSync(), isTrue, reason: path);
          }
        }
      }
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
      expect(bed.sleepersUnder, contains(avatar));

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
  });
}
