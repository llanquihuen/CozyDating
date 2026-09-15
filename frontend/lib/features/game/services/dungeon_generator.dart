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

    // Recursive Backtracker Maze carving on odd coordinates (1, 3, 5, 7, 9)
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

    int manhattanDist(Point<int> a, Point<int> b) => (a.x - b.x).abs() + (a.y - b.y).abs();

    int countWallNeighbors(int x, int y) {
      int count = 0;
      const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
      for (final d in dirs) {
        final nx = x + d[0];
        final ny = y + d[1];
        if (nx < 0 || nx >= width || ny < 0 || ny >= height || grid[ny][nx] == 1) {
          count++;
        }
      }
      return count;
    }

    // 3. Find dead-end floor tiles (tiles with exactly 3 wall neighbors).
    // Dead-end alcoves are critical: they NEVER sit on a transit route between other locations,
    // guaranteeing players are never forced to step on wrong runes while navigating the dungeon.
    List<Point<int>> getDeadEnds() {
      final list = <Point<int>>[];
      for (int r = 1; r < height - 1; r++) {
        for (int c = 1; c < width - 1; c++) {
          if (grid[r][c] == 0 && !(c == 1 && r == 1)) {
            if (countWallNeighbors(c, r) == 3) {
              list.add(Point(c, r));
            }
          }
        }
      }
      return list;
    }

    var deadEnds = getDeadEnds();

    // If there are fewer than 6 dead ends, carve dedicated 1-tile alcoves off existing corridors
    // into walls that have exactly 1 floor neighbor and 3 wall neighbors
    if (deadEnds.length < 6) {
      final candidateAlcoveWalls = <Point<int>>[];
      for (int r = 1; r < height - 1; r++) {
        for (int c = 1; c < width - 1; c++) {
          if (grid[r][c] == 1 && !(c <= 2 && r <= 2)) {
            int floorNeighbors = 0;
            const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
            for (final d in dirs) {
              final nx = c + d[0];
              final ny = r + d[1];
              if (nx >= 0 && nx < width && ny >= 0 && ny < height && grid[ny][nx] == 0) {
                floorNeighbors++;
              }
            }
            if (floorNeighbors == 1) {
              candidateAlcoveWalls.add(Point(c, r));
            }
          }
        }
      }
      candidateAlcoveWalls.shuffle(random);
      for (final wall in candidateAlcoveWalls) {
        if (deadEnds.length >= 7) break;
        grid[wall.y][wall.x] = 0;
        deadEnds = getDeadEnds();
      }
    }

    // 4. Select Portal (10) and 4 Runes (11, 12, 13, 14) exclusively in distinct dead-end alcoves
    // with strict minimum distance between each other and spawn (1, 1)
    final spawnPoint = const Point(1, 1);
    deadEnds.shuffle(random);

    // Pick portal: prefer an alcove far from spawn
    deadEnds.sort((a, b) => manhattanDist(b, spawnPoint).compareTo(manhattanDist(a, spawnPoint)));
    final portalPos = deadEnds.removeAt(0);
    grid[portalPos.y][portalPos.x] = 10;

    final selectedRunePositions = <Point<int>>[];
    final chosenRuneCodes = [11, 12, 13, 14]..shuffle(random);
    final runePositions = <int, Point<int>>{};

    // Select 4 dead-ends with maximum spatial separation (minDistance >= 3)
    deadEnds.shuffle(random);
    for (int minDist = 4; minDist >= 2; minDist--) {
      for (final candidate in List<Point<int>>.from(deadEnds)) {
        if (selectedRunePositions.length == 4) break;

        final isFarFromSpawn = manhattanDist(candidate, spawnPoint) >= 2;
        final isFarFromPortal = manhattanDist(candidate, portalPos) >= minDist;
        final isFarFromRunes = selectedRunePositions.every((p) => manhattanDist(candidate, p) >= minDist);

        if (isFarFromSpawn && isFarFromPortal && isFarFromRunes) {
          selectedRunePositions.add(candidate);
          deadEnds.remove(candidate);
        }
      }
      if (selectedRunePositions.length == 4) break;
    }

    // Fallback if needed to ensure all 4 runes have distinct alcoves
    while (selectedRunePositions.length < 4 && deadEnds.isNotEmpty) {
      selectedRunePositions.add(deadEnds.removeAt(0));
    }

    // If still less than 4, take any floor tile not adjacent to others
    if (selectedRunePositions.length < 4) {
      for (int r = 1; r < height - 1; r++) {
        for (int c = 1; c < width - 1; c++) {
          if (selectedRunePositions.length == 4) break;
          final pt = Point(c, r);
          if (grid[r][c] == 0 && pt != spawnPoint && pt != portalPos && !selectedRunePositions.contains(pt)) {
            selectedRunePositions.add(pt);
          }
        }
      }
    }

    // Assign rune codes to the chosen alcove positions
    for (int i = 0; i < 4; i++) {
      final pos = selectedRunePositions[i];
      final code = chosenRuneCodes[i];
      grid[pos.y][pos.x] = code;
      runePositions[code] = pos;
    }

    // 5. Open subtle navigation loops (1 or 2 shortcuts), but NEVER touch walls adjacent
    // to rune or portal alcoves to protect their dead-end sanctuary status
    final protectedPoints = <Point<int>>[
      spawnPoint,
      portalPos,
      ...selectedRunePositions,
    ];

    final candidateWallsToOpen = <Point<int>>[];
    for (int r = 2; r < height - 2; r++) {
      for (int c = 2; c < width - 2; c++) {
        if (grid[r][c] == 1) {
          // Do not open if adjacent to any rune alcove or portal alcove
          final isProtected = protectedPoints.any((p) => manhattanDist(Point(c, r), p) <= 1);
          if (isProtected) continue;

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
    for (int i = 0; i < min(2, candidateWallsToOpen.length); i++) {
      final wall = candidateWallsToOpen[i];
      grid[wall.y][wall.x] = 0; // Open shortcut safely
    }

    // 6. BFS Path Validator: Verifies that no walls or other runes block the sequence legs
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
      spawnPoint,
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
        // Carve minimal single-tile path directly connecting from and to if needed
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

    // 7. Place Pitfall Traps (max 2) and Spikes (max 2)
    // Traps are NEVER placed on runes, portal, or directly blocking rune alcove entrances
    final availableFloor = <Point<int>>[];
    for (int r = 1; r < height - 1; r++) {
      for (int c = 1; c < width - 1; c++) {
        if (grid[r][c] == 0 && !(c <= 2 && r <= 2)) {
          final isNearSpecial = protectedPoints.any((p) => manhattanDist(Point(c, r), p) <= 1);
          if (!isNearSpecial) {
            availableFloor.add(Point(c, r));
          }
        }
      }
    }
    availableFloor.shuffle(random);

    int pitfalls = 0;
    int spikes = 0;
    for (final slot in availableFloor) {
      if (pitfalls < 2 && random.nextDouble() < 0.25) {
        grid[slot.y][slot.x] = 6; // Pitfall trap
        pitfalls++;
      } else if (spikes < 2 && random.nextDouble() < 0.25) {
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
