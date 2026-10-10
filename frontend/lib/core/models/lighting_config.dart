import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

/// Base illumination of the room when no light reaches a cell. Never pure black, so the
/// room stays readable and cozy even with everything switched off.
enum AmbientMode { day, evening, night }

/// Which ambient the clock implies (phone's local time). Day 07:00–18:00, evening
/// 18:00–20:30 and at dawn 05:30–07:00, night otherwise.
class AmbientSchedule {
  static AmbientMode modeAt(DateTime time) {
    final minutes = time.hour * 60 + time.minute;
    if (minutes >= 7 * 60 && minutes < 18 * 60) return AmbientMode.day;
    if (minutes >= 18 * 60 && minutes < 20 * 60 + 30) return AmbientMode.evening;
    if (minutes >= 5 * 60 + 30 && minutes < 7 * 60) return AmbientMode.evening;
    return AmbientMode.night;
  }
}

extension AmbientModeX on AmbientMode {
  String get key => name;

  static AmbientMode fromKey(String? key) =>
      AmbientMode.values.firstWhere((m) => m.name == key, orElse: () => AmbientMode.day);
}

/// Colour of a light: a warm/cold preset or a free colour.
class LightColor extends Equatable {
  static const Color coldColor = Color(0xFFD6E6FF); // ~6500 K
  static const Color warmColor = Color(0xFFFFC48A); // ~2700 K

  final String preset; // 'cold' | 'warm' | 'custom'
  final int? argb; // only for 'custom'

  const LightColor._(this.preset, this.argb);

  static const LightColor cold = LightColor._('cold', null);
  static const LightColor warm = LightColor._('warm', null);
  const LightColor.custom(int value) : this._('custom', value);

  Color get color {
    switch (preset) {
      case 'cold':
        return coldColor;
      case 'custom':
        return Color(argb ?? 0xFFFFFFFF);
      default:
        return warmColor;
    }
  }

  Map<String, dynamic> toMap() => {
        'preset': preset,
        if (preset == 'custom' && argb != null) 'argb': argb,
      };

  factory LightColor.fromMap(dynamic map) {
    if (map is! Map) return LightColor.warm;
    final preset = map['preset'] as String? ?? 'warm';
    if (preset == 'cold') return LightColor.cold;
    if (preset == 'custom') return LightColor.custom((map['argb'] as num?)?.toInt() ?? 0xFFFFFFFF);
    return LightColor.warm;
  }

  /// Parses '#RRGGBB' / '#AARRGGBB' (catalog JSON). Falls back to warm.
  factory LightColor.fromHex(String? hex) {
    if (hex == null) return LightColor.warm;
    if (hex == 'warm') return LightColor.warm;
    if (hex == 'cold') return LightColor.cold;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? LightColor.warm : LightColor.custom(v);
  }

  @override
  List<Object?> get props => [preset, argb];
}

/// A ceiling fixture placed on the sub-grid. Does not occupy floor space.
class CeilingLightConfig extends Equatable {
  final String id;
  final double gridX; // tile coordinates, 0.5 steps (same convention as furniture)
  final double gridY;
  final bool on;
  final LightColor color;
  final double intensity; // 0..1.5
  final double radius; // in tiles

  const CeilingLightConfig({
    required this.id,
    required this.gridX,
    required this.gridY,
    this.on = true,
    this.color = LightColor.warm,
    this.intensity = 1.0,
    this.radius = 3.0,
  });

  CeilingLightConfig copyWith({
    String? id,
    double? gridX,
    double? gridY,
    bool? on,
    LightColor? color,
    double? intensity,
    double? radius,
  }) {
    return CeilingLightConfig(
      id: id ?? this.id,
      gridX: gridX ?? this.gridX,
      gridY: gridY ?? this.gridY,
      on: on ?? this.on,
      color: color ?? this.color,
      intensity: intensity ?? this.intensity,
      radius: radius ?? this.radius,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'gridX': gridX,
        'gridY': gridY,
        if (!on) 'on': false,
        'color': color.toMap(),
        if (intensity != 1.0) 'intensity': intensity,
        if (radius != 3.0) 'radius': radius,
      };

  factory CeilingLightConfig.fromMap(Map<String, dynamic> map) {
    return CeilingLightConfig(
      id: map['id'] as String? ?? '',
      gridX: (map['gridX'] as num?)?.toDouble() ?? 0.0,
      gridY: (map['gridY'] as num?)?.toDouble() ?? 0.0,
      on: map['on'] as bool? ?? true,
      color: LightColor.fromMap(map['color']),
      intensity: (map['intensity'] as num?)?.toDouble() ?? 1.0,
      radius: (map['radius'] as num?)?.toDouble() ?? 3.0,
    );
  }

  @override
  List<Object?> get props => [id, gridX, gridY, on, color, intensity, radius];
}

/// Lighting state of a room.
///
/// [masterOn] is the general switch for the **ceiling lights only**: it gates them without
/// touching their individual on/off, so switching it back on restores each one. Lamps and
/// other light-emitting objects are never affected by it.
class LightingConfig extends Equatable {
  final bool masterOn;
  /// true (default): the ambient follows the phone's clock ([AmbientSchedule]).
  /// false: the player picked [ambient] by hand.
  final bool autoAmbient;
  /// Manual ambient; only used when [autoAmbient] is false.
  final AmbientMode ambient;
  final List<CeilingLightConfig> ceilingLights;

