import 'package:flutter/material.dart';
import '../../../core/models/lighting_config.dart';
import '../games/cozy_room_game.dart';

/// Colour presets offered for lights: the two whites plus a few cozy colours.
const List<LightColor> kLightColorPresets = [
  LightColor.warm,
  LightColor.cold,
  LightColor.custom(0xFFFF5FD2), // rosa
  LightColor.custom(0xFFB388FF), // lavanda
  LightColor.custom(0xFF64B5F6), // azul
  LightColor.custom(0xFF69F0AE), // menta
  LightColor.custom(0xFFFFB300), // ámbar
  LightColor.custom(0xFFFF6E6E), // coral
];

const Color _kSheetBg = Color(0xFF1E1C27);
const Color _kCardBg = Color(0xFF282531);
const Color _kBorder = Color(0xFF453F58);
const Color _kAccent = Color(0xFFFFD54F);

/// Lights panel: general switch, ambient (día / atardecer / noche) and every switchable
/// light grouped by room. Ceiling lights can also change colour from here.
class LightingPanelSheet extends StatefulWidget {
  final CozyRoomGame game;
  final VoidCallback onChanged;

  const LightingPanelSheet({super.key, required this.game, required this.onChanged});

  static Future<void> show(BuildContext context, {required CozyRoomGame game, required VoidCallback onChanged}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black26,
      builder: (_) => LightingPanelSheet(game: game, onChanged: onChanged),
    );
  }

  @override
  State<LightingPanelSheet> createState() => _LightingPanelSheetState();
}

class _LightingPanelSheetState extends State<LightingPanelSheet> {
  String? _expandedId;

  CozyRoomGame get _game => widget.game;

