# Plan: Tarjeta de perfil a pantalla completa

Objetivo: que la tarjeta de perfil (la de dos caras, ver `profile-card-plan.md`) se vea
profesional a pantalla completa. La cara personaje vive en un **escenario pixel art animado** del
tema. La cara real es un **feed vertical estilo Hinge**: fotos grandes intercaladas con la bio, el
estilo de vida y los gustos. Editar la tarjeta propia se hace **sobre la misma vista que ven los
demás**, con hojas cortas que se guardan solas.

Maqueta interactiva con el sprite real y los 10 temas: [`mockups/profile_card_fullscreen.html`](mockups/profile_card_fullscreen.html).
Ábrela en un navegador: el selector de tema arriba recolorea todo, los botones ▶ reproducen las
transiciones y la sección "Editar tu tarjeta" responde a toques.

## 0. Decisiones (2026-10-08)

| Tema | Decisión |
|---|---|
| Tamaño | **Dos tamaños.** La tarjeta compacta actual (`ProfileCard`) se queda en los modales: presentación de la partida y revelación. Al tocarla se expande con un `Hero` a la **vista completa** (`ProfileCardView`). El buzón y "Tu tarjeta" abren directo la vista completa. |
| Cambiar de cara | **Selector `[Personaje \| Real]`** flotante arriba, en la misma posición en ambas caras. Tocar la tarjeta ya no la gira, y deslizar en horizontal no hace nada (queda libre). |
| Antes de la fogata | "Real" aparece **con candado**. Al tocarlo sale "Se revela en la fogata al conectar". La cara personaje no muestra edad, lugar ni bio (como hoy). |
| Cara personaje | Escenario pixel art del tema a pantalla completa, avatar en reposo animado, **la frase en un globo de diálogo pixel**, gustos destacados en **placas pixel** y el marco del tema reducido a **4 esquinas**. Debajo del escenario sigue un scroll corto con la frase y los gustos destacados. |
| Cara real | **Feed vertical estilo Hinge**: foto principal grande con nombre, edad, lugar y destacados → Sobre mí → foto → Estilo de vida → foto → Gustos por categoría → foto → botón principal. El avatar queda como sello redondo en una esquina de la primera foto. |
| Escenarios | **Uno por tema**, en capas pixel art con parallax leve y partículas propias. Misma escala de píxel que el avatar. "Mi cuarto" (el cuarto isométrico del jugador) queda como fase opcional al final. |
| Transiciones | La tarjeta nueva **llega desde un mazo** (resorte) con un **brillo** que cruza el marco. Compacta → completa con `Hero`. En la revelación, **disolución pixelada**: el pixel art se pixela hasta la foto y la foto se despixela. Todo el movimiento del pixel art es de **1 píxel entero por pasos**. Sin animaciones si el sistema pide movimiento reducido. |
| Botón principal | **Según el contexto**: "Aceptar" en la revelación, "Escribir" en el buzón, ninguno en la tarjeta propia. |
| Editar | **"Tu tarjeta" es un feed editable** en el mismo orden que lo ven los demás, con 3 partes rotuladas: *Tu personaje · lo ven antes de la fogata*, *Tu lado real · se revela en la fogata* y *Solo tú ves esto*. Arriba `[Editar \| Vista previa]` y una barra de perfil completo. |
| Cómo se edita | **Lo liviano en hojas cortas, lo pesado en pantalla completa.** Ropa, pelo y cara abren el `AvatarEditor` actual. Bio, frase, estilo de vida, destacados, escenario y búsqueda son hojas. |
| Guardado | **Automático por hoja**, con "Guardado ✓". No hay botón Guardar ni diálogo de descartar. El texto se guarda al cerrar la hoja; las opciones, al tocarlas. Si falla, se revierte y sale un aviso con "Reintentar". *(Si se prefiere el botón Guardar, solo cambia la fase 5.)* |
| Retro 70s | Ya reemplazado por **Retro 90s** (índigo, turquesa y amarillo, marco Memphis); las tarjetas guardadas con `retro70s` se leen como `retro90s`. Hecho el 2026-10-08. |
| Fuera de alcance | Estadísticas del juego en el perfil ("mazmorras juntos"): requieren backend. Pies de foto en el feed: requieren un campo nuevo por foto. Ambas quedan anotadas para después. |

