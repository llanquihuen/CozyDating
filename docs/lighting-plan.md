# Plan: Iluminación del cuarto (lobby)

Objetivo: prender/apagar luces, que cada luz ilumine su sector y que las paredes interiores
la bloqueen. Interruptor general + control individual de cada luz de techo. Colores fría,
cálida o libres. Objetos emisores: lámparas, chimenea, TV, lámpara de lava, ventanas.

## 1. Enfoque visual

Dos capas:

1. **Lightmap de piso** — grilla de luz de 16×16 sub-celdas (misma subgrilla que
   `blockedEdges`). Se dibuja como una malla `drawVertices` con color por vértice (degradado
   suave, sin imagen intermedia) con la misma matriz isométrica del piso y `BlendMode.multiply`.
   Los vértices se duplican por celda para que el degradado **no cruce muros**.
2. **Tinte por objeto** — muebles, avatares y muros se tiñen con la luz muestreada en su punto
   de apoyo (`ColorFilter.mode(color, BlendMode.modulate)`). Cada cara de un muro interior toma
   la luz de *su* lado.

Encima, **halos aditivos** alrededor de cada fuente. La lámpara encendida se dibuja **sin
tinte** (si no, se ve una lámpara oscura con un halo brillante).

## 2. Sectores y oclusión

- Sectores = flood-fill sobre la subgrilla cortando en cualquier muro interior.
- Cada arista de muro tiene una **transmitancia**: muro sólido 0, puerta/marco 0.5,
  vidrio 0.6, shoji 0.35. Sin muro = 1.
- La propagación es un "Dijkstra de máximo valor": valor = caída(distancia de camino) ×
  producto de transmitancias. 8-vecinos (diagonal solo si ambos caminos en L están libres),
  así la luz no dobla esquinas "gratis" ni atraviesa muros.

## 3. Influencia precalculada (clave de rendimiento)

La propagación **solo** se recalcula cuando cambia la topología: se mueve/rota/borra un muro,
se abre una puerta, se mueve o agrega una luz, cambia su radio. Cada luz guarda su
`Float32List` de influencia (256 valores). Por frame:

```
LuzCelda(x,y) = Ambiente + Σ Influencia_i(x,y) × Color_i × IntensidadDinámica_i(t)
```

- Las animaciones (flicker, tv, pulse) y los fundidos on/off (250 ms) **solo** cambian
  intensidad/color → nunca el radio.
- Buffers preasignados: cero asignaciones por frame en la composición.
- Compresión relativa al ambiente, por canal: `a + (1-a)·(1 - exp(-luz/(1-a)))`. Lineal con
  poca luz, tiende a 1 con mucha (luces superpuestas no queman a blanco) y un ambiente
  blanco queda **exactamente** en 1. (Un hombro fijo con rodilla en 0.8 oscurecía el día un 7 %.)

## 4. Ambiente

Nunca negro puro:
- **Día**: blanco puro → la iluminación es un no-op visual y todos los tintes se apagan
  (costo cero). Solo quedan halos tenues en las fuentes encendidas.
- **Atardecer**: ámbar/terracota tenue.
- **Noche**: azul marino/lavanda oscuro desaturado.

Los avatares tienen un **piso de brillo mínimo** mayor que los muebles (en una app de citas
no puede perderse a la otra persona en la oscuridad).

## 5. Tinte de sprites sin basura

- Cada componente tiene **un** `Paint _lightPaint` propio; se muta, nunca se recrea.
- El `ColorFilter` se reasigna solo si el color cuantizado (64 niveles/canal) cambió.
- El mismo paint se pasa por `overridePaint` a lo que el mueble dibuja aparte (respaldo de
  silla, ítems de superficie).
- Avatares: muestreo **bilineal** del lightmap en su posición continua (suave y sin
  retraso), **consciente de muros**: se ignoran las celdas al otro lado de un muro sólido.
  Brillo mínimo 0.55. Como son 20+ capas, se tiñen con un `saveLayer` acotado a su rect.
- Muros interiores: `saveLayer` acotado al panel + rect con `BlendMode.modulate` y un
  gradiente entre las dos sub-celdas de la cara visible (sur de un muro norte, este de un
  muro oeste). `modulate` también multiplica el alfa por 1, así vidrio y vanos de puerta
  conservan su transparencia. Solo se crea el layer si el tinte está activo (de noche).
- Muros exteriores: malla multiply en el espacio local de cada muro, con la luz de la fila
  de sub-celdas pegada a él; corte duro donde llega un tabique.
