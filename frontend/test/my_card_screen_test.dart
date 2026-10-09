import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/lifestyle_badges.dart';
import 'package:frontend/core/models/profile_card_style.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/features/profile/screens/my_card_screen.dart';
import 'package:frontend/features/profile/view/profile_card_view.dart';
import 'package:frontend/features/profile/widgets/search_prefs_editor.dart';
import 'package:frontend/features/revelation/screens/match_reveal_celebration_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kai = UserProfile(
  id: 'kai',
  username: 'Kai',
  age: 29,
  commune: 'Ñuñoa',
  gender: 'WOMAN',
  seekingGender: 'MAN',
  profilePhoto: 'https://example.com/kai.jpg',
  tastes: ['intent_slow', 'plat_pc', 'game_roguelike', 'music_synthwave', 'fuel_energy', 'pet_cat', 'life_books'],
  lifestyle: LifestyleBadges(smoking: 'no_smoke', drinking: 'social'),
  cardStyle: ProfileCardStyle(themeId: 'arcade', featuredTastes: ['plat_pc', 'game_roguelike', 'music_synthwave']),
);

class _Calls {
  int avatar = 0;
  final styles = <ProfileCardStyle>[];
  final bios = <String>[];
  final lifestyles = <LifestyleBadges>[];
  final searches = <SearchPrefs>[];
  final genders = <String>[];
  bool saveWorks = true;
}

Future<_Calls> _open(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final calls = _Calls();
  Future<bool> save<T>(List<T> into, T value) async {
    into.add(value);
    return calls.saveWorks;
  }

  await tester.pumpWidget(MaterialApp(
    home: MyCardScreen(
      profileOf: () => _kai,
      onEditAvatar: () async => calls.avatar++,
      saveStyle: (s) => save(calls.styles, s),
      saveBio: (b) => save(calls.bios, b),
      saveLifestyle: (l) => save(calls.lifestyles, l),
      saveSearch: (p) => save(calls.searches, p),
      onGenderChanged: calls.genders.add,
    ),
  ));
  await tester.pump();
  return calls;
}

final _page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