## 1. Estado actual

- `features/profile/card/profile_card.dart`: `ProfileCard`, la tarjeta compacta de dos caras con
  giro 3D (650 ms). La usan `DungeonMatchIntroView` (antes de la fogata),
  `MatchRevealCelebrationView` (revelación; también el diálogo de amistad o chispa mutua del
  buzón), `MyCardScreen`, `EditProfileScreen` (vista previa) y `CardStyleSheet`.
- `features/profile/screens/my_card_screen.dart`: "Tu tarjeta": la tarjeta, el selector de cara y
  los botones para editar el avatar, el perfil y el estilo.
- `features/profile/screens/edit_profile_screen.dart` (~2400 líneas): el perfil en 6 secciones
  (fotos, Acerca de mí, realidad de vida, gustos, a quién buscas, distancia y edad), con botón
  Guardar y diálogo "¿Descartar cambios?".
- `features/profile/widgets/card_style_sheet.dart`: tema, acento, frase y destacados en una hoja.
- `features/profile/card/card_themes.dart` y `card_frame_painter.dart`: 10 temas y sus marcos.
- `AuthService` ya guarda por partes: `updateLifestyle`, `updateCardStyle`, `updateProfilePhotos`,
  `updateProfilePhoto`, `updateTastes`, `saveAvatarConfig` y `saveProfileToBackend` (bio, género
  buscado, distancia, rango de edad).
- Datos que ya existen y el feed usa: `LifestyleBadges` (12 insignias con etiqueta e ícono vía
  `activeBadges`) y `PreferenceItem.category` para agrupar los gustos.

## 2. Fases

**Estado (2026-10-08):** fases 1 y 2 hechas, en `features/profile/view/`. Diferencias con lo
planeado: el `Hero` vuela solo el avatar (no la tarjeta entera); en la revelación la vista completa
no lleva botón principal (los botones siguen en el diálogo de la revelación) y "Ver fotos" se
mantiene ahí; el selector de cara también está bajo la tarjeta compacta de la revelación.

Fase 3 hecha el mismo día con PixelLab (`generate-image-v2`, el sprite del avatar como referencia de
estilo, ~10 generaciones por escenario): `CreateSprites/card_scenes/make_scenes.py`. Diferencias: **una
sola capa por tema** (las luciérnagas, la lluvia, etc. vienen pintadas en la imagen), así que todavía
no hay parallax ni partículas animadas; quedan para la fase 4. La escala es la menor entera con la que
el escenario cubre la pantalla, y el avatar usa la misma.

Fase 4 hecha: `CardEntrance` (llegada desde el mazo con brillo) en la presentación de la partida y
en la revelación; `PixelSwap` (disolución pixelada con `toImageSync`) en la revelación, que ahora
espera 1,9 s para que la tarjeta termine de llegar; `StepBob` (avatar, globo y placas, 1 píxel por
paso) y `SceneParticles` (luciérnagas, chispas, corazones, hojas o polvo según el tema) en la vista
completa. Todo se apaga con movimiento reducido y cuando la ruta no está visible. Sin parallax: con
una sola capa por escenario no aporta.

Cada fase deja la app funcionando y con `flutter test` y `flutter analyze` sin errores nuevos.

### Fase 1 — Vista completa y cara personaje

- Nuevo `features/profile/view/profile_card_view.dart`: `ProfileCardView(profile, style,
  context)`. `ProfileViewContext` = `beforeReveal | reveal | mailbox | own`; decide el candado de
  "Real", la cara inicial y el botón principal.
- `_FaceSwitch` flotante (sacar el de `my_card_screen.dart` a `view/face_switch.dart` y
  reutilizarlo), con el candado y su aviso.
- Cara personaje a pantalla completa: por ahora sobre el `panel` del tema (el escenario llega en
  la fase 3). Avatar con `AvatarLayers` en escala entera, globo de la frase, placas de
  destacados, esquinas del marco (nuevo modo "esquinas" en `CardFramePainter`) y debajo el scroll
  corto.
- `Hero` entre la `ProfileCard` compacta y la vista completa. Puntos de entrada: tocar la tarjeta
  en `MatchRevealCelebrationView` y en `DungeonMatchIntroView`, una carta del buzón y
  `MyCardScreen`.