- Halos aditivos escalados por la oscuridad del ambiente: sin charco en el piso de día.
- Las ventanas no se "auto-iluminan": de noche se ven oscuras.
- El halo del punto de emisión de las **luces de techo** solo se dibuja en modo decoración
  (donde se mueven); en juego normal solo se ve la luz que proyectan. Lámparas, TV y
  chimenea sí conservan su halo.

## 6. Modelo de datos

- `RoomConfig.lighting: LightingConfig { masterOn, ambient, ceilingLights }`.
- `CeilingLightConfig { id, gridX, gridY, on, color, intensity, radius }`.
- `LightColor { preset: cold|warm|custom, argb? }` (fría ≈ 6500 K, cálida ≈ 2700 K).
- `PlacedFurnitureConfig.lightOn` (null = default del catálogo) y `lightColor` opcional.
- Catálogo: bloque `light` por ítem (`color, radius, intensity, height, anim, toggleable,
  defaultOn`), con defaults por id para los emisores que ya existen.
- Todo retrocompatible: cuartos viejos cargan con valores por defecto.

## 7. UI

- Botón bombilla: tap = interruptor general; long-press = panel (ambiente, luces de techo por
  sector, objetos emisores).
- Interruptor general: controla **solo las luces de techo**. Las corta sin tocar su estado
  individual (al encenderlo, cada una vuelve a como estaba). Lámparas, TV, chimenea,
  escritorio, lámpara de lava y ventanas nunca se ven afectados por él.
- Luces de techo como ítem colocable (`footprint: ceiling`, no bloquea) con toolbar flotante.
- Objetos emisores se prenden/apagan con tap fuera del modo decoración.

## 8. Visitas

Mensaje WS `LIGHT_CHANGED` (añadir al `switch` de `GameWebSocketHandler.java`, el relay usa
lista blanca).

## 9. Fases

1. **Modelo y persistencia** ✅ — `lighting_config.dart`, campos en `RoomConfig`,
   `PlacedFurnitureConfig`, `FurnitureCatalogItem.light`. Tests de ida y vuelta.
2. **Motor de luz** ✅ — `RoomLightingSystem` (sectores, transmitancias, influencia
   precalculada, composición por frame, muestreo bilineal consciente de muros, animaciones),
   `RoomLightingLayer` (malla del piso + halos). Conectado al juego tras un flag
   (`lightingEnabled`, apagado hasta la fase 3).
3. **Tinte de sprites** ✅ — muebles (`overridePaint`, incluido el respaldo de sillas),
   avatares y respaldo de piernas (`saveLayer` acotado), muros interiores por cara y muros
   exteriores. `lightingEnabled` ahora es `true` (de día no cambia nada).
   CPU medido: ~35 µs/frame con 8 luces animadas + 45 muestreos (test/JIT);
   re-propagación completa de 8 luces ~0.85 ms (solo al editar). **Pendiente: medir GPU en
   Android de gama baja de noche** — hasta ~20 `saveLayer` pequeños por frame (18 tabiques
   + avatares). Si pesa, plan B: tinte uniforme por muro vía `ColorFilter` en los paints.
4. **Luces de techo + UI** ✅
   - Botón "💡 Luces" (barra superior normal y compacto en Decorar/Constructor): tap =
     interruptor general, ícono ajustes (o long-press) = panel.
   - Panel: interruptor general, ambiente Día/Atardecer/Noche, luces agrupadas por cuarto
     (nombre deducido de los muebles del sector: Baño/Cocina/Dormitorio/Sala; por nombre,
     porque la zona `kitchen_bath` del catálogo mezcla cocina y baño), switch por luz y
     colores (Cálida, Fría + 6 colores) para las de techo.
   - Decorar → "Luz de techo": se agrega al centro de la cámara y queda seleccionada.
     Marcador (plafón + tallo + anillo en el piso) solo en modo edición; tap selecciona,
     hold/arrastre la mueve con snap a media casilla y la luz se recalcula en vivo.
     Toolbar flotante: encender/apagar, ajustes (color, intensidad 30–150 %, alcance
     1.5–5 casillas) y borrar.
   - Modo normal: tap sobre lámpara/TV/chimenea la prende o apaga (ventanas no).
   - Guardado: fuera de Decorar, auto-guardado con debounce de 1.2 s (local + nube); al
     entrar a Decorar se vacía el pendiente para que "Cancelar" no lo revierta. Dentro de
     Decorar va con "Listo" y "Cancelar" lo revierte todo.