  void _changed() {
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lighting = _game.roomConfig.lighting;
    final entries = _game.lightPanelEntries();
    final sectorNames = _game.lightSectorNames();
    final bySector = <int, List<LightPanelEntry>>{};
    for (final e in entries) {
      bySector.putIfAbsent(e.sector, () => []).add(e);
    }
    final hasCeiling = entries.any((e) => e.isCeiling);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: MediaQuery.of(context).padding.bottom + 16),
        decoration: const BoxDecoration(
          color: _kSheetBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: _kBorder, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text('💡 Iluminación',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _kAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Flexible(
                  child: Text(lighting.masterOn ? 'Techo encendido' : 'Techo apagado',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ),
                const SizedBox(width: 6),
                Switch(
                  value: lighting.masterOn,
                  activeColor: _kAccent,
                  onChanged: (v) {
                    _game.setLightingMasterOn(v);
                    _changed();
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            _AmbientSelector(
              auto: lighting.autoAmbient,
              value: lighting.ambient,
              current: _game.effectiveAmbient,
              onAuto: () {
                _game.setLightingAmbientAuto();
                _changed();
              },
              onChanged: (mode) {
                _game.setLightingAmbient(mode);
                _changed();
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (!lighting.masterOn)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Luces de techo apagadas por el interruptor general: cada una vuelve a su estado al encenderlo. Las lámparas y objetos no se ven afectados.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                  for (final sector in bySector.keys.toList()..sort()) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                      child: Text(
                        (sectorNames[sector] ?? 'Zona').toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ),
                    for (final e in bySector[sector]!) _buildRow(e, dimmed: e.isCeiling && !lighting.masterOn),
                  ],
                  if (!hasCeiling)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: const Text(
                        'Aún no tienes luces de techo. Agrégalas en Decorar → "💡 Luz de techo" y muévelas donde quieras.',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(LightPanelEntry e, {required bool dimmed}) {
    final expanded = e.isCeiling && _expandedId == e.id;
    return Opacity(
      opacity: dimmed ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: expanded ? _kAccent.withOpacity(0.6) : _kBorder),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: e.isCeiling ? () => setState(() => _expandedId = expanded ? null : e.id) : null,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Row(
                  children: [
                    Icon(e.isCeiling ? Icons.light_rounded : Icons.lightbulb_outline_rounded,
                        color: e.on ? e.color : Colors.white30, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.label,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                    if (e.isCeiling)
                      Icon(expanded ? Icons.expand_less : Icons.palette_outlined, color: Colors.white38, size: 16),
                    Switch(
                      value: e.on,
                      activeColor: _kAccent,
                      onChanged: (v) {
                        _game.setLightOn(e.id, v);
                        _changed();
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: LightColorChips(
                  selected: _game.ceilingLightById(e.id)?.color,
                  onSelected: (color) {
                    _game.updateCeilingLight(e.id, (c) => c.copyWith(color: color));
                    _changed();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AmbientSelector extends StatelessWidget {
  final bool auto;
  final AmbientMode value;
  final AmbientMode current;
  final VoidCallback onAuto;
  final ValueChanged<AmbientMode> onChanged;

  const _AmbientSelector({
    required this.auto,
    required this.value,
    required this.current,
    required this.onAuto,
    required this.onChanged,
  });

  static const _labels = {
    AmbientMode.day: ('☀️', 'Día'),
    AmbientMode.evening: ('🌇', 'Atardecer'),
    AmbientMode.night: ('🌙', 'Noche'),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _option('🕒', 'Auto', selected: auto, onTap: onAuto)),
            for (final mode in AmbientMode.values) ...[
              const SizedBox(width: 6),
              Expanded(
                child: _option(_labels[mode]!.$1, _labels[mode]!.$2,
                    selected: !auto && value == mode, onTap: () => onChanged(mode)),
              ),
            ],
          ],
        ),
        if (auto)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Sigue la hora del teléfono · ahora: ${_labels[current]!.$2}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 10.5),
            ),
          ),
      ],
    );
  }

  Widget _option(String emoji, String label, {required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kAccent.withOpacity(0.18) : _kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _kAccent : _kBorder, width: 1.2),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: selected ? _kAccent : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// Fría / Cálida / colour swatches.
class LightColorChips extends StatelessWidget {
  final LightColor? selected;
  final ValueChanged<LightColor> onSelected;

  const LightColorChips({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final c in kLightColorPresets)
          if (c.preset != 'custom')
            ChoiceChip(
              label: Text(c.preset == 'warm' ? 'Cálida' : 'Fría', style: const TextStyle(fontSize: 11)),
              avatar: CircleAvatar(backgroundColor: c.color, radius: 7),
              selected: selected == c,
              selectedColor: _kAccent.withOpacity(0.25),
              backgroundColor: _kSheetBg,
              labelStyle: const TextStyle(color: Colors.white),
              side: BorderSide(color: selected == c ? _kAccent : _kBorder),
              onSelected: (_) => onSelected(c),
            )
          else
            GestureDetector(
              onTap: () => onSelected(c),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c.color,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: selected == c ? Colors.white : Colors.black26, width: selected == c ? 2.5 : 1),
                  boxShadow: [BoxShadow(color: c.color.withOpacity(0.5), blurRadius: 6)],
                ),
              ),
            ),
      ],
    );
  }
}

/// Decorate mode: colour, intensity and size of the selected ceiling light, applied live.
class CeilingLightSettingsSheet extends StatefulWidget {
  final CozyRoomGame game;
  final String lightId;

  const CeilingLightSettingsSheet({super.key, required this.game, required this.lightId});

  static Future<void> show(BuildContext context, {required CozyRoomGame game, required String lightId}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black12,
      builder: (_) => CeilingLightSettingsSheet(game: game, lightId: lightId),
    );
  }

  @override
  State<CeilingLightSettingsSheet> createState() => _CeilingLightSettingsSheetState();
}

class _CeilingLightSettingsSheetState extends State<CeilingLightSettingsSheet> {
  void _update(CeilingLightConfig Function(CeilingLightConfig) change) {
    widget.game.updateCeilingLight(widget.lightId, change);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final light = widget.game.ceilingLightById(widget.lightId);
    if (light == null) return const SizedBox.shrink();
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 16),
        decoration: const BoxDecoration(
          color: _kSheetBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: _kBorder, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💡 Luz de techo', style: TextStyle(color: _kAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            LightColorChips(selected: light.color, onSelected: (c) => _update((l) => l.copyWith(color: c))),
            const SizedBox(height: 14),
            _slider(
              label: 'Intensidad',
              value: light.intensity,
              min: 0.3,
              max: 1.5,
              display: '${(light.intensity * 100).round()}%',
              onChanged: (v) => _update((l) => l.copyWith(intensity: v)),
            ),
            _slider(
              label: 'Alcance',
              value: light.radius,
              min: 1.5,
              max: 5.0,
              divisions: 7,
              display: '${light.radius.toStringAsFixed(1)} casillas',
              onChanged: (v) => _update((l) => l.copyWith(radius: v)),
            ),
            const Text(
              'Tip: ponte en modo Noche desde el botón 💡 para ver mejor cómo ilumina.',
              style: TextStyle(color: Colors.white38, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: _kAccent,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 76,
          child: Text(display, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ),
      ],
    );
  }
}
