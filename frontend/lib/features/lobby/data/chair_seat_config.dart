import 'dart:math';
import 'package:flame/components.dart';
import '../components/isometric_furniture_component.dart';
import '../utils/isometric_coords.dart';

/// Representa un punto específico donde un personaje puede sentarse dentro de un mueble.
class SeatSpot {
  /// Índice del asiento (0: Asiento principal/único, 1: Asiento secundario en sofás, etc.)
  final int slotIndex;

  /// Subcuadro relativo (du, dv) dentro del mueble para la rotación actual.
  /// Se suma a (chair.gridX * 2, chair.gridY * 2) para obtener el subcuadro real.
  final Point<int> subCell;

  /// Desfase visual en píxeles de pantalla (dx: izquierda/derecha, dy: arriba/abajo - altura del cojín).
  final Vector2 visualOffset;

  const SeatSpot({
    required this.slotIndex,
    required this.subCell,
    required this.visualOffset,
  });

  @override
  String toString() => 'SeatSpot(slotIndex: $slotIndex, subCell: $subCell, visualOffset: $visualOffset)';
}

/// Configuración centralizada de puntos de asiento por tipo de mueble y rotación.
class ChairSeatConfig {
  /// Diccionario: tipo de mueble -> rotación (0: SW, 1: SE, 2: NE, 3: NW) -> lista de asientos disponibles.
  static final Map<String, Map<int, List<SeatSpot>>> _spots = {
    // 1. Silla simple de madera (0.5x0.5) - 1 solo asiento
    'simple_chair_sm': {
      0: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(-2.0, 0.0))],
      1: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(5.0, 2.0))],
      2: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(5.0, 2.0))],
      3: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(-5.0, 2.0))],
    },
    'simple_chair': {
      0: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(-2.0, 0.0))],
      1: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(5.0, 2.0))],
      2: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(5.0, 2.0))],
      3: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(-5.0, 2.0))],
    },
    'gamer_chair_sm': {
      0: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(-2.0, 0.0))],
      1: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(5.0, 2.0))],
      2: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(5.0, 2.0))],
      3: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(-5.0, 2.0))],
    },
    'gamer_chair': {
      0: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(-2.0, 0.0))],
      1: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(5.0, 2.0))],
      2: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(5.0, 2.0))],
      3: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(-5.0, 2.0))],
    },

    // 2. Sillón acolchado (1x1 = 2x2 subcuadros) - 1 asiento más amplio y elevado
    //(x 8.0 pixeles hacia la derecha,y 8.0 pixeles hacia abajo)
    'plush_armchair': {
      0: [SeatSpot(slotIndex: 0, subCell: const Point(0, 1), visualOffset: Vector2(11.0, 6.0))],
      1: [SeatSpot(slotIndex: 0, subCell: const Point(1, 0), visualOffset: Vector2(-11.0, 6.0))],
      2: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(5.0, 14.0))],
      3: [SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(0.0, 14.0))],
    },
    // 3. Sofá simple (2x1 y 1x2) - 3 plazas (Izquierda, Centro, Derecha)
    'simple_sofa': {
      // Rot 0: Mirando a SW (frente a la cámara, 2x1 baldosas)
      0: [
        SeatSpot(slotIndex: 0, subCell: const Point(0, 1), visualOffset: Vector2(4.0, 4.0)),   // Plaza izquierda
        SeatSpot(slotIndex: 1, subCell: const Point(1, 1), visualOffset: Vector2(10.0, 5.0)), // Plaza central
        SeatSpot(slotIndex: 2, subCell: const Point(2, 1), visualOffset: Vector2(14.0, 5.0)),   // Plaza derecha
      ],
      // Rot 1: Mirando a SE (frente a la cámara, 1x2 baldosas)
      1: [
        SeatSpot(slotIndex: 0, subCell: const Point(1, 0), visualOffset: Vector2(-4.0, 4.0)),   // Plaza 1
        SeatSpot(slotIndex: 1, subCell: const Point(1, 1), visualOffset: Vector2(-10.0, 5.0)),// Plaza 2 (Centro)
        SeatSpot(slotIndex: 2, subCell: const Point(1, 2), visualOffset: Vector2(-14.0, 5.0)),   // Plaza 3
      ],
      // Rot 2: Mirando a NE (hacia el fondo, 2x1 baldosas)
      2: [
        SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(8.0, 6.0)),
        SeatSpot(slotIndex: 1, subCell: const Point(1, 0), visualOffset: Vector2(11.0, 6.0)),
        SeatSpot(slotIndex: 2, subCell: const Point(2, 0), visualOffset: Vector2(14.0, 6.0)),
      ],
      // Rot 3: Mirando a NW (hacia el fondo, 1x2 baldosas)
      3: [
        SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2(-8.0, 6.0)),
        SeatSpot(slotIndex: 1, subCell: const Point(0, 1), visualOffset: Vector2(-11.0, 6.0)),
        SeatSpot(slotIndex: 2, subCell: const Point(0, 2), visualOffset: Vector2(-14.0, 6.0)),
      ],
    },
  };

  /// Permite registrar o sobrescribir dinámicamente la configuración de asientos para un mueble.
  static void registerFurnitureSpots(String typeName, Map<int, List<SeatSpot>> rotationSpots) {
    _spots[typeName] = rotationSpots;
  }

  /// Retorna la lista de asientos configurados para el mueble y rotación dados.
  /// Si el mueble no está registrado explícitamente, calcula un asiento por defecto en el centro geométrico.
  static List<SeatSpot> getSpots(IsometricFurnitureComponent chair, int rotation) {
    final cleanId = chair.typeName.isNotEmpty ? chair.typeName : chair.id;
    final normalizedId = cleanId.replaceAll(RegExp(r'_\d+$'), '');

    final byType = _spots[normalizedId] ?? _spots[chair.id];
    if (byType != null) {
      final list = byType[rotation] ?? byType[0];
      if (list != null && list.isNotEmpty) {
        return list;
      }
    }

    // Fallback geométrico automático basado en las dimensiones de huella (footprint)
    final wSub = (chair.gridWidth * 2.0).round();
    final hSub = (chair.gridHeight * 2.0).round();
    final centerU = (wSub > 1) ? 1 : 0;
    final centerV = (hSub > 1) ? 1 : 0;

    return [
      SeatSpot(
        slotIndex: 0,
        subCell: Point(centerU, centerV),
        visualOffset: (wSub > 1 || hSub > 1) ? Vector2(0.0, -6.0) : Vector2.zero(),
      ),
    ];
  }

  /// Retorna el asiento más cercano a la posición del toque en el mundo (worldTapPos),
  /// descartando los asientos que ya estén ocupados si hay otros disponibles.
  static SeatSpot getClosestSpot(
    IsometricFurnitureComponent chair,
    Vector2 worldTapPos, {
    Set<int>? occupiedSlots,
  }) {
    final allSpots = getSpots(chair, chair.rotation);
    if (allSpots.isEmpty) {
      return SeatSpot(slotIndex: 0, subCell: const Point(0, 0), visualOffset: Vector2.zero());
    }

    // Filtra candidatos libres si se proporcionaron ocupados
    final candidates = (occupiedSlots != null && occupiedSlots.isNotEmpty)
        ? allSpots.where((s) => !occupiedSlots.contains(s.slotIndex)).toList()
        : allSpots;

    final pool = candidates.isNotEmpty ? candidates : allSpots;
    if (pool.length == 1) return pool.first;

    final baseSubU = chair.gridX * 2.0;
    final baseSubV = chair.gridY * 2.0;

    SeatSpot bestSpot = pool.first;
    double bestDistSq = double.infinity;

    for (final spot in pool) {
      final spotScreenPos = IsometricCoords.subGridToScreen(
        baseSubU + spot.subCell.x,
        baseSubV + spot.subCell.y,
      ) + spot.visualOffset;

      final distSq = (spotScreenPos.x - worldTapPos.x) * (spotScreenPos.x - worldTapPos.x) +
          (spotScreenPos.y - worldTapPos.y) * (spotScreenPos.y - worldTapPos.y);

      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestSpot = spot;
      }
    }

    return bestSpot;
  }
}