5. **Objetos emisores** ✅
   - ✅ **Chimenea** (`fireplace`, 1x1, zona sala) y **lámpara de lava** (`lava_lamp`,
     superficie). Sprites dibujados en `CreateSprites/generate_light_emitters.py` (pixel
     art PIL, lienzo 128x128 / 64x64 como el resto; rot1/rot3 = espejo de rot0/rot2).
     El script escribe solo sus propios PNG en `established_furniture/` y `new_added/`.
     Registrados en el catálogo de respaldo de `FurnitureCatalogService` (igual que la TV).
   - Chimenea: `flicker`, alcance 3, `self_lit: 0.55` (brilla el fuego, no el ladrillo).
     Lámpara de lava: `pulse` rosa, alcance 1.5, totalmente auto-iluminada.
   - ✅ **Lámpara de pie** (`floor_lamp_sm`, 0.5x0.5, lienzo 128x176): mismos tonos que la
     lámpara de noche; luz cálida alcance 2.5, halo a la altura de la pantalla.
   - Nombre del escritorio gamer traducido en el JSON ("Escritorio PC Gamer RGB"), y los
     nombres nuevos agregados a `NAME_TRANSLATIONS` del sincronizador.
   - ⚠️ **No ejecutar `scripts/sync_furniture_assets.py` tal como está**: vacía
     `established_furniture/` y lo reconstruye desde `new_added/`, y hoy **73 archivos**
     (TV, cafetera, torre de gato, ventanas…) solo existen en `established_furniture/`.
   - ✅ **Escritorio PC gamer** (`gaming_pc_desk`): luz RGB (`anim: rgb`, ciclo de tono lento
     a saturación completa, sin asignaciones), alcance 2 casillas. **Sigue al GIF**: se
     enciende exactamente mientras alguien (tú o tu visita) está sentado frente a él y la
     pantalla se anima (`follows_activation: true` en el bloque `light`). No es un
     interruptor: no se toca ni aparece en el panel.
     `self_lit: 0.45`: solo brillan pantalla/LEDs, así que el mueble conserva parte de la
     sombra del cuarto (nuevo campo `self_lit` del bloque `light`, 0–1, por defecto 1).
6. **Ambiente día/noche** ✅
   - **Automático por defecto** (`LightingConfig.autoAmbient`): sigue la hora local del
     teléfono (`AmbientSchedule`): Día 07:00–18:00, Atardecer 18:00–20:30 y amanecer
     05:30–07:00, Noche el resto. Se revisa cada 30 s; el cambio se funde en 2 s.
   - Panel: 🕒 Auto / ☀️ Día / 🌇 Atardecer / 🌙 Noche. Elegir uno a mano apaga el automático;
     "Auto" lo vuelve a activar. Con Auto se muestra qué ambiente toca ahora.
   - **Luces de techo por defecto** (`LightingConfig.defaultCeilingLights`): sala, dormitorio,
     cocina (cálidas) y baño (fría), para que un cuarto abierto de noche no quede a oscuras.
     Las reciben los cuartos sin iluminación guardada; `ceilingLights` siempre se serializa
     (aunque esté vacío) para que borrarlas todas no las haga reaparecer.
   - Ventanas: se mantienen como estaban (luz blanca de día, cálida al atardecer, luna de
     noche). Afinar la dirección / cortinas queda como mejora opcional.
7. **Sincronización en visitas** ✅
   - Mensaje WS `HOME_LIGHTING` (agregado a la lista blanca de `GameWebSocketHandler`, que
     lo reenvía tal cual). Lleva una **foto completa** (`lighting` = `LightingConfig.toMap()`
     + `emitters` = {id: on} de lámparas/objetos conmutables), no un delta: un mensaje
     perdido no desincroniza nada.
   - Al entrar, la visita envía `HOME_LIGHTING` con `request: true` y el anfitrión responde
     con su foto actual (no depende de lo último que alcanzó a guardarse en el servidor).
   - Ambos pueden prender/apagar lámparas y objetos con tap; el anfitrión además tiene el
     botón 💡 (general de techo + panel). La visita no cambia ambiente ni luces de techo.
   - Aplicar una foto remota no dispara `onLightingChanged` → sin eco.
   - Solo el anfitrión guarda (debounce 1.2 s), incluidos los cambios que hizo la visita.
   - El escritorio gamer no viaja en la foto: cada lado lo calcula al ver a alguien sentado.

## Decisiones

- Con `wallsCut` (muros bajos) la luz **sigue** bloqueándose: es solo una vista.
