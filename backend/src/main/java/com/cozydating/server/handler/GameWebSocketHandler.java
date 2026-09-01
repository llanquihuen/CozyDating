package com.cozydating.server.handler;

import com.cozydating.server.service.GameSessionService;
import com.cozydating.server.service.MatchmakingService;
import com.cozydating.server.util.JwtUtil;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class GameWebSocketHandler extends TextWebSocketHandler {

    private static final Logger logger = LoggerFactory.getLogger(GameWebSocketHandler.class);

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private MatchmakingService matchmakingService;

    @Autowired
    private GameSessionService gameSessionService;

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final ConcurrentHashMap<WebSocketSession, String> sessionToUserMap = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        logger.info("[SOCKET HANDSHAKE] New incoming WebSocket link connected. Session ID: {}", session.getId());
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        String payload = message.getPayload();
        logger.info("[SOCKET RECV] Raw frame received from session {}: {}", session.getId(), payload);
        try {
            Map<String, Object> data = objectMapper.readValue(payload, new TypeReference<Map<String, Object>>() {});
            String type = (String) data.get("type");

            if (type == null) {
                logger.warn("[SOCKET WARN] Payload missing 'type' attribute from session {}", session.getId());
                sendError(session, "Missing 'type' field in payload.");
                return;
            }

            switch (type) {
                case "SESSION_INIT":
                    handleSessionInit(session, data);
                    break;
                case "RECONNECT_SESSION":
                    handleReconnectSession(session, data);
                    break;
                case "GAME_READY":
                    handleGameReady(session);
                    break;
                case "PLAYER_MOVE":
                    handlePlayerMove(session, data);
                    break;
                case "EMERGENCY_DISCONNECT":
                    handleEmergencyDisconnect(session, data);
                    break;
                case "BLOCK_PUSHED":
                case "TRAP_TRIGGERED":
                case "TRAP_TOGGLED":
                case "RUNE_GATE_UNLOCKED":
                case "PING_SENT":
                case "SANCTUARY_DECISION":
                case "PROFILE_SYNC":
                    handleForwardMessage(session, data);
                    break;
                case "PING":
                    sendJson(session, Map.of("type", "PONG"));
                    break;
                case "PONG":
                    // Keep-alive acknowledgment
                    break;
                case "ROLE_SWAP":
                    handleRoleSwap(session);
                    break;
                default:
                    logger.warn("[SOCKET WARN] Unsupported frame type '{}' from session {}", type, session.getId());
                    sendError(session, "Unsupported message type: " + type);
                    break;
            }
        } catch (Exception e) {
            logger.error("[SOCKET ERROR] Exception parsing raw text frame from session " + session.getId(), e);
            sendError(session, "Invalid message format: " + e.getMessage());
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
        String userId = sessionToUserMap.remove(session);
        if (userId != null) {
            logger.warn("[SOCKET CLOSED] WebSocket link closed for userId: {} (Status: {}). Triggering cleanup...", userId, status);
            matchmakingService.leaveQueue(userId);
            gameSessionService.handleDisconnect(userId, session);
        } else {
            logger.info("[SOCKET CLOSED] Unauthenticated session closed: {}", session.getId());
        }
    }

    private void handleSessionInit(WebSocketSession session, Map<String, Object> data) throws IOException {
        String token = (String) data.get("token");
        String commune = (String) data.get("commune");
        String timeSlot = (String) data.get("timeSlot");
        String mode = (String) data.get("mode");
        String username = (String) data.get("username");
        Object avatarConfig = data.get("avatarConfig");
        Object roomConfig = data.get("roomConfig");

        logger.info("[SOCKET AUTH] Verifying SESSION_INIT token signature...");
        String userId = jwtUtil.verifyTokenAndGetUserId(token);
        if (userId == null) {
            logger.warn("[SOCKET AUTH FAIL] SESSION_INIT rejected: Signature verification failed!");
            sendError(session, "Authentication failed: Invalid or expired token.");
            session.close(CloseStatus.POLICY_VIOLATION);
            return;
        }

        logger.info("[SOCKET AUTH SUCCESS] Identity verified! UserId: {} (Username: {})", userId, username);
        sessionToUserMap.put(session, userId);

        boolean queued = matchmakingService.joinQueue(userId, commune, timeSlot, mode, session, avatarConfig, roomConfig, username);
        if (!queued) {
            logger.warn("[SOCKET QUEUE FAIL] Could not queue user {}. Ticket balance or duplicate queue state.", userId);
            Map<String, Object> errorResp = new HashMap<>();
            errorResp.put("type", "ERROR");
            errorResp.put("message", "Failed to join queue. Check ticket balance or queue state.");
            sendJson(session, errorResp);
        } else {
            logger.info("[SOCKET QUEUE SUCCESS] Dispatching QUEUED confirmation frame to userId: {}", userId);
            Map<String, Object> queuedResp = new HashMap<>();
            queuedResp.put("type", "QUEUED");
            queuedResp.put("message", "Successfully placed in queue.");
            sendJson(session, queuedResp);
        }
    }

    private void handleReconnectSession(WebSocketSession session, Map<String, Object> data) throws IOException {
        String token = (String) data.get("token");
        logger.info("[SOCKET RECONNECT] Processing RECONNECT_SESSION frame...");

        String userId = jwtUtil.verifyTokenAndGetUserId(token);
        if (userId == null) {
            logger.warn("[SOCKET RECONNECT FAIL] Token verification failed!");
            sendError(session, "Authentication failed: Invalid or expired token.");
            session.close(CloseStatus.POLICY_VIOLATION);
            return;
        }

        sessionToUserMap.put(session, userId);

        boolean success = gameSessionService.reconnectSession(userId, session);
        if (!success) {
            logger.warn("[SOCKET RECONNECT FAIL] Reconnection failed for userId: {}. Grace period expired or room missing.", userId);
            Map<String, Object> failResp = new HashMap<>();
            failResp.put("type", "ERROR");
            failResp.put("message", "Reconnection failed: Grace period expired or no active room found.");
            sendJson(session, failResp);
            session.close(CloseStatus.NORMAL);
        }
    }

    private void handleGameReady(WebSocketSession session) throws IOException {
        String userId = sessionToUserMap.get(session);
        if (userId == null) return;
        gameSessionService.handleGameReady(userId);
    }

    private void handlePlayerMove(WebSocketSession session, Map<String, Object> data) throws IOException {
        String userId = sessionToUserMap.get(session);
        if (userId == null) return;
        gameSessionService.handlePlayerMove(userId, data);
    }

    private void handleEmergencyDisconnect(WebSocketSession session, Map<String, Object> data) throws IOException {
        String userId = sessionToUserMap.get(session);
        if (userId == null) return;
        
        Boolean shouldBlock = (Boolean) data.get("block");
        if (shouldBlock == null) {
            shouldBlock = false;
        }
        
        gameSessionService.handleEmergencyDisconnect(userId, shouldBlock);
    }

    private void handleForwardMessage(WebSocketSession session, Map<String, Object> data) throws IOException {
        String userId = sessionToUserMap.get(session);
        if (userId == null) return;
        gameSessionService.forwardToPartner(userId, data);
    }

    private void handleRoleSwap(WebSocketSession session) throws IOException {
        String userId = sessionToUserMap.get(session);
        if (userId == null) return;
        gameSessionService.handleRoleSwap(userId);
    }

    private void sendError(WebSocketSession session, String message) throws IOException {
        Map<String, Object> error = new HashMap<>();
        error.put("type", "ERROR");
        error.put("message", message);
        sendJson(session, error);
    }

    private void sendJson(WebSocketSession session, Map<String, Object> obj) throws IOException {
        if (session != null && session.isOpen()) {
            String json = objectMapper.writeValueAsString(obj);
            synchronized (session) {
                session.sendMessage(new TextMessage(json));
            }
        }
    }
}
