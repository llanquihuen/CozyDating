import 'package:flutter/material.dart';

import '../editor/editor_style.dart';

/// A palette of swatches plus "+" for a free colour. A current colour outside the palette is
/// shown (selected) before the "+".
class AvatarColorRow extends StatelessWidget {
  const AvatarColorRow({
    super.key,
    required this.label,
    required this.palette,
    required this.selected,
    required this.onSelected,
    this.singleLine = false,
  });

  final String label;
  final List<Color> palette;
  final Color selected;
  final ValueChanged<Color> onSelected;

  /// One line that scrolls sideways (pinned under a grid) instead of wrapping.
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final inPalette = palette.any((c) => c.toARGB32() == selected.toARGB32());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: EditorStyle.muted)),
        const SizedBox(height: 8),
        _layout([
            if (!inPalette) _Swatch(selected, true, onSelected),
            for (final colour in palette) _Swatch(colour, colour.toARGB32() == selected.toARGB32(), onSelected),
            Semantics(
              button: true,
              label: 'Otro color',
              child: InkResponse(
                onTap: () async {
                  final picked = await showDialog<Color>(
                    context: context,
                    builder: (_) => _FreeColorDialog(initial: selected),
                  );
                  if (picked != null) onSelected(picked);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: EditorStyle.strongLine),
                  ),
                  child: const Icon(Icons.add, size: 18, color: EditorStyle.muted),
                ),
              ),
            ),
          ]),
      ],
    );
  }

  Widget _layout(List<Widget> swatches) {
    if (!singleLine) return Wrap(spacing: 10, runSpacing: 10, children: swatches);
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: swatches.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => swatches[i],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.colour, this.selected, this.onSelected);

  final Color colour;
  final bool selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Color #${colour.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      child: GestureDetector(
        onTap: () => onSelected(colour),
        child: Container(
          width: 32,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? EditorStyle.accent : Colors.transparent, width: 2),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colour,
              shape: BoxShape.circle,
              border: Border.all(color: EditorStyle.line),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hue, saturation and lightness sliders with a live sample.
class _FreeColorDialog extends StatefulWidget {
  const _FreeColorDialog({required this.initial});

  final Color initial;

  @override
  State<_FreeColorDialog> createState() => _FreeColorDialogState();
}

class _FreeColorDialogState extends State<_FreeColorDialog> {
  late HSLColor _hsl = HSLColor.fromColor(widget.initial);

  Widget _slider(String label, double value, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 13, color: EditorStyle.muted))),
        Expanded(
          child: Slider(
            value: value,
            max: max,
            activeColor: EditorStyle.accent,
            inactiveColor: EditorStyle.line,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: EditorStyle.panel,
      title: const Text('Otro color', style: TextStyle(color: EditorStyle.text, fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(color: _hsl.toColor(), borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 12),
          _slider('Tono', _hsl.hue, 360, (v) => setState(() => _hsl = _hsl.withHue(v))),
          _slider('Intensidad', _hsl.saturation, 1, (v) => setState(() => _hsl = _hsl.withSaturation(v))),
          _slider('Luz', _hsl.lightness, 1, (v) => setState(() => _hsl = _hsl.withLightness(v))),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: EditorStyle.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_hsl.toColor()),
          child: const Text('Usar color', style: TextStyle(color: EditorStyle.accent)),
        ),
      ],
    );
  }
}
