package com.cozydating.server.controller;

import com.cozydating.server.service.DatabaseService;
import com.cozydating.server.util.JwtUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@CrossOrigin(origins = "*")
public class AuthController {

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private DatabaseService databaseService;

    /**
     * Authentication endpoint supporting GET and POST for test accounts.
     * Maps 'alice' -> 'userA', 'bob' -> 'userB', 'charlie' -> 'userC', 'david' -> 'userD'.
     */
    @RequestMapping(value = "/auth/token", method = {RequestMethod.GET, RequestMethod.POST})
    public Map<String, Object> getToken(
            @RequestParam String userId,
            @RequestParam(required = false) String username) {
        
        // Map alias IDs to db IDs if needed
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
        return response;
    }

    /**
     * Endpoint to fetch user ticket balance.
     */
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

    /**
     * Helper endpoint to clear all user blocks and reset ticket balances for testing.
     */
    @RequestMapping(value = "/auth/unblock-all", method = {RequestMethod.GET, RequestMethod.POST})
    public Map<String, Object> unblockAll() {
        databaseService.unblockAllUsers();
        Map<String, Object> response = new HashMap<>();
        response.put("status", "SUCCESS");
        response.put("message", "All user blocks cleared and ticket balances reset!");
        return response;
    }

    /**
     * Helper endpoint to create a directional block.
     */
    @RequestMapping(value = "/auth/block", method = {RequestMethod.GET, RequestMethod.POST})
    public Map<String, Object> blockUser(@RequestParam String userId, @RequestParam String blockedUserId) {
        databaseService.blockUser(userId, blockedUserId);
        Map<String, Object> response = new HashMap<>();
        response.put("status", "SUCCESS");
        response.put("message", "Directional block created: " + userId + " has blocked " + blockedUserId);
        return response;
    }
}
