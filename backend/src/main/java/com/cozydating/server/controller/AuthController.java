package com.cozydating.server.controller;

import com.cozydating.server.model.User;
import com.cozydating.server.service.DatabaseService;
import com.cozydating.server.util.JwtUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@CrossOrigin(origins = "*")
public class AuthController {

    private static final ObjectMapper objectMapper = new ObjectMapper();

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private DatabaseService databaseService;

    @GetMapping({"/", "/health"})
    public Map<String, Object> healthCheck() {
        Map<String, Object> status = new HashMap<>();
        status.put("status", "UP");
        status.put("service", "CozyDating Game Server");
        status.put("timestamp", System.currentTimeMillis());
        return status;
    }

    private String extractJsonString(Object obj) {
        if (obj == null) return null;
        if (obj instanceof String s) return s;
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            return obj.toString();
        }
    }

    /**
     * Register a new user with custom Avatar, Tastes/Preferences and Initial Room Configuration.
     */
    @PostMapping("/auth/register")
    public ResponseEntity<?> register(@RequestBody Map<String, Object> body) {
        String username = body.get("username") != null ? body.get("username").toString() : null;
        String password = body.get("password") != null ? body.get("password").toString() : null;
        String email = body.get("email") != null ? body.get("email").toString() : null;
        Integer age = body.get("age") instanceof Number ? ((Number) body.get("age")).intValue() : 20;
        String commune = body.get("commune") != null ? body.get("commune").toString() : null;
        String avatarConfig = extractJsonString(body.get("avatarConfig"));
        String tastes = extractJsonString(body.get("tastes"));
        String roomConfig = extractJsonString(body.get("roomConfig"));

        if (username == null || username.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "El nombre de usuario es obligatorio"));
        }
        if (email == null || email.trim().isEmpty() || !email.contains("@") || !email.contains(".")) {
            return ResponseEntity.badRequest().body(Map.of("error", "El correo electrónico es obligatorio y debe ser válido"));
        }
        if (password == null || password.length() < 4) {
            return ResponseEntity.badRequest().body(Map.of("error", "La contraseña debe tener al menos 4 caracteres"));
        }

        // Check if username is already taken
        if (databaseService.findUserByUsername(username.trim()) != null) {
            return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("error", "El nombre de usuario ya está en uso"));
        }

        // Check if email is already taken
        if (databaseService.findUserByEmail(email.trim()) != null) {
            return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("error", "El correo electrónico ya está registrado por otra cuenta"));
        }

        String userId = "user_" + UUID.randomUUID().toString().substring(0, 8);
        String passwordHash = databaseService.getPasswordEncoder().encode(password);

        User newUser = new User(
            userId,
            username.trim(),
            email != null ? email.trim() : null,
            passwordHash,
            age != null ? age : 20,
            commune != null ? commune.trim() : "Santiago",
            5, // Welcome gift of 5 tickets
            avatarConfig != null ? avatarConfig : "{}",
            tastes != null ? tastes : "[]",
            roomConfig != null ? roomConfig : "{}"
        );

        databaseService.createUser(newUser);

        String token = jwtUtil.generateToken(userId, username.trim(), 30L * 24 * 3600 * 1000);

        Map<String, Object> response = new HashMap<>();
        response.put("token", token);
        response.put("user", formatUserResponse(newUser));
        return ResponseEntity.ok(response);
    }

    /**
     * Authenticate with username and password.
     */
    @PostMapping("/auth/login")
    public ResponseEntity<?> login(@RequestBody Map<String, Object> body) {
        String usernameOrEmail = (String) body.get("username");
        String password = (String) body.get("password");

        if (usernameOrEmail == null || password == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Debes ingresar usuario y contraseña"));
        }

        User user = databaseService.findUserByUsername(usernameOrEmail.trim());
        if (user == null) {
            user = databaseService.findUserByEmail(usernameOrEmail.trim());
        }

        if (user == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Usuario no encontrado"));
        }

        if (user.getPasswordHash() != null) {
            boolean matches = databaseService.getPasswordEncoder().matches(password, user.getPasswordHash());
            if (!matches) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Contraseña incorrecta"));
            }
        }

        String token = jwtUtil.generateToken(user.getId(), user.getUsername(), 30L * 24 * 3600 * 1000);

        Map<String, Object> response = new HashMap<>();
        response.put("token", token);
        response.put("user", formatUserResponse(user));
        return ResponseEntity.ok(response);
    }

    /**
     * Get current user profile from Bearer Token or query param.
     */
    @GetMapping("/auth/me")
    public ResponseEntity<?> getCurrentUser(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(required = false) String userId) {
        
        String resolvedUserId = userId;
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            resolvedUserId = jwtUtil.verifyTokenAndGetUserId(token);
        }

        if (resolvedUserId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Token inválido o expirado"));
        }

        User user = databaseService.findUserById(resolvedUserId);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Usuario no encontrado"));
        }

        return ResponseEntity.ok(formatUserResponse(user));
    }

    /**
     * Legacy authentication endpoint supporting GET and POST for test accounts and backwards compatibility.
     */
    @RequestMapping(value = "/auth/token", method = {RequestMethod.GET, RequestMethod.POST})
    public Map<String, Object> getToken(
            @RequestParam String userId,
            @RequestParam(required = false) String username) {
        
        String dbUserId = userId;
        if ("alice".equalsIgnoreCase(userId)) dbUserId = "userA";
        else if ("bob".equalsIgnoreCase(userId)) dbUserId = "userB";
        else if ("charlie".equalsIgnoreCase(userId)) dbUserId = "userC";
        else if ("david".equalsIgnoreCase(userId)) dbUserId = "userD";

        String uname = (username != null && !username.isEmpty()) ? username : userId;
        String token = jwtUtil.generateToken(dbUserId, uname, 30L * 24 * 3600 * 1000);
        int balance = databaseService.getTicketBalance(dbUserId);

        Map<String, Object> response = new HashMap<>();
        response.put("token", token);
        response.put("userId", dbUserId);
        response.put("ticketsBalance", balance);

        User user = databaseService.findUserById(dbUserId);
        if (user != null) {
            response.put("user", formatUserResponse(user));
        }

        return response;
    }

    @RequestMapping(value = "/auth/balance", method = {RequestMethod.GET, RequestMethod.POST})
    public Map<String, Object> getBalance(@RequestParam String userId) {
        String dbUserId = userId;
        if ("alice".equalsIgnoreCase(userId)) dbUserId = "userA";
        else if ("bob".equalsIgnoreCase(userId)) dbUserId = "userB";
        else if ("charlie".equalsIgnoreCase(userId)) dbUserId = "userC";
        else if ("david".equalsIgnoreCase(userId)) dbUserId = "userD";

        int balance = databaseService.getTicketBalance(dbUserId);

        Map<String, Object> response = new HashMap<>();
        response.put("userId", dbUserId);
        response.put("ticketsBalance", balance);
        return response;
    }

    @RequestMapping(value = "/auth/unblock-all", method = {RequestMethod.GET, RequestMethod.POST})
    public Map<String, Object> unblockAll() {
        databaseService.unblockAllUsers();
        Map<String, Object> response = new HashMap<>();
        response.put("status", "SUCCESS");
        response.put("message", "All user blocks cleared and ticket balances reset!");
        return response;
    }

    @RequestMapping(value = "/auth/block", method = {RequestMethod.GET, RequestMethod.POST})
    public Map<String, Object> blockUser(@RequestParam String userId, @RequestParam String blockedUserId) {
        databaseService.blockUser(userId, blockedUserId);
        Map<String, Object> response = new HashMap<>();
        response.put("status", "SUCCESS");
        response.put("message", "Directional block created: " + userId + " has blocked " + blockedUserId);
        return response;
    }

    @PostMapping("/auth/profile")
    public ResponseEntity<?> updateProfile(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestBody Map<String, Object> body) {
        
        String resolvedUserId = null;
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            resolvedUserId = jwtUtil.verifyTokenAndGetUserId(token);
        }
        if (resolvedUserId == null && body.containsKey("userId")) {
            resolvedUserId = (String) body.get("userId");
        }
        if (resolvedUserId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Token requerido"));
        }

        User user = databaseService.findUserById(resolvedUserId);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Usuario no encontrado"));
        }

        String tastes = extractJsonString(body.get("tastes"));
        if (tastes != null) {
            databaseService.updateUserProfile(resolvedUserId, user.getAge(), user.getCommune(), tastes);
            user.setTastes(tastes);
        }

        if (body.containsKey("profilePhoto")) {
            String photo = (String) body.get("profilePhoto");
            databaseService.updateProfilePhoto(resolvedUserId, photo);
            user.setProfilePhoto(photo);
        }

        return ResponseEntity.ok(formatUserResponse(user));
    }

    private Map<String, Object> formatUserResponse(User user) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", user.getId());
        map.put("username", user.getUsername());
        map.put("email", user.getEmail());
        map.put("age", user.getAge());
        map.put("commune", user.getCommune());
        map.put("ticketsBalance", user.getTicketsBalance());
        map.put("avatarConfig", user.getAvatarConfig());
        map.put("tastes", user.getTastes());
        map.put("profilePhoto", user.getProfilePhoto());
        map.put("roomConfig", user.getRoomConfig());
        return map;
    }
}