/// Scrolls the page (or the open sheet, the last scrollable) until [finder] is visible.
Future<void> _scrollTo(WidgetTester tester, Finder finder, {bool inSheet = false, bool up = false}) async {
  final scrollable = inSheet
      ? find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last
      : _page;
  await tester.scrollUntilVisible(finder, up ? -150 : 150, scrollable: scrollable);
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _openStyle(WidgetTester tester) async {
  await _scrollTo(tester, find.text('Estilo de la tarjeta'));
  await tester.tap(find.text('Estilo de la tarjeta'));
  await _settle(tester);
}

Future<void> _openSection(WidgetTester tester, String title) async {
  final section = find.bySemanticsLabel(RegExp('^Editar $title'));
  await _scrollTo(tester, section);
  await tester.tap(section);
  await _settle(tester);
}

Future<void> _closeSheet(WidgetTester tester) async {
  await _scrollTo(tester, find.text('Listo'), inSheet: true);
  await tester.tap(find.text('Listo'));
  await _settle(tester);
}

void main() {
  testWidgets('the card is edited in the order a date sees it', (tester) async {
    await _open(tester);
    expect(find.text('Tu tarjeta'), findsOneWidget);
    const order = ['👾 TU PERSONAJE', '📷 TU LADO REAL', '🔒 SOLO TÚ VES ESTO'];
    double? last;
    for (final title in order) {
      final finder = find.textContaining(title, findRichText: true);
      await _scrollTo(tester, finder);
      final y = tester.state<ScrollableState>(_page).position.pixels + tester.getTopLeft(finder).dy;
      if (last != null) expect(y, greaterThan(last), reason: title);
      last = y;
    }
  });

  testWidgets('"Vestir a mi personaje" and the character itself open the avatar editor', (tester) async {
    final calls = await _open(tester);
    await tester.tap(find.text('Vestir a mi personaje'));
    await tester.pump();
    expect(calls.avatar, 1);
    await tester.tap(find.text('Kai').first);
    await tester.pump();
    expect(calls.avatar, 2);
  });

  testWidgets('the style sheet saves the theme, phrase and featured tastes', (tester) async {
    final calls = await _open(tester);
    await _openStyle(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('^Rústico / Forest')).first);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Plantas y ramen');
    await tester.pump();
    final books = find.textContaining('Lectura');
    await _scrollTo(tester, books, inSheet: true);
    await tester.tap(books);
    await tester.pump();

    await tester.tap(find.text('Guardar'));
    await _settle(tester);

    final saved = calls.styles.single;
    expect(saved.themeId, 'forest');
    expect(saved.accent, isNull, reason: 'a new theme starts from its own accent');
    expect(saved.phrase, 'Plantas y ramen');
    expect(saved.featuredTastes, ['plat_pc', 'game_roguelike', 'music_synthwave', 'life_books']);
    expect(find.text('Guardado ✓'), findsOneWidget);
    await _scrollTo(tester, find.text('Plantas y ramen'), up: true);
    expect(find.text('Plantas y ramen'), findsOneWidget, reason: 'the character says the new phrase');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('featured tastes stay between 1 and 5, never the intent', (tester) async {
    final calls = await _open(tester);
    await _openStyle(tester);
    await _scrollTo(tester, find.textContaining('Lectura'), inSheet: true);
    expect(find.textContaining('Conocer sin prisa'), findsNothing, reason: 'the intent cannot be featured');

    Future<void> tapTaste(String text) async {
      final chip = find.descendant(of: find.byType(FilterChip), matching: find.textContaining(text));
      await _scrollTo(tester, chip, inSheet: true);
      await tester.tap(chip);
      await tester.pump();
    }

    for (final t in ['Energéticas', 'Gatos', 'Lectura']) {
      await tapTaste(t); // 3 -> 6 asked, capped at 5
    }
    expect(find.text('5 de 5'), findsOneWidget);
    for (final t in ['PC Master Race', 'Roguelikes', 'Synthwave', 'Energéticas', 'Gatos']) {
      await tapTaste(t); // removing all but one
    }
    expect(find.text('1 de 5'), findsOneWidget);

    await tester.tap(find.text('Guardar'));
    await _settle(tester);
    expect(calls.styles.single.featuredTastes, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('closing the style sheet without saving changes nothing', (tester) async {
    final calls = await _open(tester);
    await _openStyle(tester);
    await tester.enterText(find.byType(TextField), 'Borrador');
    await tester.tapAt(const Offset(195, 20)); // outside the sheet
    await _settle(tester);
    expect(calls.styles, isEmpty);
    expect(find.text('Borrador'), findsNothing);
  });

  testWidgets('the bio saves itself when its sheet closes, however it closes', (tester) async {
    final calls = await _open(tester);
    await _openSection(tester, 'Sobre mí');
    expect(find.text('¿Sin ideas? Empieza con:'), findsOneWidget);
    await tester.tap(find.text('Me rindo ante…'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Me rindo ante un buen ramen.');
    await tester.tapAt(const Offset(195, 20)); // dismissed, not "Listo"
    await _settle(tester);
    expect(calls.bios, ['Me rindo ante un buen ramen.']);
    expect(find.text('Me rindo ante un buen ramen.'), findsOneWidget);

    await _openSection(tester, 'Sobre mí');
    await _closeSheet(tester);
    expect(calls.bios, hasLength(1), reason: 'unchanged: nothing to save');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a save the server refuses stays on the phone, with a retry', (tester) async {
    final calls = await _open(tester)..saveWorks = false;
    await _openSection(tester, 'Sobre mí');
    await tester.enterText(find.byType(TextField), 'Sin conexión');
    await _closeSheet(tester);
    expect(find.textContaining('No pudimos guardarlo en el servidor'), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget, reason: 'kept on this phone');

    calls.saveWorks = true;
    await tester.tap(find.text('Reintentar'));
    await _settle(tester);
    expect(calls.bios, ['Sin conexión', 'Sin conexión']);
    expect(find.text('Guardado ✓'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('who you seek and the age filter save from their sheet; the summary follows', (tester) async {
    final calls = await _open(tester);
    await _scrollTo(tester, find.text('Sin filtro'));
    await _openSection(tester, 'Búsqueda');

    final women = find.text('👩 Mujeres');
    await _scrollTo(tester, women, inSheet: true);
    await tester.tap(women);
    await tester.pump();
    final ageFilter = find.text('Filtrar por edad');
    await _scrollTo(tester, ageFilter, inSheet: true);
    expect(find.byType(RangeSlider), findsNothing, reason: 'off by default');
    await tester.tap(find.descendant(
        of: find.ancestor(of: ageFilter, matching: find.byType(Row)).first, matching: find.byType(Switch)));
    await tester.pump();
    expect(find.text('24 – 34 años'), findsOneWidget, reason: 'Kai is 29');
    await _closeSheet(tester);

    final saved = calls.searches.single;
    expect(saved.seekingGender, 'WOMAN');
    expect((saved.seekingAgeMin, saved.seekingAgeMax), (24, 34));
    expect(calls.genders, isEmpty, reason: 'her own gender did not change');
    await _scrollTo(tester, find.text('Mujeres'));
    expect(find.text('24 – 34 años'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a new gender asks the room to refit the avatar', (tester) async {
    final calls = await _open(tester);
    await _openSection(tester, 'Búsqueda');
    final man = find.text('👨 Hombre');
    await _scrollTo(tester, man, inSheet: true);
    await tester.tap(man);
    await tester.pump();
    await _closeSheet(tester);
    expect(calls.searches.single.gender, 'MAN');
    expect(calls.genders, ['MAN']);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('selfie verification opens from the photos and cancels cleanly', (tester) async {
    await _open(tester);
    final cert = find.textContaining('Certificar con Selfie');
    await _scrollTo(tester, cert);
    await tester.tap(cert);
    await _settle(tester);
    expect(find.text('Certificación Facial'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await _settle(tester);
    expect(find.text('Certificación Facial'), findsNothing);
  });

  testWidgets('"Ver cómo me ven" opens the fullscreen card; "Ver la revelación" the reveal', (tester) async {
    await _open(tester);
    await tester.tap(find.byTooltip('Ver cómo me ven'));
    await _settle(tester);
    expect(tester.widget<ProfileCardView>(find.byType(ProfileCardView)).mode, ProfileViewMode.own);
    await tester.tap(find.byTooltip('Cerrar'));
    await _settle(tester);

    await _scrollTo(tester, find.text('Ver la revelación'));
    await tester.tap(find.text('Ver la revelación'));
    await _settle(tester);
    expect(find.byType(MatchRevealCelebrationView), findsOneWidget);
    expect(find.text('VISTA PREVIA DE TU PERFIL'), findsOneWidget);
    await tester.pump(MatchRevealCelebrationView.revealDelay);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Kai, 29'), findsWidgets, reason: 'the reveal card turned to the real face');
  });
}