- Tests (`profile_card_view_test.dart`): el candado según el contexto; antes de la revelación no
  aparecen edad, lugar ni bio en ninguna parte del árbol; el botón principal según el contexto;
  cabe en un teléfono pequeño con texto grande.

**Listo cuando** desde la revelación se puede abrir la vista completa y cambiar de cara con el
selector.

### Fase 2 — Cara real como feed estilo Hinge

- `view/real_face_feed.dart`: `CustomScrollView` con la foto principal (nombre, edad, lugar,
  verificado, sello del avatar, destacados, "Desliza para ver más"). Le siguen tarjetas
  intercaladas con fotos: Sobre mí, foto, Estilo de vida (`activeBadges` en cuadrícula de 2),
  foto, Gustos por categoría (destacados primero, resaltados con el acento), las fotos restantes
  y el botón principal al pie.
- Las fotos que sobran se reparten entre los bloques; sin fotos, el feed sigue funcionando
  (reusar `_NoPhoto`). Un bloque vacío (sin bio, sin insignias) no se muestra.
- Colores del tema como hoy: fondo `base`, tarjetas con `base` aclarado, acento en chips y botón.
  Sin `BackdropFilter`; usar fondos sólidos semitransparentes.
- Tests: el orden del feed; los bloques vacíos se ocultan; los gustos quedan agrupados por la
  `category` del catálogo; el texto se lee en los 10 temas (extender la prueba de contraste de
  `profile_card_test.dart`).

**Listo cuando** la cara real de un compañero se recorre entera con el pulgar.

### Fase 3 — Escenarios pixel art por tema

- Arte en `CreateSprites/card_scenes/<tema>/`, en 3 capas por tema: `back.png`, `mid.png` y
  `front.png` (con transparencia). La resolución base es la del lienzo de la maqueta (150 × 310
  px de escena para un avatar de 64 × 128), dibujada a la **misma escala de píxel que el avatar**.
  Correr `convert_selout.py --scenery` y copiar a `frontend/assets/images/card_scenes/`. Declarar
  en `pubspec.yaml`.
- Referencia de contenido: los 10 escenarios de la maqueta (bosque nocturno, café con lluvia,
  ciudad con grilla neón, luna con velas, atardecer con faro, ventanales góticos, cuarto coquette,
  shoji con bambú, cuarto noventero con tele de tubo, estudio con foco).
- `card/card_scene.dart`: datos por tema (capas, factor de parallax por capa y tipo de
  partículas). `CardSceneView` dibuja las capas con `FilterQuality.none`, en escala entera, y un
  `CustomPainter` de partículas a ~12 fps (luciérnagas, lluvia, corazones, hojas, polvo…).
  Parallax leve al arrastrar; el giroscopio queda para después (evita una dependencia nueva).
- Si falta la imagen de un tema, se usa el `panel` plano (como hoy). Cargar con `rootBundle` y
  precargar; nunca con `Flame.images` (los tests se cuelgan).
- Miniaturas de escenario para la hoja de estilo: una imagen fija de la capa de fondo.
- Tests: cada tema tiene escenario o cae al panel; con movimiento reducido no hay ticker activo.

**Listo cuando** los 10 temas tienen escenario en el teléfono y el avatar se ve como parte de la
escena.

### Fase 4 — Transiciones

- **Llegada desde el mazo:** en `DungeonMatchIntroView` y `MatchRevealCelebrationView`, la
  tarjeta compacta entra con resorte (escala 0,82 → 1, giro −10° → 0°, ~800 ms) y luego un brillo
  cruza el marco una sola vez (`ShaderMask` con un degradado que se desplaza).
- **Revelación pixelada:** reemplaza el giro 3D cuando la tarjeta pasa de personaje a real en la
  revelación. Se captura la cara personaje (`RepaintBoundary.toImage`) y se dibuja a resolución
  decreciente (75, 38, 19, 10 columnas) con `FilterQuality.none`. Luego la foto principal a
  resolución creciente (10 → 150) y un fundido final. Unos 110 ms por paso.
  `pixel_reveal.dart`.
