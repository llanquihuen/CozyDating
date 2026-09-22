package com.cozydating.server.controller;

import com.cozydating.server.model.MailboxMatch;
import com.cozydating.server.model.User;
import com.cozydating.server.service.DatabaseService;
import com.cozydating.server.util.JwtUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@CrossOrigin(origins = "*")
@RequestMapping("/api/mailbox")
public class MailboxController {

    private static final Logger logger = LoggerFactory.getLogger(MailboxController.class);

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private DatabaseService databaseService;

    @Autowired(required = false)
    private com.cozydating.server.handler.GameWebSocketHandler gameWebSocketHandler;

    private String resolveUserId(String authHeader, String queryUserId) {
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            String verified = jwtUtil.verifyTokenAndGetUserId(token);
            if (verified != null) {
                return databaseService.resolveDbUserId(verified);
            }
        }
        if (queryUserId != null && !queryUserId.trim().isEmpty()) {
            return databaseService.resolveDbUserId(queryUserId.trim());
        }
        return null;
    }

    /**
     * Get all mailbox match letters for the requesting user.
     * Formats the response specifically from the requesting user's perspective.
     */
    @GetMapping
    public ResponseEntity<?> getMailbox(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(value = "userId", required = false) String queryUserId) {

        String userId = resolveUserId(authHeader, queryUserId);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Usuario no autenticado"));
        }

        List<MailboxMatch> matches = databaseService.getUserMailboxMatches(userId);
        List<Map<String, Object>> responseList = new ArrayList<>();

        String resolvedUserId = databaseService.resolveDbUserId(userId);

        for (MailboxMatch m : matches) {
            String resolvedUserA = databaseService.resolveDbUserId(m.getUserAId());
            String resolvedUserB = databaseService.resolveDbUserId(m.getUserBId());

            boolean isUserA = (userId != null && userId.equals(m.getUserAId())) ||
                              (resolvedUserId != null && (resolvedUserId.equals(m.getUserAId()) || resolvedUserId.equals(resolvedUserA)));
            boolean isUserB = (userId != null && userId.equals(m.getUserBId())) ||
                              (resolvedUserId != null && (resolvedUserId.equals(m.getUserBId()) || resolvedUserId.equals(resolvedUserB)));

            if (!isUserA && !isUserB) {
                // Skip any match that does not involve the requesting user
                continue;
            }

            String partnerId = isUserA ? m.getUserBId() : m.getUserAId();
            String partnerName = isUserA ? m.getUserBName() : m.getUserAName();
            String partnerAvatar = isUserA ? m.getUserBAvatar() : m.getUserAAvatar();
            String partnerPhoto = isUserA ? m.getUserBPhoto() : m.getUserAPhoto();
            int partnerAge = isUserA ? m.getUserBAge() : m.getUserAAge();
            String partnerCommune = isUserA ? m.getUserBCommune() : m.getUserACommune();

            User partnerUser = null;
            if (partnerId != null && !partnerId.trim().isEmpty()) {
                partnerUser = databaseService.findUserById(partnerId.trim());
            }
            if (partnerUser == null && partnerName != null && !partnerName.trim().isEmpty()) {
                partnerUser = databaseService.findUserByUsername(partnerName.trim());
            }
            String partnerPhotos = null;
            if (partnerUser != null) {
                partnerName = partnerUser.getUsername();
                if (partnerUser.getAge() > 0) {
                    partnerAge = partnerUser.getAge();
                }
                if (partnerUser.getCommune() != null && !partnerUser.getCommune().trim().isEmpty()) {
                    partnerCommune = partnerUser.getCommune().trim();
                }
                partnerPhotos = partnerUser.getPhotos();
                if (partnerUser.getProfilePhoto() != null && !partnerUser.getProfilePhoto().trim().isEmpty()) {
                    partnerPhoto = partnerUser.getProfilePhoto().trim();
                }
                if (partnerAvatar == null || partnerAvatar.trim().isEmpty() || "{}".equals(partnerAvatar.trim())) {
                    partnerAvatar = partnerUser.getAvatarConfig();
                }
            }

            String myDecision = isUserA ? m.getDecisionA() : m.getDecisionB();
            String myNote = isUserA ? m.getNoteA() : m.getNoteB();
            String partnerDecision = isUserA ? m.getDecisionB() : m.getDecisionA();
            String partnerNote = isUserA ? m.getNoteB() : m.getNoteA();

            boolean isMutual = m.isMatched();
            boolean isCelebrated = isUserA ? m.isCelebratedA() : m.isCelebratedB();
            String matchType = m.getMatchType() != null ? m.getMatchType() : "NONE";

            // Asymmetric privacy protection:
            // If matchType is FRIENDSHIP and partnerDecision was ROMANCE, sanitize partnerDecision so it never leaks
            String sanitizedPartnerDecision = partnerDecision;
            if ("FRIENDSHIP".equalsIgnoreCase(matchType) && ("ROMANCE".equalsIgnoreCase(partnerDecision) || "KEEP_IN_TOUCH".equalsIgnoreCase(partnerDecision))) {
                sanitizedPartnerDecision = "FRIENDSHIP";
            }
            if (!isMutual) {
                sanitizedPartnerDecision = null;
            }

            Map<String, Object> item = new HashMap<>();
            item.put("id", m.getId());
            item.put("partnerId", partnerId);
            item.put("partnerName", partnerName != null ? partnerName : "Compañero");
            item.put("partnerAvatar", partnerAvatar);
            item.put("partnerPhoto", partnerPhoto);
            if (partnerPhotos != null && !partnerPhotos.trim().isEmpty()) {
                item.put("partnerPhotos", partnerPhotos);
            }
            item.put("partnerAge", partnerAge);
            item.put("partnerCommune", partnerCommune);
            item.put("commonTastes", m.getCommonTastes());
            item.put("myDecision", myDecision != null ? myDecision : "PENDING");
            item.put("myNote", myNote);
            item.put("isMutualMatch", isMutual);
            item.put("matchType", matchType);
            item.put("isCelebrated", isCelebrated);
            if (isMutual) {
                item.put("partnerDecision", sanitizedPartnerDecision);
                item.put("partnerNote", partnerNote);
            }
            item.put("createdAt", m.getCreatedAt());

            responseList.add(item);
        }

        return ResponseEntity.ok(responseList);
    }

    /**
     * Submit user's decision and optional note for a specific mailbox match.
     */
    @PostMapping("/decision")
    public ResponseEntity<?> submitDecision(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestBody Map<String, Object> body) {

        String queryUserId = (String) body.get("userId");
        String userId = resolveUserId(authHeader, queryUserId);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Usuario no autenticado"));
        }

        String matchId = (String) body.get("matchId");
        String decision = (String) body.get("decision"); // "KEEP_IN_TOUCH" or "ARCHIVE"
        String note = (String) body.get("note");

        if (matchId == null || decision == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "matchId y decision son requeridos"));
        }

        MailboxMatch updated = databaseService.submitMailboxDecision(matchId, userId, decision, note);
        if (updated == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Carta no encontrada o no autorizada"));
        }

        Map<String, Object> resp = new HashMap<>();
        resp.put("status", "SUCCESS");
        resp.put("matchId", matchId);
        resp.put("myDecision", decision);
        resp.put("isMutualMatch", updated.isMatched());
        resp.put("matchType", updated.getMatchType() != null ? updated.getMatchType() : "NONE");
        if (updated.isMatched()) {
            String resolvedUserId = databaseService.resolveDbUserId(userId);
            String resolvedUserA = databaseService.resolveDbUserId(updated.getUserAId());
            boolean isUserA = (userId != null && userId.equals(updated.getUserAId())) ||
                              (resolvedUserId != null && (resolvedUserId.equals(updated.getUserAId()) || resolvedUserId.equals(resolvedUserA)));
            resp.put("partnerNote", isUserA ? updated.getNoteB() : updated.getNoteA());

            if (gameWebSocketHandler != null) {
                gameWebSocketHandler.notifyMutualMatch(updated);
            }
        }

        return ResponseEntity.ok(resp);
    }

    /**
     * Get count of pending / unread letters for HUD badge.
     */
    @GetMapping("/badge-count")
    public ResponseEntity<?> getBadgeCount(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(value = "userId", required = false) String queryUserId) {

        String userId = resolveUserId(authHeader, queryUserId);
        if (userId == null) {
            return ResponseEntity.ok(Map.of("unreadCount", 0));
        }

        int count = databaseService.getUnreadMailboxCount(userId);
        return ResponseEntity.ok(Map.of("unreadCount", count));
    }

    /**
     * Mark a match celebration as acknowledged so it won't appear again on future logins.
     */
    @PostMapping("/celebrated")
    public ResponseEntity<?> markCelebrated(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestBody Map<String, Object> body) {

        String queryUserId = (String) body.get("userId");
        String userId = resolveUserId(authHeader, queryUserId);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Usuario no autenticado"));
        }

        String matchId = (String) body.get("matchId");
        if (matchId != null) {
            databaseService.markMatchCelebrated(matchId, userId);
        }

        return ResponseEntity.ok(Map.of("status", "SUCCESS", "matchId", matchId != null ? matchId : ""));
    }

    /**
     * Record a newly finished date letter directly into the mailbox.
     */
    @PostMapping("/record")
    public ResponseEntity<?> recordDateLetter(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestBody Map<String, Object> body) {

        String queryUserId = (String) body.get("userId");
        String userId = resolveUserId(authHeader, queryUserId);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Usuario no autenticado"));
        }

        String matchId = (String) body.get("id");
        if (matchId == null || matchId.isBlank()) {
            matchId = (String) body.get("matchId");
        }
        if (matchId == null || matchId.isBlank()) {
            matchId = "date_" + System.currentTimeMillis();
        }

        String partnerId = (String) body.get("partnerId");
        if (partnerId == null || partnerId.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "partnerId es requerido"));
        }
        String resolvedPartnerId = databaseService.resolveDbUserId(partnerId);

        String partnerName = (String) body.get("partnerName");
        Object partnerAvatar = body.get("partnerAvatar");
        String partnerPhoto = (String) body.get("partnerPhoto");
        int partnerAge = body.get("partnerAge") instanceof Number ? ((Number) body.get("partnerAge")).intValue() : 24;
        String partnerCommune = (String) body.get("partnerCommune");
        Object commonTastes = body.get("commonTastes");
        String commonTastesStr = commonTastes != null ? commonTastes.toString() : "";

        User partnerUser = databaseService.findUserById(resolvedPartnerId);
        String partnerPhotos = null;
        if (partnerUser != null) {
            partnerName = partnerUser.getUsername();
            if (partnerUser.getAge() > 0) partnerAge = partnerUser.getAge();
            if (partnerUser.getCommune() != null && !partnerUser.getCommune().trim().isEmpty()) {
                partnerCommune = partnerUser.getCommune().trim();
            }
            if (partnerUser.getProfilePhoto() != null && !partnerUser.getProfilePhoto().trim().isEmpty()) {
                partnerPhoto = partnerUser.getProfilePhoto().trim();
            }
            partnerPhotos = partnerUser.getPhotos();
            if (partnerAvatar == null && partnerUser.getAvatarConfig() != null) {
                partnerAvatar = partnerUser.getAvatarConfig();
            }
        }

        User currentUser = databaseService.findUserById(userId);
        String myName = currentUser != null ? currentUser.getUsername() : userId;
        String myAvatar = currentUser != null ? currentUser.getAvatarConfig() : null;
        String myPhoto = currentUser != null ? currentUser.getProfilePhoto() : null;
        int myAge = currentUser != null ? currentUser.getAge() : 24;
        String myCommune = currentUser != null ? currentUser.getCommune() : "Santiago";

        MailboxMatch match = new MailboxMatch(
            matchId,
            userId,
            resolvedPartnerId,
            myName,
            partnerName != null ? partnerName : "Compañero",
            myAvatar,
            partnerAvatar != null ? partnerAvatar.toString() : null,
            myPhoto,
            partnerPhoto,
            myAge,
            partnerAge,
            myCommune,
            partnerCommune != null ? partnerCommune : "Santiago",
            commonTastesStr,
            "PENDING",
            null,
            "PENDING",
            null,
            false
        );

        databaseService.saveOrUpdateMailboxMatch(match);
        logger.info("[MAILBOX REST] Successfully recorded date letter {} for user {} with partner {}",
                matchId, userId, resolvedPartnerId);

        Map<String, Object> resp = new HashMap<>();
        resp.put("status", "SUCCESS");
        resp.put("matchId", matchId);
        resp.put("partnerPhoto", partnerPhoto != null ? partnerPhoto : "");
        if (partnerPhotos != null && !partnerPhotos.trim().isEmpty()) {
            resp.put("partnerPhotos", partnerPhotos);
        }
        resp.put("partnerAge", partnerAge);
        resp.put("partnerCommune", partnerCommune != null ? partnerCommune : "Santiago");
        resp.put("partnerName", partnerName != null ? partnerName : "Compañero");

        return ResponseEntity.ok(resp);
    }
}
