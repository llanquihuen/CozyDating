import 'package:flutter/material.dart';

import '../../../core/models/profile_card_style.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_service.dart';
import '../card/card_themes.dart';
import '../card/profile_card.dart';
import '../widgets/card_style_sheet.dart';

/// "Tu tarjeta", opened from the room: the player's two-sided card, a Personaje / Real switch that
/// flips it, a button to edit the visible face (avatar or dating profile) and the card's style.
class MyCardScreen extends StatefulWidget {
  const MyCardScreen({
    super.key,
    required this.profileOf,
    required this.onEditAvatar,
    required this.onEditProfile,
    this.saveStyle = AuthService.updateCardStyle,
    this.initiallyReal = false,
  });

  /// The current profile, read again after each edit (the room owns the live avatar).
  final UserProfile Function() profileOf;

  /// Open the avatar or the dating profile editor; the card refreshes when they return.
  final Future<void> Function() onEditAvatar;
  final Future<void> Function() onEditProfile;

  /// Persists a new card style; false when it could not be saved.
  final Future<bool> Function(ProfileCardStyle style) saveStyle;
  final bool initiallyReal;

  @override
  State<MyCardScreen> createState() => _MyCardScreenState();
}

class _MyCardScreenState extends State<MyCardScreen> {
  late bool _real = widget.initiallyReal;

  /// A style saved here but not (yet) reflected by [MyCardScreen.profileOf] (offline, or no session).
  ProfileCardStyle? _localStyle;

  UserProfile get _profile {
    final p = widget.profileOf();
    return _localStyle == null ? p : p.copyWith(cardStyle: _localStyle);
  }

  Future<void> _edit() async {
    await (_real ? widget.onEditProfile() : widget.onEditAvatar());
    if (mounted) setState(() {});
  }

  Future<void> _editStyle() async {
    final chosen = await showCardStyleSheet(context, _profile);
    if (chosen == null || !mounted) return;
    setState(() => _localStyle = chosen);
    final saved = await widget.saveStyle(chosen);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved ? 'Estilo guardado' : 'No pudimos guardar el estilo. Se verá solo en este teléfono por ahora.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final theme = cardThemeOf(profile.effectiveCardStyle.themeId);
    final accent = theme.accentOf(profile.effectiveCardStyle);
    final background = Color.lerp(theme.base, Colors.black, 0.55)!;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Tu tarjeta', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: GestureDetector(
                    // Anywhere on the card, text included (it ignores pointers).
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _real = !_real),
                    // Swipe sideways to flip too, like turning a card over.
                    onHorizontalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0).abs() > 200) setState(() => _real = !_real);
                    },
                    child: ProfileCard(profile: profile, showReal: _real),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _FaceSwitch(real: _real, accent: accent, onChanged: (real) => setState(() => _real = real)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _edit,
                  icon: Icon(_real ? Icons.edit_note : Icons.checkroom),
                  label: Text(_real ? 'Editar perfil' : 'Editar avatar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: theme.onAccent(accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    // Merged into the theme's style, so the button keeps the app's font.
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _editStyle,
                  icon: const Icon(Icons.palette_outlined, size: 19),
                  label: const Text('Estilo de la tarjeta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Personaje / Real: which face of the card is shown.
class _FaceSwitch extends StatelessWidget {
  const _FaceSwitch({required this.real, required this.accent, required this.onChanged});

  final bool real;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool value) {
      final selected = real == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: selected ? accent.withValues(alpha: 0.22) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white60,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(13)),
      child: Row(children: [option('Personaje', false), option('Real', true)]),
    );
  }
}
