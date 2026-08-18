# ESPECIFICACIÓN TÉCNICA: Cozy Slow Dating (Flutter + Flame + Node.js)

## 1. Visión y Flujo de Usuario
Emparejamiento sin catálogo visual. Dos usuarios compatibles entran directo a una mini-aventura cooperativa asimétrica de 8–10 min con perspectiva cenital 2D (Top-Down estilo Zelda SNES / A Link to the Past).

### Perfil Pre-Partida (Lightweight):
- Avatar personalizable 2D (estilo Mii/Cozy).
- Edad y Comuna. (Cero fotos reales en esta etapa).

### Modos de Comunicación (Seleccionables en Cola):
- `VOICE`: Audio en vivo vía LiveKit (consume ticket de bienvenida / suscripción).
- `SILENT`: Comunicación asistida vía radar de pings en pantalla + rueda de emotes/frases rápidas en 1-tap.

### Las 4 Fases de la Partida:
1. **Acto 1 (Cripta en Penumbra - 3.5 min):**
   - **Explorador:** Radio de luz circular (linterna de 3 casillas). Movimiento en 4 direcciones, empuja bloques, pisa placas y esquiva trampas de púas/sombras.
   - **Guía:** Vista cenital esquemática completa e iluminada. Envía pings, activa reflectores temporales o desactiva trampas desde terminales.
2. **El Relevo Simétrico (Transición - 30 seg):**
   - El Explorador pisa la placa central y abre la compuerta del Guía. Se invierten los roles para el Acto 2.
3. **El Intermedio ("Bifurcación del Santuario" - 3 seg):**
   - Ambos eligen en pantalla: `[🔥 Ir a la Fogata]` o `[🪙 Reclamar Loot y Salir]`.
   - Si uno elige salir, van directo al cofre y finaliza amigablemente. Si ambos eligen Fogata, avanzan al Acto 3.
4. **Acto 3 (La Fogata - 2 min) + Doble Ciego:**
   - Tarjetas interactivas de dilemas y valores.
   - Votación secreta post-juego: si hay doble "SÍ", se revelan fotos HD y se abre chat privado. Si no, exclusión permanente sin aviso de rechazo.

## 2. Stack Tecnológico
- **Frontend:** Flutter (Dart) + Feature-First + Flutter BLoC (`flutter_bloc`).
- **Motor 2D:** Flame Engine (Top-Down Grid / Tiled, HasCollisionDetection).
- **Backend:** Node.js (TypeScript) + Fastify/Express + WebSockets (`ws`) + Redis (Matchmaking).
- **Audio:** LiveKit Cloud (`livekit_client`).

## 3. Modelo de Red y Seguridad
- **Servidor Autoritativo:** El backend valida el estado de trampas, interruptores y posiciones finales de bloques para evitar desincronizaciones.
- **Salida Segura `[🚨 SALIR]`:** Overlay nativo siempre visible. Desconecta WebSockets y LiveKit en 0ms, bloquea emparejamiento mutuo y regresa al menú.