  /// One fixture per area of the default room, so a room opened at night isn't pitch dark.
  /// Rooms saved without a `lighting` block get these too; they can be moved or removed.
  static const List<CeilingLightConfig> defaultCeilingLights = [
    CeilingLightConfig(id: 'ceiling_living', gridX: 4.5, gridY: 5.5),
    CeilingLightConfig(id: 'ceiling_bedroom', gridX: 6.5, gridY: 1.5, radius: 2.5),
    CeilingLightConfig(id: 'ceiling_bath', gridX: 1.5, gridY: 1.5, color: LightColor.cold, radius: 2.5),
    CeilingLightConfig(id: 'ceiling_kitchen', gridX: 1.5, gridY: 5.5, radius: 2.5),
  ];

  const LightingConfig({
    this.masterOn = true,
    this.autoAmbient = true,
    this.ambient = AmbientMode.day,
    this.ceilingLights = defaultCeilingLights,
  });

  LightingConfig copyWith({
    bool? masterOn,
    bool? autoAmbient,
    AmbientMode? ambient,
    List<CeilingLightConfig>? ceilingLights,
  }) {
    return LightingConfig(
      masterOn: masterOn ?? this.masterOn,
      autoAmbient: autoAmbient ?? this.autoAmbient,
      ambient: ambient ?? this.ambient,
      ceilingLights: ceilingLights ?? this.ceilingLights,
    );
  }

  /// The ambient to render right now.
  AmbientMode effectiveAmbient(DateTime now) => autoAmbient ? AmbientSchedule.modeAt(now) : ambient;

  bool get isDefault => this == const LightingConfig();

  Map<String, dynamic> toMap() => {
        if (!masterOn) 'masterOn': false,
        if (!autoAmbient) 'autoAmbient': false,
        'ambient': ambient.key,
        // Always written (even empty) so a room whose lights were all removed doesn't get
        // the defaults back on reload.
        'ceilingLights': ceilingLights.map((l) => l.toMap()).toList(),
      };

  factory LightingConfig.fromMap(dynamic map) {
    if (map is! Map) return const LightingConfig();
    final lights = map['ceilingLights'];
    return LightingConfig(
      masterOn: map['masterOn'] as bool? ?? true,
      autoAmbient: map['autoAmbient'] as bool? ?? true,
      ambient: AmbientModeX.fromKey(map['ambient'] as String?),
      ceilingLights: lights is List
          ? lights.whereType<Map>().map((m) => CeilingLightConfig.fromMap(Map<String, dynamic>.from(m))).toList()
          : defaultCeilingLights,
    );
  }

  @override
  List<Object?> get props => [masterOn, autoAmbient, ambient, ceilingLights];
}

/// How an emitter's intensity/colour evolves over time. Animations never touch the radius,
/// so the precomputed influence map stays valid.
enum LightAnim { none, flicker, tv, pulse, daylight, rgb }

/// Catalog metadata for furniture that emits light (lamps, fireplace, TV, windows...).
class EmitterLightSpec extends Equatable {
  final LightColor color;
  final double radius; // tiles
  final double intensity;
  final double height; // px above the anchor, for the glow halo only
  final LightAnim anim;
  final bool toggleable;
  final bool defaultOn;
  /// How much the object itself shows its own colours when lit (0 = takes the room's
  /// shadow like any furniture, 1 = fully self-lit like a lamp). A gaming desk only glows
  /// at the screen/LEDs, so it keeps part of the room's shadow.
  final double selfLit;
  /// The light follows the object's activation instead of a switch: it's on exactly while
  /// the object is active (e.g. the gaming desk while someone sits at it and its screen
  /// GIF plays). Such lights aren't toggleable by tap or from the panel.
  final bool followsActivation;

