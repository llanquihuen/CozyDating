import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/lifestyle_badges.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/core/services/auth_service.dart';
import 'package:frontend/features/profile/card/profile_card.dart';
import 'package:frontend/features/profile/screens/edit_profile_screen.dart';

const _valeria = UserProfile(
  id: 'user_edit_test',
  username: 'Valeria',
  profilePhoto: 'https://example.com/valeria_profile.jpg',
  photos: ['https://example.com/valeria_extra1.jpg'],
  bio: 'Me encanta el té verde, los juegos indies y leer bajo la lluvia.',
  age: 25,
  commune: 'Providencia',
  gender: 'WOMAN',
  seekingGender: 'MAN',
  tastes: ['intent_slow', 'game_coop', 'cinema_ghibli'],
  lifestyle: LifestyleBadges(heightCm: 175, smoking: 'no_smoke', drinking: 'social', pets: 'dog'),
);

/// Opens the screen from a home page, so popping it can be observed.
Future<List<AvatarConfig>> _open(WidgetTester tester, {UserProfile user = _valeria}) async {
  SharedPreferences.setMockInitialValues({});
  AuthService.setCurrentUserForTesting(user);
  addTearDown(() => AuthService.setCurrentUserForTesting(null));
  tester.view.physicalSize = const Size(430 * 2, 932 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final saved = <AvatarConfig>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EditProfileScreen(
                avatarConfig: const AvatarConfig(bodyType: 'female', hairStyle: 'bob'),
                onSaved: saved.add,
              ),
            )),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return saved;
}

/// Scrolls the form until [finder] matches something (the list only builds what is near the
/// screen), then brings its first match into view.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
    await tester.pump();
  }
  await tester.ensureVisible(finder.first);
  await tester.pump();
}

void main() {
  testWidgets('the card shows the real face on top, and the sections come in the agreed order', (tester) async {
    await _open(tester);
    expect(find.byType(ProfileCard), findsOneWidget);
    expect(find.text('Valeria, 25'), findsOneWidget);

    const order = [
      'Tus fotos',
      'Acerca de mí',
      'Quién eres y cómo es tu realidad de vida',
      'Vibes y gustos',
      'A quién buscas conocer',
      'Distancia y edad de búsqueda',
    ];
    double? last;
    for (final title in order) {
      await _scrollTo(tester, find.text(title));
      // Position in the whole form: scroll offset + where it shows on screen.
      final offset = tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
      final y = offset + tester.getTopLeft(find.text(title).first).dy;
      if (last != null) expect(y, greaterThan(last), reason: '$title comes after the previous section');
      last = y;
    }
    await _scrollTo(tester, find.text('Filtrar por edad'));
    expect(find.text('Filtrar por edad'), findsOneWidget);
  });

  testWidgets('the age filter is off by default; turning it on starts around your age and saves', (tester) async {
    final saved = await _open(tester);
    await _scrollTo(tester, find.text('Filtrar por edad'));
    expect(find.byType(RangeSlider), findsNothing);

    await tester.tap(find.descendant(of: find.ancestor(of: find.text('Filtrar por edad'), matching: find.byType(Row)).first, matching: find.byType(Switch)));
    await tester.pump();
    expect(find.text('20 – 30 años'), findsOneWidget, reason: 'Valeria is 25');
    expect(find.byType(RangeSlider), findsOneWidget);

    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(AuthService.currentUser!.seekingAgeMin, 20);
    expect(AuthService.currentUser!.seekingAgeMax, 30);
    expect(saved, hasLength(1));
    expect(find.text('abrir'), findsOneWidget, reason: 'closed after saving');
  });

  testWidgets('who you seek has its own section and saves', (tester) async {
    await _open(tester);
    final women = find.text('👩 Mujeres');
    await _scrollTo(tester, women);
    await tester.tap(women);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(AuthService.currentUser!.seekingGender, 'WOMAN');
  });

  testWidgets('a new gender refits the avatar handed back on save', (tester) async {
    final saved = await _open(tester);
    final man = find.text('👨 Hombre');
    await _scrollTo(tester, man);
    await tester.tap(man);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(saved.single.bodyType, 'male');
  });

  testWidgets('leaving with changes asks first; untouched closes at once', (tester) async {
    await _open(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('abrir'), findsOneWidget);

    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await _scrollTo(tester, find.byType(TextField)); // the first field is the bio
    await tester.enterText(find.byType(TextField).first, 'Otra bio');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(find.text('¿Descartar cambios?'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('abrir'), findsOneWidget);
    expect(AuthService.currentUser!.bio, _valeria.bio, reason: 'discarded');
  });

  testWidgets('saving without an official photo is blocked', (tester) async {
    await _open(tester, user: _valeria.copyWith(profilePhoto: '', photos: const []));
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Debes definir tu Foto de Perfil oficial para citas.'), findsOneWidget);
    expect(find.text('Editar perfil'), findsOneWidget, reason: 'still open');
  });

  testWidgets('selfie verification dialog opens and cancels cleanly (moved section)', (tester) async {
    await _open(tester);
    final cert = find.textContaining('Certificar con Selfie');
    await _scrollTo(tester, cert);
    await tester.tap(cert);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Certificación Facial'), findsOneWidget);
    expect(find.text('Abrir Cámara Frontal'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Certificación Facial'), findsNothing);
  });

  testWidgets('lifestyle badges show in their section (moved) and on the card', (tester) async {
    await _open(tester);
    expect(find.textContaining('175 cm'), findsWidgets, reason: 'on the card');
    final title = find.text('¿Quién eres y cómo es tu realidad de vida actual?');
    await _scrollTo(tester, title);
    expect(find.text('4/12'), findsOneWidget);
    expect(find.text('Gestionar mis Insignias (4/12 activas)'), findsOneWidget);
  });
}
