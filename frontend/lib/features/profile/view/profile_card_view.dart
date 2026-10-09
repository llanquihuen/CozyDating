import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/profile_card_style.dart';
import '../../../core/models/user_profile.dart';
import '../card/card_themes.dart';
import 'card_face_switch.dart';
import 'character_face_view.dart';
import 'real_face_feed.dart';

/// Where the fullscreen card is opened from; decides whether the real face is locked.
enum ProfileViewMode {
  /// Before the campfire: only the character face; the real one shows a lock.
  beforeReveal,

  /// At or after the reveal: both faces.
  revealed,

  /// The player's own card: both faces.
  own,
}

/// The main button at the bottom of the fullscreen card ("Aceptar" at the reveal, "Escribir" in
/// the mailbox...). The own card has none.
class ProfileCardAction {
  const ProfileCardAction({required this.label, required this.onPressed, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
}

/// A profile card at full screen: the character face on its stage and the real face as a vertical
/// feed, switched with the floating Personaje / Real pill.
class ProfileCardView extends StatefulWidget {
  const ProfileCardView({
    super.key,
    required this.profile,
    this.style,
    this.mode = ProfileViewMode.revealed,
    this.initiallyReal = false,
    this.distanceKm,
    this.action,
    this.avatarHeroTag,
  });

  final UserProfile profile;

  /// Overrides the profile's own style (live previews while editing it).
  final ProfileCardStyle? style;
  final ProfileViewMode mode;
  final bool initiallyReal;
  final double? distanceKm;
  final ProfileCardAction? action;

  /// Tag of the avatar on the compact card this view opens from, so the avatar flies in.
  final Object? avatarHeroTag;

  /// Pushes the fullscreen card over the current route (a dialog too) with a fade.
  static Future<void> open(
    BuildContext context, {
    required UserProfile profile,
    ProfileCardStyle? style,
    ProfileViewMode mode = ProfileViewMode.revealed,
    bool initiallyReal = false,
    double? distanceKm,
    ProfileCardAction? action,
    Object? avatarHeroTag,
  }) {
    return Navigator.of(context).push(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => ProfileCardView(
        profile: profile,
        style: style,
        mode: mode,
        initiallyReal: initiallyReal && mode != ProfileViewMode.beforeReveal,
        distanceKm: distanceKm,
        action: action,
        avatarHeroTag: avatarHeroTag,
      ),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
        );
      },
    ));
  }

  @override
  State<ProfileCardView> createState() => _ProfileCardViewState();
}

class _ProfileCardViewState extends State<ProfileCardView> {
  late bool _real = widget.initiallyReal && !_locked;
  bool _lockHint = false;
  Timer? _lockHintTimer;

  bool get _locked => widget.mode == ProfileViewMode.beforeReveal;

  void _showLockHint() {
    _lockHintTimer?.cancel();
    setState(() => _lockHint = true);
    _lockHintTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _lockHint = false);
    });
  }

  @override
  void dispose() {
    _lockHintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final style = (widget.style ?? profile.effectiveCardStyle).normalizedFor(profile.tastes);
    final theme = cardThemeOf(style.themeId);
    final accent = theme.accentOf(style);
    final padding = MediaQuery.paddingOf(context);
    final topInset = padding.top + 56;
    final bottomInset = padding.bottom + (widget.action == null ? 0 : 76);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: theme.base,
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _real
                    ? RealFaceFeed(
                        key: const ValueKey('real'),
                        profile: profile,
                        style: style,
                        theme: theme,
                        distanceKm: widget.distanceKm,
                        topInset: topInset,
                        bottomInset: bottomInset,
                      )
                    : CharacterFaceView(
                        key: const ValueKey('character'),
                        profile: profile,
                        style: style,
                        theme: theme,
                        avatarHeroTag: widget.avatarHeroTag,
                        topInset: topInset,
                        bottomInset: bottomInset,
                      ),
              ),
            ),
            Positioned(
              top: padding.top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: CardFaceSwitch(
                          real: _real,
                          onChanged: (real) => setState(() => _real = real),
                          accent: accent,
                          onAccent: theme.onAccent(accent),
                          realLocked: _locked,
                          onLockedTap: _showLockHint,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Positioned(
              top: padding.top + 56,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _lockHint ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xEE111114),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent),
                      ),
                      child: const Text(
                        'Se revela en la fogata al conectar',
                        style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.action != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomAction(action: widget.action!, theme: theme, accent: accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.14))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 20, color: Colors.white)),
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.action, required this.theme, required this.accent});

  final ProfileCardAction action;
  final ProfileCardTheme theme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final onAccent = theme.onAccent(accent);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.base.withValues(alpha: 0), theme.base.withValues(alpha: 0.92), theme.base],
          stops: const [0, 0.35, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: action.onPressed,
            icon: action.icon == null ? const SizedBox.shrink() : Icon(action.icon, size: 20),
            label: Text(action.label),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