  const EmitterLightSpec({
    this.color = LightColor.warm,
    this.radius = 2.0,
    this.intensity = 0.9,
    this.height = 24,
    this.anim = LightAnim.none,
    this.toggleable = true,
    this.defaultOn = true,
    this.selfLit = 1.0,
    this.followsActivation = false,
  });

  factory EmitterLightSpec.fromJson(Map<String, dynamic> json) {
    return EmitterLightSpec(
      color: LightColor.fromHex(json['color'] as String?),
      radius: (json['radius'] as num?)?.toDouble() ?? 2.0,
      intensity: (json['intensity'] as num?)?.toDouble() ?? 0.9,
      height: (json['height'] as num?)?.toDouble() ?? 24,
      anim: LightAnim.values.firstWhere((a) => a.name == json['anim'], orElse: () => LightAnim.none),
      toggleable: json['toggleable'] as bool? ?? true,
      defaultOn: json['default_on'] as bool? ?? json['defaultOn'] as bool? ?? true,
      selfLit: ((json['self_lit'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0),
      followsActivation: json['follows_activation'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'color': '#${color.color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
        'radius': radius,
        'intensity': intensity,
        'height': height,
        'anim': anim.name,
        'toggleable': toggleable,
        'default_on': defaultOn,
        if (selfLit != 1.0) 'self_lit': selfLit,
        if (followsActivation) 'follows_activation': true,
      };

  /// Defaults for emitters that already exist in the catalog without a `light` block.
  /// Matched by id prefix so wall variants (`window_yellow_n`, `_w`) resolve too.
  static EmitterLightSpec? defaultFor(String id) {
    for (final entry in _defaults.entries) {
      if (id.startsWith(entry.key)) return entry.value;
    }
    return null;
  }

  static const Map<String, EmitterLightSpec> _defaults = {
    'table_lamp': EmitterLightSpec(radius: 2.0, intensity: 0.85, height: 30),
    'floor_lamp': EmitterLightSpec(radius: 2.5, intensity: 0.9, height: 62),
    'lava_lamp': EmitterLightSpec(
        color: LightColor.custom(0xFFFF5FA2), radius: 1.5, intensity: 0.6, height: 20, anim: LightAnim.pulse),
    'fireplace': EmitterLightSpec(
        color: LightColor.custom(0xFFFF9A3C), radius: 3.0, intensity: 1.0, height: 16, anim: LightAnim.flicker, selfLit: 0.55),
    'gaming_pc_desk': EmitterLightSpec(
        color: LightColor.custom(0xFFB388FF),
        radius: 2.0,
        intensity: 0.7,
        height: 30,
        anim: LightAnim.rgb,
        selfLit: 0.45,
        toggleable: false,
        defaultOn: false,
        followsActivation: true),
    'home_theater_tv': EmitterLightSpec(
        color: LightColor.custom(0xFF9EC9FF), radius: 2.0, intensity: 0.6, height: 28, anim: LightAnim.tv, defaultOn: false),
    'window_yellow': EmitterLightSpec(
        color: LightColor.cold, radius: 3.0, intensity: 0.8, height: 40, anim: LightAnim.daylight, toggleable: false),
    'curtained_window': EmitterLightSpec(
        color: LightColor.cold, radius: 3.0, intensity: 0.7, height: 40, anim: LightAnim.daylight, toggleable: false),
    'crt_tv_console': EmitterLightSpec(
        color: LightColor.custom(0xFF9EC9FF), radius: 1.8, intensity: 0.55, height: 24, anim: LightAnim.tv, defaultOn: false),
    'lantern': EmitterLightSpec(
        color: LightColor.custom(0xFFFFB25C), radius: 1.8, intensity: 0.7, height: 22, anim: LightAnim.flicker, selfLit: 0.4),
    'candelabra': EmitterLightSpec(
        color: LightColor.custom(0xFFFFB25C), radius: 2.2, intensity: 0.8, height: 56, anim: LightAnim.flicker, selfLit: 0.4),
    'stained_glass_window': EmitterLightSpec(
        color: LightColor.custom(0xFFB9A2FF), radius: 3.0, intensity: 0.6, height: 44, anim: LightAnim.daylight, toggleable: false),
  };

  @override
  List<Object?> get props => [color, radius, intensity, height, anim, toggleable, defaultOn, selfLit, followsActivation];
}
