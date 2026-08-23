import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../../../core/models/avatar_config.dart';
import 'components/darkness_overlay_component.dart';
import 'components/explorer_component.dart';
import 'components/floor_component.dart';
import 'components/floor_switch_component.dart';
import 'components/light_trail_component.dart';
import 'components/ping_beacon_component.dart';
import 'components/pitfall_component.dart';
import 'components/pushable_block_component.dart';
import 'components/rune_gate_component.dart';
import 'components/rune_tile_component.dart';
import 'components/spike_trap_component.dart';
import 'components/wall_component.dart';
import 'services/dungeon_generator.dart';
import 'widgets/dpad_widget.dart';

class DungeonGame extends FlameGame with HasCollisionDetection {
  late ExplorerComponent explorer;
  DungeonMapData? dungeonMapData;

  final void Function()? onSanctuaryReached;
  final void Function(Vector2 pos)? onExplorerMoved;
  final void Function(Vector2 pos, String direction, bool isMoving)? onExplorerMovedFull;
  final void Function(bool hasKey)? onKeyStatusChanged;
  final void Function(String message)? onRuneFeedback;
  final AvatarConfig? explorerAvatarConfig;
  final bool isGuideMode;
  final double tileSize = 36.0;

  bool hasKey = false;
  final List<String> currentSteppedSequence = [];
  Vector2? _lastProcessedRunePos;

  DungeonGame({
    this.dungeonMapData,
    this.onSanctuaryReached,
    this.onExplorerMoved,
    this.onExplorerMovedFull,
    this.onKeyStatusChanged,
    this.onRuneFeedback,
    this.explorerAvatarConfig,
    this.isGuideMode = false,
  });

