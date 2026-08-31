import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/services/avatar_storage_service.dart';
import 'package:frontend/features/avatar/components/modular_avatar_component.dart';
import 'package:frontend/features/avatar/screens/character_creator_screen.dart';

void main() {
  group('AvatarConfig Model & Storage Tests', () {
    test('AvatarConfig default instantiation & JSON serialization with OCTOPLAYER 8-dir options', () {
      const config = AvatarConfig(
        spriteResolution: '64x128',
        faceShape: 'oval',
        skinColor: Color(0xFFFCD5B5),
        eyeStyle: 'cateyes',
        eyeColor: Color(0xFF059669),
        eyebrowStyle: 'none',
        eyebrowColor: Color(0xFF1E293B),
        noseStyle: 'standard',
        mouthStyle: 'catmouth',
        faceDetail: 'none',
        faceDetailColor: Color(0xFFFF7777),
        hairStyle: 'long_flow',
        hairColor: Color(0xFF1E293B),
        topStyle: 'jacket',
        topColor: Color(0xFF059669),
        bottomStyle: 'jeans',
        bottomColor: Color(0xFF78350F),
        shoeStyle: 'none',
        shoeColor: Color(0xFF451A03),
        accessoryStyle: 'none',
        accessoryColor: Color(0xFFEAB308),
      );

      final json = config.toJson();
      final deserialized = AvatarConfig.fromJson(json);

      expect(deserialized.spriteResolution, equals('64x128'));
      expect(deserialized.faceShape, equals('oval'));
      expect(deserialized.eyeStyle, equals('cateyes'));
      expect(deserialized.eyebrowStyle, equals('none'));
      expect(deserialized.noseStyle, equals('standard'));
      expect(deserialized.mouthStyle, equals('catmouth'));
      expect(deserialized.faceDetail, equals('none'));
      expect(deserialized.hairStyle, equals('long_flow'));
      expect(deserialized.topStyle, equals('jacket'));
      expect(deserialized.bottomStyle, equals('jeans'));
      expect(deserialized.shoeStyle, equals('none'));
      expect(deserialized.accessoryStyle, equals('none'));
      expect(deserialized, equals(config));
    });

    test('AvatarStorageService saves and retrieves current avatar config', () {
      const customConfig = AvatarConfig(
        spriteResolution: '64x128',
        hairStyle: 'bangs',
        topStyle: 'jacket',
      );

      AvatarStorageService.saveConfig(customConfig);
      final retrieved = AvatarStorageService.loadConfig();

      expect(retrieved.spriteResolution, equals('64x128'));
      expect(retrieved.hairStyle, equals('bangs'));
      expect(retrieved.topStyle, equals('jacket'));
    });

    test('AvatarDirection supports 8 directions with 1..8 numbering', () {
      expect(AvatarDirection.values.length, equals(8));
      expect(AvatarDirection.south.dirNumber, equals(1));
      expect(AvatarDirection.southEast.dirNumber, equals(2));
      expect(AvatarDirection.east.dirNumber, equals(3));
      expect(AvatarDirection.northEast.dirNumber, equals(4));
      expect(AvatarDirection.north.dirNumber, equals(5));
      expect(AvatarDirection.northWest.dirNumber, equals(6));
      expect(AvatarDirection.west.dirNumber, equals(7));
      expect(AvatarDirection.southWest.dirNumber, equals(8));
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

      // Verify Rotate and Swipe Hints
      expect(find.textContaining('Desliza para girar'), findsOneWidget);
      expect(find.byIcon(Icons.rotate_left), findsWidgets);
      expect(find.byIcon(Icons.rotate_right), findsWidgets);

      // Verify Controls
      expect(find.textContaining('Caminar'), findsOneWidget);
      expect(find.byIcon(Icons.casino), findsOneWidget);
      expect(find.byTooltip('Aleatorio'), findsOneWidget);
    });
  });
}
