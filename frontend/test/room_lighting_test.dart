import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/furniture_item.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/core/services/furniture_catalog_service.dart';
import 'package:frontend/features/lobby/lighting/room_lighting_system.dart';

/// A west wall along the whole column between tiles 3 and 4 (sub-cells 7 | 8).
List<InteriorWallConfig> _fullWestWall({bool doorwayAtRow3 = false, String style = 'wood_slats'}) => [
      for (int gy = 0; gy < 8; gy++)
        InteriorWallConfig(
          id: 'w$gy',
          gridX: 4,
          gridY: gy,
          orientation: 'west',
          style: style,
          hasDoorway: doorwayAtRow3 && gy == 3,
        ),
    ];

double _lum(RoomLightingSystem s, int i, int j) {
  final out = Float32List(3);
  s.cellInto(i, j, out);
  return (out[0] + out[1] + out[2]) / 3;
}

RoomLightingSystem _systemWith(List<InteriorWallConfig> walls, List<LightSourceDef> lights,
    {AmbientMode ambient = AmbientMode.night}) {
  return RoomLightingSystem()
    ..setOcclusion(LightOcclusion.fromWalls(walls))
    ..setAmbient(ambient)
    ..setLights(lights)
    ..settle();
}

const _lamp = LightSourceDef(id: 'lamp', u: 5, v: 7, radius: 6, color: Color(0xFFFFFFFF));

