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
    testWidgets('Renders CharacterCreatorScreen tabs and controls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterCreatorScreen(),
        ),
      );

      // Verify UI Title
      expect(find.text('Avatar Studio 16-Bit'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);

      // Verify Resolution Toggles
      expect(find.text('64x128 (Detalle)'), findsOneWidget);
      expect(find.text('32x64 (Pixel Chibi)'), findsWidgets);

      // Verify Tabs
      expect(find.text('Cara & Piel'), findsOneWidget);
      expect(find.text('Expresión & Ojos'), findsOneWidget);
      expect(find.text('Peinado'), findsOneWidget);
      expect(find.text('Vestimenta'), findsOneWidget);
      expect(find.text('Accesorios'), findsOneWidget);

      // Verify Controls
      expect(find.text('Caminar'), findsOneWidget);
      expect(find.text('Aleatorio'), findsOneWidget);
    });
  });
}
