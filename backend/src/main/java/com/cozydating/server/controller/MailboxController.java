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

    private String resolveUserId(String authHeader, String queryUserId) {
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            String verified = jwtUtil.verifyTokenAndGetUserId(token);
            if (verified != null) return verified;
        }
        if (queryUserId != null && !queryUserId.trim().isEmpty()) {
            if ("alice".equalsIgnoreCase(queryUserId)) return "userA";
            if ("bob".equalsIgnoreCase(queryUserId)) return "userB";
            if ("charlie".equalsIgnoreCase(queryUserId)) return "userC";
            if ("david".equalsIgnoreCase(queryUserId)) return "userD";
            return queryUserId;
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

        for (MailboxMatch m : matches) {
            boolean isUserA = userId.equals(m.getUserAId());
            String partnerId = isUserA ? m.getUserBId() : m.getUserAId();
            String partnerName = isUserA ? m.getUserBName() : m.getUserAName();
            String partnerAvatar = isUserA ? m.getUserBAvatar() : m.getUserAAvatar();
            String partnerPhoto = isUserA ? m.getUserBPhoto() : m.getUserAPhoto();
            int partnerAge = isUserA ? m.getUserBAge() : m.getUserAAge();
            String partnerCommune = isUserA ? m.getUserBCommune() : m.getUserACommune();

            String myDecision = isUserA ? m.getDecisionA() : m.getDecisionB();
            String myNote = isUserA ? m.getNoteA() : m.getNoteB();
            String partnerDecision = isUserA ? m.getDecisionB() : m.getDecisionA();
            String partnerNote = isUserA ? m.getNoteB() : m.getNoteA();

            // Zero-rejection logic: only reveal partner note and mutual status if matched == true
            boolean isMutual = m.isMatched();

            Map<String, Object> item = new HashMap<>();
            item.put("id", m.getId());
            item.put("partnerId", partnerId);
            item.put("partnerName", partnerName != null ? partnerName : "Compañero");
            item.put("partnerAvatar", partnerAvatar);
            item.put("partnerPhoto", partnerPhoto);
            item.put("partnerAge", partnerAge);
            item.put("partnerCommune", partnerCommune);
            item.put("commonTastes", m.getCommonTastes());
            item.put("myDecision", myDecision != null ? myDecision : "PENDING");
            item.put("myNote", myNote);
            item.put("isMutualMatch", isMutual);
            if (isMutual) {
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
        if (updated.isMatched()) {
            boolean isUserA = userId.equals(updated.getUserAId());
            resp.put("partnerNote", isUserA ? updated.getNoteB() : updated.getNoteA());
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
}
