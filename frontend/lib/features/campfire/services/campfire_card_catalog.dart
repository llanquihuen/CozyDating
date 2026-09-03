import 'dart:math';
import '../../../core/models/preference_tags.dart';
import '../../../core/models/user_profile.dart';
import '../models/campfire_models.dart';

class CampfireCardCatalog {
  // Helper para obtener el título y emoji amigable de una etiqueta
  static String getTagTitle(String tagId) {
    for (final category in PreferenceCatalog.categories) {
      for (final item in category.items) {
        if (item.id == tagId) {
          return '${item.title} ${item.emoji}';
        }
      }
    }
    return tagId;
  }

  // =========================================================================
  // 1. Preguntas de Pasión Compartida (Shared Passion) - Stock Completo
  // =========================================================================
  static final Map<String, List<CampfireCard>> sharedTasteCards = {
    // --- VIDEOJUEGOS ---
    'game_coop': [
      const CampfireCard(
        id: 'shared_coop_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🎮 PASIÓN COMPARTIDA: VIDEOJUEGOS CO-OP',
        question: 'En una partida cooperativa en pareja: ¿Cuál suele ser tu rol natural?',
        options: [
          CampfireOption(id: 'a', text: 'El estratega paciente que planea cada paso', emoji: '📋'),
          CampfireOption(id: 'b', text: 'El que se lanza de cabeza al caos', emoji: '💥'),
          CampfireOption(id: 'c', text: 'El que se distrae recogiendo todo el botín', emoji: '🎒'),
          CampfireOption(id: 'd', text: 'El soporte salvador que revive al otro al límite', emoji: '🛡️'),
        ],
      ),
      const CampfireCard(
        id: 'shared_coop_2',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🎮 PASIÓN COMPARTIDA: VIDEOJUEGOS CO-OP',
        question: 'Cuando se quedan atascados en un nivel cooperativo muy difícil: ¿Qué pasa?',
        options: [
          CampfireOption(id: 'a', text: 'Nos entra la risa tonta por los errores absurdos', emoji: '🤣'),
          CampfireOption(id: 'b', text: 'Nos concentramos en silencio hasta pasarlo perfecto', emoji: '🤫'),
          CampfireOption(id: 'c', text: 'Uno busca la guía en secreto y se hace el genio', emoji: '🕵️'),
          CampfireOption(id: 'd', text: 'Pausa para snacks y volvemos con energía renovada', emoji: '🍕'),
        ],
      ),
    ],

    'game_cozy': [
      const CampfireCard(
        id: 'shared_cozy_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🌾 PASIÓN COMPARTIDA: MUNDO COZY',
        question: 'Si tuvieran una granja juntos en Stardew Valley o Animal Crossing: ¿Qué tarea te pides primero?',
        options: [
          CampfireOption(id: 'a', text: 'Cuidar a los animalitos y darles cariño', emoji: '🐾'),
          CampfireOption(id: 'b', text: 'Decorar la casa y organizar los cofres con colores', emoji: '🏡'),
          CampfireOption(id: 'c', text: 'Ir a las minas a luchar y buscar gemas', emoji: '⛏️'),
          CampfireOption(id: 'd', text: 'Pescar todo el día junto al muelle', emoji: '🎣'),
        ],
      ),
      const CampfireCard(
        id: 'shared_cozy_2',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🌾 PASIÓN COMPARTIDA: JUEGOS TRANQUILOS',
        question: '¿Qué es lo que más paz te da de los juegos cozy?',
        options: [
          CampfireOption(id: 'a', text: 'La banda sonora acústica con lluvia o naturaleza', emoji: '🌧️'),
          CampfireOption(id: 'b', text: 'Ver cómo crece algo bonito poco a poco sin presión', emoji: '🌱'),
          CampfireOption(id: 'c', text: 'Personalizar cada rincón a mi gusto estético', emoji: '🎨'),
          CampfireOption(id: 'd', text: 'Compartir la calma con alguien querido al lado', emoji: '☕'),
        ],
      ),
    ],

    'game_roguelike': [
      const CampfireCard(
        id: 'shared_rogue_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '⚔️ PASIÓN COMPARTIDA: ROGUELIKES & ACCIÓN',
        question: 'En un Roguelike desafiante (Hades, Dead Cells): ¿Qué estilo de juego te define?',
        options: [
          CampfireOption(id: 'a', text: 'Build de daño masivo aunque me quede con 1 HP', emoji: '🔥'),
          CampfireOption(id: 'b', text: 'Súper defensivo, esquivando y con paciencia de monje', emoji: '🛡️'),
          CampfireOption(id: 'c', text: 'Elegir siempre los poderes más raros y caóticos', emoji: '🎲'),
          CampfireOption(id: 'd', text: 'El más veloz: entrar, golpear y salir volando', emoji: '⚡'),
        ],
      ),
    ],

    'game_rpg': [
      const CampfireCard(
        id: 'shared_rpg_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '📜 PASIÓN COMPARTIDA: HISTORIAS RPG',
        question: 'Al jugar un gran RPG con decisiones (Baldur’s Gate, Final Fantasy): ¿Qué camino tomas?',
        options: [
          CampfireOption(id: 'a', text: 'El héroe compasivo que intenta salvar a todo el mundo', emoji: '🕊️'),
          CampfireOption(id: 'b', text: 'El pícaro pragmático que negocia hasta el último centavo', emoji: '💰'),
          CampfireOption(id: 'c', text: 'El que hace todas las misiones secundarias antes de la historia', emoji: '🗺️'),
          CampfireOption(id: 'd', text: 'Elegir opciones sarcásticas solo para ver qué responden', emoji: '😏'),
        ],
      ),
    ],

    'game_souls': [
      const CampfireCard(
        id: 'shared_souls_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🛡️ PASIÓN COMPARTIDA: SOULSLIKES & RETOS',
        question: 'Cuando un jefe te derrota 20 veces seguidas: ¿Cuál es tu reacción?',
        options: [
          CampfireOption(id: 'a', text: '"Una vez más y me sale": la perseverancia me alimenta', emoji: '😤'),
          CampfireOption(id: 'b', text: 'Pausa táctica de 10 minutos para respirar y analizar patrones', emoji: '🧘'),
          CampfireOption(id: 'c', text: 'Probar una estrategia completamente absurda que termina funcionando', emoji: '🧠'),
          CampfireOption(id: 'd', text: 'Celebrar a los gritos cuando por fin cae el jefe', emoji: '🏆'),
        ],
      ),
    ],

    'game_tabletop': [
      const CampfireCard(
        id: 'shared_tabletop_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🎲 PASIÓN COMPARTIDA: JUEGOS DE MESA & D&D',
        question: 'En una noche de juegos de mesa con amigos o rol: ¿Qué papel te divierte más?',
        options: [
          CampfireOption(id: 'a', text: 'El estratega que piensa 4 jugadas adelante', emoji: '♟️'),
          CampfireOption(id: 'b', text: 'El que inventa una historia dramática para su personaje', emoji: '🎭'),
          CampfireOption(id: 'c', text: 'El que trae los mejores snacks y anima el ambiente', emoji: '🍿'),
          CampfireOption(id: 'd', text: 'El maestro del engaño y las alianzas secretas', emoji: '🃏'),
        ],
      ),
    ],

    'game_mmo': [
      const CampfireCard(
        id: 'shared_mmo_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🌐 PASIÓN COMPARTIDA: MMORPGS & AVENTURA ONLINE',
        question: 'En un mundo masivo online: ¿Qué actividad disfrutas más compartir?',
        options: [
          CampfireOption(id: 'a', text: 'Explorar paisajes remotos y sacar fotos juntos', emoji: '🌄'),
          CampfireOption(id: 'b', text: 'Hacer mazmorras y bosses difíciles en equipo', emoji: '⚔️'),
          CampfireOption(id: 'c', text: 'Pasar horas consiguiendo cosméticos y monturas raras', emoji: '✨'),
          CampfireOption(id: 'd', text: 'Pescar o charlar en la taberna principal del servidor', emoji: '🍺'),
        ],
      ),
    ],

    'game_strategy': [
      const CampfireCard(
        id: 'shared_strategy_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🏰 PASIÓN COMPARTIDA: ESTRATEGIA & GESTIÓN',
        question: 'Al construir una civilización o ciudad: ¿Cuál es tu prioridad número uno?',
        options: [
          CampfireOption(id: 'a', text: 'Que sea hermosa estéticamente con parques y armonía', emoji: '🌳'),
          CampfireOption(id: 'b', text: 'Economía imparable y máxima eficiencia tecnológica', emoji: '⚙️'),
          CampfireOption(id: 'c', text: 'Defensas impenetrables contra cualquier sorpresa', emoji: '🏰'),
          CampfireOption(id: 'd', text: 'Expandirme rápido por todo el mapa', emoji: '🗺️'),
        ],
      ),
    ],

    // --- TECNOLOGÍA & GEEK ---
    'tech_pc_gamer': [
      const CampfireCard(
        id: 'shared_pc_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🖥️ PASIÓN COMPARTIDA: SETUP & PC GAMER',
        question: '¿Qué es lo más sagrado en tu rincón de juego o trabajo?',
        options: [
          CampfireOption(id: 'a', text: 'La iluminación cálida/RGB que da la atmósfera perfecta', emoji: '💡'),
          CampfireOption(id: 'b', text: 'Una silla comodísima donde el tiempo no pasa', emoji: '🪑'),
          CampfireOption(id: 'c', text: 'Buen audio o auriculares que te aíslen del mundo', emoji: '🎧'),
          CampfireOption(id: 'd', text: 'El orden de cables y los coleccionables sobre la mesa', emoji: '🧸'),
        ],
      ),
    ],

    'tech_programming': [
      const CampfireCard(
        id: 'shared_code_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🧑‍💻 PASIÓN COMPARTIDA: PROGRAMACIÓN & CREACIÓN',
        question: 'La sensación de resolver un bug misterioso a la madrugada se compara con:',
        options: [
          CampfireOption(id: 'a', text: 'Ganarle al boss final de un juego difícil', emoji: '🏆'),
          CampfireOption(id: 'b', text: 'Magia pura: ver cobrar vida a una idea de la nada', emoji: '✨'),
          CampfireOption(id: 'c', text: 'Paz mental infinita para ir a dormir feliz', emoji: '😴'),
          CampfireOption(id: 'd', text: 'Ganas de empezar otro proyecto nuevo de inmediato', emoji: '🚀'),
        ],
      ),
    ],

    'tech_retro': [
      const CampfireCard(
        id: 'shared_retro_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🕹️ PASIÓN COMPARTIDA: CONSOLAS & RETRO',
        question: '¿Qué época o sonido retro te transporta instantáneamente a la infancia?',
        options: [
          CampfireOption(id: 'a', text: 'El sonido de inicio de la PS1 / Game Boy', emoji: '🔔'),
          CampfireOption(id: 'b', text: 'El pixel art colorido de la era 16-bits (SNES)', emoji: '👾'),
          CampfireOption(id: 'c', text: 'Jugar en pantalla dividida en el sillón con alguien', emoji: '📺'),
          CampfireOption(id: 'd', text: 'El manual con ilustraciones que venía dentro de la caja', emoji: '📖'),
        ],
      ),
    ],

    'tech_gadgets': [
      const CampfireCard(
        id: 'shared_gadgets_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '⚙️ PASIÓN COMPARTIDA: GADGETS & DOMÓTICA',
        question: 'Si pudieras automatizar una sola cosa mágica en tu hogar: ¿Cuál sería?',
        options: [
          CampfireOption(id: 'a', text: 'Que el café recién hecho te espere listo al despertar', emoji: '☕'),
          CampfireOption(id: 'b', text: 'Luces que cambien solas con el clima y la música', emoji: '🌈'),
          CampfireOption(id: 'c', text: 'Que la cama esté siempre a la temperatura perfecta', emoji: '🛏️'),
          CampfireOption(id: 'd', text: 'Limpieza automática silenciosa mientras no estás', emoji: '🤖'),
        ],
      ),
    ],

    // --- MÚSICA & AUDIO ---
    'music_lofi': [
      const CampfireCard(
        id: 'shared_lofi_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🎧 PASIÓN COMPARTIDA: LO-FI & CHILL VIBES',
        question: 'Tarde de lluvia con música suave de fondo: ¿Qué no puede faltar en la escena?',
        options: [
          CampfireOption(id: 'a', text: 'Manta calentita y un buen libro o cómic', emoji: '📖'),
          CampfireOption(id: 'b', text: 'Té o chocolate caliente y mirar las gotas caer', emoji: '🍫'),
          CampfireOption(id: 'c', text: 'Una charla pausada sobre la vida sin prisas', emoji: '💬'),
          CampfireOption(id: 'd', text: 'Dibujar, escribir o programar en paz', emoji: '✏️'),
        ],
      ),
    ],

    'music_ost': [
      const CampfireCard(
        id: 'shared_ost_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🎼 PASIÓN COMPARTIDA: SOUNDTRACKS ÉPICOS',
        question: '¿Qué tipo de banda sonora te inspira más?',
        options: [
          CampfireOption(id: 'a', text: 'Melodías de piano y cuerdas nostálgicas', emoji: '🎹'),
          CampfireOption(id: 'b', text: 'Coros y orquestas épicas de aventura', emoji: '🎻'),
          CampfireOption(id: 'c', text: 'Sintetizadores espaciales y futuristas', emoji: '🌌'),
          CampfireOption(id: 'd', text: 'Guitarras acústicas de fogata y naturaleza', emoji: '🎸'),
        ],
      ),
    ],

    'music_synthwave': [
      const CampfireCard(
        id: 'shared_synth_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🌆 PASIÓN COMPARTIDA: SYNTHWAVE & RETRO 80S',
        question: 'Paseo nocturno en auto con luces de neón: ¿Hacia dónde conducirían?',
        options: [
          CampfireOption(id: 'a', text: 'Hacia un mirador alto para ver la ciudad brillante', emoji: '🌃'),
          CampfireOption(id: 'b', text: 'Hacia la costa para ver el reflejo de la luna en el mar', emoji: '🌊'),
          CampfireOption(id: 'c', text: 'Por autopistas vacías sin destino fijo escuchando música', emoji: '🚗'),
          CampfireOption(id: 'd', text: 'A un café nocturno que abre las 24 horas', emoji: '☕'),
        ],
      ),
    ],

    'music_indie': [
      const CampfireCard(
        id: 'shared_indie_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🎸 PASIÓN COMPARTIDA: INDIE ROCK & POP',
        question: '¿Cuál es tu momento favorito para escuchar música indie?',
        options: [
          CampfireOption(id: 'a', text: 'Caminando con auriculares al atardecer', emoji: '🌅'),
          CampfireOption(id: 'b', text: 'Cocinando algo rico en casa con calma', emoji: '🍳'),
          CampfireOption(id: 'c', text: 'En viajes largos mirando por la ventana', emoji: '🚌'),
          CampfireOption(id: 'd', text: 'En un concierto íntimo en un local pequeño', emoji: '🎤'),
        ],
      ),
    ],

    'music_jazz': [
      const CampfireCard(
        id: 'shared_jazz_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🎷 PASIÓN COMPARTIDA: JAZZ & VINILOS',
        question: 'Una copa o infusión, vinilo sonando y luces tenues: ¿De qué les gustaría hablar?',
        options: [
          CampfireOption(id: 'a', text: 'De recuerdos bonitos y momentos que marcaron la vida', emoji: '🕰️'),
          CampfireOption(id: 'b', text: 'De sueños y proyectos locos que nos gustaría cumplir', emoji: '✨'),
          CampfireOption(id: 'c', text: 'De arte, películas y curiosidades del mundo', emoji: '🎨'),
          CampfireOption(id: 'd', text: 'Simplemente disfrutar de la música en silencio cómodo', emoji: '🎶'),
        ],
      ),
    ],

    // --- CINE & SERIES ---
    'cinema_ghibli': [
      const CampfireCard(
        id: 'shared_ghibli_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🍃 PASIÓN COMPARTIDA: UNIVERSO GHIBLI',
        question: 'Si pudieran mudarse a vivir dentro de una película mágica por una semana: ¿A dónde irían?',
        options: [
          CampfireOption(id: 'a', text: 'A una panadería en un pueblo costero con mar', emoji: '🌊'),
          CampfireOption(id: 'b', text: 'A un castillo mágico ambulante en las nubes', emoji: '☁️'),
          CampfireOption(id: 'c', text: 'A una cabaña oculta en un bosque encantado', emoji: '🌲'),
          CampfireOption(id: 'd', text: 'A una cafetería con tren que viaja sobre el agua', emoji: '🚂'),
        ],
      ),
      const CampfireCard(
        id: 'shared_ghibli_2',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🍃 PASIÓN COMPARTIDA: ANIMACIÓN & DETALLES',
        question: '¿Qué comida animada de Studio Ghibli se te hace más irresistible?',
        options: [
          CampfireOption(id: 'a', text: 'El ramen humeante con huevo y jamón de Ponyo', emoji: '🍜'),
          CampfireOption(id: 'b', text: 'El desayuno de tocino y huevos del Castillo Vagabundo', emoji: '🍳'),
          CampfireOption(id: 'c', text: 'El pan recién horneado de Kiki', emoji: '🥐'),
          CampfireOption(id: 'd', text: 'Los pastelitos y tés de Chihiro', emoji: '🍰'),
        ],
      ),
    ],

    'cinema_scifi': [
      const CampfireCard(
        id: 'shared_scifi_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🚀 PASIÓN COMPARTIDA: CIENCIA FICCIÓN & CYBERPUNK',
        question: 'Si tuvieran una nave espacial para dos personas: ¿Cuál sería el primer viaje?',
        options: [
          CampfireOption(id: 'a', text: 'Ver los anillos de Saturno de cerca con música de fondo', emoji: '🪐'),
          CampfireOption(id: 'b', text: 'Buscar una estación espacial con mercado intergaláctico', emoji: '🛸'),
          CampfireOption(id: 'c', text: 'Aterrizar en un planeta con selvas bioluminiscentes', emoji: '🌌'),
          CampfireOption(id: 'd', text: 'Volar a la velocidad de la luz y ver pasar las estrellas', emoji: '✨'),
        ],
      ),
    ],

    'cinema_fantasy': [
      const CampfireCard(
        id: 'shared_fantasy_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🐉 PASIÓN COMPARTIDA: FANTASÍA ÉPICA',
        question: 'En un mundo de fantasía (El Señor de los Anillos, etc.): ¿Dónde preferirías vivir?',
        options: [
          CampfireOption(id: 'a', text: 'Una casa en la colina de la Comarca comiendo rico', emoji: '🏡'),
          CampfireOption(id: 'b', text: 'Un reino élfico oculto entre cascadas y árboles milenarios', emoji: '🧝'),
          CampfireOption(id: 'c', text: 'Una ciudad fortaleza en las montañas nevadas', emoji: '🏔️'),
          CampfireOption(id: 'd', text: 'Una torre de magos llena de libros y pociones', emoji: '🧙'),
        ],
      ),
    ],

    'cinema_horror': [
      const CampfireCard(
        id: 'shared_horror_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '👻 PASIÓN COMPARTIDA: TERROR & MISTERIO',
        question: 'Viendo una película de miedo juntos con luces apagadas: ¿Cómo reaccionas?',
        options: [
          CampfireOption(id: 'a', text: 'Me tapo con la manta pero miro entre los dedos', emoji: '🫣'),
          CampfireOption(id: 'b', text: 'Analizo al asesino y predigo quién sobrevive primero', emoji: '🧠'),
          CampfireOption(id: 'c', text: 'Finjo valentía y salto del susto con el jump scare', emoji: '😱'),
          CampfireOption(id: 'd', text: 'Me río de los clichés y me como todo el pop corn', emoji: '🍿'),
        ],
      ),
    ],

    'cinema_sitcoms': [
      const CampfireCard(
        id: 'shared_sitcom_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🍿 PASIÓN COMPARTIDA: COMEDIAS CONFORT',
        question: 'Tu serie de comedia de confort (The Office, Friends, B99) te salva cuando:',
        options: [
          CampfireOption(id: 'a', text: 'Tuve un día pesado y necesito apagar la cabeza', emoji: '💆'),
          CampfireOption(id: 'b', text: 'Estoy almorzando y necesito compañía que me haga reír', emoji: '🥪'),
          CampfireOption(id: 'c', text: 'Para ponerla de fondo mientras hago cosas en casa', emoji: '🧹'),
          CampfireOption(id: 'd', text: 'Para citar chistes y memes con la persona indicada', emoji: '😂'),
        ],
      ),
    ],

    // --- ANIME & MANGA ---
    'anime_romance': [
      const CampfireCard(
        id: 'shared_romcom_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '💖 PASIÓN COMPARTIDA: ROMANCE & SLICE OF LIFE',
        question: 'En los animes románticos: ¿Qué tropo o momento te da más ternura?',
        options: [
          CampfireOption(id: 'a', text: 'Compartir el paraguas bajo la lluvia camino a casa', emoji: '☂️'),
          CampfireOption(id: 'b', text: 'Caminar juntos en el festival de fuegos artificiales', emoji: '🎆'),
          CampfireOption(id: 'c', text: 'Los celos tiernos o sonrojos cuando se rozan las manos', emoji: '😳'),
          CampfireOption(id: 'd', text: 'Prepararle un bento casero con mucho cariño', emoji: '🍱'),
        ],
      ),
    ],

    'anime_shonen': [
      const CampfireCard(
        id: 'shared_shonen_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🔥 PASIÓN COMPARTIDA: AVENTURAS SHONEN',
        question: 'Si tuvieras un poder especial de anime: ¿Cuál elegirías?',
        options: [
          CampfireOption(id: 'a', text: 'Teletransportación instantánea a cualquier lugar', emoji: '🌀'),
          CampfireOption(id: 'b', text: 'Poder de curación y restaurar energía a los demás', emoji: '✨'),
          CampfireOption(id: 'c', text: 'Control del fuego o la electricidad', emoji: '⚡'),
          CampfireOption(id: 'd', text: 'Poder volar libremente por el cielo', emoji: '🦅'),
        ],
      ),
    ],

    'anime_isekai': [
      const CampfireCard(
        id: 'shared_isekai_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '✨ PASIÓN COMPARTIDA: MUNDOS ISEKAI',
        question: 'Si los transportaran a otro mundo de fantasía: ¿Qué profesión elegirías?',
        options: [
          CampfireOption(id: 'a', text: 'Dueño de una taberna acogedora donde van los héroes', emoji: '🍺'),
          CampfireOption(id: 'b', text: 'Alquimista o boticario en una cabaña tranquila', emoji: '🧪'),
          CampfireOption(id: 'c', text: 'Aventurero errante que explora ruinas antiguas', emoji: '🗺️'),
          CampfireOption(id: 'd', text: 'Criador de monstruos adorables y criaturas mágicas', emoji: '🐾'),
        ],
      ),
    ],

    // --- ESTILO DE VIDA & HOBBIES ---
    'life_coffee_tea': [
      const CampfireCard(
        id: 'shared_coffee_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '☕ PASIÓN COMPARTIDA: CULTURA DEL CAFÉ & TÉ',
        question: '¿Cómo sería su tarde perfecta de café y conversación?',
        options: [
          CampfireOption(id: 'a', text: 'Buscar una cafetería de especialidad escondida con buena música', emoji: '🎷'),
          CampfireOption(id: 'b', text: 'Preparar café en casa con rica pastelería y charlar horas', emoji: '🥐'),
          CampfireOption(id: 'c', text: 'Pedir café para llevar y caminar por un parque arbolado', emoji: '🌿'),
          CampfireOption(id: 'd', text: 'Café, juegos de mesa y risas compartidas', emoji: '🎲'),
        ],
      ),
    ],

    'life_plants': [
      const CampfireCard(
        id: 'shared_plants_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🪴 PASIÓN COMPARTIDA: AMOR POR LAS PLANTAS',
        question: '¿Cómo imaginas tu espacio verde ideal en casa?',
        options: [
          CampfireOption(id: 'a', text: 'Una selva urbana llena de monsteras y helechos colgantes', emoji: '🌿'),
          CampfireOption(id: 'b', text: 'Un huerto pequeño con hierbas aromáticas para cocinar', emoji: '🌱'),
          CampfireOption(id: 'c', text: 'Colección de suculentas y cactus ordenados con cariño', emoji: '🌵'),
          CampfireOption(id: 'd', text: 'Plantas con flores coloridas que atraigan abejas y colibríes', emoji: '🌸'),
        ],
      ),
    ],

    'life_photography': [
      const CampfireCard(
        id: 'shared_photo_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '📷 PASIÓN COMPARTIDA: FOTOGRAFÍA & MOMENTOS',
        question: 'Al viajar o pasear: ¿Qué es lo que más te gusta capturar?',
        options: [
          CampfireOption(id: 'a', text: 'Risas y momentos espontáneos que no se posan', emoji: '📸'),
          CampfireOption(id: 'b', text: 'Paisajes naturales y colores mágicos del atardecer', emoji: '🌄'),
          CampfireOption(id: 'c', text: 'Detalles arquitectónicos y texturas de la ciudad', emoji: '🏛️'),
          CampfireOption(id: 'd', text: 'Platos de comida deliciosa y mesas compartidas', emoji: '🍽️'),
        ],
      ),
    ],

    'life_cooking': [
      const CampfireCard(
        id: 'shared_cook_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🍰 PASIÓN COMPARTIDA: COCINA & REPOSTERÍA',
        question: 'Cocinando juntos una cena especial en casa: ¿Quién hace qué?',
        options: [
          CampfireOption(id: 'a', text: 'Uno sigue la receta al pie de la letra y el otro improvisa sabores', emoji: '👨‍🍳'),
          CampfireOption(id: 'b', text: 'Cocinamos pastas o pizzas caseras desde cero', emoji: '🍕'),
          CampfireOption(id: 'c', text: 'Uno cocina el plato fuerte y el otro prepara el postre', emoji: '🍰'),
          CampfireOption(id: 'd', text: 'Poner música, picar algo mientras cocinamos y bailar', emoji: '💃'),
        ],
      ),
    ],

    'life_books': [
      const CampfireCard(
        id: 'shared_books_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '📚 PASIÓN COMPARTIDA: LECTURA & HISTORIAS',
        question: '¿Cuál es el ritual de lectura que más disfrutas?',
        options: [
          CampfireOption(id: 'a', text: 'Sillón cómodo, té caliente y desconectar el celular', emoji: '🛋️'),
          CampfireOption(id: 'b', text: 'Leer en el parque o bajo la sombra de un árbol', emoji: '🌳'),
          CampfireOption(id: 'c', text: 'Visitar librerías antiguas oliendo el papel nuevo y viejo', emoji: '📖'),
          CampfireOption(id: 'd', text: 'Comentar teorías locas sobre los personajes con alguien', emoji: '💬'),
        ],
      ),
    ],

    // --- MASCOTAS ---
    'pet_cat': [
      const CampfireCard(
        id: 'shared_cats_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🐱 PASIÓN COMPARTIDA: COMPAÑEROS FELINOS',
        question: '¿Qué es lo que más te conmueve de la energía de los gatitos?',
        options: [
          CampfireOption(id: 'a', text: 'Su ronroneo sanador cuando se acurrucan encima', emoji: '💤'),
          CampfireOption(id: 'b', text: 'Sus ataques repentinos de locura a las 3 AM', emoji: '😹'),
          CampfireOption(id: 'c', text: 'Que ganarse su confianza se siente como un trofeo', emoji: '🏆'),
          CampfireOption(id: 'd', text: 'Su elegancia e independencia tranquila', emoji: '👑'),
        ],
      ),
    ],

    'pet_dog': [
      const CampfireCard(
        id: 'shared_dogs_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🐶 PASIÓN COMPARTIDA: COMPAÑEROS PERRUNOS',
        question: '¿Cuál es el mejor momento del día con un perrito?',
        options: [
          CampfireOption(id: 'a', text: 'El saludo emocionado cuando abres la puerta al llegar', emoji: '🐾'),
          CampfireOption(id: 'b', text: 'Caminar por el parque viéndolo correr feliz', emoji: '🎾'),
          CampfireOption(id: 'c', text: 'Cuando apoya su cabecita en tus piernas pidiendo cariño', emoji: '🥺'),
          CampfireOption(id: 'd', text: 'Ver cómo se duerme roncando tiernamente al lado', emoji: '😴'),
        ],
      ),
    ],

    'pet_all': [
      const CampfireCard(
        id: 'shared_petall_1',
        type: CampfireCardType.sharedPassion,
        categoryHeader: '🐾 PASIÓN COMPARTIDA: AMOR POR LOS ANIMALES',
        question: 'Si tuvieran un santuario en el campo: ¿Qué animalitos no podrían faltar?',
        options: [
          CampfireOption(id: 'a', text: 'Perros y gatos conviviendo en armonía total', emoji: '🐶🐱'),
          CampfireOption(id: 'b', text: 'Patos, gallinas y animales de granja felices', emoji: '🦆'),
          CampfireOption(id: 'c', text: 'Animales rescatados que necesiten mucho amor y cuidados', emoji: '❤️'),
          CampfireOption(id: 'd', text: 'Capibaras y alpacas descansando bajo el sol', emoji: '🦙'),
        ],
      ),
    ],
  };

