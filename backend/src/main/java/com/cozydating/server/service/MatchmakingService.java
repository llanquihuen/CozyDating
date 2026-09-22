package com.cozydating.server.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
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
        public final double maxDistanceKm;
        public final long timestamp;
        public final String gender;
        public final String seekingGender;
        public final boolean isInternational;
        public final Double latitude;
        public final Double longitude;

        public QueueEntry(String userId, String commune, String timeSlot, String mode, WebSocketSession session,
                          Object avatarConfig, Object roomConfig, String username, Object tastes, double maxDistanceKm) {
            this(userId, commune, timeSlot, mode, session, avatarConfig, roomConfig, username, tastes, maxDistanceKm,
                 "OTHER", "ANY", false, null, null);
        }

        public QueueEntry(String userId, String commune, String timeSlot, String mode, WebSocketSession session,
                          Object avatarConfig, Object roomConfig, String username, Object tastes, double maxDistanceKm,
                          String gender, String seekingGender, boolean isInternational, Double latitude, Double longitude) {
            this.userId = userId;
            this.commune = commune != null && !commune.trim().isEmpty() ? commune : "Santiago";
            this.timeSlot = timeSlot;
            this.mode = mode;
            this.session = session;
            this.avatarConfig = avatarConfig;
            this.roomConfig = roomConfig;
            this.username = username != null ? username : userId;
            this.tastes = tastes;
            this.maxDistanceKm = maxDistanceKm;
            this.gender = gender != null ? gender : "OTHER";
            this.seekingGender = seekingGender != null ? seekingGender : "ANY";
            this.isInternational = isInternational;
            this.latitude = latitude;
            this.longitude = longitude;
            this.timestamp = System.currentTimeMillis();
        }

        public double getEffectiveRadiusKm(long currentTime) {
            if (isInternational || maxDistanceKm < 0) {
                return Double.MAX_VALUE; // Unlimited / International
            }
            double base = maxDistanceKm > 0 ? maxDistanceKm : 25.0;
            long elapsedSeconds = Math.max(0, (currentTime - timestamp) / 1000);
            if (elapsedSeconds < 15) {
                return Math.min(base, 15.0); // 0-15s: zona cercana (< 15 km)
            } else if (elapsedSeconds < 30) {
                return Math.min(Math.max(base, 35.0), 35.0); // 15-30s: 35 km
            } else if (elapsedSeconds < 50) {
                return Math.min(Math.max(base, 60.0), 60.0); // 30-50s: 60 km
            } else {
                return Double.MAX_VALUE; // 50s+: nacional / sin fronteras
            }
        }
    }

    public synchronized boolean joinQueue(String userId, String commune, String timeSlot, String mode, WebSocketSession session) {
        return joinQueue(userId, commune, timeSlot, mode, session, null, null, null, null, 25.0);
    }

    public synchronized boolean joinQueue(String userId, String commune, String timeSlot, String mode, WebSocketSession session,
                                          Object avatarConfig, Object roomConfig, String username) {
        return joinQueue(userId, commune, timeSlot, mode, session, avatarConfig, roomConfig, username, null, 25.0);
    }

    public synchronized boolean joinQueue(String userId, String commune, String timeSlot, String mode, WebSocketSession session,
                                          Object avatarConfig, Object roomConfig, String username, Object tastes) {
        return joinQueue(userId, commune, timeSlot, mode, session, avatarConfig, roomConfig, username, tastes, 25.0);
    }

    public synchronized boolean joinQueue(String userId, String commune, String timeSlot, String mode, WebSocketSession session,
                                          Object avatarConfig, Object roomConfig, String username, Object tastes, double maxDistanceKm) {
        return joinQueue(userId, commune, timeSlot, mode, session, avatarConfig, roomConfig, username, tastes, maxDistanceKm, null, null, false, null, null);
    }

    public synchronized boolean joinQueue(String userId, String commune, String timeSlot, String mode, WebSocketSession session,
                                          Object avatarConfig, Object roomConfig, String username, Object tastes, double maxDistanceKm,
                                          String gender, String seekingGender, boolean isInternational, Double latitude, Double longitude) {
        logger.info("[MATCHMAKING REQUEST] User {} ({}) requesting to join queue [Commune: {}, MaxDist: {} km, TimeSlot: {}, Mode: {}, Gender: {}, Seeking: {}, Intl: {}]",
                userId, username, commune, maxDistanceKm, timeSlot, mode, gender, seekingGender, isInternational);

        Object resolvedTastes = tastes;
        boolean isEmptyTastes = (resolvedTastes == null) ||
                               (resolvedTastes instanceof List && ((List<?>) resolvedTastes).isEmpty()) ||
                               (resolvedTastes instanceof String && (((String) resolvedTastes).trim().isEmpty() || "[]".equals(((String) resolvedTastes).trim())));

        String dbUserId = databaseService.resolveDbUserId(userId);
        com.cozydating.server.model.User userEntity = databaseService.findUserById(dbUserId);
        if (userEntity != null && !userEntity.isVerified()) {
            logger.warn("[MATCHMAKING REJECTED] User {} ({}) is NOT verified. Only verified users can join matchmaking.", userId, dbUserId);
            try {
                if (session != null && session.isOpen()) {
                    session.sendMessage(new org.springframework.web.socket.TextMessage(
                        "{\"type\":\"ERROR\",\"code\":\"NOT_VERIFIED\",\"message\":\"Debes certificar tu identidad con una selfie antes de buscar pareja.\"}"
                    ));
                }
            } catch (Exception ignored) {}
            return false;
        }

        if (isEmptyTastes) {
            if (userEntity != null && userEntity.getTastes() != null && !userEntity.getTastes().trim().isEmpty() && !"[]".equals(userEntity.getTastes().trim())) {
                resolvedTastes = userEntity.getTastes();
            }
        }

        String resolvedGender = gender != null ? gender : (userEntity != null ? userEntity.getGender() : "OTHER");
        String resolvedSeeking = seekingGender != null ? seekingGender : (userEntity != null ? userEntity.getSeekingGender() : "ANY");
        boolean resolvedIntl = isInternational || (userEntity != null && userEntity.isInternational());
        Double resolvedLat = latitude != null ? latitude : (userEntity != null ? userEntity.getLatitude() : null);
        Double resolvedLon = longitude != null ? longitude : (userEntity != null ? userEntity.getLongitude() : null);
        double resolvedMaxDist = maxDistanceKm > 0 ? maxDistanceKm : (userEntity != null && userEntity.getMaxDistanceKm() > 0 ? userEntity.getMaxDistanceKm() : 25.0);

        for (int i = 0; i < queue.size(); i++) {
            QueueEntry entry = queue.get(i);
            if (entry.userId.equals(userId)) {
                logger.info("[MATCHMAKING UPDATE] User {} is ALREADY in queue. Updating session and candidate parameters.", userId);
                queue.set(i, new QueueEntry(userId, commune, timeSlot, mode, session, avatarConfig, roomConfig, username, resolvedTastes, resolvedMaxDist, resolvedGender, resolvedSeeking, resolvedIntl, resolvedLat, resolvedLon));
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

        QueueEntry newEntry = new QueueEntry(userId, commune, timeSlot, mode, session, avatarConfig, roomConfig, username, resolvedTastes, resolvedMaxDist, resolvedGender, resolvedSeeking, resolvedIntl, resolvedLat, resolvedLon);
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

    private double calculateDistance(QueueEntry a, QueueEntry b) {
        if (a.latitude != null && a.longitude != null && b.latitude != null && b.longitude != null) {
            return com.cozydating.server.util.GeoDistanceUtil.calculateDistanceKm(a.latitude, a.longitude, b.latitude, b.longitude);
        }
        return com.cozydating.server.util.GeoDistanceUtil.calculateDistanceKm(a.commune, b.commune);
    }

    private boolean isGenderCompatible(String seeking, String candidateGender) {
        if (seeking == null || seeking.trim().isEmpty() || "ANY".equalsIgnoreCase(seeking) || "ALL".equalsIgnoreCase(seeking) || "TODOS".equalsIgnoreCase(seeking)) {
            return true;
        }
        if (candidateGender == null || candidateGender.trim().isEmpty()) {
            return true;
        }
        return seeking.trim().equalsIgnoreCase(candidateGender.trim());
    }

    @Scheduled(fixedDelay = 3000)
    public synchronized void checkAndFormMatches() {
        if (queue.size() < 2) {
            return;
        }

        List<QueueEntry> matchedEntries = new ArrayList<>();
        long now = System.currentTimeMillis();

        for (int i = 0; i < queue.size(); i++) {
            QueueEntry entryA = queue.get(i);
            if (matchedEntries.contains(entryA)) continue;

            double radiusA = entryA.getEffectiveRadiusKm(now);

            QueueEntry bestCandidate = null;
            double bestDistance = Double.MAX_VALUE;

            for (int j = i + 1; j < queue.size(); j++) {
                QueueEntry entryB = queue.get(j);
                if (matchedEntries.contains(entryB)) continue;

                double radiusB = entryB.getEffectiveRadiusKm(now);
                double distanceKm = calculateDistance(entryA, entryB);

                boolean modeMatch = entryA.mode.equalsIgnoreCase(entryB.mode);
                boolean slotMatch = entryA.timeSlot.equals(entryB.timeSlot);
                boolean differentUsers = !entryA.userId.equals(entryB.userId);
                boolean notBlocked = !databaseService.isMutuallyBlocked(entryA.userId, entryB.userId);
                boolean notPreviouslyMet = !databaseService.haveUsersMetOrMatched(entryA.userId, entryB.userId);

                boolean genderMatch = isGenderCompatible(entryA.seekingGender, entryB.gender)
                        && isGenderCompatible(entryB.seekingGender, entryA.gender);

                boolean distanceMatch = entryA.isInternational || entryB.isInternational || (distanceKm <= radiusA && distanceKm <= radiusB);

                if (modeMatch && slotMatch && differentUsers && notBlocked && notPreviouslyMet && genderMatch && distanceMatch) {
                    if (distanceKm < bestDistance) {
                        bestDistance = distanceKm;
                        bestCandidate = entryB;
                    }
                }
            }

            if (bestCandidate != null) {
                logger.info("[MATCHMAKING MATCH FOUND] Valid pair identified: {} <-> {} for mode {} (Distance: {:.1f} km)",
                        entryA.userId, bestCandidate.userId, entryA.mode, bestDistance);

                matchedEntries.add(entryA);
                matchedEntries.add(bestCandidate);

                processMatch(entryA, bestCandidate, bestDistance);
            }
        }
    }

    private void processMatch(QueueEntry entryA, QueueEntry entryB, double distanceKm) {
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
        logger.info("[MATCHMAKING ROOM INIT] Creating room {} for Explorer {} ({}) and Guide {} ({}) [Mode: {}, Dist: {:.1f} km]",
                roomId, entryA.userId, entryA.username, entryB.userId, entryB.username, entryA.mode, distanceKm);

        gameSessionService.createRoom(
            roomId, 
            entryA.userId, entryA.session, entryA.avatarConfig, entryA.roomConfig, entryA.username, entryA.tastes,
            entryB.userId, entryB.session, entryB.avatarConfig, entryB.roomConfig, entryB.username, entryB.tastes,
            entryA.mode,
            distanceKm
        );
    }

    public void clearQueue() {
        queue.clear();
        logger.info("[MATCHMAKING CLEAR] Queue reset.");
    }
}
