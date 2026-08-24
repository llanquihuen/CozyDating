import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/services/avatar_storage_service.dart';
import 'package:frontend/features/avatar/screens/character_creator_screen.dart';

void main() {
  group('AvatarConfig Model & Storage Tests', () {
    test('AvatarConfig default instantiation & JSON serialization with 12 layers & resolution', () {
      const config = AvatarConfig(
        spriteResolution: '32x64',
        faceShape: 'sharp_v',
        skinColor: Color(0xFFFCD5B5),
        eyeStyle: 'jrpg_classic',
        eyeColor: Color(0xFF059669),
        eyebrowStyle: 'serious',
        eyebrowColor: Color(0xFF1E293B),
        noseStyle: 'pointed',
        mouthStyle: 'smirk',
        faceDetail: 'scar',
        faceDetailColor: Color(0xFF8B0000),
        hairStyle: 'adventurer_spiky',
        hairColor: Color(0xFF1E293B),
        topStyle: 'traveler_tunic',
        topColor: Color(0xFF059669),
        bottomStyle: 'adventurer_pants',
        bottomColor: Color(0xFF78350F),
        shoeStyle: 'adventurer_boots',
        shoeColor: Color(0xFF451A03),
        accessoryStyle: 'scholar_glasses',
        accessoryColor: Color(0xFFEAB308),
      );

      final json = config.toJson();
      final deserialized = AvatarConfig.fromJson(json);

      expect(deserialized.spriteResolution, equals('32x64'));
      expect(deserialized.faceShape, equals('sharp_v'));
      expect(deserialized.eyeStyle, equals('jrpg_classic'));
      expect(deserialized.eyebrowStyle, equals('serious'));
      expect(deserialized.noseStyle, equals('pointed'));
      expect(deserialized.mouthStyle, equals('smirk'));
      expect(deserialized.faceDetail, equals('scar'));
      expect(deserialized.hairStyle, equals('adventurer_spiky'));
      expect(deserialized.topStyle, equals('traveler_tunic'));
      expect(deserialized.bottomStyle, equals('adventurer_pants'));
      expect(deserialized.shoeStyle, equals('adventurer_boots'));
      expect(deserialized.accessoryStyle, equals('scholar_glasses'));
      expect(deserialized, equals(config));
    });

    test('AvatarStorageService saves and retrieves current avatar config', () {
      const customConfig = AvatarConfig(
        spriteResolution: '32x64',
        hairStyle: 'high_ponytail',
        topStyle: 'hoodie',
      );

      AvatarStorageService.saveConfig(customConfig);
      final retrieved = AvatarStorageService.loadConfig();

      expect(retrieved.spriteResolution, equals('32x64'));
      expect(retrieved.hairStyle, equals('high_ponytail'));
      expect(retrieved.topStyle, equals('hoodie'));
    });
  });

  group('CharacterCreatorScreen Widget Tests', () {
    testWidgets('Renders CharacterCreatorScreen 2-section workspace, zoom mode and controls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterCreatorScreen(),
        ),
      );

      // Verify Title & Save Button
      expect(find.textContaining('Armario'), findsWidgets);
      expect(find.text('Guardar'), findsOneWidget);

      // Verify Main 2 Sections
      expect(find.text('1. Rostro & Cabello'), findsOneWidget);
      expect(find.text('2. Vestimenta & Estilo'), findsOneWidget);

      // Verify Camera Mode Badge (initial is Face Zoom)
      expect(find.text('Zoom Rostro'), findsOneWidget);

      // Verify Section 1 Sub-tabs
      expect(find.text('Cara & Piel'), findsOneWidget);
      expect(find.text('Expresión & Ojos'), findsOneWidget);
      expect(find.text('Peinado'), findsOneWidget);

      // Switch to Section 2 (Vestimenta & Estilo)
      await tester.tap(find.text('2. Vestimenta & Estilo'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Section 2 Sub-tabs
      expect(find.widgetWithText(Tab, 'Prenda Superior'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Prenda Inferior'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Calzado'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Accesorios'), findsOneWidget);

      // Verify Resolution Toggles
      expect(find.textContaining('64x128'), findsOneWidget);
      expect(find.textContaining('32x64'), findsWidgets);

      // Verify Controls
      expect(find.textContaining('Caminar'), findsOneWidget);
      expect(find.byIcon(Icons.casino), findsOneWidget);
      expect(find.byTooltip('Aleatorio'), findsOneWidget);
    });
  });
}
