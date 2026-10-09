# Auditoría de muebles (2026-10-09)

Primer paso de la fase 3 de `room-art-plan.md`: antes de hacer muebles nuevos por estilo, revisar los
62 del catálogo y decidir qué se arregla, qué se rehace y qué se retira.

## Cómo se hizo (repetible, sin créditos)

- `frontend/test/furniture_audit_tool_test.dart`: el propio juego pone cada mueble en un cuarto vacío
  en sus 4 rotaciones (rot0 arriba, rot1 derecha, rot2 izquierda, rot3 abajo; los de pared en norte,
  oeste y norte alto) y dibuja encima el contorno de su huella. Se salta en la suite normal:
  `AUDIT_DIR=<carpeta> flutter test test/furniture_audit_tool_test.dart` (`AUDIT_ONLY=id,id` para
  unos pocos).
- `CreateSprites/furniture_gen/audit_files.py <carpeta>/_meta.tsv`: revisa los archivos (rotaciones
  que faltan, vista trasera, espejos, píxel al doble, contorno negro puro).
- Cobertura de la huella: cuánto del ancho del rombo cubre el dibujo y a cuántos píxeles queda su
  base del vértice inferior (con la misma geometría que el juego; los cubos guía dan 100 % y 0 px).

![Muebles sobre su huella, rot0 y rot2, agrupados por diagnóstico](furniture-audit.png)

## Hallazgos

### A. Huella mal ocupada o mal ubicada

| Mueble | Medida | Qué pasa |
|---|---|---|
| `kitchen_sink` | 81 % del ancho, base 9 px arriba | El mueble no llega a los bordes de la casilla: entre dos muebles de cocina queda un hueco. |
| `kitchen_stove` | 66 %, base 13 px arriba | Igual, más angosta todavía. |
| `dining_table_2x2` | 57 %, 8 px abajo | Tablero chico flotando sobre patas sueltas; no llena el 2×2. |
| `bathtub_2x2` | lienzo 192 (debería ser 256), 75 px arriba | Lienzo de 1×2 en un mueble 2×2: queda corrida y flotando. rot1 no es espejo. |
| `bathtub_regular_1x2` | 81 %, 20 px arriba | Más chica que la casilla y corrida. |
| `stone_fountain` | 60 %, 29 px arriba | Chica para su 2×2 y muy simple. |
| `manga_shelf` | 32 %, 75 px arriba | Flota muy por encima de su casilla (lienzo y offset de otro tamaño). |

Los muebles que van contra la pared (armario, estanterías, inodoro) cubren 50–65 % del ancho a
propósito: son poco profundos. No es un error.

### B. Arte sin terminar o muy simple

`bbq_grill`, `cat_tree_tower`, `pet_dog_bed`, `yoga_mat_floor`, `home_theater_tv`,
`acoustic_guitar_stand` (la guitarra flota sobre la base) y `monstera_plant_pot` (bolas verdes
sobre un cubo). Son dibujos de pocos colores, sin el detalle ni el sombreado del resto, y ninguno
tiene vista trasera.

### C. Objetos de superficie y de pared flojos

`tea_set_table`, `vinyl_record_player`, `espresso_machine`, `polaroid_camera_table`,
`boardgame_box_set` (muy chicos y planos), `wall_clock`, `wall_world_map` (un cartón con dos
puntos verdes), `hanging_shelf_wall` (una tabla con dos figuras) y `curtained_window` (la barra de
la cortina baja hasta el suelo).

### D. Técnico

- **Negro puro** en `single_bed`, `gamer_chair_sm`, `vinyl_record_player`, estanterías,
  `gaming_pc_desk` y pósters: revisado, **no son contornos** sino materiales oscuros (marco negro,
  cuero, la silueta del castillo). El contorno selectivo ya está aplicado a todo
  (`convert_selout.py --scenery --dry`: 0 de 618 sprites cambiarían).
- ~~**Píxel al doble**~~: falso positivo. El detector contaba como "píxeles de 2×2" las zonas de
  color liso (la vista trasera de las estanterías, los cubos guía). Corregido en `audit_files.py`
  (solo mira bloques en bordes de color): ningún mueble está a media densidad.
- **Sin vista trasera** (rot2 = rot0): casi todos los muebles salvo camas, sillas, sillones,
  armario, estanterías, refrigerador, inodoro y sofá. En simétricos (mesa, lámpara, planta) da
  igual; en los que tienen frente (cocina, fregadero, TV, chimenea) al girarlos 180° siguen
  mirando hacia la cámara.

### E. Bien (sirven de referencia)

`single_high_bed`, `king_bed`, `closet`, `plush_armchair`, `simple_sofa`, `bathtub_classic`,
`bathroom_toilet`, `kitchen_fridge_sm`, `table`, `simple_chair_sm`, `side_table_sm`,
`floor_lamp_sm`, `floor_plant_sm`, `fireplace`, `window_yellow`, `towel_rack_wall`,
`pan_rack_wall`, `art_painting`, los pósters, `coffee_mug`, `table_lamp`, `open_book`, `lava_lamp`.

### Duplicados

| Grupo | Situación |
|---|---|
| `single_bed` / `single_high_bed` | El cuarto inicial ya usa la alta. La baja tiene contorno negro y peor arte. |
| `bathtub_classic` / `bathtub_regular_1x2` / `bathtub_2x2` | La clásica está bien; las otras dos tienen la huella mal. |
| `manga_shelf` / `tall_mangashelf` / `tall_mangashelf_white` | La baja flota; las altas están a media densidad. |
| `bookshelf` / `tall_bookshelf` | Distintas alturas, las dos sirven (solo contorno). |