  // =========================================================================
  // 2. Preguntas de Contraste & Complementariedad (Curious Contrast)
  // =========================================================================
  static const List<CampfireCard> contrastCards = [
    // Contraste 0: Ritmos (Nocturno vs Madrugador)
    CampfireCard(
      id: 'contrast_rhythm_1',
      type: CampfireCardType.curiousContrast,
      categoryHeader: '⚖️ EL CONTRASTE: RITMOS DE VIDA',
      question: 'Uno es criatura nocturna y el otro despierta con el sol... ¿Cómo diseñarían su fin de semana ideal a medias?',
      options: [
        CampfireOption(id: 'a', text: 'Mañanas tranquilas para uno, salidas nocturnas para el otro', emoji: '☀️🌙'),
        CampfireOption(id: 'b', text: 'Despertar tarde y juntarnos a almorzar un rico brunch', emoji: '🥞'),
        CampfireOption(id: 'c', text: 'Cada quien a su ritmo y reencontrarnos en el atardecer', emoji: '🌅'),
        CampfireOption(id: 'd', text: 'Turnarnos: un fin de semana madrugador y otro trasnochador', emoji: '🔄'),
      ],
    ),

    // Contraste 1: Energía (Aventurero vs Hogareño)
    CampfireCard(
      id: 'contrast_energy_1',
      type: CampfireCardType.curiousContrast,
      categoryHeader: '⚖️ EL CONTRASTE: MOCHILA VS. MANTITA',
      question: 'Uno ama explorar afuera y el otro disfruta la paz del hogar... ¿Cuál sería su punto de encuentro?',
      options: [
        CampfireOption(id: 'a', text: 'Glamping en la naturaleza con cama cómoda y fogata', emoji: '⛺'),
        CampfireOption(id: 'b', text: 'Una escapada corta de día y noche de películas en el sillón', emoji: '🏡'),
        CampfireOption(id: 'c', text: 'Cabaña en el bosque con chimenea, juegos y caminatas cortas', emoji: '🪵'),
        CampfireOption(id: 'd', text: 'Pasear por librerías y cafés acogedores de la ciudad', emoji: '☕'),
      ],
    ),

    // Contraste 2: Social (Introvertido vs Extrovertido)
    CampfireCard(
      id: 'contrast_social_1',
      type: CampfireCardType.curiousContrast,
      categoryHeader: '⚖️ EL CONTRASTE: BATERÍA SOCIAL',
      question: 'Uno recarga energía en soledad y el otro en grupo... ¿Cómo se equilibran en una reunión social?',
      options: [
        CampfireOption(id: 'a', text: 'El extrovertido anima la fiesta y el introvertido conversa en grupos chicos', emoji: '🔋⚡'),
        CampfireOption(id: 'b', text: 'Acordar una "palabra clave" para retirarse cuando la batería se agote', emoji: '🔑'),
        CampfireOption(id: 'c', text: 'Planear siempre un día de descanso absoluto después de salir', emoji: '🛋️'),
        CampfireOption(id: 'd', text: 'Salidas cortas pero intensas para disfrutar sin agotarse', emoji: '⏱️'),
      ],
    ),

    // Contraste 3: Planificación vs Improvisación
    CampfireCard(
      id: 'contrast_planning_1',
      type: CampfireCardType.curiousContrast,
      categoryHeader: '⚖️ EL CONTRASTE: PLANIFICACIÓN VS. IMPROVISACIÓN',
      question: 'En un viaje o paseo nuevo: ¿Son de itinerario detallado o de dejarse llevar?',
      options: [
        CampfireOption(id: 'a', text: 'Tener los lugares clave listos pero el resto del día libre', emoji: '🗺️'),
        CampfireOption(id: 'b', text: 'Itinerario organizado para no perderse nada importante', emoji: '📅'),
        CampfireOption(id: 'c', text: 'Cero planes: caminar y ver qué sorpresas encontramos', emoji: '🧭'),
        CampfireOption(id: 'd', text: 'Uno planifica la mañana y el otro improvisa la tarde', emoji: '🤝'),
      ],
    ),
  ];

