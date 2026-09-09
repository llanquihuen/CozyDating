package com.cozydating.server.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.socket.WebSocketSession;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;

@Service
public class MatchmakingService {

    private static final Logger logger = LoggerFactory.getLogger(MatchmakingService.class);

    @Autowired
    private DatabaseService databaseService;

    @Autowired
    private GameSessionService gameSessionService;

    private final List<QueueEntry> queue = new CopyOnWriteArrayList<>();

    public static class QueueEntry {
        public final String userId;
        public final String commune;
        public final String timeSlot;
        public final String mode;
        public final WebSocketSession session;
        public final Object avatarConfig;
        public final Object roomConfig;
        public final String username;
        public final Object tastes;
        public final long timestamp;

        public QueueEntry(String userId, String commune, String timeSlot, String mode, WebSocketSession session,
                          Object avatarConfig, Object roomConfig, String username, Object tastes) {
            this.userId = userId;
            this.commune = commune;
            this.timeSlot = timeSlot;
            this.mode = mode;
            this.session = session;
            this.avatarConfig = avatarConfig;
            this.roomConfig = roomConfig;
            this.username = username != null ? username : userId;
            this.tastes = tastes;
            this.timestamp = System.currentTimeMillis();
        }
    }

    public synchronized boolean joinQueue(String userId, String commune, String timeSlot, String mode, WebSocketSession session) {
        return joinQueue(userId, commune, timeSlot, mode, session, null, null, null, null);
    }

    public synchronized boolean joinQueue(String userId, String commune, String timeSlot, String mode, WebSocketSession session,
                                          Object avatarConfig, Object roomConfig, String username) {
        return joinQueue(userId, commune, timeSlot, mode, session, avatarConfig, roomConfig, username, null);
    }

    public synchronized boolean joinQueue(String userId, String commune, String timeSlot, String mode, WebSocketSession session,
                                          Object avatarConfig, Object roomConfig, String username, Object tastes) {
        logger.info("[MATCHMAKING REQUEST] User {} ({}) requesting to join queue [Commune: {}, TimeSlot: {}, Mode: {}]", userId, username, commune, timeSlot, mode);

        Object resolvedTastes = tastes;
        boolean isEmptyTastes = (resolvedTastes == null) ||
                               (resolvedTastes instanceof List && ((List<?>) resolvedTastes).isEmpty()) ||
                               (resolvedTastes instanceof String && (((String) resolvedTastes).trim().isEmpty() || "[]".equals(((String) resolvedTastes).trim())));

        if (isEmptyTastes) {
            com.cozydating.server.model.User u = databaseService.findUserById(userId);
            if (u != null && u.getTastes() != null && !u.getTastes().trim().isEmpty() && !"[]".equals(u.getTastes().trim())) {
                resolvedTastes = u.getTastes();
            }
        }

        for (int i = 0; i < queue.size(); i++) {
            QueueEntry entry = queue.get(i);
            if (entry.userId.equals(userId)) {
                logger.info("[MATCHMAKING UPDATE] User {} is ALREADY in queue. Updating session and candidate parameters.", userId);
                queue.set(i, new QueueEntry(userId, commune, timeSlot, mode, session, avatarConfig, roomConfig, username, resolvedTastes));
                checkAndFormMatches();
                return true;
            }
        }

        if ("VOICE".equalsIgnoreCase(mode)) {
            int balance = databaseService.getTicketBalance(userId);
            logger.info("[MATCHMAKING VOICE CHECK] User {} tickets balance: {}", userId, balance);
            if (balance < 1) {
                logger.warn("[MATCHMAKING REJECTED] User {} has 0 tickets balance. Queue join REJECTED.", userId);
                return false;
            }
        }

        QueueEntry newEntry = new QueueEntry(userId, commune, timeSlot, mode, session, avatarConfig, roomConfig, username, resolvedTastes);
        queue.add(newEntry);
        logger.info("[MATCHMAKING QUEUED] User {} successfully added to queue. Current Queue Size: {}", userId, queue.size());

        checkAndFormMatches();
        return true;
    }

    public synchronized void leaveQueue(String userId) {
        leaveQueue(userId, null);
    }

    public synchronized void leaveQueue(String userId, WebSocketSession session) {
        boolean removed = queue.removeIf(entry -> entry.userId.equals(userId) && (session == null || entry.session == null || entry.session.equals(session)));
        if (removed) {
            logger.info("[MATCHMAKING LEAVE] User {} removed from queue. New Queue Size: {}", userId, queue.size());
        }
    }

