import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../editor/avatar_editor_controller.dart';
import '../editor/editor_style.dart';
import '../editor/editor_tabs.dart';
import '../games/character_preview_game.dart';
import '../services/avatar_thumbnail_service.dart';
import 'avatar_color_row.dart';
import 'avatar_item_picker.dart';

/// The avatar editor shared by registration and the room (layout A): the live preview fixed on
/// top, then the tabs, the section pills, the thumbnail grid and the colour row. It edits
/// [controller]; saving, skipping or leaving is up to the screen around it.
class AvatarEditor extends StatefulWidget {
  const AvatarEditor({super.key, required this.controller, this.thumbnails});

  final AvatarEditorController controller;

  /// Shared thumbnail cache; the editor makes its own when none is given.
  final AvatarThumbnailService? thumbnails;

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  late final AvatarThumbnailService _thumbnails = widget.thumbnails ?? AvatarThumbnailService();
  late final CharacterPreviewGame _preview;
  String _tabId = editorTabs.first.id;

  /// Horizontal drag on the preview turns the avatar one direction per [_dragStep] pixels.
  static const double _dragStep = 18;
  double _drag = 0;

  /// Open section per tab, so coming back to a tab shows the same pill.
  final Map<String, String> _sectionOfTab = {};

  @override
  void initState() {
    super.initState();
    final tab = _currentTab;
    _preview = CharacterPreviewGame(config: widget.controller.config, initialFaceZoom: tab.faceFocus);
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(AvatarEditor old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _onChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final config = widget.controller.config;
    if (_preview.config != config) {
      // Before the game loads, its onLoad reads the config field.
      _preview.isLoaded ? _preview.updateConfig(config) : _preview.config = config;
    }
    setState(() {});
  }

  /// The open tab; falls back to the first when it was hidden (e.g. after a gender change).
  EditorTab get _currentTab {
    final tabs = widget.controller.tabs;
    return tabs.firstWhere((t) => t.id == _tabId, orElse: () => tabs.first);
  }

  EditorSection _currentSection(EditorTab tab) {
    final id = _sectionOfTab[tab.id];
    return tab.sections.firstWhere((s) => s.id == id, orElse: () => tab.sections.first);
  }

  void _openTab(EditorTab tab) {
    setState(() => _tabId = tab.id);
    _preview.setFaceFocus(tab.faceFocus);
  }

  @override
  Widget build(BuildContext context) {
    final tab = _currentTab;
    final section = _currentSection(tab);
    return ColoredBox(
      color: EditorStyle.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final previewHeight = (constraints.maxHeight * 0.3).clamp(170.0, 300.0);
          return Column(
            children: [
              SizedBox(height: previewHeight, child: _buildPreview()),
              _buildTabBar(tab),
              if (tab.sections.length > 1) _buildPills(tab, section),
              Expanded(
                child: SingleChildScrollView(
                  key: PageStorageKey('avatar-editor/${tab.id}/${section.id}'),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (section.slot != null)
                        AvatarItemPicker(controller: widget.controller, section: section, thumbnails: _thumbnails)
                      else
                        for (final target in section.colors) ...[
                          _colorRow(target, singleLine: false),
                          const SizedBox(height: 16),
                        ],
                    ],
                  ),
                ),
              ),
              // Under a grid the colours stay pinned in reach, however long the grid is.
              if (section.slot != null && section.colors.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: const BoxDecoration(
                    color: EditorStyle.panel,
                    border: Border(top: BorderSide(color: EditorStyle.line)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, target) in section.colors.indexed) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _colorRow(target, singleLine: true),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _colorRow(ColorTarget target, {required bool singleLine}) => AvatarColorRow(
        key: ValueKey(target.label),
        label: target.label,
        palette: target.palette,
        selected: widget.controller.colorOf(target),
        onSelected: (c) => widget.controller.setColor(target, c),
        singleLine: singleLine,
      );

  Widget _buildPreview() {
    final controller = widget.controller;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(color: EditorStyle.panel, borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                _drag += details.delta.dx;
                while (_drag.abs() >= _dragStep) {
                  _drag > 0 ? _preview.rotateRight() : _preview.rotateLeft();
                  _drag -= _drag.sign * _dragStep;
                }
              },
              onHorizontalDragEnd: (_) => _drag = 0,
              child: GameWidget(game: _preview),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Row(children: [
              _roundButton(Icons.rotate_left, 'Girar a la izquierda', () => _preview.rotateLeft()),
              _roundButton(Icons.rotate_right, 'Girar a la derecha', () => _preview.rotateRight()),
              _roundButton(Icons.directions_walk, 'Caminar', () => setState(_preview.toggleWalk),
                  active: _preview.isWalking),
            ]),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Row(children: [
              _roundButton(Icons.undo, 'Deshacer', controller.undo, enabled: controller.canUndo),
              _roundButton(Icons.casino_outlined, 'Avatar al azar', controller.randomize),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onTap, {bool enabled = true, bool active = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: active ? EditorStyle.accentWash : EditorStyle.line,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon,
                  size: 18,
                  color: !enabled
                      ? EditorStyle.strongLine
                      : active
                          ? EditorStyle.accent
                          : EditorStyle.text),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(EditorTab current) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: EditorStyle.line))),
      child: Row(
        children: [
          for (final tab in widget.controller.tabs)
            Expanded(
              child: Semantics(
                button: true,
                selected: tab.id == current.id,
                child: InkWell(
                  onTap: () => _openTab(tab),
                  child: Container(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: tab.id == current.id ? EditorStyle.accent : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(tab.icon, size: 20, color: tab.id == current.id ? EditorStyle.accent : EditorStyle.muted),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: tab.id == current.id ? EditorStyle.accent : EditorStyle.muted,
                              fontWeight: tab.id == current.id ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPills(EditorTab tab, EditorSection current) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        children: [
          for (final section in tab.sections)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(section.label),
                selected: section.id == current.id,
                showCheckmark: false,
                onSelected: (_) => setState(() => _sectionOfTab[tab.id] = section.id),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: section.id == current.id ? EditorStyle.accent : EditorStyle.muted,
                  fontWeight: section.id == current.id ? FontWeight.w600 : FontWeight.w400,
                ),
                backgroundColor: EditorStyle.background,
                selectedColor: EditorStyle.accentWash,
                side: BorderSide(color: section.id == current.id ? EditorStyle.accent : EditorStyle.strongLine),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}