  // =========================================================================
  // 3. Fallbacks y Casos Especiales
  // =========================================================================

  // Caso Borde A: Cero Afinidad Común ➔ Descubrimiento Mutuo
  static const List<CampfireCard> discoveryCards = [
    CampfireCard(
      id: 'discovery_1',
      type: CampfireCardType.discoveryWildcard,
      categoryHeader: '🧭 DESCUBRIMIENTO: MUNDOS DIFERENTES',
      question: 'Tienen universos de gustos distintos... Si tuvieras que convencer a tu compañero de probar una de tus pasiones por una tarde: ¿Qué le mostrarías?',
      options: [
        CampfireOption(id: 'a', text: 'Mi videojuego o pasatiempo favorito de siempre', emoji: '🎮'),
        CampfireOption(id: 'b', text: 'Ese rincón secreto de comida que nadie conoce', emoji: '🍜'),
        CampfireOption(id: 'c', text: 'La música o álbum que me eriza la piel', emoji: '🎵'),
        CampfireOption(id: 'd', text: 'Una caminata tranquila por mi rincón favorito de la ciudad', emoji: '🌿'),
      ],
    ),
    CampfireCard(
      id: 'discovery_2',
      type: CampfireCardType.discoveryWildcard,
      categoryHeader: '🧭 DESCUBRIMIENTO: LA CURIOSIDAD',
      question: '¿Qué es algo que te apasiona y que la mayoría de la gente no suele entender hasta que lo prueba?',
      options: [
        CampfireOption(id: 'a', text: 'La emoción de las historias profundas de juegos y rol', emoji: '📜'),
        CampfireOption(id: 'b', text: 'La paz absoluta de estar en silencio sin que sea incómodo', emoji: '🤫'),
        CampfireOption(id: 'c', text: 'Aprender datos curiosos o cómo funcionan cosas complejas', emoji: '🧠'),
        CampfireOption(id: 'd', text: 'Caminar sin rumbo fijo solo por observar los detalles', emoji: '🚶'),
      ],
    ),
  ];

