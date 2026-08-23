import 'dart:collection';
import 'dart:math';

class DungeonMapData {
  final List<List<int>> gridMatrix;
  final List<String> secretRuneSequence;

  DungeonMapData({
    required this.gridMatrix,
    required this.secretRuneSequence,
  });
}

class DungeonGenerator {
  static const List<String> allRunes = ['SOL', 'MOON', 'SNAKE', 'LIGHTNING'];

  static String getRuneLabel(String type) {
    switch (type) {
      case 'SOL':
        return '☀️ SOL';
      case 'MOON':
        return '🌙 LUNA';
      case 'SNAKE':
        return '🐍 SERPIENTE';
      case 'LIGHTNING':
        return '⚡ RAYO';
      default:
        return type;
    }
  }

  /// Generates a deterministic positive integer hash from a string (e.g. roomId)
  /// Guaranteed to be 100% identical across all Dart platforms and devices.
  static int deterministicStringSeed(String str) {
    var hash = 5381;
    for (var i = 0; i < str.length; i++) {
      hash = ((hash << 5) + hash) + str.codeUnitAt(i);
      hash = hash & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Generates a dense, maze-like 11x11 dungeon map with rich wall architecture.
  /// Guarantees:
  /// 1. High wall density with 1-tile wide corridors and pillars.
  /// 2. The 3-rune secret sequence can always be traversed in exact order
  ///    (Spawn -> R1 -> R2 -> R3 -> Portal) without impassable walls or forced wrong runes.
  static DungeonMapData generateMap({int? seed, int act = 1}) {
    final effectiveSeed = (seed ?? DateTime.now().millisecondsSinceEpoch) + (act * 7919);
    final random = Random(effectiveSeed);

    const int width = 11;
    const int height = 11;

    // 1. Select random 3-rune secret sequence
    final shuffledRunes = List<String>.from(allRunes)..shuffle(random);
    final secretSequence = shuffledRunes.sublist(0, 3);

    final runeNameToCode = {
      'SOL': 11,
      'MOON': 12,
      'SNAKE': 13,
      'LIGHTNING': 14,
    };

    // 2. Initialize solid wall grid (all 1s)
    final grid = List.generate(height, (_) => List.generate(width, (_) => 1));

    // Recursive Backtracker Maze carving on odd coordinates
    void carveMaze(int cx, int cy) {
      grid[cy][cx] = 0;

      final directions = [
        [0, -2], // Up
        [0, 2],  // Down
        [-2, 0], // Left
        [2, 0],  // Right
      ]..shuffle(random);

      for (final dir in directions) {
        final nx = cx + dir[0];
        final ny = cy + dir[1];

        if (nx > 0 && nx < width - 1 && ny > 0 && ny < height - 1 && grid[ny][nx] == 1) {
          grid[cy + dir[1] ~/ 2][cx + dir[0] ~/ 2] = 0; // Carve 1-tile connector
          carveMaze(nx, ny);
        }
      }
    }

    carveMaze(1, 1);

    // 3. Open only 2 or 3 single wall tiles to form subtle navigational loops
    final candidateWallsToOpen = <Point<int>>[];
    for (int r = 2; r < height - 2; r++) {
      for (int c = 2; c < width - 2; c++) {
        if (grid[r][c] == 1) {
          // Horizontal wall between two floor tiles
          if (grid[r][c - 1] == 0 && grid[r][c + 1] == 0 && grid[r - 1][c] == 1 && grid[r + 1][c] == 1) {
            candidateWallsToOpen.add(Point(c, r));
          }
          // Vertical wall between two floor tiles
          else if (grid[r - 1][c] == 0 && grid[r + 1][c] == 0 && grid[r][c - 1] == 1 && grid[r][c + 1] == 1) {
            candidateWallsToOpen.add(Point(c, r));
          }
        }
      }
    }
    candidateWallsToOpen.shuffle(random);
    for (int i = 0; i < min(3, candidateWallsToOpen.length); i++) {
      final wall = candidateWallsToOpen[i];
      grid[wall.y][wall.x] = 0; // Open a single loop shortcut
    }

    // 4. Identify all floor tiles (excluding spawn (1, 1) and its immediate step)
    final floorTiles = <Point<int>>[];
    for (int r = 1; r < height - 1; r++) {
      for (int c = 1; c < width - 1; c++) {
        if (grid[r][c] == 0 && !(c <= 2 && r <= 2)) {
          floorTiles.add(Point(c, r));
        }
      }
    }
    floorTiles.shuffle(random);

    // Pick 5 distinct floor tiles: 1 for Portal (10) + 4 for Runes (11, 12, 13, 14)
    final portalPos = floorTiles.removeLast();
    grid[portalPos.y][portalPos.x] = 10;

    final runePositions = <int, Point<int>>{};
    final runeCodes = [11, 12, 13, 14]..shuffle(random);
    for (int i = 0; i < 4; i++) {
      final pos = floorTiles.removeLast();
      final code = runeCodes[i];
      grid[pos.y][pos.x] = code;
      runePositions[code] = pos;
    }

    // 5. BFS Path Validator: Verifies that no walls block the sequence legs
    bool hasCleanPath(Point<int> start, Point<int> target, Set<Point<int>> forbiddenTiles) {
      final queue = Queue<Point<int>>();
      final visited = List.generate(height, (_) => List.generate(width, (_) => false));

      queue.add(start);
      visited[start.y][start.x] = true;

      while (queue.isNotEmpty) {
        final curr = queue.removeFirst();
        if (curr == target) return true;

        final neighbors = [
          Point(curr.x + 1, curr.y),
          Point(curr.x - 1, curr.y),
          Point(curr.x, curr.y + 1),
          Point(curr.x, curr.y - 1),
        ];

        for (final next in neighbors) {
          if (next.x > 0 && next.x < width - 1 && next.y > 0 && next.y < height - 1) {
            if (!visited[next.y][next.x] && grid[next.y][next.x] != 1) {
              if (next == target || !forbiddenTiles.contains(next)) {
                visited[next.y][next.x] = true;
                queue.add(next);
              }
            }
          }
        }
      }
      return false;
    }

    // Verify each leg of the 3-rune secret sequence:
    // Spawn (1, 1) -> R1 -> R2 -> R3 -> Portal
    final seqPoints = <Point<int>>[
      const Point(1, 1),
      runePositions[runeNameToCode[secretSequence[0]]!]!,
      runePositions[runeNameToCode[secretSequence[1]]!]!,
      runePositions[runeNameToCode[secretSequence[2]]!]!,
      portalPos,
    ];

    final allRunePoints = runePositions.values.toSet();

    for (int leg = 0; leg < seqPoints.length - 1; leg++) {
      final from = seqPoints[leg];
      final to = seqPoints[leg + 1];
      final forbidden = Set<Point<int>>.from(allRunePoints)..remove(to);

      if (!hasCleanPath(from, to, forbidden)) {
        // Carve minimal single-tile path directly connecting from and to
        int cx = from.x;
        int cy = from.y;
        while (cx != to.x) {
          cx += (to.x > cx) ? 1 : -1;
          if (grid[cy][cx] == 1) grid[cy][cx] = 0;
        }
        while (cy != to.y) {
          cy += (to.y > cy) ? 1 : -1;
          if (grid[cy][cx] == 1) grid[cy][cx] = 0;
        }
      }
    }

    // 6. Place Pitfall Traps (max 2) and Spikes (2-3) on remaining floor tiles
    final availableFloor = <Point<int>>[];
    for (int r = 1; r < height - 1; r++) {
      for (int c = 1; c < width - 1; c++) {
        if (grid[r][c] == 0 && !(c <= 2 && r <= 2)) {
          availableFloor.add(Point(c, r));
        }
      }
    }
    availableFloor.shuffle(random);

    int pitfalls = 0;
    int spikes = 0;
    for (final slot in availableFloor) {
      if (pitfalls < 2 && random.nextDouble() < 0.3) {
        grid[slot.y][slot.x] = 6; // Pitfall trap
        pitfalls++;
      } else if (spikes < 3 && random.nextDouble() < 0.3) {
        grid[slot.y][slot.x] = 3; // Spike trap
        spikes++;
      }
    }

    // Set spawn marker on (1, 1)
    grid[1][1] = 2;

    return DungeonMapData(
      gridMatrix: grid,
      secretRuneSequence: secretSequence,
    );
  }
}