## Decisiones (2026-10-09)

1. **Duplicados: se retiran y su id apunta al bueno.** `single_bed` → `single_high_bed`,
   `bathtub_regular_1x2` y `bathtub_2x2` → `bathtub_classic`, `manga_shelf` → `tall_mangashelf`
   (`PlacedFurnitureConfig.retiredTypes`). Los cuartos guardados se migran al leerse (con la huella
   del reemplazo según la rotación), el decorador ya no los ofrece y `getItem` los resuelve al
   reemplazo. El cuarto inicial por gustos usa `tall_mangashelf`. Hecho.
2. **Vista trasera solo para muebles con frente** (cocina, fregadero, TV, chimenea, escritorio,
   estanterías) al rehacerlos. Los simétricos quedan como están.
3. **Orden de las tandas:**
   1. Cuarto inicial: `kitchen_sink`, `kitchen_stove` (llenar el 1×1 y vista trasera),
      `dining_table_2x2`.
   2. Piezas de estilo: `tea_set_table`, `vinyl_record_player`, `monstera_plant_pot`,
      `pet_dog_bed`, `yoga_mat_floor` (`tall_mangashelf` salió de la lista: estaba bien).
   3. El resto: `bbq_grill`, `stone_fountain`, `cat_tree_tower`, `home_theater_tv`,
      `acoustic_guitar_stand`, `espresso_machine`, `polaroid_camera_table`, `boardgame_box_set`,
      `wall_clock`, `wall_world_map`, `hanging_shelf_wall`, `curtained_window`.

## Tanda 1: cuarto inicial (2026-10-09) ✓

`CreateSprites/furniture_gen/make_furniture.py`:

1. **Maqueta** dibujada en Python sobre el lienzo del catálogo: cajas isométricas que llenan la
   huella exacta (misma geometría y offset que el juego), con lo principal marcado (puertas,
   lavaplatos, quemadores, tablones). Vista frontal (rot0) y trasera (rot2).
2. **PixelLab `edit-images-v2` con `edit_with_reference`**: las maquetas toman el aspecto de un
   sprite terminado (el propio mueble si su arte es bueno, o uno con la textura buscada) y conservan
   su forma. Las dos vistas van en la misma llamada, así son el mismo objeto. Con `edit_with_text`
   (sin referencia) el resultado quedaba casi igual a la maqueta, sin detalle.
3. `--build`: contorno selectivo, rot1 y rot3 en espejo, y escribe en `established_furniture/` y en
   `new_added/` (si no, el próximo sync volvería a copiar el arte viejo).

| Mueble | Referencia | Resultado |
|---|---|---|
| `kitchen_sink` | su propio rot0 | llena el 1×1, mismo escurridor, llave y detergente; vista trasera con panel liso |
| `kitchen_stove` | su propio rot0 | llena el 1×1; vista trasera con los paneles de atrás |
| `dining_table_2x2` | `closet_rot0` (vetas) | roble con tablones sobre 4 patas, llena el 2×2; simétrica (rot2 = rot0); `surface_height` 18 → 22, la altura del tablero nuevo |

Costo: ~10 generaciones por mueble con dos vistas, ~5 por uno simétrico; la tanda completa con las
pruebas, ~60.

Pendiente de tu revisión: en la vista trasera del fregadero la llave queda en el mismo borde que en
la frontal (al girarlo 180° debería quedar del lado cercano).

![Cocina del cuarto inicial con el fregadero y la cocina nuevos, y la mesa 2×2](furniture-batch1.png)

## Tanda 2: piezas de estilo (2026-10-09) ✓

Piezas chicas, sin huella que llenar: `make_furniture.py --genimg` las genera nuevas con
`generate-image-v2` (un sprite terminado como imagen de estilo, para que el píxel calce; a 48×48 o
80×64 salen 16 candidatas por llamada, a 96×112 salen 4) y `--place` las asienta con la base donde
estaba el arte anterior (o en el centro de su casilla). Son simétricas: rot2 = rot0, rot1/rot3 en
espejo.

| Mueble | Estilo de referencia | Elegida | Para |
|---|---|---|---|
| `tea_set_table` | `coffee_mug` | tetera verde con dos tazas y batidor en bandeja de bambú | Matcha |
| `vinyl_record_player` | `coffee_mug` | tocadiscos en caja de madera con la tapa abierta | Retro 90s |
| `monstera_plant_pot` | `floor_plant_sm` | monstera en maceta de terracota; ahora en el lienzo de la planta (128 × 176) | Rústico |
| `pet_dog_bed` | `plush_armchair` | cama redonda a cuadros con un hueso | Rústico |
| `yoga_mat_floor` | `simple_sofa` | colchoneta turquesa con un extremo enrollado y una botella | Matcha |

`tall_mangashelf` no se tocó (ver la corrección de arriba). La prueba de pasarla por
`edit_with_reference` con otra estantería como referencia la convirtió en una copia de esa
estantería: ese modo sirve para dar aspecto a una maqueta, no para cambiar el estilo de un mueble
terminado.

Costo: ~130 generaciones según el saldo (6 llamadas de candidatas, ~15–20 cada una, más 2 de la prueba descartada).

![Antes y después de cada pieza (rot0)](furniture-batch2.png)