void main() {
  group('Phase 1 — model & persistence', () {
    test('old room JSON without lighting loads with defaults', () {
      final cfg = RoomConfig.fromMap({'wallpaper': 'rustic_wood', 'floor': 'oak_parquet'});
      expect(cfg.lighting, const LightingConfig());
      expect(cfg.lighting.masterOn, isTrue);
      expect(cfg.lighting.ambient, AmbientMode.day);
      expect(cfg.toMap().containsKey('lighting'), isFalse, reason: 'default lighting is not serialized');
    });

    test('lighting config round-trips through JSON', () {
      const lighting = LightingConfig(
        masterOn: false,
        ambient: AmbientMode.night,
        ceilingLights: [
          CeilingLightConfig(id: 'c1', gridX: 2.5, gridY: 3, color: LightColor.cold, intensity: 0.7),
          CeilingLightConfig(id: 'c2', gridX: 6, gridY: 1.5, on: false, color: LightColor.custom(0xFFFF00AA), radius: 2),
        ],
      );
      final cfg = const RoomConfig().copyWith(lighting: lighting);
      final back = RoomConfig.fromJson(cfg.toJson());
      expect(back.lighting, lighting);
      expect(back, cfg);
    });

    test('furniture lightOn / lightColor round-trip and stay optional', () {
      const f = PlacedFurnitureConfig(
          id: 'lamp1', typeName: 'table_lamp', gridX: 4, gridY: 4, lightOn: false, lightColor: LightColor.cold);
      final back = PlacedFurnitureConfig.fromMap(f.toMap());
      expect(back, f);

      const plain = PlacedFurnitureConfig(id: 't', typeName: 'table', gridX: 1, gridY: 1);
      expect(plain.toMap().containsKey('lightOn'), isFalse);
      expect(PlacedFurnitureConfig.fromMap(plain.toMap()).lightOn, isNull);
    });

    test('catalog: explicit light block wins, known emitters get defaults', () {
      final withBlock = FurnitureCatalogItem.fromJson('lava_lamp', {
        'footprint': 'surface',
        'light': {'color': '#00FF88', 'radius': 1.0, 'anim': 'pulse', 'default_on': false},
      });
      expect(withBlock.lightSpec!.color, const LightColor.custom(0xFF00FF88));
      expect(withBlock.lightSpec!.anim, LightAnim.pulse);
      expect(withBlock.lightSpec!.defaultOn, isFalse);

      expect(FurnitureCatalogItem.fromJson('table_lamp', {}).isLightEmitter, isTrue);
      expect(FurnitureCatalogItem.fromJson('window_yellow_n', {}).lightSpec!.anim, LightAnim.daylight);
      expect(FurnitureCatalogItem.fromJson('table', {}).isLightEmitter, isFalse);
    });

    test('LightColor presets and hex parsing', () {
      expect(LightColor.fromHex('#FF8800').color, const Color(0xFFFF8800));
      expect(LightColor.fromHex('cold'), LightColor.cold);
      expect(LightColor.fromHex('garbage'), LightColor.warm);
    });
  });

  group('Phase 2 — occlusion & sectors', () {
    test('solid wall blocks, doorway and glass attenuate', () {
      final solid = LightOcclusion.fromWalls(_fullWestWall());
      expect(solid.transmittance(7, 0, 8, 0), 0);
      expect(solid.transmittance(6, 0, 7, 0), 1);

      final door = LightOcclusion.fromWalls(_fullWestWall(doorwayAtRow3: true));
      expect(door.transmittance(7, 6, 8, 6), 0.5);
      expect(door.transmittance(7, 7, 8, 7), 0.5);
      expect(door.transmittance(7, 8, 8, 8), 0);

      final glass = LightOcclusion.fromWalls(_fullWestWall(style: 'bathroom_glass'));
      expect(glass.transmittance(7, 0, 8, 0), closeTo(0.6, 1e-6));
    });

    test('sectors split on walls (default room has 4 areas)', () {
      expect(LightOcclusion.open().sectorCount, 1);
      expect(LightOcclusion.fromWalls(_fullWestWall()).sectorCount, 2);
      final def = LightOcclusion.fromWalls(RoomConfig.defaultInteriorWalls);
      // Bath and bedroom are closed rooms; the kitchen has no wall on its south side
      // (gy = 7), so it shares the living-room sector.
      expect(def.sectorCount, 3);
      expect(def.sectorAt(1, 1), isNot(def.sectorAt(10, 10)));
      expect(def.sectorAt(12, 1), isNot(def.sectorAt(10, 10)));
      expect(def.sectorAt(2, 10), def.sectorAt(10, 10));
    });

    test('diagonal steps cannot cut through a wall corner', () {
      final occ = LightOcclusion.fromWalls(_fullWestWall());
      expect(occ.diagonalOpen(7, 3, 8, 4), isFalse);
      expect(occ.diagonalOpen(5, 3, 6, 4), isTrue);
    });
  });

  group('Phase 2 — propagation', () {
    test('light does not cross a solid wall: far side stays at ambient', () {
      final s = _systemWith(_fullWestWall(), [_lamp]);
      final ambient = _systemWith(_fullWestWall(), []);
      expect(_lum(s, 5, 7), greaterThan(_lum(ambient, 5, 7) + 0.3));
      // Right behind the wall, 3 sub-cells from the lamp: untouched.
      expect(_lum(s, 8, 7), closeTo(_lum(ambient, 8, 7), 1e-6));
      expect(s.lights.single.influence[7 * 16 + 8], 0);
    });

    test('doorway lets some light through, less than an open room', () {
      final open = _systemWith(const [], [_lamp]);
      final door = _systemWith(_fullWestWall(doorwayAtRow3: true), [_lamp]);
      final inOpen = open.lights.single.influence[7 * 16 + 8];
      final inDoor = door.lights.single.influence[7 * 16 + 8];
      expect(inDoor, greaterThan(0));
      expect(inDoor, lessThan(inOpen));
    });

    test('influence falls off with distance and reaches zero at the radius', () {
      final s = _systemWith(const [], [_lamp]);
      final inf = s.lights.single.influence;
      expect(inf[7 * 16 + 5], greaterThan(inf[7 * 16 + 7]));
      expect(inf[7 * 16 + 7], greaterThan(inf[7 * 16 + 9]));
      expect(inf[7 * 16 + 12], 0);
    });

    test('animations and fades never re-run propagation', () {
      final s = _systemWith(const [], [
        const LightSourceDef(id: 'fire', u: 4, v: 4, radius: 5, color: Color(0xFFFF9A3C), anim: LightAnim.flicker),
      ]);
      final runs = s.propagationCount;
      final before = _lum(s, 4, 4);
      bool changed = false;
      for (int k = 0; k < 30; k++) {
        changed |= s.update(1 / 30);
      }
      expect(changed, isTrue);
      expect(s.propagationCount, runs);
      expect(_lum(s, 4, 4), isNot(closeTo(before, 1e-9)));

      s.setLightOn('fire', false);
      s.update(0.1);
      expect(s.propagationCount, runs, reason: 'fade is a scalar');
    });

    test('topology changes trigger propagation, unchanged lights are reused', () {
      final s = _systemWith(const [], [_lamp]);
      final runs = s.propagationCount;
      s.setLights([_lamp]); // same position → reuse
      s.update(0);
      expect(s.propagationCount, runs);

      s.setOcclusion(LightOcclusion.fromWalls(_fullWestWall()));
      s.update(0);
      expect(s.propagationCount, runs + 1);
    });

    test('static scene settles: no recomposition once fades end', () {
      final s = _systemWith(const [], [_lamp]);
      expect(s.update(1 / 60), isFalse);
    });
  });

  group('Phase 2 — switching & ambient', () {
    test('master switch keeps individual state', () {
      final s = _systemWith(const [], [
        _lamp,
        const LightSourceDef(id: 'off', u: 12, v: 12, radius: 4, color: Color(0xFFFFFFFF), on: false),
      ]);
      s.setMasterOn(false);
      for (int k = 0; k < 20; k++) {
        s.update(0.05);
      }
      expect(s.lightById('lamp')!.level, 0);
      s.setMasterOn(true);
      for (int k = 0; k < 20; k++) {
        s.update(0.05);
      }
      expect(s.lightById('lamp')!.level, 1);
      expect(s.lightById('off')!.level, 0);
    });

    test('fade takes ~250 ms instead of snapping', () {
      final s = _systemWith(const [], [_lamp]);
      s.setLightOn('lamp', false);
      s.update(0.1);
      expect(s.lightById('lamp')!.level, closeTo(0.6, 1e-6));
      s.update(0.2);
      expect(s.lightById('lamp')!.level, 0);
    });

    test('windows ignore the master switch', () {
      final s = _systemWith(const [], [
        const LightSourceDef(
            id: 'win', u: 7, v: 1.5, radius: 6, color: Color(0xFFD6E6FF), anim: LightAnim.daylight, affectedByMaster: false),
      ]);
      s.setMasterOn(false);
      s.update(1);
      expect(s.lightById('win')!.level, 1);
    });

    test('night ambient is never pure black and is bluish', () {
      final s = _systemWith(const [], const []);
      final out = Float32List(3);
      s.cellInto(0, 0, out);
      expect(out[0], greaterThan(0.1));
      expect(out[2], greaterThan(out[0]), reason: 'navy/lavender, not grey');
    });

    test('overlapping lights ease towards 1 instead of clipping', () {
      final many = [
        for (int k = 0; k < 5; k++)
          LightSourceDef(id: 'l$k', u: 8, v: 8, radius: 6, color: const Color(0xFFFFFFFF)),
      ];
      final s = _systemWith(const [], many);
      final out = Float32List(3);
      s.cellInto(8, 8, out);
      expect(out[0], lessThanOrEqualTo(1.0));
      expect(out[0], greaterThan(0.95));
      expect(RoomLightingSystem.compress(0.2, 0.01), closeTo(0.21, 1e-3), reason: 'linear for small light');
      expect(RoomLightingSystem.compress(0.2, 1.2), greaterThan(RoomLightingSystem.compress(0.2, 1.0)));
      expect(RoomLightingSystem.compress(0.2, 1.0), lessThan(1.0));
    });
  });

  group('Phase 5 — gaming PC desk', () {
    test('desk emits an RGB light that follows its activation, not a switch', () {
      final spec = FurnitureCatalogItem.fromJson('gaming_pc_desk', {}).lightSpec!;
      expect(spec.anim, LightAnim.rgb);
      expect(spec.followsActivation, isTrue);
      expect(spec.toggleable, isFalse, reason: 'no tap / panel switch: it lights while someone sits');
      expect(spec.selfLit, lessThan(1.0));
      expect(EmitterLightSpec.fromJson({'self_lit': 0.3}).selfLit, 0.3);
      expect(EmitterLightSpec.fromJson({'follows_activation': true}).followsActivation, isTrue);

      const cfg = RoomConfig(furniture: [
        // lightOn is ignored for activation-driven lights.
        PlacedFurnitureConfig(id: 'desk', typeName: 'gaming_pc_desk', gridX: 5, gridY: 5, lightOn: true),
      ]);
      LightSourceDef desk(Set<String> active) =>
          RoomLightSources.fromRoomConfig(cfg, activeIds: active).firstWhere((d) => d.id == 'desk');
      final idle = desk({});
      expect(idle.on, isFalse);
      expect(idle.selfLit, spec.selfLit);
      expect(idle.u, 11);
      expect(desk({'desk'}).on, isTrue);
    });

    test('RGB cycles the hue over time without re-propagating', () {
      const d = LightSourceDef(id: 'desk', u: 8, v: 8, radius: 4, color: Color(0xFFB388FF), anim: LightAnim.rgb);
      final a = LightAnimator.evaluate(d, 0, AmbientMode.night);
      final a0 = [a.r, a.g, a.b];
      final b = LightAnimator.evaluate(d, 5, AmbientMode.night);
      expect([b.r, b.g, b.b], isNot(a0));
      // Always a saturated colour: one channel at 1, one at 0.
      for (final t in [0.0, 1.3, 4.2, 9.9]) {
        final c = LightAnimator.evaluate(d, t, AmbientMode.night);
        final ch = [c.r, c.g, c.b]..sort();
        expect(ch.last, closeTo(1, 1e-9));
        expect(ch.first, closeTo(0, 1e-9));
      }

      final s = _systemWith(const [], [d]);
      final runs = s.propagationCount;
      for (int k = 0; k < 20; k++) {
        expect(s.update(0.1), isTrue, reason: 'animated light recomposes every frame');
      }
      expect(s.propagationCount, runs);
    });
  });

  group('Phase 5 — fireplace & lava lamp', () {
    test('catalog exposes both emitters with sprites and the right placement', () {
      final fire = FurnitureCatalogService.getItem('fireplace')!;
      expect(fire.footprint, '1x1');
      expect(fire.isSurfaceItem, isFalse);
      expect(fire.lightSpec!.anim, LightAnim.flicker);
      expect(fire.lightSpec!.selfLit, lessThan(1.0), reason: 'only the fire glows, not the bricks');

      final lava = FurnitureCatalogService.getItem('lava_lamp')!;
      expect(lava.isSurfaceItem, isTrue);
      expect(lava.lightSpec!.anim, LightAnim.pulse);
      expect(FurnitureCatalogService.getByCategory('surface').map((i) => i.id), contains('lava_lamp'));
      expect(FurnitureCatalogService.getByCategory('living').map((i) => i.id), contains('fireplace'));

      for (final f in ['fireplace', 'lava_lamp']) {
        for (int r = 0; r < 4; r++) {
          expect(File('assets/images/furniture/established_furniture/${f}_rot$r.png').existsSync(), isTrue,
              reason: '$f rot$r sprite');
        }
      }
    });
  });

  group('Floor lamp', () {
    test('floor lamp is a switchable 0.5x0.5 emitter with sprites', () {
      final item = FurnitureCatalogService.getItem('floor_lamp_sm')!;
      expect(item.footprint, '0.5x0.5');
      expect(item.lightSpec, isNotNull);
      expect(item.lightSpec!.toggleable, isTrue);
      expect(FurnitureCatalogService.getByCategory('living').map((i) => i.id), contains('floor_lamp_sm'));
      for (int r = 0; r < 4; r++) {
        expect(File('assets/images/furniture/established_furniture/floor_lamp_sm_rot$r.png').existsSync(), isTrue);
      }
      final defs = RoomLightSources.fromRoomConfig(const RoomConfig(furniture: [
        PlacedFurnitureConfig(id: 'fl', typeName: 'floor_lamp_sm', gridX: 3, gridY: 3, gridWidth: 0.5, gridHeight: 0.5),
      ]));
      expect(defs.firstWhere((d) => d.id == 'fl').u, 6.5, reason: 'centre of the sub-cell');
    });
  });

  group('Phase 6 — automatic ambient', () {
    test('schedule: day 07–18, evening 18–20:30 and dawn 05:30–07, night otherwise', () {
      AmbientMode at(int h, int m) => AmbientSchedule.modeAt(DateTime(2026, 9, 30, h, m));
      expect(at(12, 0), AmbientMode.day);
      expect(at(7, 0), AmbientMode.day);
      expect(at(17, 59), AmbientMode.day);
      expect(at(18, 0), AmbientMode.evening);
      expect(at(20, 29), AmbientMode.evening);
      expect(at(20, 30), AmbientMode.night);
      expect(at(0, 0), AmbientMode.night);
      expect(at(5, 29), AmbientMode.night);
      expect(at(5, 30), AmbientMode.evening);
      expect(at(6, 59), AmbientMode.evening);
    });

    test('automatic by default; manual choice overrides and round-trips', () {
      const auto = LightingConfig();
      expect(auto.autoAmbient, isTrue);
      expect(auto.effectiveAmbient(DateTime(2026, 1, 1, 23)), AmbientMode.night);
      expect(auto.effectiveAmbient(DateTime(2026, 1, 1, 10)), AmbientMode.day);

      final manual = auto.copyWith(autoAmbient: false, ambient: AmbientMode.evening);
      expect(manual.effectiveAmbient(DateTime(2026, 1, 1, 23)), AmbientMode.evening);
      expect(LightingConfig.fromMap(manual.toMap()), manual);
    });

    test('rooms without lighting get default ceiling lights; an emptied list stays empty', () {
      expect(RoomConfig.fromMap({'wallpaper': 'rustic_wood'}).lighting.ceilingLights, LightingConfig.defaultCeilingLights);
      expect(LightingConfig.fromMap({'ambient': 'night'}).ceilingLights, LightingConfig.defaultCeilingLights);
      const emptied = LightingConfig(ceilingLights: []);
      expect(LightingConfig.fromMap(emptied.toMap()).ceilingLights, isEmpty);
    });

    test('ambient changes fade in instead of snapping', () {
      final s = _systemWith(const [], const [], ambient: AmbientMode.day);
      s.setAmbient(AmbientMode.night);
      s.update(RoomLightingSystem.ambientFadeSeconds / 2);
      final mid = s.currentAmbientColor;
      final night = RoomLightingSystem.ambientColor(AmbientMode.night);
      expect(mid.red, lessThan(255));
      expect(mid.red, greaterThan(night.red));
      s.update(RoomLightingSystem.ambientFadeSeconds);
      expect(s.currentAmbientColor, night);
      expect(s.update(0.1), isFalse, reason: 'settled after the fade');
    });
  });

  group('Phase 3 — daytime is a no-op', () {
    test('white day ambient stays exactly white, even under lights', () {
      final s = _systemWith(const [], [_lamp], ambient: AmbientMode.day);
      final out = Float32List(3);
      for (final cell in [(0, 0), (5, 7), (15, 15)]) {
        s.cellInto(cell.$1, cell.$2, out);
        expect(out.every((c) => c == 1.0), isTrue, reason: 'cell $cell = $out');
      }
    });
  });

  group('Phase 2 — wall-aware sampling', () {
    test('sampling next to a solid wall ignores the lit far side', () {
      // Lamp on the right of the wall; sample right at the left edge of the wall.
      final s = _systemWith(_fullWestWall(),
          [const LightSourceDef(id: 'r', u: 9, v: 7, radius: 6, color: Color(0xFFFFFFFF))]);
      final out = Float32List(3);
      s.sampleInto(7.95, 7.5, out);
      final ambient = Float32List(3);
      s.cellInto(0, 0, ambient);
      expect(out[0], closeTo(ambient[0], 1e-6));

      // Same distance on the lit side is bright.
      s.sampleInto(8.05, 7.5, out);
      expect(out[0], greaterThan(ambient[0] + 0.3));
    });

    test('sampling is continuous across open cells (no pop)', () {
      final s = _systemWith(const [], [_lamp]);
      final a = Float32List(3), b = Float32List(3);
      s.sampleInto(7.99, 7.5, a);
      s.sampleInto(8.01, 7.5, b);
      expect((a[0] - b[0]).abs(), lessThan(0.01));
    });
  });

  group('Phase 2 — sources from room config', () {
    test('default room: windows emit, toggles & ceiling lights are read', () {
      final cfg = const RoomConfig().copyWith(
        lighting: const LightingConfig(ceilingLights: [CeilingLightConfig(id: 'c1', gridX: 4, gridY: 5)]),
        furniture: [
          ...RoomConfig.defaultFurniture,
          const PlacedFurnitureConfig(id: 'lamp1', typeName: 'table_lamp', gridX: 4, gridY: 4, lightOn: false),
        ],
      );
      final defs = RoomLightSources.fromRoomConfig(cfg);
      final byId = {for (final d in defs) d.id: d};
      expect(byId['c1']!.isCeiling, isTrue);
      expect(byId['c1']!.u, 8);
      expect(byId['lamp1']!.on, isFalse);
      final win = byId['window_yellow_n']!;
      expect(win.affectedByMaster, isFalse);
      expect(win.toggleable, isFalse);
      expect(byId['lamp1']!.affectedByMaster, isFalse, reason: 'the master only gates ceiling lights');
      expect(byId['lamp1']!.toggleable, isTrue);
      expect(byId['c1']!.affectedByMaster, isTrue);
      expect(win.v, 1.5, reason: 'window light starts inside the room');
      expect(byId.containsKey('table'), isFalse);
    });

    test('lights in the same sector are grouped', () {
      final s = _systemWith(RoomConfig.defaultInteriorWalls, const [
        LightSourceDef(id: 'bath', u: 2, v: 2, radius: 4, color: Color(0xFFFFFFFF)),
        LightSourceDef(id: 'living', u: 9, v: 10, radius: 4, color: Color(0xFFFFFFFF)),
      ]);
      expect(s.lightIdsInSectorOf(1, 1), ['bath']);
      expect(s.lightIdsInSectorOf(10, 12), ['living']);
    });
  });
}