- Fuera de la revelación, el selector de cara usa un fundido corto (sin giro a pantalla completa).
- Animaciones de reposo por pasos de 1 píxel: respiración del avatar, globo y placas.
- Todo se desactiva con `MediaQuery.disableAnimations`.
- Tests: la revelación termina en la cara real; con movimiento reducido el cambio es inmediato.

**Listo cuando** la revelación en el teléfono se siente como un momento, no como un cambio de
pantalla.

### Fase 5 — Editar "Tu tarjeta"

- `MyCardScreen` pasa a ser el feed editable (`own_card_editor.dart`), con `[Editar | Vista
  previa]` arriba. "Vista previa" muestra exactamente `ProfileCardView` en contexto `own`. También
  lleva la barra de perfil completo y lo que falta ("Agrega 1 foto").
- **Tu personaje:** el escenario con el avatar y el botón "Vestir a mi personaje", que abre
  `AvatarEditorScreen` con un `Hero` del avatar. Al volver, la tarjeta se actualiza. Tres accesos
  rápidos: Escenario y color, Frase y Destacados (partir `CardStyleSheet` en tres hojas). Tocar
  el globo también edita la frase.
- **Tu lado real:** cuadrícula de fotos con ✕, espacios "+" y reordenar manteniendo presionado
  (`updateProfilePhotos`). La foto principal y su verificación reutilizan los diálogos de
  `EditProfileScreen`. Luego las tarjetas Sobre mí (hoja de texto: contador de 300 e ideas para
  empezar), Estilo de vida (hoja con todas las opciones a la vista; un toque elige y otro borra →
  `updateLifestyle`) y Gustos (el selector actual).
- **Solo tú ves esto:** a quién buscas, rango de edad y distancia, cada uno en su hoja →
  `saveProfileToBackend`.
- **Guardado automático:** nuevo `ProfileSaveQueue` en `core/services/`, que hace los guardados
  de a uno (evita que dos respuestas se pisen). Guardado optimista: se actualiza la vista, se
  envía y, si falla, se revierte con un aviso y "Reintentar". El texto se guarda al cerrar la
  hoja.
- Ojo: `saveProfileToBackend` solo envía `lifestyle` si queda alguna insignia, así que borrar la
  última no llegaría al servidor. Por eso el estilo de vida va siempre por `updateLifestyle`.
- Tests: cada hoja guarda con el método correcto; un error revierte; "Vista previa" esconde todos
  los controles; el estilo de vida se puede vaciar.

**Listo cuando** se puede cambiar ropa, bio, fumar o beber, fotos y búsqueda sin pasar por un
formulario largo ni un botón Guardar.

### Fase 6 — Retirar `EditProfileScreen`

- Mover lo reutilizable a `features/profile/widgets/` (selector de fotos, certificación con
  selfie, selector de gustos, controles de búsqueda) y borrar la pantalla.
- Revisar `fun_registration_wizard.dart`: si usa piezas de esa pantalla, que use los widgets
  movidos. Ojo: el archivo tiene cambios sin commitear al escribir este plan.
- Ajustar `edit_profile_screen_test.dart` → pruebas de las hojas. Actualizar `CLAUDE.md`
  (sección Profile card).

### Fase 7 (opcional) — "Mi cuarto" como escenario

- Opción extra en la hoja de escenario: el cuarto isométrico del jugador detrás del avatar.
- Investigar primero si la configuración del cuarto del compañero llega al cliente (hoy viaja con
  la visita a casa) o si conviene guardar una captura al salir del lobby. Decidir antes de
  dibujar nada.

## 3. Riesgos

- **Escala de píxel:** si el escenario y el avatar no comparten escala entera, se ve como un
  recorte pegado. Fijar la escala en un solo lugar (`CardSceneView`) y probarla en 2 o 3 tamaños
  de teléfono.
- **Rendimiento:** 3 capas + partículas + avatar animado en teléfonos de gama baja. Ticker a 12
  fps, sin desenfoques, y pausar todo cuando la vista no está visible.
- **Contraste:** el globo y las placas van sobre escenarios claros (Coquette, Matcha, Retro 90s).
  Por eso llevan fondo propio y no dependen del color del escenario; la prueba de contraste debe
  cubrirlos.
- **Gestos:** el feed vertical y el arrastre para el parallax pueden competir; el parallax solo
  responde a arrastres horizontales.