  // Caso Borde B: Sin Contrastes (Idénticos) ➔ Complicidad de Espejo
  static const List<CampfireCard> mirrorComplicityCards = [
    CampfireCard(
      id: 'mirror_1',
      type: CampfireCardType.mirrorComplicity,
      categoryHeader: '✨ EN SINTONÍA: COMPLICIDAD DE ESPEJO',
      question: '¡Tienen una energía y estilo muy parecidos! En una aventura de fantasía o un imprevisto: ¿Quién sería qué?',
      options: [
        CampfireOption(id: 'a', text: 'Yo la mente estratega y tú la acción espontánea', emoji: '🧠'),
        CampfireOption(id: 'b', text: 'Yo la acción espontánea y tú la mente estratega', emoji: '⚡'),
        CampfireOption(id: 'c', text: 'Los dos improvisando y riéndonos del desastre', emoji: '🎲'),
        CampfireOption(id: 'd', text: 'Nos turnamos según lo que se necesite en el momento', emoji: '🤝'),
      ],
    ),
    CampfireCard(
      id: 'mirror_2',
      type: CampfireCardType.mirrorComplicity,
      categoryHeader: '✨ EN SINTONÍA: COMPLICIDAD DE ESPEJO',
      question: 'Si se ganaran un fin de semana sorpresa con todo pagado para dos: ¿Qué elegirían hacer?',
      options: [
        CampfireOption(id: 'a', text: 'Comer delicioso en un restaurante único y pasear', emoji: '🍷'),
        CampfireOption(id: 'b', text: 'Encerrarnos en una cabaña con juegos, snacks y películas', emoji: '🍿'),
        CampfireOption(id: 'c', text: 'Explorar un pueblito pintoresco y sacar fotos', emoji: '📸'),
        CampfireOption(id: 'd', text: 'Ir a un concierto o evento que ambos queríamos ver', emoji: '🎟️'),
      ],
    ),
  ];