  // Default compact 11x11 Dungeon Grid Matrix
  static final List<List<int>> defaultGrid = [
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 2, 0, 3, 0, 1, 0, 11, 0, 0, 1],
    [1, 0, 1, 1, 6, 1, 0, 1, 1, 0, 1],
    [1, 0, 1, 12, 0, 10, 0, 0, 1, 0, 1],
    [1, 3, 0, 0, 1, 1, 1, 0, 6, 3, 1],
    [1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1],
    [1, 0, 1, 13, 1, 1, 1, 14, 1, 0, 1],
    [1, 0, 0, 3, 0, 1, 0, 3, 0, 0, 1],
    [1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1],
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  ];

  @override
  Color backgroundColor() => const Color(0xFF121212);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final mapWidth = 11 * tileSize;
    final mapHeight = 11 * tileSize;

    // Zoom to fit the width of the map into the screen width, with a small padding
    final zoomWidthFit = (size.x * 0.95) / mapWidth;

    camera.viewfinder.anchor = Anchor.topCenter;
    camera.viewfinder.position = Vector2(mapWidth / 2, 0);
    camera.viewfinder.zoom = zoomWidthFit;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load floor texture
    final floorSprite = await loadSprite('floor.png');
    world.add(FloorComponent(sprite: floorSprite));

    // Load all wall variations
    final wallFaceMid = await loadSprite('wall.png');
    final wallFaceLeft = await loadSprite('wall-left.png');
    final wallFaceRight = await loadSprite('wall-right.png');
    final wallFaceSingle = await loadSprite('wall-single.png');

    final wallTopMid = await loadSprite('wall-up.png');
    final wallTopLeft = await loadSprite('wall-up-left.png');
    final wallTopRight = await loadSprite('wall-up-right.png');
    final wallTopSingle = await loadSprite('wall-up-single.png');

    // Vertical wall variations
    final wallFaceVertical = await loadSprite('vertical-wall.png');
    final wallFaceVerticalLeftEdge = await loadSprite('vertical-left-more-wall-at-right.png');
    final wallFaceVerticalRightEdge = await loadSprite('vertical-right-more-wall-at-left.png');
    final wallFaceVerticalDownLeft = await loadSprite('vertical-wall-down-left.png');
    final wallFaceVerticalDownRight = await loadSprite('vertical-wall-down-right.png');
    final wallFaceVerticalDownLeftAndRight = await loadSprite('vertical-wall-down-left-and-right.png');
    final wallFaceSurrounded = await loadSprite('wall-surrounded.png');

    // Preload spike trap animation frames
    final spikeSprites = [
      await loadSprite('spike-off1.png'),
      await loadSprite('spike-off2.png'),
      await loadSprite('spike-off3.png'),
      await loadSprite('spike-off4.png'),
    ];

    // Preload pitfall floor crack animation frames
    final floorCrackSprites = [
      await loadSprite('floor-crack1.png'),
      await loadSprite('floor-crack2.png'),
      await loadSprite('floor-crack3.png'),
      await loadSprite('floor-crack4.png'),
    ];

    // Preload rune tile sprites
    final sunOff = await loadSprite('sun-off.png');
    final sunOn = await loadSprite('sun-on.png');
    final moonOff = await loadSprite('moon-off.png');
    final moonOn = await loadSprite('moon-on.png');
    final snakeOff = await loadSprite('snake-off.png');
    final snakeOn = await loadSprite('snake-on.png');
    final lightningOff = await loadSprite('lighting-off.png');
    final lightningOn = await loadSprite('lighting-on.png');

    dungeonMapData ??= DungeonGenerator.generateMap();
    final grid = dungeonMapData!.gridMatrix;
    final rows = grid.length;
    final cols = grid[0].length;

    final spriteSize = Vector2(tileSize * 0.70, tileSize * 1.5); // 1.5 tiles tall in 2.5D
    Vector2 spawnPosition = ExplorerComponent.getCenteredTilePosition(1, 1, tileSize, spriteSize);

    // Parse matrix and build dungeon environment components
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cell = grid[r][c];
        final tilePos = Vector2(c * tileSize, r * tileSize);
        final tileVectorSize = Vector2(tileSize, tileSize);

        if (cell == 1) {
          // Neighbor detection for Autotiling
          final hasLeft = c > 0 && grid[r][c - 1] == 1;
          final hasRight = c < cols - 1 && grid[r][c + 1] == 1;
          final hasUp = r > 0 && grid[r - 1][c] == 1;
          final hasDown = r < rows - 1 && grid[r + 1][c] == 1;

          // Advanced detection: check if lateral neighbors also extend vertically downwards
          final leftHasDown = hasLeft && r < rows - 1 && grid[r + 1][c - 1] == 1;
          final rightHasDown = hasRight && r < rows - 1 && grid[r + 1][c + 1] == 1;

          // Projection detection: check lateral neighbors of the tile BELOW (for 2.5D perspective projection)
          final downHasLeft = hasDown && c > 0 && grid[r + 1][c - 1] == 1;
          final downHasRight = hasDown && c < cols - 1 && grid[r + 1][c + 1] == 1;

          Sprite face;
          Sprite? top;

          // 2.5D PERSPECTIVE LOGIC:
          // If there is a wall below (hasDown == true), this tile is a VERTICAL column / shaft.
          // If there is NO wall below (hasDown == false), this tile is a SOUTH-FACING FRONT FACE.

          if (hasDown) {
            // VERTICAL PART (Column / wall body extending downwards)
            if (leftHasDown && rightHasDown) {
              face = wallFaceSurrounded; // Interior of a wide 3+ tile vertical block
            } else if (rightHasDown) {
              face = wallFaceVerticalLeftEdge; // Left edge of a multi-tile wide vertical wall
            } else if (leftHasDown) {
              face = wallFaceVerticalRightEdge; // Right edge of a multi-tile wide vertical wall
            } else {
              // 1-tile column: project the shape of the front face below upwards!
              if (downHasLeft && downHasRight) {
                // Inverted T: Lands on a continuous horizontal wall
                face = wallFaceVerticalDownLeftAndRight;
              } else if (downHasRight) {
                // Normal L: Lands on a wall-left that extends right
                face = wallFaceVerticalDownLeft;
              } else if (downHasLeft) {
                // Mirrored L: Lands on a wall-right that extends left
                face = wallFaceVerticalDownRight;
              } else {
                // Isolated vertical column
                face = wallFaceVertical; // vertical-wall.png
              }
            }
          } else {
            // FRONT FACE PART (Facing the player southwards)
            // Regardless of whether it's standalone or the base of a vertical column,
            // the front horizontal face uses the standard front-facing wall sprites:
            if (hasLeft && hasRight) {
              face = wallFaceMid; // wall.png
            } else if (hasRight) {
              face = wallFaceLeft; // wall-left.png (extremo izquierdo inferior)
            } else if (hasLeft) {
              face = wallFaceRight; // wall-right.png (extremo derecho inferior)
            } else {
              face = wallFaceSingle; // wall-single.png (muro individual)
            }
          }

          // ROOF: Only if there is nothing above
          if (!hasUp) {
            if (hasLeft && hasRight) {
              top = wallTopMid;
            } else if (hasLeft) {
              top = wallTopRight;
            } else if (hasRight) {
              top = wallTopLeft;
            } else {
              top = wallTopSingle;
            }
          }

          world.add(WallComponent(
            position: tilePos,
            size: tileVectorSize,
            faceSprite: face,
            topSprite: top,
          ));
        } else if (cell == 2) {
          spawnPosition = ExplorerComponent.getCenteredTilePosition(c, r, tileSize, spriteSize);
        } else if (cell == 3) {
          world.add(SpikeTrapComponent(
            position: tilePos,
            size: tileVectorSize,
            sprites: spikeSprites,
          ));
        } else if (cell == 4) {
          world.add(PushableBlockComponent(position: tilePos, size: tileVectorSize));
        } else if (cell == 5) {
          world.add(FloorSwitchComponent(position: tilePos, size: tileVectorSize));
        } else if (cell == 6) {
          world.add(PitfallComponent(
            position: tilePos,
            size: tileVectorSize,
            sprites: floorCrackSprites,
          ));
        } else if (cell == 10) {
          world.add(RuneGateComponent(
            position: tilePos,
            size: tileVectorSize,
            onGatePassed: onSanctuaryReached,
            runeSprites: [sunOn, moonOn, snakeOn, lightningOn],
          ));
        } else if (cell == 11) {
          world.add(RuneTileComponent(
            position: tilePos,
            size: tileVectorSize,
            runeType: 'SOL',
            spriteOff: sunOff,
            spriteOn: sunOn,
          ));
        } else if (cell == 12) {
          world.add(RuneTileComponent(
            position: tilePos,
            size: tileVectorSize,
            runeType: 'MOON',
            spriteOff: moonOff,
            spriteOn: moonOn,
          ));
        } else if (cell == 13) {
          world.add(RuneTileComponent(
            position: tilePos,
            size: tileVectorSize,
            runeType: 'SNAKE',
            spriteOff: snakeOff,
            spriteOn: snakeOn,
          ));
        } else if (cell == 14) {
          world.add(RuneTileComponent(
            position: tilePos,
            size: tileVectorSize,
            runeType: 'LIGHTNING',
            spriteOff: lightningOff,
            spriteOn: lightningOn,
          ));
        }
      }
    }

    // Instantiate Explorer Component centered inside cell
    explorer = ExplorerComponent(
      position: spawnPosition,
      size: spriteSize,
      avatarConfig: explorerAvatarConfig,
      onPositionChanged: onExplorerMoved,
      onPositionChangedFull: (pos, dir, moving) {
        onExplorerMovedFull?.call(pos, dir.name, moving);
      },
    );
    world.add(explorer);

    // Add Darkness Overlay Component ONLY if NOT in Guide Mode
    if (!isGuideMode) {
      world.add(DarknessOverlayComponent());
    }
  }

  void respawnExplorerAtStart() {
    final startTileTopLeft = Vector2(tileSize * 1, tileSize * 1);
    explorer.resetPosition(startTileTopLeft);
    _lastProcessedRunePos = null;
    onRuneFeedback?.call('🕳️ Fell into an invisible Pitfall Trap! Respawned at start.');
  }

  void stepOnRuneTile(String runeType, Vector2 tilePos) {
    if (dungeonMapData == null) return;
    
    // Safety: ignore if we are still processing the same tile
    if (_lastProcessedRunePos != null && (_lastProcessedRunePos! - tilePos).length < 1.0) {
      return;
    }
    _lastProcessedRunePos = tilePos.clone();

    final targetSeq = dungeonMapData!.secretRuneSequence;

    currentSteppedSequence.add(runeType);
    final currentIdx = currentSteppedSequence.length - 1;

    if (currentIdx < targetSeq.length && targetSeq[currentIdx] == runeType) {
      print('[RUNE LOG] Correct rune step: ${DungeonGenerator.getRuneLabel(runeType)}');
      onRuneFeedback?.call('✨ Correct Rune: ${DungeonGenerator.getRuneLabel(runeType)}');

      if (currentSteppedSequence.length == targetSeq.length) {
        unlockRuneGate();
        onRuneFeedback?.call('🔓 RUNE GATE UNLOCKED! 8 SECONDS to pass!');
      }
    } else {
      print('[RUNE LOG] Wrong rune stepped! Resetting sequence...');
      currentSteppedSequence.clear();
      onRuneFeedback?.call('❌ Wrong Rune Order! Sequence Reset.');

      // Reset all rune tiles visually
      for (final tile in world.children.whereType<RuneTileComponent>()) {
        tile.reset();
      }
    }
  }

  void unlockRuneGate() {
    for (final gate in world.children.whereType<RuneGateComponent>()) {
      gate.unlockForDuration(const Duration(seconds: 8), onRelocked: () {
        currentSteppedSequence.clear();
        onRuneFeedback?.call('🔒 Time Expired! Rune Gate Relocked.');
        // Reset tiles when gate relocks
        for (final tile in world.children.whereType<RuneTileComponent>()) {
          tile.reset();
        }
      });
    }
  }

  void collectKey() {
    hasKey = true;
    onKeyStatusChanged?.call(true);
  }

  void addPingBeacon(Vector2 tilePos) {
    world.add(PingBeaconComponent(
      position: tilePos,
      size: Vector2(tileSize, tileSize),
    ));
  }

  void addTrailPoint(Vector2 worldPos) {
    world.add(LightTrailComponent(position: worldPos));
  }

  void disarmAllTraps() {
    for (final trap in world.children.whereType<SpikeTrapComponent>()) {
      trap.disarmTemporarily(const Duration(seconds: 5));
    }
  }

  bool isTileOccupied(Vector2 targetPos, {PushableBlockComponent? currentBlock}) {
    for (final wall in world.children.whereType<WallComponent>()) {
      if ((wall.position - targetPos).length < (tileSize * 0.5)) {
        return true;
      }
    }

    for (final block in world.children.whereType<PushableBlockComponent>()) {
      if (block != currentBlock && (block.position - targetPos).length < (tileSize * 0.5)) {
        return true;
      }
    }

    // Active Spike Traps are solid
    for (final trap in world.children.whereType<SpikeTrapComponent>()) {
      if (trap.isActive && (trap.position - targetPos).length < (tileSize * 0.5)) {
        return true;
      }
    }

    return false;
  }

  bool isActiveSpikeAt(Vector2 targetPos) {
    for (final trap in world.children.whereType<SpikeTrapComponent>()) {
      if (trap.isActive && (trap.position - targetPos).length < (tileSize * 0.5)) {
        return true;
      }
    }
    return false;
  }

  void moveExplorer(Vector2 dir) {
    explorer.setMovementDirection(dir);
  }

  void stopExplorer() {
    explorer.stopMovement();
  }
}

@Preview(name: 'Dungeon - Explorer Mode')
Widget previewDungeonExplorer() {
  return GameWidget(
    game: DungeonGame(
      isGuideMode: false,
    ),
  );
}

@Preview(name: 'Dungeon - Guide Mode')
Widget previewDungeonGuide() {
  return GameWidget(
    game: DungeonGame(
      isGuideMode: true,
    ),
  );
}

@Preview(name: 'Dungeon - Interactive D-Pad')
Widget previewDungeonInteractive() {
  final game = DungeonGame(isGuideMode: true);
  return Material(
    color: const Color(0xFF121212),
    child: Stack(
      children: [
        GameWidget(game: game),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: DPadWidget(game: game),
        ),
      ],
    ),
  );
}
