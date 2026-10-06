# Plan: Tarjeta de perfil de dos caras

Objetivo: que el avatar y el perfil real se sientan como **una sola tarjeta con dos caras**. La
cara personaje es lo que ve la otra persona antes de la fogata; en la revelación la tarjeta se
voltea a la cara real. Desde la sala, la tarjeta es también el menú para editar cada cara, y su
estilo se puede personalizar. Este plan absorbe la fase 7 del plan del editor de personaje: sacar
el perfil de `character_creator_screen.dart` y borrar ese archivo.

![Los 10 temas en la cara personaje (sprites reales)](profile-card-themes.png)

![Mismo tema, dos lenguajes: cara personaje (juego) y cara real (app de citas)](profile-card-faces.png)

## 0. Decisiones (2026-10-06)

| Tema | Decisión |
|---|---|
| Menú desde la sala | **Una tarjeta que se voltea** con selector Personaje / Real; el botón de editar sigue a la cara visible ("Editar avatar" / "Editar perfil"), más "Estilo de la tarjeta". Reemplaza el menú de dos opciones de la fase 6 del plan anterior. |
| Editar la cara real | **Sobre la tarjeta**: la tarjeta arriba (en vivo) y debajo todas las opciones, en este orden: 1. foto oficial + otras fotos + galería de pasatiempos (viajes, hobbies, mascotas); 2. Acerca de mí; 3. Quién eres y cómo es tu realidad de vida (insignias); 4. Vibes y gustos; 5. Qué sexo buscas conocer; 6. Distancia de búsqueda y filtro de edad. |
| Cara personaje | Avatar, nombre de usuario, insignia de certificación, **frase corta** (máx. 60 caracteres) y **gustos destacados**. Sin edad, comuna ni intención (se revelan después). |
| Gustos destacados | **1 a 5**, a elección. |
| Estilo | **Temas armados + color de acento** (10 temas, abajo). |
| Lenguaje de cada cara | La cara personaje se siente **juego** (pixel art, marco con adornos del tema). La cara real se siente **app de citas** (estilo Tinder): conserva los colores del tema pero cambia el lenguaje, ver abajo. |
| Quién la ve | **Cara personaje antes de la fogata** (emparejamiento, presentación de la partida, campamento); **se voltea a la real en la revelación**. |
| Filtro de edad | Nuevo. **Sin filtro por defecto**; si se ajusta, cuenta **en ambos sentidos** en el emparejamiento (cada uno debe caer en el rango del otro), como el género buscado. |

### Temas

| Tema | Base | Acentos | Ambiente |
|---|---|---|---|
| Metal / Goth | negro carbón, púrpura espectral | carmesí, plata | cuero, rock, noche |
| Rústico / Forest | verde musgo, marrón corteza | ocre, arcilla | naturaleza, cabaña |
| Pink Lady / Coquette | malva oscuro, rosa empolvado | rosa chicle, dorado champaña | dulce, glam |
| Café de Especialidad | marrón espresso, beige avena | toffee, caramelo | minimalista, libros, lofi |
| Arcade / Cyberpunk | azul noche abisal | cyan neón, magenta | gamer, tech, retro |
| Místico / Brujita | azul medianoche aterciopelado | dorado lunar, lavanda | tarot, constelaciones |
| Matcha / Zen | verde té savia | pistacho claro, amarillo suave | plantas, calma, bienestar |
| Retro 70s / Vinyl | terracota tostado | mostaza, naranja quemado | vintage, análogo, atardecer |
| Monocromo Elegante | negro azabache | gris platino, blanco puro | sobrio, moderno, formal |
| Costa / Marino | azul petróleo profundo | azul cielo, amarillo faro | mar, brisa, salitre |

### Mismo tema, dos lenguajes

| | Cara personaje (juego) | Cara real (app de citas) |
|---|---|---|
| Protagonista | el avatar en pixel art sobre un panel | la foto a sangre, en toda la tarjeta, con barras de progreso arriba |
| Marco | adornos del tema (tachas, moños, estrellas…) | sin adornos: borde fino del color de acento, esquinas más redondeadas |
| Texto | sobre el fondo plano del tema | sobre un degradado del color base del tema en la mitad inferior de la foto |
| Tipografía | lúdica | limpia y moderna; nombre y edad grandes |
| Gustos | chips llenos del acento | chips translúcidos con borde de acento |
| Avatar | protagonista | sello redondo pequeño en una esquina (la misma persona) |