  // Caso Borde C: Intenciones de Cita Distintas ➔ Valores Humanos Universales
  static const List<CampfireCard> universalValuesCards = [
    CampfireCard(
      id: 'universal_values_1',
      type: CampfireCardType.universalValues,
      categoryHeader: '🌱 CONEXIÓN HUMANA: LO QUE REALMENTE IMPORTA',
      question: 'Más allá de lo que busquemos hoy: ¿Qué actitud en alguien te hace sentir de inmediato "esta persona vale la pena"?',
      options: [
        CampfireOption(id: 'a', text: 'La honestidad transparente y sin rodeos', emoji: '💎'),
        CampfireOption(id: 'b', text: 'El sentido del humor y saber reírse de sí mismo', emoji: '😂'),
        CampfireOption(id: 'c', text: 'La empatía y la capacidad de escuchar con atención', emoji: '👂'),
        CampfireOption(id: 'd', text: 'La pasión con la que habla de lo que le apasiona', emoji: '✨'),
      ],
    ),
    CampfireCard(
      id: 'universal_values_2',
      type: CampfireCardType.universalValues,
      categoryHeader: '🌱 CONEXIÓN HUMANA: LA BUENA COMPAÑÍA',
      question: '¿Qué convierte a una charla casual en una conexión memorable?',
      options: [
        CampfireOption(id: 'a', text: 'Poder hablar de tonterías y reírnos sin juzgarnos', emoji: '🤣'),
        CampfireOption(id: 'b', text: 'Tocar temas profundos y vulnerables con confianza', emoji: '🌌'),
        CampfireOption(id: 'c', text: 'Sentir que el tiempo pasa volando sin darse cuenta', emoji: '⏳'),
        CampfireOption(id: 'd', text: 'Poder compartir silencios cómodos sin presión', emoji: '🍵'),
      ],
    ),
    CampfireCard(
      id: 'universal_values_3',
      type: CampfireCardType.universalValues,
      categoryHeader: '🌱 CONEXIÓN HUMANA: MADUREZ Y COMPRENSIÓN',
      question: 'En un momento de desacuerdo o malentendido: ¿Qué valoras más para resolverlo?',
      options: [
        CampfireOption(id: 'a', text: 'Hablarlo directo con calma en el momento sin acumular', emoji: '🗣️'),
        CampfireOption(id: 'b', text: 'Darse un respiro para procesar y volver con la mente fría', emoji: '🧘'),
        CampfireOption(id: 'c', text: 'Tener la humildad de pedir perdón si uno se equivocó', emoji: '🕊️'),
        CampfireOption(id: 'd', text: 'Usar el humor y un abrazo para desarmar la tensión', emoji: '🫂'),
      ],
    ),
    CampfireCard(
      id: 'universal_values_4',
      type: CampfireCardType.universalValues,
      categoryHeader: '🌱 CONEXIÓN HUMANA: GENEROSIDAD',
      question: 'Si pudieras regalarle un superpoder cotidiano a tu compañero hoy: ¿Cuál sería?',
      options: [
        CampfireOption(id: 'a', text: 'Paz mental infinita cada vez que sienta estrés', emoji: '🧘'),
        CampfireOption(id: 'b', text: 'Suerte legendaria en todo lo que emprenda', emoji: '🍀'),
        CampfireOption(id: 'c', text: 'Tiempo extra para dedicarse a lo que ama sin prisas', emoji: '⏳'),
        CampfireOption(id: 'd', text: 'La comida más rica del mundo servida cada vez que tenga hambre', emoji: '🍲'),
      ],
    ),
  ];

