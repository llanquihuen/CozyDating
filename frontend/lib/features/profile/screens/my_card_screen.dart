import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/lifestyle_badges.dart';
import '../../../core/models/profile_card_style.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../../core/services/profile_save_queue.dart';
import '../../avatar/widgets/lifestyle_badges_sheet.dart';
import '../../revelation/screens/match_reveal_celebration_view.dart';
import '../card/card_themes.dart';
import '../view/card_face_switch.dart';
import '../view/card_sections.dart';
import '../view/character_face_view.dart';
import '../view/profile_card_view.dart';
import '../view/real_face_feed.dart';
import '../widgets/card_style_sheet.dart';
import '../widgets/profile_photos_editor.dart';
import '../widgets/search_prefs_editor.dart';
import '../widgets/tastes_editor.dart';

/// "Tu tarjeta", opened from the room: everything on the player's card, editable in the order a
/// date sees it. First the character (seen before the campfire), then the real side (revealed at
/// the campfire), then what only the player sees (who they seek, age and distance). Light edits
/// open a short sheet that saves itself when it closes; the avatar opens the avatar editor.
class MyCardScreen extends StatefulWidget {
  const MyCardScreen({
    super.key,
    required this.profileOf,
    required this.onEditAvatar,
    this.saveStyle = AuthService.updateCardStyle,
    this.saveBio = saveBioToServer,
    this.saveLifestyle = saveLifestyleToServer,
    this.saveSearch = saveSearchToServer,
    this.onGenderChanged,
  });

  /// The current profile, read again after each edit (the room owns the live avatar).
  final UserProfile Function() profileOf;

  /// Opens the avatar editor; the card refreshes when it returns.
  final Future<void> Function() onEditAvatar;

  /// Each save reports whether the server took it.
  final Future<bool> Function(ProfileCardStyle style) saveStyle;
  final Future<bool> Function(String bio) saveBio;
  final Future<bool> Function(LifestyleBadges lifestyle) saveLifestyle;
  final Future<bool> Function(SearchPrefs prefs) saveSearch;

  /// The player's gender changed: the room refits the avatar to it.
  final ValueChanged<String>? onGenderChanged;

  static String get _userId => AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;

  static Future<bool> saveBioToServer(String bio) {
    AvatarStorageService.saveUserBio(_userId, bio);
    AuthService.updateDatingProfile(bio: bio);
    return AuthService.saveProfileToBackend();
  }

  /// Always through [AuthService.updateLifestyle]: the general profile save leaves the lifestyle out
  /// once every badge is cleared, so clearing the last one would never reach the server.
  static Future<bool> saveLifestyleToServer(LifestyleBadges lifestyle) {
    AvatarStorageService.saveUserLifestyle(_userId, lifestyle);
    return AuthService.updateLifestyle(lifestyle);
  }

  static Future<bool> saveSearchToServer(SearchPrefs p) {
    AvatarStorageService.saveUserMaxDistance(_userId, p.maxDistanceKm);
    AuthService.updateDatingProfile(
      gender: p.gender,
      seekingGender: p.seekingGender,
      age: p.age,
      commune: p.commune,
      isInternational: p.isInternational,
      maxDistanceKm: p.maxDistanceKm,
    );
    AuthService.updateSeekingAgeRange(p.seekingAgeMin, p.seekingAgeMax);
    return AuthService.saveProfileToBackend();
  }

  @override
  State<MyCardScreen> createState() => _MyCardScreenState();
}

class _MyCardScreenState extends State<MyCardScreen> {
  final ProfileSaveQueue _queue = ProfileSaveQueue();

  /// Edits made here, applied over [MyCardScreen.profileOf] until it reflects them (and kept when the
  /// server could not take them: they live on this phone meanwhile).
  final Map<String, UserProfile Function(UserProfile)> _patches = {};

  final TextEditingController _bio = TextEditingController();
  bool _savedToast = false;

  /// Which face the preview at the top shows.
  bool _previewReal = false;
  Timer? _toastTimer;

  UserProfile get _profile => _patches.values.fold(widget.profileOf(), (p, patch) => patch(p));

  @override
  void dispose() {
    _toastTimer?.cancel();
    _bio.dispose();
    super.dispose();
  }

