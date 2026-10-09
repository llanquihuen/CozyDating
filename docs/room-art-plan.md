# Plan: Arte del cuarto por estilo (pisos, paredes y muebles)

Objetivo: que el cuarto del jugador pueda vestirse con los mismos estilos que las tarjetas (Metal,
Rústico, Coquette, Café, Arcade, Místico, Matcha, Retro 90s, Monocromo, Costa), y que pisos y
paredes tengan **el mismo tamaño de píxel que los muebles y el avatar**. Con eso, más adelante, el
cuarto podría usarse como escenario de la tarjeta (la antigua fase 7 de
`profile-card-fullscreen-plan.md`, ahora en pausa).

## 0. Diagnóstico (2026-10-09)

Medido en el código (`cozy_room_game.dart`, `isometric_furniture_component.dart`):

| Elemento | Cómo se dibuja | Tamaño de un píxel en el mundo |
|---|---|---|
| Muebles | sprites de 128 px por casilla, dibujados a 0,5× | **0,5 unidades** (casilla = 64 × 32) |
| Avatar | sprite de 64 × 128 en 30 × 60 unidades | ~0,47 unidades |
| Piso | **una** textura de 256 × 256 estirada sobre todo el piso (8 × 8 casillas) y deformada a isométrico | 1 unidad en cada eje: un rombo de **2 × 1**, el doble de ancho que un píxel de mueble y rotado |
| Paredes | una textura de 256 × 256 estirada a 256 × 70 unidades | 1 unidad de ancho × **0,27** de alto: píxeles aplastados casi 4 veces |

Las texturas, además, tienen detalle de 1 píxel (vetas, ruido, mármol). Al deformarlas se ven como
foto, no como pixel art, y nunca pueden calzar con la grilla de los muebles.

![Piso actual (izquierda) vs. piso dibujado a la densidad de los muebles (derecha)](room-floor-density.png)

A la izquierda, el piso de parquet actual con dos estanterías existentes. A la derecha, un prototipo
del mismo cuarto con el piso dibujado píxel a píxel en la pantalla, a 0,5 unidades por píxel: ahora
calza con los muebles.

**Muebles por estilo:** hay 89 muebles base, casi todos genéricos (cocina, baño, dormitorio, salón).
Algunos estilos tienen piezas (Arcade: escritorio gamer, silla gamer, TV, pósters; Café: cafetera,
taza, libros; Matcha: set de té, tatami, mat de yoga). Coquette, Místico, Costa, Monocromo y Metal
casi no tienen nada propio (ver la matriz en §2).

## 1. Decisiones (confirmadas 2026-10-09: pisos y paredes primero, hechos con PixelLab)

| Tema | Propuesta |
|---|---|
| Pisos | **Baldosas isométricas prerenderizadas**: un sprite de 128 × 64 px por casilla (la casilla de 64 × 32 a 0,5×), con 3 o 4 variantes por material, elegidas por casilla con un hash fijo para que no se note la repetición. Se dibujan casilla por casilla en vez de una textura estirada. |
| Paredes | **Paneles prerenderizados por columna**: cada panel de pared mide 32 × 70 unidades, o sea 64 × 140 px, inclinado como paralelogramo isométrico (sube 1 px cada 2). Hay una versión para la pared norte y su espejo para la oeste, y lo mismo para las paredes interiores (`isometric_interior_wall_component.dart`). |
| Cómo se hacen pisos y paredes | **PixelLab** (decisión del usuario, en vez de procedural). Pisos con `create-tiles-pro` (`tile_type: isometric`, `tile_size: 128`, `tile_height: 64`, `tile_view_angle: 30`, `outline_mode: segmentation`): una llamada da 10 baldosas de 128 × 64 a la densidad exacta, por ~15 generaciones. Se eligen las variantes que calzan entre sí. |
| Colores lisos | Se mantienen como hoy: una base en gris con matiz (`modulate`), ahora también por baldosa o panel. |
| Muebles nuevos | **PixelLab con un mueble existente como referencia de estilo**, en las 4 rotaciones que usa el cuarto y con los tamaños de lienzo del catálogo (128 × 128 para 1 × 1, 192 × 144 para 1 × 2, etc.). Después, contorno selectivo (`convert_selout.py --scenery`), `sync_furniture_assets.py` y `pubspec.yaml`, como siempre. |
| Paquetes por estilo | Cada estilo de tarjeta tiene un **paquete de cuarto**: piso, papel mural y unos 8 muebles. El cuarto inicial que se arma desde los gustos (`generateStarterRoomConfig`) usa el paquete del estilo sugerido. En "Decorar", un filtro por estilo. |
| Orden | Primero pisos y paredes, porque arreglan todos los cuartos de una vez. Después muebles, empezando por un piloto de 2 estilos para medir costo y calidad. |

