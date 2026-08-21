# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Cozy Slow Dating** — a Flutter-based mobile game where two matched players collaborate in a procedurally-generated dungeon (one Explorer, one Guide). Lobby, dungeon gameplay, and eventual voice-chat phases are gated by a ticket economy.

## Commands

### Backend (from `backend/`)
```
mvn clean package -DskipTests        # build JAR
mvn spring-boot:run                  # run dev server (port 8080)
mvn test                             # run all tests
mvn test -Dtest=ClassName            # run a single test class
```
MySQL must be running at `localhost:3306/cozy_dating` (user: `root`, password: `admin`) for dev. Tests use H2 in-memory (MySQL-compatibility mode) via `src/test/resources/application-test.properties`.

### Frontend (from `frontend/`)
```
flutter pub get                              # install dependencies
flutter run                                  # run on connected device/emulator
flutter test                                 # run all tests
flutter test test/path/to_test.dart          # run a single test file
flutter analyze                              # lint/type-check
flutter build apk                            # release build
```
When running on Android emulator the backend host resolves to `10.0.2.2` automatically.

### Asset Pipeline (from repo root)
```
python scripts/sync_furniture_assets.py      # copy furniture PNGs from CreateSprites/ to frontend/assets/
python scripts/pack_avatar_spritesheets.py   # pack avatar layer PNGs into spritesheets
```
Sprite sources live in `CreateSprites/`. Re-run sync after regenerating sprites. After syncing new furniture, update asset declarations in `frontend/pubspec.yaml`.

## Architecture

### Communication Model
The backend is a **relay server** — it does not simulate game state. All gameplay logic runs on Flutter clients; the server only forwards messages between matched partners.

```
Flutter Client ──HTTP──> /auth/token    (JWT issue + ticket balance)
Flutter Client ──WS───>  /game          (all gameplay traffic)
```

On WebSocket connect, the client sends `SESSION_INIT` (JWT + commune + timeSlot + mode). The server verifies the token, enqueues the player, and when two compatible players are found creates a `GameRoom` and assigns roles (`EXPLORER` / `GUIDE`). All subsequent messages (`PLAYER_MOVE`, `BLOCK_PUSHED`, `TRAP_TOGGLED`, `PING_SENT`, etc.) are forwarded verbatim to the partner session.

### Frontend State Machine (`GameBloc`)
`GameInitialState` → `MatchmakingQueueState` → `ActiveGameState` ↔ `PausedGameState` → `TerminatedGameState`

- **Lobby** (`CozyLobbyView` / `CozyRoomGame`): shown during `GameInitialState` or `MatchmakingQueueState`. Isometric room with drag-and-drop furniture; avatar walks to furniture via `IsometricPathfinder`.
- **Explorer** (`DungeonGame`): shown when `ActiveGameState.role == 'EXPLORER'`. 11×11 procedural maze with darkness overlay and DPad controls.
- **Guide** (`GuideDungeonGame`): shown when `ActiveGameState.role == 'GUIDE'`. Fully-lit schematic view; sends pings and disarms traps remotely.

### Dungeon Generation
`DungeonGenerator` uses a recursive backtracker seeded by `seed + act * 7919`. Tile codes: `0`=floor, `1`=wall, `2`=spawn, `3`=pushable block, `6`=door, `10`=sanctuary plate, `11-14`=rune tiles.

### Avatar & Furniture Systems
- **Avatar**: 20+ modular sprite layers (face, hair, clothing, accessories) in two resolutions — `64x128` Detailed and `32x64` Pixel Chibi. Configs serialized to JSON via `AvatarStorageService`.
- **Furniture**: multi-resolution sprites (`32x64`, `64x128`, `128x256`) catalogued by `FurnitureCatalogService`. Source generation in `CreateSprites/`.

### Backend Services
- `MatchmakingService`: in-memory `CopyOnWriteArrayList` queue. Match criteria: same `mode` + `commune` + `timeSlot` + not mutually blocked.
- `GameSessionService`: manages active rooms, role-swap logic, and a 20-second reconnect grace window (`GAME_PAUSED` / `GAME_RESUMED`).
- `DatabaseService`: thin `JdbcTemplate` wrapper over MySQL. Tables: `users` (id, username, tickets_balance), `user_blocks` (directional pairs).
- `JwtUtil`: HMAC256 JWT signed with secret from `application.properties`. Token carries `userId`.
- `LiveKitTokenGenerator`: signs LiveKit Cloud access tokens for future voice-chat.

### Ticket Economy
VOICE mode atomically reserves 1 ticket per player before room creation. Tickets are refunded if both players never send `GAME_READY` and the reconnect window expires.

### CI/CD
GitHub Actions (`.github/workflows/deploy-backend.yml`) triggers on pushes to `main` under `backend/**`: builds with `mvn clean package -DskipTests`, SCPs the JAR to Amazon Lightsail, and restarts the `cozy-dating-backend.service` systemd unit.
