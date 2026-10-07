import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/profile_card_style.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/features/profile/card/profile_card.dart';
import 'package:frontend/features/profile/screens/my_card_screen.dart';
import 'package:frontend/features/revelation/screens/match_reveal_celebration_view.dart';

const _kai = UserProfile(
  id: 'kai',
  username: 'Kai',
  age: 29,
  commune: 'Ñuñoa',
  tastes: ['intent_slow', 'plat_pc', 'game_roguelike', 'music_synthwave', 'fuel_energy', 'pet_cat', 'life_books'],
  cardStyle: ProfileCardStyle(themeId: 'arcade', featuredTastes: ['plat_pc', 'game_roguelike', 'music_synthwave']),
);

class _Calls {
  int avatar = 0;
  int profile = 0;
  final saved = <ProfileCardStyle>[];
  bool saveWorks = true;
}

Future<_Calls> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final calls = _Calls();
  await tester.pumpWidget(MaterialApp(
    home: MyCardScreen(
      profileOf: () => _kai,
      onEditAvatar: () async => calls.avatar++,
      onEditProfile: () async => calls.profile++,
      saveStyle: (style) async {
        calls.saved.add(style);
        return calls.saveWorks;
      },
    ),
  ));
  await tester.pump();
  return calls;
}

/// Scrolls the style sheet down until [finder] is built and visible.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  final sheetList = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last;
  await tester.scrollUntilVisible(finder, 120, scrollable: sheetList);
  await tester.pump();
}

Future<void> _openStyle(WidgetTester tester) async {
  await tester.tap(find.text('Estilo de la tarjeta'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('starts on the character face; the switch flips it and the edit button follows', (tester) async {
    final calls = await _open(tester);
    expect(find.text('Kai'), findsOneWidget);
    expect(find.text('Kai, 29'), findsNothing);
    await tester.tap(find.text('Editar avatar'));
    await tester.pump();
    expect(calls.avatar, 1);

    await tester.tap(find.text('Real'));
    await tester.pump(); // the flip starts on the next frame
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Kai, 29'), findsOneWidget);
    await tester.tap(find.text('Editar perfil'));
    await tester.pump();
    expect(calls.profile, 1);

    await tester.tap(find.byType(ProfileCard)); // tapping the card flips it back
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Editar avatar'), findsOneWidget);
  });

  testWidgets('the style sheet saves the theme, phrase and featured tastes', (tester) async {
    final calls = await _open(tester);
    await _openStyle(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('^Rústico / Forest')).first);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Plantas y ramen');
    await tester.pump();
    final books = find.textContaining('Lectura');
    await _scrollTo(tester, books);
    await tester.tap(books);
    await tester.pump();

    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final saved = calls.saved.single;
    expect(saved.themeId, 'forest');
    expect(saved.accent, isNull, reason: 'a new theme starts from its own accent');
    expect(saved.phrase, 'Plantas y ramen');
    expect(saved.featuredTastes, ['plat_pc', 'game_roguelike', 'music_synthwave', 'life_books']);
    expect(find.text('Estilo guardado'), findsOneWidget);
    expect(find.text('“Plantas y ramen”'), findsOneWidget, reason: 'the card shows the new style');
  });

  testWidgets('featured tastes stay between 1 and 5, never the intent', (tester) async {
    final calls = await _open(tester);
    await _openStyle(tester);
    await _scrollTo(tester, find.textContaining('Lectura')); // the last taste chip
    expect(find.textContaining('Conocer sin prisa'), findsNothing, reason: 'the intent cannot be featured');

    Future<void> tapTaste(String text) async {
      final chip = find.descendant(of: find.byType(FilterChip), matching: find.textContaining(text));
      await _scrollTo(tester, chip);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls.saved.single.featuredTastes, hasLength(1));
  });

  testWidgets('a style that cannot be saved still shows on this phone, with a notice', (tester) async {
    final calls = await _open(tester)..saveWorks = false;
    await _openStyle(tester);
    await tester.enterText(find.byType(TextField), 'Sin conexión');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls.saved, hasLength(1));
    expect(find.textContaining('No pudimos guardar el estilo'), findsOneWidget);
    expect(find.text('“Sin conexión”'), findsOneWidget);
  });

  testWidgets('closing the sheet without saving changes nothing', (tester) async {
    final calls = await _open(tester);
    await _openStyle(tester);
    await tester.enterText(find.byType(TextField), 'Borrador');
    await tester.tapAt(const Offset(195, 20)); // outside the sheet
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls.saved, isEmpty);
    expect(find.text('“Borrador”'), findsNothing);
  });

  testWidgets('"Ver cómo me ven" opens the reveal with your own card, which flips', (tester) async {
    await _open(tester);
    await tester.tap(find.byTooltip('Ver cómo me ven'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MatchRevealCelebrationView), findsOneWidget);
    expect(find.text('VISTA PREVIA DE TU PERFIL'), findsOneWidget);
    await tester.pump(MatchRevealCelebrationView.revealDelay);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Kai, 29'), findsWidgets, reason: 'the reveal card turned to the real face');
  });
}
