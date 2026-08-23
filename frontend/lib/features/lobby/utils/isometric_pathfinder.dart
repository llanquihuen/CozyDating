import 'dart:math';

class IsometricPathfinder {
  static const int gridSize = 8;
  static const int subGridSize = 16;

  /// Calculates A* path from [start] to [goal] avoiding [obstacles] and [blockedEdges].
  /// Returns a list of Points representing the step-by-step path.
  static List<Point<int>> findPath({
    required Point<int> start,
    required Point<int> goal,
    required Set<Point<int>> obstacles,
    Set<String> blockedEdges = const {},
    int mapSize = gridSize,
  }) {
    if (start == goal) return [];

    // If goal is an obstacle (e.g. clicked directly on a furniture), target nearest free neighbor
    Point<int> effectiveGoal = goal;
    if (obstacles.contains(goal)) {
      final neighbors = [
        Point(goal.x + 1, goal.y),
        Point(goal.x - 1, goal.y),
        Point(goal.x, goal.y + 1),
        Point(goal.x, goal.y - 1),
      ].where((p) => _isValid(p, mapSize) && !obstacles.contains(p) && !blockedEdges.contains(edgeKey(goal.x, goal.y, p.x, p.y))).toList();

      if (neighbors.isEmpty) return [];
      neighbors.sort((a, b) => _manhattan(a, start).compareTo(_manhattan(b, start)));
      effectiveGoal = neighbors.first;
    }

    final openSet = <Point<int>>{start};
    final cameFrom = <Point<int>, Point<int>>{};

    final gScore = <Point<int>, double>{start: 0.0};
    final fScore = <Point<int>, double>{start: _manhattan(start, effectiveGoal).toDouble()};

    while (openSet.isNotEmpty) {
      // Get point with lowest fScore
      Point<int> current = openSet.first;
      double lowestF = fScore[current] ?? double.infinity;
      for (final p in openSet) {
        final f = fScore[p] ?? double.infinity;
        if (f < lowestF) {
          lowestF = f;
          current = p;
        }
      }

      if (current == effectiveGoal) {
        return _reconstructPath(cameFrom, current);
      }

      openSet.remove(current);

      final neighbors = [
        Point(current.x + 1, current.y),
        Point(current.x - 1, current.y),
        Point(current.x, current.y + 1),
        Point(current.x, current.y - 1),
      ];

      for (final neighbor in neighbors) {
        if (!_isValid(neighbor, mapSize) || obstacles.contains(neighbor)) continue;
        if (blockedEdges.contains(edgeKey(current.x, current.y, neighbor.x, neighbor.y))) continue;

        final tentativeG = (gScore[current] ?? double.infinity) + 1.0;

        if (tentativeG < (gScore[neighbor] ?? double.infinity)) {
          cameFrom[neighbor] = current;
          gScore[neighbor] = tentativeG;
          fScore[neighbor] = tentativeG + _manhattan(neighbor, effectiveGoal);
          openSet.add(neighbor);
        }
      }
    }

    return []; // No path found
  }

  static bool _isValid(Point<int> p, [int mapSize = gridSize]) {
    return p.x >= 0 && p.x < mapSize && p.y >= 0 && p.y < mapSize;
  }

  static int _manhattan(Point<int> a, Point<int> b) {
    return (a.x - b.x).abs() + (a.y - b.y).abs();
  }

  static List<Point<int>> _reconstructPath(
    Map<Point<int>, Point<int>> cameFrom,
    Point<int> current,
  ) {
    final totalPath = <Point<int>>[current];
    while (cameFrom.containsKey(current)) {
      current = cameFrom[current]!;
      totalPath.insert(0, current);
    }
    // Remove start position from path
    if (totalPath.isNotEmpty) {
      totalPath.removeAt(0);
    }
    return totalPath;
  }

  static String edgeKey(int x1, int y1, int x2, int y2) {
    if (x1 < x2 || (x1 == x2 && y1 < y2)) {
      return '$x1,$y1-$x2,$y2';
    } else {
      return '$x2,$y2-$x1,$y1';
    }
  }
}