Cada tema trae su marco (tachas, madera, moños, neón, estrellas, franjas, cuerda...) y sus acentos
sugeridos; el color de acento se elige entre los del tema y una paleta corta común. Los marcos se
dibujan primero en código (`CustomPainter`, como en el boceto); pasarlos a sprites de pixel art con
outline selectivo queda como mejora posterior.

## 1. Estado actual

- **Perfil**: se edita en el modo perfil de `features/avatar/screens/character_creator_screen.dart`
  (~3500 líneas), con secciones `_buildOfficialPhotoAndVerificationSection`,
  `_buildHobbyGallerySection`, `_buildBioSection`, `_buildDistanceAndLocationSection` (incluye qué
  género buscas), `_buildLifestyleBadgesSection`, `_buildTastesSection`. Desde la sala se llega por
  "Tu perfil de citas" (menú de la tarjeta) o por "Certificar ahora".
- **Revelación**: `features/revelation/screens/match_reveal_celebration_view.dart` (851 líneas)
  muestra fotos, bio e insignias, sin avatar. Se abre desde la sala y el buzón con los datos de una
  `MailboxLetter`.
- **Antes de la fogata**: el servidor manda `partnerUsername` y `partnerAvatarConfig` al iniciar la
  partida (`GameSessionService`); `dungeon_match_intro_view.dart` y el campamento los usan.
- **Backend**: el perfil vive en la tabla `users`, con columnas JSON `LONGTEXT` agregadas con
  `ALTER TABLE` al arrancar (así llegó `lifestyle`); se guarda por `POST /auth/profile`.
  `MatchmakingService` ya filtra por género buscado y distancia.

## 2. Fases

Cada fase deja la app funcionando y va en su propio commit.

### Fase 1 — Datos de la tarjeta (cliente y servidor) — hecha

- `ProfileCardStyle` (`core/models/profile_card_style.dart`): `themeId`, `accent` (null = el del
  tema), `phrase` (≤ 60 caracteres visibles, espacios colapsados) y `featuredTastes` (1-5, nunca la
  intención). `defaultFor(tastes)` sugiere el tema por los gustos (`themeHints`; empate → el que va
  antes; ninguno → Café) y destaca los 3 primeros gustos; `normalizedFor(tastes)` lo mantiene
  válido si cambian los gustos. Lectura tolerante a datos rotos.
- `UserProfile`: `cardStyle` (null hasta que la persona elige; `effectiveCardStyle` da el que se
  muestra), `seekingAgeMin` / `seekingAgeMax` (null = sin límite) con `withSeekingAgeRange`.
- **La bio ahora se guarda en el servidor.** Hasta hoy solo vivía en memoria del teléfono: se
  perdía al cerrar la app y la otra persona veía una bio genérica en la revelación.
- Backend: columnas `bio TEXT`, `card_style LONGTEXT`, `seeking_age_min INT NULL`,
  `seeking_age_max INT NULL` (patrón `ALTER TABLE` al arrancar). `POST /auth/profile` y el registro
  las aceptan: bio recortada a 180; edades limitadas a 18-99 y ordenadas; `null` borra el filtro.
  Las respuestas de login, registro y perfil las devuelven.
- `AuthService.saveProfileToBackend` envía bio, estilo y rango (el rango siempre, para poder
  borrarlo) y conserva la intención local al leer la respuesta (el servidor no la guarda).
- Tests: `profile_card_style_test.dart` (8) y 2 tests nuevos en `AuthAndRoomPersistenceTests`.

### Fase 2 — Emparejamiento por edad — hecha

- `MatchmakingService`: cada jugador debe caer en el rango de edad del otro, si lo tiene
  (`isAgeCompatible`, límites inclusivos). La edad y el rango se leen de la base al entrar a la cola
  (son preferencias guardadas, no vienen en el mensaje de conexión). Edad desconocida (0) pasa
  cualquier filtro; sin rango no se filtra.
- Tests: sin filtro empareja cualquier edad; filtro recíproco (Alice acepta a David, pero David no
  a Alice → no se emparejan; David y Bob sí); compatibles en ambos sentidos; casos de borde.

### Fase 3 — Catálogo de temas y widget `ProfileCard` — hecha

![Las 10 caras personaje y las 10 caras reales (widget real, sin fotos)](profile-card-widget.png)

- `features/profile/card/card_themes.dart`: los 10 temas (`ProfileCardTheme`: base, panel del
  avatar, acentos sugeridos, marco) y una paleta común de acentos. El color de texto se elige por
  contraste (oscuro o claro, el que se lea mejor) y el relleno de los chips toma menos acento si
  hace falta. Matcha y Retro 70s quedaron un poco más oscuros que en el boceto para que el texto
  llegue a 4,5:1.
