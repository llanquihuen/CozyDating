import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/lifestyle_badges.dart';
import 'package:frontend/core/models/profile_card_style.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/features/profile/card/card_themes.dart';
import 'package:frontend/features/profile/view/card_sections.dart';
import 'package:frontend/features/profile/view/character_face_view.dart';
import 'package:frontend/features/profile/view/profile_card_view.dart';
import 'package:frontend/features/profile/view/real_face_feed.dart';

/// Set to a folder (--dart-define=AVATAR_RENDER_DIR=...) to also save screenshots as PNGs.
const _dumpDir = String.fromEnvironment('AVATAR_RENDER_DIR');

UserProfile _profile({String theme = 'forest', List<String> photos = const []}) => UserProfile(
      id: 'juli',
      username: 'julieta',
      age: 38,
      commune: 'Rancagua',
      isVerified: true,
      bio: 'Amante de las aventuras cooperativas, las buenas charlas y momentos sinceros.',
      tastes: const ['intent_slow', 'fuel_coffee', 'pet_cat', 'vacation_cabin', 'music_lofi', 'game_coop'],
      lifestyle: const LifestyleBadges(smoking: 'no_smoke', drinking: 'social', pets: 'cat'),
      profilePhoto: photos.isEmpty ? null : photos.first,
      photos: photos.skip(1).toList(),
      avatarConfig: const AvatarConfig(bodyType: 'female', hairStyle: 'long', topStyle: 'jacket', bottomStyle: 'jeans'),
      cardStyle: ProfileCardStyle(
        themeId: theme,
        phrase: 'Lluvia, café y un cooperativo',
        featuredTastes: const ['fuel_coffee', 'pet_cat', 'vacation_cabin'],
      ),
    );

