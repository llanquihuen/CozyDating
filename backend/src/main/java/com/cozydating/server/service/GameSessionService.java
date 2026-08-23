package com.cozydating.server.service;

import com.cozydating.server.model.GameRoom;
import com.cozydating.server.util.LiveKitTokenGenerator;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

@Service
public class GameSessionService {

    private static final Logger logger = LoggerFactory.getLogger(GameSessionService.class);

    @Autowired
    private DatabaseService databaseService;

    @Autowired
    private LiveKitTokenGenerator liveKitTokenGenerator;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private final ConcurrentHashMap<String, GameRoom> activeRooms = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, String> userToRoomMap = new ConcurrentHashMap<>();

    private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(4);

    public void createRoom(String roomId, String explorerId, WebSocketSession explorerSession,
                           String guideId, WebSocketSession guideSession, String mode) {
        
        logger.info("[GAME SESSION INIT] Building room {} [Explorer: {}, Guide: {}, Mode: {}]", roomId, explorerId, guideId, mode);

        String livekitTokenExplorer = "";
        String livekitTokenGuide = "";

        if ("VOICE".equalsIgnoreCase(mode)) {
            logger.info("[GAME SESSION LIVEKIT] Signing LiveKit JWT access tokens for roomId: {}", roomId);
            livekitTokenExplorer = liveKitTokenGenerator.createToken(explorerId, roomId);
            livekitTokenGuide = liveKitTokenGenerator.createToken(guideId, roomId);
        }

        long dungeonSeed = Math.abs((long) roomId.hashCode() * 31 + (System.currentTimeMillis() % 1000000L));

        GameRoom room = new GameRoom(
            roomId,
            explorerId, explorerSession,
            guideId, guideSession,
            mode,
            livekitTokenExplorer,
            livekitTokenGuide,
            dungeonSeed
        );

        activeRooms.put(roomId, room);
        userToRoomMap.put(explorerId, roomId);
        userToRoomMap.put(guideId, roomId);

        // Send SESSION_INIT to Explorer
        logger.info("[GAME SESSION NOTIFY] Dispatching SESSION_INIT packet to Explorer ({}) with seed {}", explorerId, dungeonSeed);
        Map<String, Object> explorerInit = new HashMap<>();
        explorerInit.put("type", "SESSION_INIT");
        explorerInit.put("roomId", roomId);
        explorerInit.put("role", "EXPLORER");
        explorerInit.put("mode", mode);
        explorerInit.put("livekitToken", livekitTokenExplorer);
        explorerInit.put("partnerId", guideId);
        explorerInit.put("seed", dungeonSeed);
        explorerInit.put("act", 1);
        sendJsonMessage(explorerSession, explorerInit);

        // Send SESSION_INIT to Guide
        logger.info("[GAME SESSION NOTIFY] Dispatching SESSION_INIT packet to Guide ({}) with seed {}", guideId, dungeonSeed);
        Map<String, Object> guideInit = new HashMap<>();
        guideInit.put("type", "SESSION_INIT");
        guideInit.put("roomId", roomId);
        guideInit.put("role", "GUIDE");
        guideInit.put("mode", mode);
        guideInit.put("livekitToken", livekitTokenGuide);
        guideInit.put("partnerId", explorerId);
        guideInit.put("seed", dungeonSeed);
        guideInit.put("act", 1);
        sendJsonMessage(guideSession, guideInit);
    }

    public void handleDisconnect(String userId) {
        String roomId = userToRoomMap.get(userId);
        if (roomId == null) return;

        GameRoom room = activeRooms.get(roomId);
        if (room == null || room.isPaused()) return;

        logger.warn("[GAME SESSION PAUSE] User {} disconnected from room {}. Transitioning to WAITING_RECONNECT (20s grace period).", userId, roomId);
        
        room.setPaused(true);
        room.setDisconnectedUserId(userId);
        
        if (userId.equals(room.getExplorerId())) {
            room.setExplorerSession(null);
        } else {
            room.setGuideSession(null);
        }

        WebSocketSession partnerSession = room.getPartnerSession(userId);
        if (partnerSession != null && partnerSession.isOpen()) {
            logger.info("[GAME SESSION NOTIFY] Sending GAME_PAUSED frame to connected partner...");
            Map<String, Object> pausedMsg = new HashMap<>();
            pausedMsg.put("type", "GAME_PAUSED");
            pausedMsg.put("reason", "PARTNER_DISCONNECTED");
            sendJsonMessage(partnerSession, pausedMsg);
        }

        room.setReconnectGraceTask(scheduler.schedule(() -> {
            handleGracePeriodExpiry(roomId);
        }, 20, TimeUnit.SECONDS));
    }

