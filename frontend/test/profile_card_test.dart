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
import 'package:frontend/features/profile/card/profile_card.dart';

/// Set to a folder (--dart-define=AVATAR_RENDER_DIR=...) to also save the cards as PNGs.
const _dumpDir = String.fromEnvironment('AVATAR_RENDER_DIR');

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

UserProfile _profile(
        {String theme = 'arcade', String phrase = 'Speedruns y ramen a las 3 AM', List<String>? featured}) =>
    UserProfile(
      id: 'kai',
      username: 'Kai',
      age: 29,
      commune: 'Ñuñoa',
      isVerified: true,
      bio: 'Ingeniero de día, speedrunner de noche. Hago el mejor ramen casero de Santiago.',
      tastes: const ['intent_slow', 'plat_pc', 'game_roguelike', 'music_synthwave', 'fuel_energy', 'pet_cat'],
      lifestyle: const LifestyleBadges(smoking: 'no_smoke', drinking: 'social', heightCm: 178),
      avatarConfig: const AvatarConfig(
        bodyType: 'male',
        hairStyle: 'spiky',
        hairColor: Color(0xFF00B8D4),
        topStyle: 'hoodie',
        topColor: Color(0xFF1A1F4A),
        bottomStyle: 'jeans',
        shoeStyle: 'sneakers',
        shoeColor: Color(0xFFF1F5F9),
      ),
      cardStyle: ProfileCardStyle(
        themeId: theme,
        phrase: phrase,
        featuredTastes: featured ?? const ['plat_pc', 'game_roguelike', 'music_synthwave'],
      ),
    );

Widget _host(Widget child, {double width = 300}) => MaterialApp(
      theme: ThemeData(fontFamily: _dumpDir.isEmpty ? null : 'Card', fontFamilyFallback: const ['Emoji']),
      home: Scaffold(
        backgroundColor: const Color(0xFFECE9E4),
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  test('every theme keeps text readable: names, phrases, chips and the verified tick', () {
    expect(cardThemes.map((t) => t.id), ProfileCardStyle.themeIds);
    for (final theme in cardThemes) {
      expect(_contrast(theme.text, theme.base), greaterThanOrEqualTo(4.5), reason: '${theme.id} text');
      expect(_contrast(theme.mutedText, theme.base), greaterThanOrEqualTo(3), reason: '${theme.id} phrase');
      for (final accent in [...theme.accents, ...sharedCardAccents]) {
        expect(_contrast(theme.chipText(accent), theme.chipFill(accent)), greaterThanOrEqualTo(4.5),
            reason: '${theme.id} chip on $accent');
      }
      for (final accent in theme.accents) {
        expect(_contrast(theme.onAccent(accent), accent), greaterThanOrEqualTo(3),
            reason: '${theme.id} tick on $accent');
      }
    }
  });

  testWidgets('both faces draw in every theme, and showReal flips from character to real', (tester) async {
    for (final theme in cardThemes) {
      final profile = _profile(theme: theme.id);
      await tester.pumpWidget(_host(ProfileCard(profile: profile)));
      await tester.pump(const Duration(milliseconds: 700)); // flips back from the previous theme's real face
      expect(find.text('Kai'), findsOneWidget, reason: theme.id);
      expect(find.text('Kai, 29'), findsNothing, reason: 'age is revealed only on the real face');
      expect(find.text('“Speedruns y ramen a las 3 AM”'), findsOneWidget);

      await tester.pumpWidget(_host(ProfileCard(profile: profile, showReal: true, distanceKm: 4.2)));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Kai, 29'), findsOneWidget, reason: theme.id);
      expect(find.text('Ñuñoa · 4 km'), findsOneWidget);
      expect(find.text('“Speedruns y ramen a las 3 AM”'), findsNothing);
      expect(tester.takeException(), isNull, reason: theme.id);
    }
  });

  testWidgets('the longest content fits a small phone with large system text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final crowded = _profile(
      phrase: List.filled(ProfileCardStyle.maxPhraseLength, 'm').join(),
      featured: const ['plat_pc', 'game_roguelike', 'music_synthwave', 'fuel_energy', 'pet_cat'],
    ).copyWith(
      username: 'Maximiliano_Alejandro_Fuentes',
      bio: List.filled(180, 'b').join(),
      lifestyle: const LifestyleBadges(
          smoking: 'no_smoke',
          drinking: 'social',
          kids: 'want_kids',
          heightCm: 192,
          occupation: 'Ingeniero en computación'),
    );
    for (final real in [false, true]) {
      await tester.pumpWidget(_host(ProfileCard(profile: crowded, showReal: real), width: 260));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull, reason: real ? 'real face' : 'character face');
    }
  });

  testWidgets('without photos the real face still shows the person', (tester) async {
    await tester.pumpWidget(_host(ProfileCard(profile: _profile(), showReal: true)));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.text('Kai, 29'), findsOneWidget);
  });

  testWidgets('screenshots of all themes (only with AVATAR_RENDER_DIR)', (tester) async {
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
    tester.view.physicalSize = const Size(5 * 320 * 2, 2 * 2 * 480 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Card', fontFamilyFallback: const ['Emoji']),
      home: RepaintBoundary(
        key: key,
        // Run this test alone: the other tests leave avatar renders pending in the shared cache.
        child: Material(
          type: MaterialType.transparency,
          child: ColoredBox(
            color: const Color(0xFFECE9E4),
            child: Wrap(
              children: [
                for (final real in [false, true])
                  for (final theme in cardThemes)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: SizedBox(
                        width: 300,
                        child: ProfileCard(profile: _profile(theme: theme.id), showReal: real, distanceKm: 4),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    ));
    await _settle(tester);
    await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_dumpDir/profile_cards.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
