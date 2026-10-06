import 'package:flutter/material.dart';

import '../../../core/models/avatar_config.dart';
import '../editor/avatar_editor_controller.dart';
import '../editor/editor_style.dart';
import '../widgets/avatar_editor.dart';

/// Editing the avatar from the room: the shared [AvatarEditor] on a draft. "Guardar" hands the
/// result to [onSaved] and closes; leaving with unsaved changes asks first.
class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({super.key, required this.initialConfig, required this.gender, required this.onSaved});

  final AvatarConfig initialConfig;

  /// Profile gender ('MAN', 'WOMAN', 'NON_BINARY'...): which body and items are offered.
  final String gender;
  final ValueChanged<AvatarConfig> onSaved;

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  late final AvatarEditorController _controller =
      AvatarEditorController(initial: widget.initialConfig, gender: widget.gender)..addListener(_onChanged);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _save() {
    if (_controller.isDirty || _controller.config != widget.initialConfig) {
      widget.onSaved(_controller.config);
    }
    _controller.markSaved();
    Navigator.of(context).pop();
  }

  Future<void> _confirmLeave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EditorStyle.panel,
        title: const Text('¿Descartar cambios?', style: TextStyle(color: EditorStyle.text, fontSize: 17)),
        content: const Text(
          'Si sales ahora, tu avatar queda como estaba.',
          style: TextStyle(color: EditorStyle.muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir editando', style: TextStyle(color: EditorStyle.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar', style: TextStyle(color: Color(0xFFF87171))),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      _controller.removeListener(_onChanged);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dirty = _controller.isDirty;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: EditorStyle.background,
        appBar: AppBar(
          backgroundColor: EditorStyle.background,
          foregroundColor: EditorStyle.text,
          elevation: 0,
          centerTitle: true,
          title: const Text('Tu avatar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: dirty ? EditorStyle.accent : EditorStyle.line,
                  foregroundColor: dirty ? EditorStyle.background : EditorStyle.muted,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
        body: SafeArea(top: false, child: AvatarEditor(controller: _controller)),
      ),
    );
  }
}