Future<void> _pump(WidgetTester tester, Widget view, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: view));
  await tester.pump(const Duration(milliseconds: 400));
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  testWidgets('before the campfire the real face is locked and nothing real shows', (tester) async {
    await _pump(tester, ProfileCardView(profile: _profile(), mode: ProfileViewMode.beforeReveal, initiallyReal: true));
    expect(find.byType(CharacterFaceView), findsOneWidget, reason: 'locked: starts on the character face');
    expect(find.text('julieta'), findsOneWidget);
    expect(find.text('Lluvia, café y un cooperativo'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Real, se revela en la fogata'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RealFaceFeed), findsNothing);
    final hint = tester.widget<AnimatedOpacity>(
        find.ancestor(of: find.text('Se revela en la fogata al conectar'), matching: find.byType(AnimatedOpacity)));
    expect(hint.opacity, 1);

    // Scroll the whole character face: no age, place, bio or lifestyle anywhere.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pump();
    for (final real in ['julieta, 38', 'Rancagua', 'Sobre mí', 'Estilo de vida']) {
      expect(find.textContaining(real), findsNothing, reason: real);
    }
    expect(find.textContaining('Amante de las aventuras'), findsNothing);
    await tester.pump(const Duration(seconds: 3)); // the hint's timer
  });

  testWidgets('after the reveal the switch shows the real face as a feed', (tester) async {
    await _pump(tester, ProfileCardView(profile: _profile(), distanceKm: 12.4));
    await tester.tap(find.text('Real'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RealFaceFeed), findsOneWidget);
    expect(find.text('julieta, 38'), findsOneWidget);
    expect(find.text('Rancagua · a 12 km'), findsOneWidget);

    await tester.drag(
        find.descendant(of: find.byType(RealFaceFeed), matching: find.byType(CustomScrollView)), const Offset(0, -700));
    await tester.pump();
    expect(find.text('SOBRE MÍ'), findsOneWidget);

    await tester.tap(find.text('Personaje'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CharacterFaceView), findsOneWidget);
  });

  testWidgets('the main action shows only when given, and the close button pops', (tester) async {
    var accepted = 0;
    await _pump(
      tester,
      ProfileCardView(
        profile: _profile(),
        action: ProfileCardAction(label: 'Escribir', icon: Icons.mail_outline, onPressed: () => accepted++),
      ),
    );
    await tester.tap(find.text('Escribir'));
    expect(accepted, 1);

    await _pump(tester, ProfileCardView(profile: _profile(), mode: ProfileViewMode.own));
    expect(find.byType(FilledButton), findsNothing);
  });

  test('the feed puts photos between the blocks and leaves out empty ones', () {
    final four = _profile(photos: const ['a.png', 'b.png', 'c.png', 'd.png']);
    expect(RealFaceFeed.layout(four), ['bio', 'photo:1', 'lifestyle', 'photo:2', 'tastes', 'photo:3']);

    final six = _profile(photos: const ['a', 'b', 'c', 'd', 'e', 'f']);
    expect(RealFaceFeed.layout(six).skip(6), ['photo:4', 'photo:5'], reason: 'leftover photos at the end');

    final bare = _profile().copyWith(bio: '  ', lifestyle: const LifestyleBadges());
    expect(RealFaceFeed.layout(bare), ['tastes']);
  });

  test('tastes are grouped by catalog category, featured first, without the intent', () {
    final groups = TastesByCategory.groups(
      const ['intent_slow', 'music_lofi', 'fuel_tea', 'fuel_coffee', 'pet_cat'],
      const ['fuel_coffee'],
    );
    final flat = [for (final (c, ids) in groups) '${c.id}:${ids.join(',')}'];
    expect(flat, ['daily_fuel:fuel_coffee,fuel_tea', 'pets_dilemma:pet_cat', 'music:music_lofi']);
  });

  test('section text and taste chips stay readable in every theme', () {
    for (final theme in cardThemes) {
      final surface = CardSection.surfaceOf(theme);
      expect(_contrast(ProfileCardTheme.textOn(surface), surface), greaterThanOrEqualTo(4.5), reason: theme.id);
      for (final accent in [...theme.accents, ...sharedCardAccents]) {
        final featured = TastesByCategory.readableFill(accent);
        expect(_contrast(ProfileCardTheme.textOn(featured), featured), greaterThanOrEqualTo(4.5),
            reason: '${theme.id} $accent');
        final chip = TastesByCategory.chipFill(surface, accent);
        expect(_contrast(ProfileCardTheme.textOn(chip), chip), greaterThanOrEqualTo(4.5), reason: '${theme.id} chip');
      }
    }
  });

  testWidgets('both faces fit a small phone with large text in every theme', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final theme in cardThemes) {
      for (final real in [false, true]) {
        await _pump(
          tester,
          ProfileCardView(key: UniqueKey(), profile: _profile(theme: theme.id), initiallyReal: real),
          size: const Size(320, 568),
        );
        expect(tester.takeException(), isNull, reason: '${theme.id} ${real ? 'real' : 'character'}');
      }
    }
  });

  testWidgets('screenshots of both faces (only with AVATAR_RENDER_DIR)', (tester) async {
    if (_dumpDir.isEmpty) return;
    await tester.runAsync(() async {
      Future<ByteData> bytes(String p) async => ByteData.sublistView(File(p).readAsBytesSync());
      final root = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
      await (FontLoader('Card')
            ..addFont(bytes('C:/Windows/Fonts/segoeui.ttf'))
            ..addFont(bytes('C:/Windows/Fonts/segoeuib.ttf')))
          .load();
      await (FontLoader('Emoji')..addFont(bytes('C:/Windows/Fonts/seguiemj.ttf'))).load();
      await (FontLoader('MaterialIcons')
            ..addFont(bytes('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')))
          .load();
    });
    const phone = Size(390, 780);
    final shots = [
      for (final theme in ['forest', 'retro90s', 'matcha'])
        for (final real in [false, true]) (theme, real),
    ];
    tester.view.physicalSize = Size(phone.width * shots.length + 10 * (shots.length + 2), phone.height + 20);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    const avatar = AvatarConfig(
      bodyType: 'female',
      hairStyle: 'wavy_long',
      hairColor: Color(0xFFB4501E),
      topStyle: 'jacket',
      topColor: Color(0xFFB71C1C),
      bottomStyle: 'jeans',
      shoeStyle: 'boots',
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Card', fontFamilyFallback: const ['Emoji']),
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xFF0C0E15),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (theme, real) in shots)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox.fromSize(
                      size: phone,
                      child: MediaQuery(
                        data: const MediaQueryData(size: phone, padding: EdgeInsets.only(top: 24)),
                        child: ClipRect(
                          child: ProfileCardView(
                            profile: _profile(theme: theme).copyWith(avatarConfig: avatar),
                            initiallyReal: real,
                            distanceKm: 12,
                            action: real
                                ? ProfileCardAction(label: 'Escribir', icon: Icons.mail_outline, onPressed: () {})
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_dumpDir/profile_card_view.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
