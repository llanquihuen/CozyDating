package com.cozydating.server.controller;

import com.cozydating.server.model.User;
import com.cozydating.server.service.DatabaseService;
import com.cozydating.server.util.JwtUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/user")
@CrossOrigin(origins = "*")
public class RoomController {

    private static final ObjectMapper objectMapper = new ObjectMapper();

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private DatabaseService databaseService;

    private String extractJsonString(Object obj) {
        if (obj == null) return null;
        if (obj instanceof String s) return s;
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            return obj.toString();
        }
    }

    private String resolveUserId(String authHeader, String queryUserId) {
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            String verifiedId = jwtUtil.verifyTokenAndGetUserId(token);
            if (verifiedId != null) return verifiedId;
        }
        if (queryUserId != null && !queryUserId.isEmpty()) {
            if ("alice".equalsIgnoreCase(queryUserId)) return "userA";
            if ("bob".equalsIgnoreCase(queryUserId)) return "userB";
            if ("charlie".equalsIgnoreCase(queryUserId)) return "userC";
            if ("david".equalsIgnoreCase(queryUserId)) return "userD";
            return queryUserId;
        }
        return null;
    }

    /**
     * Get the persisted RoomConfig JSON of a user.
     */
    @GetMapping("/room")
    public ResponseEntity<?> getRoomConfig(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(required = false) String userId) {
        
        String resolvedId = resolveUserId(authHeader, userId);
        if (resolvedId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "No autorizado"));
        }

        User user = databaseService.findUserById(resolvedId);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Usuario no encontrado"));
        }

        return ResponseEntity.ok(Map.of(
            "userId", user.getId(),
            "roomConfig", user.getRoomConfig() != null ? user.getRoomConfig() : "{}"
        ));
    }

    /**
     * Update/Persist the RoomConfig JSON of a user.
     */
    @PutMapping("/room")
    public ResponseEntity<?> updateRoomConfig(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(required = false) String userId,
            @RequestBody Map<String, Object> body) {
        
        String resolvedId = resolveUserId(authHeader, userId != null ? userId : (String) body.get("userId"));
        if (resolvedId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "No autorizado"));
        }

        String roomConfigJson = extractJsonString(body.get("roomConfig"));
        if (roomConfigJson == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "roomConfig es requerido"));
        }

        databaseService.updateRoomConfig(resolvedId, roomConfigJson);
        return ResponseEntity.ok(Map.of("status", "SUCCESS", "message", "Lobby guardado exitosamente en la base de datos"));
    }

    /**
     * Update/Persist the AvatarConfig JSON of a user.
     */
    @PutMapping("/avatar")
    public ResponseEntity<?> updateAvatarConfig(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(required = false) String userId,
            @RequestBody Map<String, Object> body) {
        
        String resolvedId = resolveUserId(authHeader, userId != null ? userId : (String) body.get("userId"));
        if (resolvedId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "No autorizado"));
        }

        String avatarConfigJson = extractJsonString(body.get("avatarConfig"));
        if (avatarConfigJson == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "avatarConfig es requerido"));
        }

        databaseService.updateAvatarConfig(resolvedId, avatarConfigJson);
        return ResponseEntity.ok(Map.of("status", "SUCCESS", "message", "Avatar guardado exitosamente en la base de datos"));
    }
}