  // Intenciones Mixtas 1: Romance / Slow Dating vs Amistad / Dúo Gamer
  static const List<CampfireCard> romanceVsFriendshipCards = [
    CampfireCard(
      id: 'mixed_rf_1',
      type: CampfireCardType.universalValues,
      categoryHeader: '🌱 INTENCIONES MIXTAS: ROMANCE & AMISTAD',
      question: 'Uno tiene el radar en el romance y el otro en la amistad... ¿Qué hace que una conexión empiece con el pie derecho?',
      options: [
        CampfireOption(id: 'a', text: 'Que las mejores historias siempre nacen de una amistad genuina', emoji: '🤝'),
        CampfireOption(id: 'b', text: 'Disfrutar la compañía sin etiquetas forzadas ni expectativas', emoji: '🍃'),
        CampfireOption(id: 'c', text: 'Risas y momentos compartidos como base de todo', emoji: '🤣'),
        CampfireOption(id: 'd', text: 'Honestidad transparente sobre cómo nos vamos sintiendo', emoji: '💎'),
      ],
    ),
    CampfireCard(
      id: 'mixed_rf_2',
      type: CampfireCardType.universalValues,
      categoryHeader: '🌱 INTENCIONES MIXTAS: CONSTRUIR CONFIANZA',
      question: 'Cuando dos personas con búsquedas distintas coinciden y la pasan increíble: ¿Cómo prefieren vivirlo?',
      options: [
        CampfireOption(id: 'a', text: 'Celebrar el presente y dejar que el tiempo diga', emoji: '⏳'),
        CampfireOption(id: 'b', text: 'Convertirse en un apoyo leal para el día a día', emoji: '🛡️'),
        CampfireOption(id: 'c', text: 'Compartir pasatiempos y ser compañeros de aventuras', emoji: '🗺️'),
        CampfireOption(id: 'd', text: 'Tener conversaciones profundas de esas que reinician el alma', emoji: '🌌'),
      ],
    ),
  ];

  // Intenciones Mixtas 2: Slow Dating vs Relación Seria Directa
  static const List<CampfireCard> slowVsSeriousCards = [
    CampfireCard(
      id: 'mixed_ss_1',
      type: CampfireCardType.deepConnection,
      categoryHeader: '💖 RITMOS AFECTIVOS: PASO A PASO VS COMPROMISO',
      question: 'Ambos tienen el corazón abierto, pero uno prefiere ir despacio y el otro busca certeza: ¿Qué es clave para entenderse?',
      options: [
        CampfireOption(id: 'a', text: 'Disfrutar cada etapa sin acelerar los tiempos', emoji: '🌱'),
        CampfireOption(id: 'b', text: 'Tener claro que ambos valoramos la lealtad y el respeto', emoji: '💍'),
        CampfireOption(id: 'c', text: 'Comunicar las dudas con total ternura y honestidad', emoji: '💬'),
        CampfireOption(id: 'd', text: 'Demostrar el interés con acciones cotidianas y no solo palabras', emoji: '✨'),
      ],
    ),
    CampfireCard(
      id: 'mixed_ss_2',
      type: CampfireCardType.deepConnection,
      categoryHeader: '💖 RITMOS AFECTIVOS: LA SEGURIDAD',
      question: 'En el camino de conocerse: ¿Qué gesto del otro te da más paz y tranquilidad?',
      options: [
        CampfireOption(id: 'a', text: 'Que sea constante y no desaparezca de la nada', emoji: '📱'),
        CampfireOption(id: 'b', text: 'Que respete mis espacios individuales sin reclamos', emoji: '🧘'),
        CampfireOption(id: 'c', text: 'Que recuerde lo que me importa y se preocupe por mi bienestar', emoji: '❤️'),
        CampfireOption(id: 'd', text: 'Que podamos reírnos y ser nosotros mismos sin filtros', emoji: '😂'),
      ],
    ),
  ];

