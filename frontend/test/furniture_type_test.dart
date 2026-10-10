import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/lobby/components/isometric_furniture_component.dart';
import 'package:frontend/features/lobby/games/cozy_room_game.dart';

void main() {
  test('rugs are carpets (walkable, under everything); beds and wardrobes keep their type', () {
    expect(CozyRoomGame.furnitureTypeFor('heart_rug'), FurnitureType.carpet);
    expect(CozyRoomGame.furnitureTypeFor('canopy_bed'), FurnitureType.bed);
    expect(CozyRoomGame.furnitureTypeFor('wardrobe_tall'), FurnitureType.wardrobe);
    expect(CozyRoomGame.furnitureTypeFor('vanity_table'), FurnitureType.custom);
  });
}