## 2. Matriz de muebles por estilo

✓ = ya existe (puede necesitar una variante de color). Lo demás está por hacer. Unos 8 muebles por
estilo; la lista es un punto de partida para ajustar contigo.

| Estilo | Piso / pared | Ya hay | Faltan |
|---|---|---|---|
| Metal / Goth | piedra oscura / ladrillo oscuro o damasco | ✓ chimenea, ✓ estantería alta, ✓ armario | candelabro de pie, sillón de terciopelo, cama con dosel negra, vitral (pared), alfombra roja, soporte de guitarra eléctrica |
| Rústico | tablones / troncos | ✓ chimenea, ✓ mesa rústica, ✓ sillón, ✓ monstera, ✓ cama de perro | cama de troncos, farol, leña apilada, alfombra escocesa, cabeza de ciervo de peluche (pared) |
| Coquette | alfombra rosa / rayas rosadas | — | cama con dosel rosa, tocador con espejo, sillón rosado, alfombra de corazón, moños (pared), florero, peluches |
| Café | madera oscura / ladrillo | ✓ cafetera, ✓ taza, ✓ libro, ✓ estantería | barra de café, mesa bistró, lámpara colgante, pizarra con menú (pared), sacos de café |
| Arcade | grilla neón / panel oscuro | ✓ escritorio gamer, ✓ silla gamer, ✓ TV, ✓ pósters, ✓ lámpara de lava | máquina arcade, letrero neón (pared), puf, repisa de consolas, cama con luces LED |
| Místico | alfombra morada con runas / estrellas ✓ | ✓ papel estrellado | mesa con bola de cristal, estante de pociones, caldero, tapiz de luna (pared), velas de pie, hierbas colgadas |
| Matcha | tatami ✓ / shoji ✓ | ✓ set de té, ✓ tatami, ✓ yoga, ✓ shoji (pared interior) | mesa baja, futón, bonsái, farol de papel, cojines zabuton |
| Retro 90s | damero morado y turquesa / Memphis | ✓ lámpara de lava, ✓ juegos de mesa | tele de tubo con consola, radiocasete, puf inflable, repisa de casetes, pósters noventeros, alfombra Memphis |
| Monocromo | concreto / yeso blanco | — | cama minimalista, sofá negro, lámpara de arco, cuadro en blanco y negro, mesa de vidrio |
| Costa | tablones claros / madera blanca | — | hamaca, tabla de surf (pared), silla de ratán, salvavidas (pared), conchas (superficie), alfombra a rayas azules |

En total son unos 55 muebles nuevos, más 10 pisos y 10 papeles murales.

## 3. Fases

Cada fase deja el cuarto funcionando, con `flutter test` y `flutter analyze` sin errores nuevos.

### Fase 1 — Pisos a la densidad de los muebles ✓ (2026-10-09)

- `CreateSprites/room_tiles/make_floors.py`: `--gen <id>` llama a PixelLab y guarda las 10 baldosas
  crudas en `gen/` (como `make_scenes.py`); `--sheet` arma una hoja de contacto con un piso de 4 × 4;
  `--build id=gen[:i,j,...]` recorta cada baldosa al rombo de 128 × 64 y la copia a
  `frontend/assets/images/floors/tiles/<id>_v<n>.png`, y reescribe `tiles.json` (cuántas variantes
  tiene cada id). Las bases grises (`solid_tiles`, `solid_carpet`) se pasan a gris neutro con el
  mismo promedio que las texturas viejas, así los colores lisos se tiñen igual que antes; la
  alfombra pierde el borde que dibuja PixelLab (`drop_edge`) para que no se vea la grilla.
- Elegidas: parquet, nogal y terracota con las 10 variantes; damero con 3 (las únicas con la misma
  fase: arriba y abajo negro, a los lados blanco); tatami con 3 (un tatami entero con borde); baldosa
  gris y alfombra gris con 4 cada una. Costo: 7 llamadas, ~105 generaciones (más 2 de prueba).
