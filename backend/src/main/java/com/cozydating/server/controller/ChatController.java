package com.cozydating.server.controller;

import com.cozydating.server.model.ChatMessage;
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
@RequestMapping("/api/chat")
public class ChatController {

    private static final Logger logger = LoggerFactory.getLogger(ChatController.class);

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

    @GetMapping("/messages")
    public ResponseEntity<?> getMessages(
            @RequestParam("matchId") String matchId,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(value = "userId", required = false) String queryUserId) {

        if (matchId == null || matchId.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "matchId is required"));
        }

        List<ChatMessage> messages = databaseService.getChatMessages(matchId);
        return ResponseEntity.ok(messages);
    }

    @PostMapping("/messages")
    public ResponseEntity<?> saveMessage(
            @RequestBody Map<String, Object> body,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {

        String matchId = (String) body.get("matchId");
        String senderId = (String) body.get("senderId");
        String receiverId = (String) body.get("receiverId");
        String text = (String) body.get("text");
        String dateType = (String) body.get("dateType");
        String id = (String) body.get("id");

        if (id == null || id.isEmpty()) {
            id = "msg_" + System.currentTimeMillis() + "_" + UUID.randomUUID().toString().substring(0, 8);
        }

        if (matchId == null || senderId == null || text == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "matchId, senderId and text are required"));
        }

        ChatMessage msg = new ChatMessage(id, matchId, senderId, receiverId, text, dateType, null);
        databaseService.saveChatMessage(msg);

        return ResponseEntity.ok(msg);
    }
}