  /// Applies [patch] at once and saves it; "Guardado" when the server took it, a notice with a retry
  /// when not (the change stays on this phone).
  Future<void> _save(String key, UserProfile Function(UserProfile) patch, Future<bool> Function() save) async {
    setState(() => _patches[key] = patch);
    final ok = await _queue.run(save);
    if (!mounted) return;
    if (ok) {
      _toastTimer?.cancel();
      setState(() => _savedToast = true);
      _toastTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _savedToast = false);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No pudimos guardarlo en el servidor. Se verá en este teléfono por ahora.'),
        action: SnackBarAction(label: 'Reintentar', onPressed: () => _save(key, patch, save)),
      ));
    }
  }

  Future<void> _editAvatar() async {
    await widget.onEditAvatar();
    if (mounted) setState(() {});
  }

  Future<void> _editStyle() async {
    final chosen = await showCardStyleSheet(context, _profile);
    if (chosen == null || !mounted) return;
    await _save('style', (p) => p.copyWith(cardStyle: chosen), () => widget.saveStyle(chosen));
  }

  Future<void> _editBio() async {
    final before = _profile.bio.trim();
    _bio.text = before;
    await _showSheet(
      title: 'Sobre mí',
      subtitle: 'Lo lee tu cita después de la fogata. Escribe como hablarías.',
      child: _BioField(controller: _bio),
    );
    final after = _bio.text.trim();
    if (after == before || !mounted) return;
    await _save('bio', (p) => p.copyWith(bio: after), () => widget.saveBio(after));
  }

  Future<void> _editLifestyle() async {
    final before = _profile.lifestyle;
    var latest = before;
    await LifestyleBadgesSheet.show(context, initialLifestyle: before, onSaved: (l) => latest = l);
    if (latest.toJson() == before.toJson() || !mounted) return;
    final chosen = latest;
    await _save('lifestyle', (p) => p.copyWith(lifestyle: chosen), () => widget.saveLifestyle(chosen));
  }

  Future<void> _editTastes() async {
    final profile = _profile;
    await _showSheet(
      title: 'Gustos',
      subtitle: 'Cada cambio se guarda al tocarlo.',
      child: TastesEditor(
        initialTastes: profile.tastes,
        initialIntent: profile.intent,
        onChanged: (tastes) => setState(() => _patches['tastes'] = (p) => p.copyWith(tastes: tastes)),
      ),
    );
  }

  Future<void> _editSearch() async {
    final p = _profile;
    final before = SearchPrefs(
      gender: p.gender,
      seekingGender: p.seekingGender,
      age: p.age,
      commune: p.commune,
      isInternational: p.isInternational,
      maxDistanceKm: p.maxDistanceKm,
      seekingAgeMin: p.seekingAgeMin,
      seekingAgeMax: p.seekingAgeMax,
    );
    var latest = before;
    await _showSheet(
      title: 'Lo que solo ves tú',
      subtitle: 'Sirve para emparejarte; no aparece en tu tarjeta.',
      child: SearchPrefsEditor(initial: before, onChanged: (v) => latest = v),
    );
    final v = latest;
    if (identical(v, before) || !mounted) return;
    await _save(
      'search',
      (p) => p
          .copyWith(
            gender: v.gender,
            seekingGender: v.seekingGender,
            age: v.age,
            commune: v.commune,
            isInternational: v.isInternational,
            maxDistanceKm: v.maxDistanceKm,
          )
          .withSeekingAgeRange(v.seekingAgeMin, v.seekingAgeMax),
      () => widget.saveSearch(v),
    );
    if (v.gender != before.gender) widget.onGenderChanged?.call(v.gender);
  }

  void _photosChanged(ProfilePhotos v) {
    final id = MyCardScreen._userId;
    if (v.profilePhoto != null) AvatarStorageService.saveUserPhoto(id, v.profilePhoto!);
    AvatarStorageService.saveUserPhotos(id, v.photos);
    AuthService.updateDatingProfile(profilePhoto: v.profilePhoto, photos: v.photos, isVerified: v.isVerified);
    setState(() => _patches['photos'] = (p) => p.copyWith(
          profilePhoto: v.profilePhoto,
          photos: v.photos,
          isVerified: v.isVerified,
          verificationSelfie: v.verificationSelfie,
        ));
  }

  /// A sheet that saves when it closes (however it closes).
  Future<void> _showSheet({required String title, required String subtitle, required Widget child}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14161F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(16, 10, 16, 24 + MediaQuery.viewInsetsOf(ctx).bottom),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Color(0xFF9A98A6), fontSize: 13)),
            const SizedBox(height: 14),
            child,
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Listo')),
          ],
        ),
      ),
    );
  }

  /// The photo blocks in the card theme's colours, legible on its surface.
  PhotosPalette _photosPalette(ProfileCardTheme theme, Color accent) {
    final surface = CardSection.surfaceOf(theme);
    final text = ProfileCardTheme.textOn(surface);
    final lightText = text.computeLuminance() > 0.5;
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    final button = TastesByCategory.readableFill(accent);
    return PhotosPalette(
      surface: surface,
      inner: Color.lerp(surface, lightText ? Colors.black : Colors.white, lightText ? 0.22 : 0.3)!,
      border: text.withValues(alpha: 0.16),
      accent: contrast(accent, surface) >= 3 ? accent : text,
      button: button,
      onButton: ProfileCardTheme.textOn(button),
      text: text,
      muted: text.withValues(alpha: 0.72),
    );
  }

  void _previewReveal() {
    final profile = _profile;
    showDialog<void>(
      context: context,
      builder: (ctx) => MatchRevealCelebrationView(
        localUser: profile,
        partnerUser: profile,
        partnerName: profile.username,
        isCelebration: false,
        isMutualMatch: false,
        isPreview: true,
        onReturnHome: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final style = profile.effectiveCardStyle.normalizedFor(profile.tastes);
    final theme = cardThemeOf(style.themeId);
    final accent = theme.accentOf(style);
    final background = Color.lerp(theme.base, Colors.black, 0.45)!;
    final text = ProfileCardTheme.textOn(background);

    Widget sideTitle(String title, String note) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              TextSpan(text: '  ·  $note', style: TextStyle(color: text.withValues(alpha: 0.65))),
            ]),
            style: TextStyle(color: text, fontSize: 12),
          ),
        );

    final outlined = OutlinedButton.styleFrom(
      foregroundColor: text,
      side: BorderSide(color: text.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    );

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        centerTitle: true,
        title: const Text('Tu tarjeta', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Ver cómo me ven',
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () => ProfileCardView.open(context, profile: profile, mode: ProfileViewMode.own),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // The card as a date sees it, either face.
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Center(
                  child: CardFaceSwitch(
                    real: _previewReal,
                    onChanged: (real) => setState(() => _previewReal = real),
                    accent: accent,
                    onAccent: theme.onAccent(accent),
                  ),
                ),
              ),
              Center(
                child: GestureDetector(
                  onTap: _previewReal
                      ? () => ProfileCardView.open(context, profile: profile, mode: ProfileViewMode.own, initiallyReal: true)
                      : _editAvatar,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: math.min(MediaQuery.sizeOf(context).width - 28, 340),
                      height: 540,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _previewReal
                            ? RealFaceCover(
                                key: const ValueKey('real'),
                                profile: profile,
                                style: style,
                                theme: theme,
                                accent: accent,
                                topInset: 0,
                                showHint: false,
                              )
                            : CharacterStage(
                                key: const ValueKey('character'),
                                profile: profile,
                                style: style,
                                theme: theme,
                                accent: accent,
                                fixedScale: 2,
                                feetAt: 0.6,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              sideTitle('👾 Tu personaje', 'lo ven antes de la fogata'),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                child: FilledButton.icon(
                  onPressed: _editAvatar,
                  icon: const Icon(Icons.checkroom, size: 19),
                  label: const Text('Vestir a mi personaje'),
                  style: FilledButton.styleFrom(
                    backgroundColor: TastesByCategory.readableFill(accent),
                    foregroundColor: ProfileCardTheme.textOn(TastesByCategory.readableFill(accent)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _editStyle,
                        icon: const Icon(Icons.palette_outlined, size: 18),
                        label: const Text('Estilo de la tarjeta'),
                        style: outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _previewReveal,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Ver la revelación'),
                        style: outlined,
                      ),
                    ),
                  ],
                ),
              ),
              sideTitle('📷 Tu lado real', 'se revela en la fogata'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ProfilePhotosEditor(
                  initial: ProfilePhotos(
                    profilePhoto: profile.profilePhoto,
                    photos: profile.photos,
                    isVerified: profile.isVerified,
                    verificationSelfie: profile.verificationSelfie,
                  ),
                  onChanged: _photosChanged,
                  palette: _photosPalette(theme, accent),
                ),
              ),
              _EditableSection(
                theme: theme,
                title: 'Sobre mí',
                onTap: _editBio,
                child: Text(
                  profile.bio.trim().isEmpty ? 'Cuéntale a tu cita quién eres.' : profile.bio.trim(),
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontStyle: profile.bio.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              _EditableSection(
                theme: theme,
                title: 'Estilo de vida',
                onTap: _editLifestyle,
                child: profile.lifestyle.activeBadges.isEmpty
                    ? const Text('Fumar, beber, mascotas, hijos… lo que quieras contar.',
                        style: TextStyle(fontStyle: FontStyle.italic))
                    : LifestyleGrid(badges: profile.lifestyle.activeBadges, theme: theme),
              ),
              _EditableSection(
                theme: theme,
                title: 'Gustos',
                onTap: _editTastes,
                child: TastesByCategory(
                  tastes: profile.tastes,
                  featured: style.featuredTastes,
                  theme: theme,
                  accent: accent,
                ),
              ),
              sideTitle('🔒 Solo tú ves esto', 'para emparejarte'),
              _EditableSection(
                theme: theme,
                title: 'Búsqueda',
                onTap: _editSearch,
                child: _SearchSummary(profile: profile),
              ),
            ],
          ),
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _savedToast ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(99)),
                    child: const Text('Guardado ✓',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A [CardSection] that opens its editor when tapped, with an "Editar" mark.
class _EditableSection extends StatelessWidget {
  const _EditableSection({required this.theme, required this.title, required this.onTap, required this.child});

  final ProfileCardTheme theme;
  final String title;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mark = TastesByCategory.readableFill(theme.accents.first);
    return Semantics(
      button: true,
      label: 'Editar $title',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [
            CardSection(theme: theme, title: title, child: child),
            Positioned(
              top: 16,
              right: 28,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: mark, borderRadius: BorderRadius.circular(99)),
                  child: Text('Editar',
                      style: TextStyle(color: ProfileCardTheme.textOn(mark), fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSummary extends StatelessWidget {
  const _SearchSummary({required this.profile});

  final UserProfile profile;

  static const Map<String, String> _seeking = {'MAN': 'Hombres', 'WOMAN': 'Mujeres', 'ANY': 'Todos'};

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final noAgeFilter = p.seekingAgeMin == null && p.seekingAgeMax == null;
    final rows = [
      ('💞 Busco conocer', _seeking[p.seekingGender] ?? 'Todos'),
      ('🎂 Edad', noAgeFilter ? 'Sin filtro' : '${p.seekingAgeMin ?? 18} – ${p.seekingAgeMax ?? 99} años'),
      ('📍 Distancia', p.isInternational ? 'Sin límite' : 'Hasta ${p.maxDistanceKm.round()} km'),
      if (p.commune.isNotEmpty) ('🏙️ Vivo en', p.commune),
    ];
    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}

class _BioField extends StatelessWidget {
  const _BioField({required this.controller});

  final TextEditingController controller;

  static const List<String> _starts = [
    'Un domingo perfecto es…',
    'Me rindo ante…',
    'En una mazmorra yo sería…',
    'Mi lugar favorito…',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLength: 300,
          minLines: 4,
          maxLines: 8,
          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1F2230),
            counterStyle: const TextStyle(color: Color(0xFF9A98A6)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 6),
        const Text('¿Sin ideas? Empieza con:', style: TextStyle(color: Color(0xFF9A98A6), fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in _starts)
              ActionChip(
                label: Text(s),
                onPressed: () {
                  controller.text = '${s.substring(0, s.length - 1)} ';
                  controller.selection = TextSelection.collapsed(offset: controller.text.length);
                },
              ),
          ],
        ),
      ],
    );
  }
}