- `FloorTiles` (`lobby/utils/floor_tiles.dart`): ruta, manifiesto, `tileKey` (un color liso usa la
  base gris de su textura) y el hash de variante, igual al de Python. `_renderFloor` dibuja casilla
  por casilla, incluidos los reemplazos por zona; si un piso en uso no tiene baldosas, se usa la
  textura estirada de antes. La luz del cuarto sigue encima, sin cambios.
- Tests: `floor_tiles_test.dart` (cada piso del catálogo tiene sus variantes en 128 × 64, tantas como
  dice el manifiesto; colores lisos; hash estable).

![Damero, alfombra rosa (base gris teñida), tatami y terracota en el cuarto](room-floor-tiles.png)

### Fase 2 — Paredes a la densidad de los muebles

- `make_walls.py`: cada papel mural es una función del espacio de la pared, dibujada en el
  paralelogramo del panel (64 × 140 px más la inclinación). Genera la pared norte, su espejo para la
  oeste y la versión de pared interior. Rehacer los 7 papeles más los lisos.
- `_renderWalls` y `isometric_interior_wall_component.dart`: un panel por columna (ya se pintan por
  columna para los reemplazos `n,x`, ver la memoria "wall panels are 32px wide"). Se mantienen el
  orden de dibujo de los muebles de pared y la luz.
- Tests: como en la fase 1, más los reemplazos por panel.

### Fase 3 — Piloto de muebles con PixelLab (Coquette y Retro 90s)

- Son los dos estilos con menos piezas y con identidad más clara.
- `CreateSprites/furniture_gen/make_furniture.py`: PixelLab genera las 4 rotaciones isométricas con
  un mueble existente como referencia de estilo, en el lienzo del catálogo. Las imágenes crudas
  quedan en `gen/`, así se pueden reconstruir sin gastar créditos (como `make_scenes.py`).
- Antes de generar en serie, probar 2 muebles (cama con dosel, tele de tubo) y revisarlos junto a
  muebles existentes en una captura del cuarto. Se miden: costo por mueble, que las 4 rotaciones
  sean el mismo objeto, que el tamaño calce con la casilla y el contorno.
- Contorno selectivo, sync al catálogo (zona, huella, `surface_spots` si aplica, capas de silla si
  es asiento) y `pubspec.yaml`.

**Listo cuando** los 2 estilos tienen sus ~8 muebles y un cuarto completo de cada uno se ve
coherente.

### Fase 4 — Los otros 8 estilos

- Mismo proceso, un estilo por tanda, revisando cada uno contigo antes de sincronizarlo.
- Presupuesto: con el piloto se sabrá cuántas generaciones cuesta cada mueble. Si es parecido a la
  ropa (~20 por objeto con sus rotaciones), unos 55 muebles caben en un mes del plan Tier 3.

### Fase 5 — Paquetes de cuarto por estilo

- `RoomStylePack` (piso, pared, muebles y una disposición sugerida) para cada id de tema de tarjeta.
- `generateStarterRoomConfig` arma el cuarto inicial con el paquete del estilo sugerido por los
  gustos (`ProfileCardStyle.suggestedTheme`).
- En "Decorar", un filtro "Estilo" y la opción de aplicar el paquete completo.
- Tests: cada estilo tiene su paquete y todos sus ids existen en el catálogo.

### Después — "Mi cuarto" como escenario de la tarjeta

Con el cuarto ya coherente se retoma la fase 7 del plan de la tarjeta (el cuarto del jugador detrás
de su avatar).

## 4. Riesgos

- **Rotaciones inconsistentes en PixelLab:** que las 4 vistas no sean el mismo mueble. Por eso el
  piloto, y regenerar solo la rotación mala con otra semilla, como con el pelo.
- **Iluminación:** las luces del cuarto se calculan sobre el piso y las paredes actuales. Hay que
  revisar que sigan bien con baldosas y paneles.
- **Rendimiento:** son 64 baldosas y 16 paneles en vez de 3 texturas. Son sprites chicos y se
  pueden prerenderizar a una sola imagen cuando cambia el cuarto (en Flame, a un `Picture` o
  `Image` en caché).
- **Cuartos guardados:** los ids de piso y pared no cambian, solo su arte, así que los cuartos
  existentes se ven con el arte nuevo sin migrar nada.