    private void handleGracePeriodExpiry(String roomId) {
        GameRoom room = activeRooms.remove(roomId);
        if (room == null) return;

        logger.warn("[GAME SESSION TIMEOUT] 20-second grace window EXPIRED for room {}. Terminating game session.", roomId);

        userToRoomMap.remove(room.getExplorerId());
        userToRoomMap.remove(room.getGuideId());

        boolean bothReady = room.isBothReady();
        logger.info("[GAME SESSION REFUND CHECK] Both players confirmed start: {}. Mode: {}", bothReady, room.getMode());
        if (!bothReady && "VOICE".equalsIgnoreCase(room.getMode())) {
            logger.warn("[GAME SESSION REFUND TRIGGERED] Game start not confirmed. Executing automatic ticket refunds for Explorer ({}) and Guide ({}).",
                    room.getExplorerId(), room.getGuideId());
            databaseService.refundVoiceTicket(room.getExplorerId());
            databaseService.refundVoiceTicket(room.getGuideId());
        }

        WebSocketSession partnerSession = room.getExplorerSession() != null ? room.getExplorerSession() : room.getGuideSession();
        if (partnerSession != null && partnerSession.isOpen()) {
            Map<String, Object> overMsg = new HashMap<>();
            overMsg.put("type", "GAME_OVER");
            overMsg.put("reason", "RECONNECT_TIMEOUT");
            sendJsonMessage(partnerSession, overMsg);
            try {
                partnerSession.close();
            } catch (Exception e) {}
        }
    }

    public boolean reconnectSession(String userId, WebSocketSession newSession) {
        String roomId = userToRoomMap.get(userId);
        if (roomId == null) return false;

        GameRoom room = activeRooms.get(roomId);
        if (room == null || !room.isPaused()) return false;

        if (room.getReconnectGraceTask() != null) {
            room.getReconnectGraceTask().cancel(false);
            room.setReconnectGraceTask(null);
        }

        logger.info("[GAME SESSION RESUME] User {} successfully reconnected within grace window to room {}. Resuming match!", userId, roomId);

        if (userId.equals(room.getExplorerId())) {
            room.setExplorerSession(newSession);
        } else {
            room.setGuideSession(newSession);
        }

        room.setPaused(false);
        room.setDisconnectedUserId(null);

        Map<String, Object> resumeMsg = new HashMap<>();
        resumeMsg.put("type", "GAME_RESUMED");
        
        sendJsonMessage(room.getExplorerSession(), resumeMsg);
        sendJsonMessage(room.getGuideSession(), resumeMsg);

        return true;
    }

    public void handleEmergencyDisconnect(String userId) {
        handleEmergencyDisconnect(userId, true);
    }

    public void handleEmergencyDisconnect(String userId, boolean shouldBlock) {
        String roomId = userToRoomMap.remove(userId);
        if (roomId == null) return;

        GameRoom room = activeRooms.remove(roomId);
        if (room == null) return;

        logger.warn("[EXIT DISCONNECT] User {} triggered exit (ShouldBlock: {})! Destroying room {} in 0ms.", userId, shouldBlock, roomId);

        if (room.getReconnectGraceTask() != null) {
            room.getReconnectGraceTask().cancel(true);
        }

        String partnerId = room.getPartnerId(userId);
        userToRoomMap.remove(partnerId);

        if (shouldBlock) {
            logger.info("[EXIT BLOCK] Registering reciprocal permanent block between {} and {} in MySQL...", userId, partnerId);
            databaseService.blockUser(userId, partnerId);
        } else {
            logger.info("[EXIT FRIENDLY] User {} opted for a friendly exit. Skipping permanent block.", userId);
        }

        WebSocketSession partnerSession = room.getPartnerSession(userId);
        if (partnerSession != null && partnerSession.isOpen()) {
            Map<String, Object> emergencyMsg = new HashMap<>();
            emergencyMsg.put("type", "EMERGENCY_DISCONNECT");
            emergencyMsg.put("reason", shouldBlock ? "PARTNER_ABORTED_AND_BLOCKED" : "PARTNER_LEFT_FRIENDLY");
            sendJsonMessage(partnerSession, emergencyMsg);
            try {
                partnerSession.close();
            } catch (Exception e) {}
        }

        WebSocketSession mySession = userId.equals(room.getExplorerId()) ? room.getExplorerSession() : room.getGuideSession();
        if (mySession != null && mySession.isOpen()) {
            try {
                mySession.close();
            } catch (Exception e) {}
        }
    }