  // Intenciones Mixtas 3: Dúo Gamer vs Charlas de Café
  static const List<CampfireCard> gamingVsChatsCards = [
    CampfireCard(
      id: 'mixed_gc_1',
      type: CampfireCardType.deepConnection,
      categoryHeader: '🤝 CONVIVENCIA: PANTALLAS & CAFÉS',
      question: 'Uno se inclina por el juego activo (Dúo Gamer) y el otro por la charla tranquila (Café): ¿Cuál sería su tarde perfecta?',
      options: [
        CampfireOption(id: 'a', text: 'Jugar algo cooperativo relajado mientras charlamos de la vida', emoji: '🎮☕'),
        CampfireOption(id: 'b', text: 'Una buena sesión de juego y luego desconectar con merienda rica', emoji: '🍕'),
        CampfireOption(id: 'c', text: 'Juegos de mesa en una cafetería acogedora', emoji: '🎲'),
        CampfireOption(id: 'd', text: 'Compartir música o stream mientras cada uno hace sus cosas juntos', emoji: '🎧'),
      ],
    ),
    CampfireCard(
      id: 'mixed_gc_2',
      type: CampfireCardType.deepConnection,
      categoryHeader: '🤝 CONVIVENCIA: DESCONECTAR DEL DÍA',
      question: 'Para recargar energías tras un día pesado: ¿Qué plan les parece más reparador?',
      options: [
        CampfireOption(id: 'a', text: 'Reírse de partidas caóticas y ganar partidas juntos', emoji: '🏆'),
        CampfireOption(id: 'b', text: 'Una infusión caliente y desahogarse de todo lo que pasó', emoji: '🍵'),
        CampfireOption(id: 'c', text: 'Ver videos divertidos o memes comiendo algo rico', emoji: '🍿'),
        CampfireOption(id: 'd', text: 'Silencio cómodo compartiendo el mismo espacio sin presiones', emoji: '🛋️'),
      ],
    ),
  ];

  // Intención Compartida: Romance / Slow Dating / Pareja
  static const List<CampfireCard> romanticConnectionCards = [
    CampfireCard(
      id: 'romantic_1',
      type: CampfireCardType.deepConnection,
      categoryHeader: '❤️ CONEXIÓN AFECTIVA: EL RITMO DEL CORAZÓN',
      question: 'Ambos buscan conocerse con calma y afecto... ¿Qué pequeño gesto cotidiano te parece más romántico?',
      options: [
        CampfireOption(id: 'a', text: 'Un mensaje inesperado diciendo "me acordé de ti"', emoji: '📱'),
        CampfireOption(id: 'b', text: 'Prepararle su comida o café favorito cuando tuvo un mal día', emoji: '🥞'),
        CampfireOption(id: 'c', text: 'Recordar un detalle pequeño que mencionó hace tiempo', emoji: '🧠'),
        CampfireOption(id: 'd', text: 'Un abrazo largo y en silencio que te reinicie el día', emoji: '🫂'),
      ],
    ),
    CampfireCard(
      id: 'romantic_2',
      type: CampfireCardType.deepConnection,
      categoryHeader: '❤️ CONEXIÓN AFECTIVA: PRIMERAS CITAS',
      question: 'En una cita ideal para conocerse sin máscaras: ¿Qué plan prefieres?',
      options: [
        CampfireOption(id: 'a', text: 'Un paseo tranquilo al atardecer seguido de cena rica', emoji: '🌅'),
        CampfireOption(id: 'b', text: 'Ir a un arcade o jugar algo que rompa el hielo con risas', emoji: '🕹️'),
        CampfireOption(id: 'c', text: 'Cocinar algo juntos en casa con música de fondo', emoji: '🍳'),
        CampfireOption(id: 'd', text: 'Cafetería acogedora con sofás y charla sin límite de tiempo', emoji: '☕'),
      ],
    ),
  ];

  // Intención Compartida: Amistad & Dúo Gamer / Charlas de Café
  static const List<CampfireCard> friendshipConnectionCards = [
    CampfireCard(
      id: 'friendship_1',
      type: CampfireCardType.deepConnection,
      categoryHeader: '🤝 COMPAÑERISMO: AVENTURAS & AMISTAD',
      question: 'Ambos buscan buena compañía y camaradería: ¿Qué valoras más en un amigo o compañero?',
      options: [
        CampfireOption(id: 'a', text: 'Cero drama y risas garantizadas en cada encuentro', emoji: '🤣'),
        CampfireOption(id: 'b', text: 'Lealtad: saber que está ahí en las buenas y en las malas', emoji: '🛡️'),
        CampfireOption(id: 'c', text: 'Poder hablar de cualquier tema sin filtros ni poses', emoji: '💬'),
        CampfireOption(id: 'd', text: 'Complicidad: entenderse solo con una mirada o ping', emoji: '👀'),
      ],
    ),
    CampfireCard(
      id: 'friendship_2',
      type: CampfireCardType.deepConnection,
      categoryHeader: '🤝 COMPAÑERISMO: EL DÚO IDEAL',
      question: '¿Qué hace que una sesión de juegos o charla sea legendaria?',
      options: [
        CampfireOption(id: 'a', text: 'Quedarse hablando hasta tarde perdiendo la noción de la hora', emoji: '🌙'),
        CampfireOption(id: 'b', text: 'Ganar una partida imposible gracias al trabajo en equipo', emoji: '🏆'),
        CampfireOption(id: 'c', text: 'Tener bromas internas que solo ustedes dos entienden', emoji: '🤫'),
        CampfireOption(id: 'd', text: 'Apoyarse cuando el otro necesita desahogarse de un mal día', emoji: '☕'),
      ],
    ),
  ];

  // Helper para obtener el nombre de la intención de cita
  static String _getDatingIntentTitle(List<String> tastes) {
    if (tastes.contains('intent_slow')) return 'Slow Dating 🌱';
    if (tastes.contains('intent_serious')) return 'Relación Seria 💍';
    if (tastes.contains('intent_gaming_duo')) return 'Dúo Gamer 🎮';
    if (tastes.contains('intent_cozy_chats')) return 'Charlas de Café ☕';
    return 'Conocer Personas 🌱';
  }

