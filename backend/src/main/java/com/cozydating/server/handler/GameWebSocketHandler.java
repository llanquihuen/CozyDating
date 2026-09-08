package com.cozydating.server.handler;

import com.cozydating.server.model.ChatMessage;
import com.cozydating.server.service.DatabaseService;
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
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import com.cozydating.server.model.User;

@Component
public class GameWebSocketHandler extends TextWebSocketHandler {

    private static final Logger logger = LoggerFactory.getLogger(GameWebSocketHandler.class);

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private MatchmakingService matchmakingService;

    @Autowired
    private GameSessionService gameSessionService;

    @Autowired
    private DatabaseService databaseService;

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final ConcurrentHashMap<WebSocketSession, String> sessionToUserMap = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, WebSocketSession> userToSessionMap = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, String> userPresenceModeMap = new ConcurrentHashMap<>();

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
                case "USER_ONLINE":
                    handleUserOnline(session, data);
                    break;
                case "SET_PRESENCE_MODE":
                    handleSetPresenceMode(session, data);
                    break;
                case "PRESENCE_CHECK":
                    handlePresenceCheck(session, data);
                    break;
                case "CHAT_MESSAGE":
                    handleChatMessage(session, data);
                    break;
                case "DATE_INVITE":
                    handleDateInvite(session, data);
                    break;
                case "DATE_INVITE_RESPONSE":
                    handleDateInviteResponse(session, data);
                    break;
                case "DATE_INVITE_CANCEL":
                    handleDateInviteCancel(session, data);
                    break;
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
                case "EMOTE_TRIGGERED":
                case "PITFALL_TRAPPED":
                case "PITFALL_RESCUED":
                case "RUNE_STEPPED":
                case "CAMPFIRE_ANSWER":
                case "CAMPFIRE_NEXT_ROUND":
                case "CAMPFIRE_EMOTE":
                case "HOME_AVATAR_MOVE":
                case "HOME_AVATAR_SIT":
                case "HOME_AVATAR_STAND":
                case "HOME_ACTION":
                case "HOME_EMOTE":
                case "HOME_CHAT":
                    handleForwardMessage(session, data);
                    break;
                case "CAMPFIRE_COMPLETED":
                case "DATE_COMPLETED":
                case "HOME_COMPLETED":
                    handleDateCompleted(session, data);
                    break;
                case "LEAVE_QUEUE":
                    handleLeaveQueue(session);
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
            userToSessionMap.remove(userId, session);
            userPresenceModeMap.remove(userId);
            broadcastPresence(userId, false);
            logger.warn("[SOCKET CLOSED] WebSocket link closed for userId: {} (Status: {}). Triggering cleanup...", userId, status);
            matchmakingService.leaveQueue(userId);
            gameSessionService.handleDisconnect(userId, session);
        } else {
            logger.info("[SOCKET CLOSED] Unauthenticated session closed: {}", session.getId());
        }
    }

    private void handleUserOnline(WebSocketSession session, Map<String, Object> data) throws IOException {
        String token = (String) data.get("token");
        String requestedUserId = (String) data.get("userId");
        String presenceMode = (String) data.getOrDefault("presenceMode", "ONLINE");

        String userId = null;
        if (token != null && !token.trim().isEmpty()) {
            userId = jwtUtil.verifyTokenAndGetUserId(token);
        }
        if (userId == null && requestedUserId != null && !requestedUserId.trim().isEmpty()) {
            userId = requestedUserId;
            if ("alice".equalsIgnoreCase(userId)) userId = "userA";
            if ("bob".equalsIgnoreCase(userId)) userId = "userB";
            if ("charlie".equalsIgnoreCase(userId)) userId = "userC";
            if ("david".equalsIgnoreCase(userId)) userId = "userD";
        }

        if (userId == null) {
            logger.warn("[SOCKET AUTH FAIL] USER_ONLINE rejected: Could not determine userId");
            sendError(session, "Authentication failed: Missing or invalid token/userId.");
            return;
        }

        sessionToUserMap.put(session, userId);
        userToSessionMap.put(userId, session);
        userPresenceModeMap.put(userId, presenceMode.toUpperCase());

        logger.info("[SOCKET USER_ONLINE] User {} registered online. Presence mode: {}", userId, presenceMode);

        Map<String, Object> ack = new HashMap<>();
        ack.put("type", "USER_ONLINE_ACK");
        ack.put("userId", userId);
        ack.put("presenceMode", presenceMode.toUpperCase());
        sendJson(session, ack);

        if (!"INVISIBLE".equalsIgnoreCase(presenceMode)) {
            broadcastPresence(userId, true);
        }
    }

    private void handleSetPresenceMode(WebSocketSession session, Map<String, Object> data) throws IOException {
        String userId = sessionToUserMap.get(session);
        if (userId == null) return;

        String mode = (String) data.get("presenceMode");
        if (mode == null || mode.trim().isEmpty()) mode = "ONLINE";
        mode = mode.toUpperCase();

        userPresenceModeMap.put(userId, mode);
        boolean isVisible = "ONLINE".equalsIgnoreCase(mode) && !gameSessionService.isUserInActiveSession(userId);
        broadcastPresence(userId, isVisible);

        logger.info("[SOCKET PRESENCE_MODE] User {} updated presence mode to: {} (Visible: {})", userId, mode, isVisible);

        Map<String, Object> ack = new HashMap<>();
        ack.put("type", "SET_PRESENCE_MODE_ACK");
        ack.put("presenceMode", mode);
        sendJson(session, ack);
    }

    private void handlePresenceCheck(WebSocketSession session, Map<String, Object> data) throws IOException {
        String targetUserId = (String) data.get("targetUserId");
        if (targetUserId != null) {
            if ("alice".equalsIgnoreCase(targetUserId)) targetUserId = "userA";
            if ("bob".equalsIgnoreCase(targetUserId)) targetUserId = "userB";
            if ("charlie".equalsIgnoreCase(targetUserId)) targetUserId = "userC";
            if ("david".equalsIgnoreCase(targetUserId)) targetUserId = "userD";
        }

        boolean isOnline = false;
        if (targetUserId != null) {
            WebSocketSession targetSession = userToSessionMap.get(targetUserId);
            String mode = userPresenceModeMap.getOrDefault(targetUserId, "ONLINE");
            boolean inDate = gameSessionService.isUserInActiveSession(targetUserId);
            // In-Date Shield and Invisible Shield:
            isOnline = targetSession != null && targetSession.isOpen() && !"INVISIBLE".equalsIgnoreCase(mode) && !inDate;
        }

        Map<String, Object> resp = new HashMap<>();
        resp.put("type", "PRESENCE_STATUS");
        resp.put("targetUserId", targetUserId);
        resp.put("isOnline", isOnline);
        sendJson(session, resp);
    }

    private void handleChatMessage(WebSocketSession session, Map<String, Object> data) throws IOException {
        String fromUserId = sessionToUserMap.get(session);
        if (fromUserId == null) {
            fromUserId = (String) data.get("fromUserId");
        }
        String toUserId = (String) data.get("toUserId");
        String matchId = (String) data.get("matchId");
        String text = (String) data.get("text");
        String messageId = (String) data.get("messageId");
        if (messageId == null || messageId.isEmpty()) {
            messageId = "msg_" + System.currentTimeMillis();
        }

        if (fromUserId != null) {
            if ("alice".equalsIgnoreCase(fromUserId)) fromUserId = "userA";
            if ("bob".equalsIgnoreCase(fromUserId)) fromUserId = "userB";
        }
        if (toUserId != null) {
            if ("alice".equalsIgnoreCase(toUserId)) toUserId = "userA";
            if ("bob".equalsIgnoreCase(toUserId)) toUserId = "userB";
        }

        // Persist message to DB
        ChatMessage msg = new ChatMessage(messageId, matchId, fromUserId, toUserId, text, null, null);
        databaseService.saveChatMessage(msg);

        // Real-time relay to toUserId if connected
        WebSocketSession targetSession = userToSessionMap.get(toUserId);
        if (targetSession != null && targetSession.isOpen()) {
            Map<String, Object> forward = new HashMap<>();
            forward.put("type", "CHAT_MESSAGE");
            forward.put("matchId", matchId);
            forward.put("fromUserId", fromUserId);
            forward.put("toUserId", toUserId);
            forward.put("text", text);
            forward.put("messageId", messageId);
            forward.put("timestamp", System.currentTimeMillis());
            sendJson(targetSession, forward);
            logger.info("[SOCKET CHAT] Relayed message {} from {} to {}", messageId, fromUserId, toUserId);
        } else {
            logger.info("[SOCKET CHAT] Target user {} is offline/invisible. Message {} saved in DB.", toUserId, messageId);
        }
    }

    private void handleDateInvite(WebSocketSession session, Map<String, Object> data) throws IOException {
        String fromUserId = sessionToUserMap.get(session);
        if (fromUserId == null) {
            fromUserId = (String) data.get("fromUserId");
        }
        String toUserId = (String) data.get("toUserId");
        String matchId = (String) data.get("matchId");
        String dateType = (String) data.get("dateType");
        String title = (String) data.get("title");
        String inviterName = (String) data.get("inviterName");
        String messageId = (String) data.get("messageId");
        if (messageId == null || messageId.isEmpty()) {
            messageId = "invite_" + System.currentTimeMillis();
        }

        if (fromUserId != null) {
            if ("alice".equalsIgnoreCase(fromUserId)) fromUserId = "userA";
            if ("bob".equalsIgnoreCase(fromUserId)) fromUserId = "userB";
        }
        if (toUserId != null) {
            if ("alice".equalsIgnoreCase(toUserId)) toUserId = "userA";
            if ("bob".equalsIgnoreCase(toUserId)) toUserId = "userB";
        }

        // Ephemeral invitation event - do NOT persist as permanent junk message in chat_messages table
        logger.info("[SOCKET INVITE] Processing date invite {} from {} to {} for activity {}", messageId, fromUserId, toUserId, dateType);

        // Check privacy & in-date status
        boolean inDate = gameSessionService.isUserInActiveSession(toUserId);
        String targetMode = userPresenceModeMap.getOrDefault(toUserId, "ONLINE");
        WebSocketSession targetSession = userToSessionMap.get(toUserId);

        if (inDate || "INVISIBLE".equalsIgnoreCase(targetMode) || targetSession == null || !targetSession.isOpen()) {
            logger.info("[SOCKET INVITE] User {} is not available for direct date popup (InDate: {}, Invisible: {}, SessionOpen: {}).",
                    toUserId, inDate, "INVISIBLE".equalsIgnoreCase(targetMode), targetSession != null && targetSession.isOpen());
            Map<String, Object> busyNotice = new HashMap<>();
            busyNotice.put("type", "DATE_INVITE_BUSY");
            busyNotice.put("matchId", matchId);
            busyNotice.put("toUserId", toUserId);
            busyNotice.put("message", "Tu compañero no está disponible para citas en este momento.");
            sendJson(session, busyNotice);
        } else {
            // Forward real-time date invite popup
            Map<String, Object> forward = new HashMap<>();
            forward.put("type", "DATE_INVITE");
            forward.put("matchId", matchId);
            forward.put("fromUserId", fromUserId);
            forward.put("toUserId", toUserId);
            forward.put("inviterName", inviterName);
            forward.put("dateType", dateType);
            forward.put("title", title);
            forward.put("messageId", messageId);
            forward.put("timestamp", System.currentTimeMillis());
            sendJson(targetSession, forward);
            logger.info("[SOCKET INVITE] Relayed date invite {} from {} to {}", messageId, fromUserId, toUserId);
        }
    }

    private void handleDateInviteResponse(WebSocketSession session, Map<String, Object> data) throws IOException {
        String fromUserId = sessionToUserMap.get(session);
        if (fromUserId == null) fromUserId = (String) data.get("fromUserId");
        String toUserId = (String) data.get("toUserId");
        String matchId = (String) data.get("matchId");
        Boolean accepted = (Boolean) data.get("accepted");
        String dateType = (String) data.get("dateType");
        String title = (String) data.get("title");

        if (fromUserId != null) {
            if ("alice".equalsIgnoreCase(fromUserId)) fromUserId = "userA";
            if ("bob".equalsIgnoreCase(fromUserId)) fromUserId = "userB";
        }
        if (toUserId != null) {
            if ("alice".equalsIgnoreCase(toUserId)) toUserId = "userA";
            if ("bob".equalsIgnoreCase(toUserId)) toUserId = "userB";
        }

        WebSocketSession targetSession = userToSessionMap.get(toUserId);
        if (targetSession != null && targetSession.isOpen()) {
            Map<String, Object> forward = new HashMap<>(data);
            forward.put("fromUserId", fromUserId);
            forward.put("toUserId", toUserId);
            sendJson(targetSession, forward);
            logger.info("[SOCKET INVITE RESPONSE] Relayed response from {} to {} (Accepted: {})", fromUserId, toUserId, accepted);

            if (Boolean.TRUE.equals(accepted)) {
                // Auto-launch real multiplayer date session for BOTH players
                String roomId = "date_" + UUID.randomUUID().toString().substring(0, 8);
                String sessionMode = "CAMPFIRE".equalsIgnoreCase(dateType)
                        ? "CAMPFIRE"
                        : ("HOME".equalsIgnoreCase(dateType) ? "HOME" : "STANDARD");

                User inviter = databaseService.findUserById(toUserId);
                User accepter = databaseService.findUserById(fromUserId);

                logger.info("[SOCKET DATE LAUNCH] Launching synchronized date session {} between inviter {} and accepter {} [Mode: {}]",
                        roomId, toUserId, fromUserId, sessionMode);

                matchmakingService.leaveQueue(toUserId);
                matchmakingService.leaveQueue(fromUserId);

                gameSessionService.createRoom(
                    roomId,
                    toUserId, targetSession,
                    inviter != null ? inviter.getAvatarConfig() : null,
                    inviter != null ? inviter.getRoomConfig() : null,
                    inviter != null ? inviter.getUsername() : toUserId,
                    inviter != null ? inviter.getTastes() : "[]",
                    fromUserId, session,
                    accepter != null ? accepter.getAvatarConfig() : null,
                    accepter != null ? accepter.getRoomConfig() : null,
                    accepter != null ? accepter.getUsername() : fromUserId,
                    accepter != null ? accepter.getTastes() : "[]",
                    sessionMode
                );
            }
        }
    }

    private void handleDateInviteCancel(WebSocketSession session, Map<String, Object> data) throws IOException {
        String fromUserId = sessionToUserMap.get(session);
        if (fromUserId == null) fromUserId = (String) data.get("fromUserId");
        String toUserId = (String) data.get("toUserId");
        String matchId = (String) data.get("matchId");

        if (fromUserId != null) {
            if ("alice".equalsIgnoreCase(fromUserId)) fromUserId = "userA";
            if ("bob".equalsIgnoreCase(fromUserId)) fromUserId = "userB";
        }
        if (toUserId != null) {
            if ("alice".equalsIgnoreCase(toUserId)) toUserId = "userA";
            if ("bob".equalsIgnoreCase(toUserId)) toUserId = "userB";
        }

        WebSocketSession targetSession = userToSessionMap.get(toUserId);
        if (targetSession != null && targetSession.isOpen()) {
            Map<String, Object> forward = new HashMap<>(data);
            forward.put("type", "DATE_INVITE_CANCEL");
            forward.put("fromUserId", fromUserId);
            forward.put("toUserId", toUserId);
            forward.put("matchId", matchId);
            sendJson(targetSession, forward);
            logger.info("[SOCKET INVITE CANCEL] Relayed cancellation from {} to {}", fromUserId, toUserId);
        }
    }

    private void broadcastPresence(String userId, boolean isOnline) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", "USER_PRESENCE_UPDATE");
        msg.put("userId", userId);
        msg.put("isOnline", isOnline);
        for (Map.Entry<String, WebSocketSession> entry : userToSessionMap.entrySet()) {
            if (!entry.getKey().equals(userId) && entry.getValue().isOpen()) {
                try {
                    sendJson(entry.getValue(), msg);
                } catch (Exception ignored) {}
            }
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
        Object tastes = data.get("tastes");

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
        userToSessionMap.put(userId, session);

        boolean queued = matchmakingService.joinQueue(userId, commune, timeSlot, mode, session, avatarConfig, roomConfig, username, tastes);
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
        userToSessionMap.put(userId, session);

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

        String type = (String) data.get("type");
        if ("CAMPFIRE_ANSWER".equalsIgnoreCase(type)) {
            Object roundObj = data.get("round");
            if (roundObj instanceof Number && ((Number) roundObj).intValue() >= 2) {
                // Final round of campfire reached - date completed!
                logger.info("[SOCKET DATE AUTO-COMPLETE] Final campfire round completed by user {}", userId);
                gameSessionService.recordCompletedDateForUser(userId);
            }
        }

        gameSessionService.forwardToPartner(userId, data);
    }

    private void handleLeaveQueue(WebSocketSession session) {
        String userId = sessionToUserMap.get(session);
        if (userId == null) return;
        logger.info("[SOCKET LEAVE_QUEUE] User {} explicitly requested to leave matchmaking queue.", userId);
        matchmakingService.leaveQueue(userId);
    }

    private void handleDateCompleted(WebSocketSession session, Map<String, Object> data) throws IOException {
        String userId = sessionToUserMap.get(session);
        if (userId == null) return;
        logger.info("[SOCKET DATE COMPLETED] Date completed packet received from user {}", userId);
        gameSessionService.recordCompletedDateForUser(userId);
        gameSessionService.forwardToPartner(userId, data);

        // Clean up the active date room so users are no longer marked as InDate: true
        gameSessionService.endSessionForUser(userId);

        Map<String, Object> ack = new HashMap<>();
        ack.put("type", "DATE_COMPLETED_ACK");
        ack.put("userId", userId);
        sendJson(session, ack);
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