    public void handleGameReady(String userId) {
        String roomId = userToRoomMap.get(userId);
        if (roomId == null) return;

        GameRoom room = activeRooms.get(roomId);
        if (room == null) return;

        if (userId.equals(room.getExplorerId())) {
            room.setExplorerReady(true);
        } else {
            room.setGuideReady(true);
        }

        logger.info("[GAME SESSION READY] User {} confirmed GAME_READY in room {}", userId, roomId);

        WebSocketSession partnerSession = room.getPartnerSession(userId);
        if (partnerSession != null && partnerSession.isOpen()) {
            Map<String, Object> readyMsg = new HashMap<>();
            readyMsg.put("type", "GAME_READY");
            readyMsg.put("senderId", userId);
            sendJsonMessage(partnerSession, readyMsg);
        }
    }

    public void handlePlayerMove(String userId, Map<String, Object> messagePayload) {
        String roomId = userToRoomMap.get(userId);
        if (roomId == null) return;

        GameRoom room = activeRooms.get(roomId);
        if (room == null || room.isPaused()) return;

        if (userId.equals(room.getExplorerId())) {
            room.setExplorerReady(true);
        } else {
            room.setGuideReady(true);
        }

        WebSocketSession partnerSession = room.getPartnerSession(userId);
        if (partnerSession != null && partnerSession.isOpen()) {
            sendJsonMessage(partnerSession, messagePayload);
        }
    }

    public void forwardToPartner(String userId, Map<String, Object> messagePayload) {
        String roomId = userToRoomMap.get(userId);
        if (roomId == null) return;

        GameRoom room = activeRooms.get(roomId);
        if (room == null || room.isPaused()) return;

        WebSocketSession partnerSession = room.getPartnerSession(userId);
        if (partnerSession != null && partnerSession.isOpen()) {
            sendJsonMessage(partnerSession, messagePayload);
        }
    }

    public void handleRoleSwap(String userId) {
        String roomId = userToRoomMap.get(userId);
        if (roomId == null) return;

        GameRoom room = activeRooms.get(roomId);
        if (room == null || room.isPaused()) return;

        long newSeed = Math.abs(room.getDungeonSeed() * 31 + 7919);
        room.swapRoles(newSeed);

        String newExplorerId = room.getExplorerId();
        String newGuideId = room.getGuideId();

        logger.info("[GAME SESSION SWAP] User {} entered Final Portal in room {}. Swapped Act 2 Roles: Explorer ({}) <-> Guide ({}) with seed {}",
                userId, roomId, newExplorerId, newGuideId, newSeed);

        Map<String, Object> swapMsg = new HashMap<>();
        swapMsg.put("type", "ROLE_SWAP");
        swapMsg.put("message", "Roles swapped for Act 2.");
        swapMsg.put("triggerUserId", userId);
        swapMsg.put("seed", newSeed);
        swapMsg.put("act", 2);
        swapMsg.put("explorerId", newExplorerId);
        swapMsg.put("guideId", newGuideId);

        WebSocketSession explorerSession = room.getExplorerSession();
        WebSocketSession guideSession = room.getGuideSession();

        if (explorerSession != null && explorerSession.isOpen()) {
            sendJsonMessage(explorerSession, swapMsg);
        }
        if (guideSession != null && guideSession.isOpen() && guideSession != explorerSession) {
            sendJsonMessage(guideSession, swapMsg);
        }
    }

    private void sendJsonMessage(WebSocketSession session, Map<String, Object> message) {
        if (session == null || !session.isOpen()) return;
        try {
            String json = objectMapper.writeValueAsString(message);
            synchronized (session) {
                session.sendMessage(new TextMessage(json));
            }
        } catch (Exception e) {
            logger.error("[GAME SESSION ERROR] Failed to send JSON payload over socket", e);
        }
    }

    public GameRoom getRoomForUser(String userId) {
        String roomId = userToRoomMap.get(userId);
        return roomId != null ? activeRooms.get(roomId) : null;
    }

    public void clearSessions() {
        activeRooms.clear();
        userToRoomMap.clear();
        logger.info("[GAME SESSION CLEAR] All rooms reset.");
    }
}