  // =========================================================================
  // Algoritmo de Selección Dinámica con Explicación de Motivos
  // =========================================================================
  static List<CampfireCard> selectCardsForUsers(
    UserProfile userA,
    UserProfile userB, {
    int? seed,
  }) {
    final rng = Random(seed ?? (userA.id.hashCode ^ userB.id.hashCode));
    final List<CampfireCard> selected = [];

    final setA = userA.tastes.toSet();
    final setB = userB.tastes.toSet();

    final nameA = (userA.username == 'Tú' || userA.username.isEmpty) ? 'Tú' : userA.username;
    final nameB = (userB.username == 'Tú' || userB.username.isEmpty) ? 'Compañero' : userB.username;

    // -----------------------------------------------------------------------
    // RONDA 1: Pasión Compartida vs. Descubrimiento Mutuo (Elige cualquiera de los similares)
    // -----------------------------------------------------------------------
    final commonTastes = (setA.intersection(setB).toList())..sort();
    final validCommonTastes = commonTastes
        .where((t) => sharedTasteCards.containsKey(t) && sharedTasteCards[t]!.isNotEmpty)
        .toList();

    CampfireCard? round1Card;
    String? round1Reason;

    if (validCommonTastes.isNotEmpty) {
      // Elegir aleatoriamente cualquiera de los gustos compartidos, no siempre el primero
      final chosenTaste = validCommonTastes[rng.nextInt(validCommonTastes.length)];
      final cards = sharedTasteCards[chosenTaste]!;
      round1Card = cards[rng.nextInt(cards.length)];
      final tasteTitle = getTagTitle(chosenTaste);
      round1Reason = '✨ Coincidencia de Gustos: Ambos eligieron [$tasteTitle]';
    } else {
      // Si no hay gustos en común específicos, usar fallback de Descubrimiento
      round1Card = discoveryCards[rng.nextInt(discoveryCards.length)];
      round1Reason = '🧭 Descubrimiento Mutuo: Tienen aficiones distintas, ¡momento de explorar el mundo del otro!';
    }
    selected.add(round1Card.copyWith(matchReason: round1Reason));

    // -----------------------------------------------------------------------
    // RONDA 2: Contraste Divertido vs. Complicidad de Espejo (Especifica quién tiene A y quién tiene B)
    // -----------------------------------------------------------------------
    final hasNightOwlA = setA.contains('vibe_night_owl');
    final hasNightOwlB = setB.contains('vibe_night_owl');
    final hasEarlyBirdA = setA.contains('vibe_early_bird');
    final hasEarlyBirdB = setB.contains('vibe_early_bird');

    final hasAdventurerA = setA.contains('vibe_adventurer');
    final hasAdventurerB = setB.contains('vibe_adventurer');
    final hasHomebodyA = setA.contains('vibe_homebody');
    final hasHomebodyB = setB.contains('vibe_homebody');

    final hasIntrovertA = setA.contains('vibe_introvert');
    final hasIntrovertB = setB.contains('vibe_introvert');
    final hasExtrovertA = setA.contains('vibe_extrovert');
    final hasExtrovertB = setB.contains('vibe_extrovert');

    final isRhythmContrast = (hasNightOwlA && hasEarlyBirdB) || (hasEarlyBirdA && hasNightOwlB);
    final isEnergyContrast = (hasAdventurerA && hasHomebodyB) || (hasHomebodyA && hasAdventurerB);
    final isSocialContrast = (hasIntrovertA && hasExtrovertB) || (hasExtrovertA && hasIntrovertB);

    CampfireCard round2Card;
    String round2Reason;

    if (isRhythmContrast) {
      round2Card = contrastCards[0];
      final traitA = hasNightOwlA ? 'Criatura Nocturna 🌙' : 'Madrugador(a) ☀️';
      final traitB = hasNightOwlB ? 'Criatura Nocturna 🌙' : 'Madrugador(a) ☀️';
      round2Reason = '⚖️ El Contraste: [$nameA: $traitA] vs [$nameB: $traitB]';
    } else if (isEnergyContrast) {
      round2Card = contrastCards[1];
      final traitA = hasAdventurerA ? 'Modo Mochila 🎒' : 'Modo Mantita 🛋️';
      final traitB = hasAdventurerB ? 'Modo Mochila 🎒' : 'Modo Mantita 🛋️';
      round2Reason = '⚖️ El Contraste: [$nameA: $traitA] vs [$nameB: $traitB]';
    } else if (isSocialContrast) {
      round2Card = contrastCards[2];
      final traitA = hasIntrovertA ? 'Introvertido(a) 🔋' : 'Extrovertido(a) ⚡';
      final traitB = hasIntrovertB ? 'Introvertido(a) 🔋' : 'Extrovertido(a) ⚡';
      round2Reason = '⚖️ El Contraste: [$nameA: $traitA] vs [$nameB: $traitB]';
    } else if (commonTastes.length >= 3) {
      // Mucha afinidad idéntica ➔ Complicidad de Espejo
      round2Card = mirrorComplicityCards[rng.nextInt(mirrorComplicityCards.length)];
      round2Reason = '✨ Complicidad de Espejo: Coinciden en múltiples gustos y tienen una sintonía idéntica';
    } else {
      round2Card = contrastCards[3];
      round2Reason = '⚖️ El Contraste: Planificación organizada vs. Aventura espontánea';
    }
    selected.add(round2Card.copyWith(matchReason: round2Reason));

    // -----------------------------------------------------------------------
    // RONDA 3: Conexión Real / Intenciones Específicas & Mixtas
    // -----------------------------------------------------------------------
    final isRomanceA = setA.contains('intent_serious') || setA.contains('intent_slow');
    final isRomanceB = setB.contains('intent_serious') || setB.contains('intent_slow');

    final isFriendshipA = setA.contains('intent_gaming_duo') || setA.contains('intent_cozy_chats');
    final isFriendshipB = setB.contains('intent_gaming_duo') || setB.contains('intent_cozy_chats');

    final isSlowA = setA.contains('intent_slow');
    final isSlowB = setB.contains('intent_slow');
    final isSeriousA = setA.contains('intent_serious');
    final isSeriousB = setB.contains('intent_serious');

    final isGamingA = setA.contains('intent_gaming_duo');
    final isGamingB = setB.contains('intent_gaming_duo');
    final isChatsA = setA.contains('intent_cozy_chats');
    final isChatsB = setB.contains('intent_cozy_chats');

    final intentNameA = _getDatingIntentTitle(userA.tastes);
    final intentNameB = _getDatingIntentTitle(userB.tastes);

    CampfireCard round3Card;
    String round3Reason;

    if (isRomanceA && isRomanceB) {
      if ((isSlowA && isSeriousB) || (isSeriousA && isSlowB)) {
        round3Card = slowVsSeriousCards[rng.nextInt(slowVsSeriousCards.length)];
        round3Reason = '💖 Ritmos de Romance: [$nameA: $intentNameA] vs [$nameB: $intentNameB]';
      } else {
        round3Card = romanticConnectionCards[rng.nextInt(romanticConnectionCards.length)];
        round3Reason = '💖 Intención Compartida: Ambos buscan [$intentNameA]';
      }
    } else if (isFriendshipA && isFriendshipB) {
      if ((isGamingA && isChatsB) || (isChatsA && isGamingB)) {
        round3Card = gamingVsChatsCards[rng.nextInt(gamingVsChatsCards.length)];
        round3Reason = '🤝 Estilos de Convivencia: [$nameA: $intentNameA] vs [$nameB: $intentNameB]';
      } else {
        round3Card = friendshipConnectionCards[rng.nextInt(friendshipConnectionCards.length)];
        round3Reason = '🤝 Intención Compartida: Ambos buscan [$intentNameA]';
      }
    } else if ((isRomanceA && isFriendshipB) || (isFriendshipA && isRomanceB)) {
      round3Card = romanceVsFriendshipCards[rng.nextInt(romanceVsFriendshipCards.length)];
      round3Reason = '🌱 Intenciones Mixtas: [$nameA: $intentNameA] vs [$nameB: $intentNameB]';
    } else {
      // Intenciones no declaradas o generales
      round3Card = universalValuesCards[rng.nextInt(universalValuesCards.length)];
      round3Reason = '🌱 Valores Humanos: [$nameA: $intentNameA] vs [$nameB: $intentNameB]';
    }
    selected.add(round3Card.copyWith(matchReason: round3Reason));

    return selected;
  }
}