    private synchronized void checkAndFormMatches() {
        logger.info("[MATCHMAKING SCAN] Scanning active queue of {} candidates...", queue.size());
        if (queue.size() < 2) {
            logger.info("[MATCHMAKING SCAN] Insufficient candidates (<2) in queue. Waiting for more users.");
            return;
        }

        List<QueueEntry> matchedEntries = new ArrayList<>();

        for (int i = 0; i < queue.size(); i++) {
            QueueEntry entryA = queue.get(i);
            if (matchedEntries.contains(entryA)) continue;

            for (int j = i + 1; j < queue.size(); j++) {
                QueueEntry entryB = queue.get(j);
                if (matchedEntries.contains(entryB)) continue;

                logger.info("[MATCHMAKING EVAL] Comparing candidate A ({}) with candidate B ({})...", entryA.userId, entryB.userId);

                boolean modeMatch = entryA.mode.equalsIgnoreCase(entryB.mode);
                boolean communeMatch = entryA.commune.equalsIgnoreCase(entryB.commune);
                boolean slotMatch = entryA.timeSlot.equals(entryB.timeSlot);
                boolean differentUsers = !entryA.userId.equals(entryB.userId);
                boolean notBlocked = !databaseService.isMutuallyBlocked(entryA.userId, entryB.userId);
                boolean notPreviouslyMet = !databaseService.haveUsersMetOrMatched(entryA.userId, entryB.userId);

                logger.info("[MATCHMAKING EVAL RESULT] Candidates ({} vs {}): Mode: {}, Commune: {}, Slot: {}, DiffUser: {}, NotBlocked: {}, NotPreviouslyMet: {}",
                        entryA.userId, entryB.userId, modeMatch, communeMatch, slotMatch, differentUsers, notBlocked, notPreviouslyMet);

                if (modeMatch && communeMatch && slotMatch && differentUsers && notBlocked && notPreviouslyMet) {
                    logger.info("[MATCHMAKING MATCH FOUND] Valid pair identified: {} <-> {} for mode {}", entryA.userId, entryB.userId, entryA.mode);
                    
                    matchedEntries.add(entryA);
                    matchedEntries.add(entryB);
                    
                    processMatch(entryA, entryB);
                    break;
                }
            }
        }
    }

    private void processMatch(QueueEntry entryA, QueueEntry entryB) {
        boolean matchFailed = false;

        if ("VOICE".equalsIgnoreCase(entryA.mode)) {
            logger.info("[MATCHMAKING TRANSACTION] Executing voice ticket reservation for {} and {}...", entryA.userId, entryB.userId);
            
            boolean reservedA = databaseService.reserveVoiceTicket(entryA.userId);
            if (!reservedA) {
                logger.warn("[MATCHMAKING TRANSACTION FAIL] Reservation failed for {}. Cancelling match.", entryA.userId);
                queue.remove(entryA);
                matchFailed = true;
            } else {
                boolean reservedB = databaseService.reserveVoiceTicket(entryB.userId);
                if (!reservedB) {
                    logger.warn("[MATCHMAKING TRANSACTION FAIL] Reservation failed for {}. Refunding {} and cancelling match.", entryB.userId, entryA.userId);
                    databaseService.refundVoiceTicket(entryA.userId);
                    queue.remove(entryB);
                    matchFailed = true;
                }
            }
        }

        if (matchFailed) {
            logger.warn("[MATCHMAKING FAILED] Re-evaluating remaining candidates in queue...");
            checkAndFormMatches();
            return;
        }

        queue.remove(entryA);
        queue.remove(entryB);

        String roomId = "room_" + UUID.randomUUID().toString().substring(0, 8);
        logger.info("[MATCHMAKING ROOM INIT] Creating room {} for Explorer {} ({}) and Guide {} ({}) [Mode: {}]",
                roomId, entryA.userId, entryA.username, entryB.userId, entryB.username, entryA.mode);

        gameSessionService.createRoom(
            roomId, 
            entryA.userId, entryA.session, entryA.avatarConfig, entryA.roomConfig, entryA.username, entryA.tastes,
            entryB.userId, entryB.session, entryB.avatarConfig, entryB.roomConfig, entryB.username, entryB.tastes,
            entryA.mode
        );
    }

    public void clearQueue() {
        queue.clear();
        logger.info("[MATCHMAKING CLEAR] Queue reset.");
    }
}