- `card_frame_painter.dart`: los adornos de cada marco (tachas, madera, moños, neón, estrellas,
  franjas, línea fina, cuerda).
- `profile_card.dart`: `ProfileCard(profile, style?, showReal, distanceKm?)`. Se dibuja a un
  tamaño de diseño fijo (300×454) y se escala, así se ve igual en cualquier pantalla; el texto del
  sistema se limita a ×1,15 dentro de la tarjeta. Giro en Y de 650 ms.
  - Cara personaje: nombre + sello de certificación del color de acento, avatar en pixel art,
    frase, gustos destacados (título corto: `PreferenceCatalog.shortTitle`).
  - Cara real: foto a sangre con barras de progreso y toques a los lados, degradado del color
    base, nombre y edad, comuna · distancia, bio (3 líneas), hasta 3 insignias, 3 gustos en chips
    translúcidos, sello con la cabeza del avatar. Sin fotos, una silueta sobre el degradado.
- `avatar/widgets/avatar_still_image.dart`: el avatar quieto como imagen nítida, con caché.
- Tests (`profile_card_test.dart`): contraste de cada tema con cada acento; ambas caras en los 10
  temas y el giro; contenido al máximo en un teléfono chico con texto grande; sin fotos.

### Fase 4 — "Tu tarjeta": el menú desde la sala

- Pantalla `MyCardScreen`: tu tarjeta grande, selector Personaje / Real (gira la tarjeta), botón
  principal "Editar avatar" o "Editar perfil" según la cara, y "Estilo de la tarjeta".
- "Estilo de la tarjeta" (hoja inferior): tema (miniaturas de tu propia tarjeta en cada tema),
  color de acento, frase y gustos destacados (elegir 1-5 entre tus gustos), con vista previa.
- La tarjeta de perfil de la sala abre esta pantalla (adiós al menú de dos opciones); el armario
  sigue abriendo el editor de avatar directo; "Certificar ahora" abre "Editar perfil".

### Fase 5 — "Editar perfil" sobre la tarjeta

- Pantalla `EditProfileScreen`: la cara real en vivo arriba (compacta, se encoge al bajar) y debajo
  todas las secciones en el orden decidido. Borrador + Guardar + "¿Descartar cambios?", como el
  editor de avatar.
- Las secciones se **mueven** de `character_creator_screen.dart` a widgets propios en
  `features/profile/widgets/` sin cambiar su comportamiento (subida de fotos, selfie de
  certificación, insignias, gustos), salvo:
  - "Qué sexo buscas conocer" pasa a ser su propia sección (hoy está dentro de distancia);
  - la última sección suma el filtro de edad: interruptor "Filtrar por edad" (apagado por defecto)
    y un rango de 18 a 99.
- Borrar `character_creator_screen.dart` y pasar `dating_profile_preview_test.dart` a las
  pantallas nuevas.

### Fase 6 — La tarjeta frente a los demás

- El servidor agrega a los datos de la pareja que manda al iniciar la partida su `cardStyle` y si
  está certificada; la presentación de la partida y el campamento muestran su **cara personaje**.
- La revelación (`MatchRevealCelebrationView`) muestra la tarjeta de la pareja que **se voltea** de
  personaje a real; la vista ampliada de fotos se mantiene. Las cartas del buzón guardan el
  `cardStyle` para poder repetir la revelación.
- "Ver cómo me ven" en `MyCardScreen` usa la misma revelación.

### Fase 7 — Cierre

- `flutter analyze`, `flutter test`, `mvn test`.
- Capturas de las pantallas nuevas en tamaño de teléfono.
- Actualizar `CLAUDE.md` y la memoria del proyecto.

## 3. Riesgos

- **Mover el perfil sin romperlo**: la subida de fotos y la selfie de certificación hablan con el
  servidor. Mitigación: mover el código tal cual a widgets, con los tests de la pantalla vieja
  pasados a las nuevas antes de borrarla.
- **Despliegue**: el backend se despliega al hacer push a `main`. Las fases 1, 2 y 6 tocan el
  servidor; conviene publicarlas juntas, después de probarlas en local con MySQL.
- **Contraste**: con 10 temas y acentos a elección, algún texto puede quedar ilegible. Mitigación:
  el color del texto se calcula según la luminosidad del fondo, y hay un test que revisa el
  contraste mínimo de cada tema con cada acento sugerido.
- **Tamaño de la tarjeta en teléfonos pequeños**: proporción fija y textos con tope de líneas; el
  test de texto grande del sistema lo cubre.
