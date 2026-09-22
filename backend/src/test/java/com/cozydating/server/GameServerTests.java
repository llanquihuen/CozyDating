package com.cozydating.server;

import com.cozydating.server.model.GameRoom;
import com.cozydating.server.service.DatabaseService;
import com.cozydating.server.service.GameSessionService;
import com.cozydating.server.service.MatchmakingService;
import com.cozydating.server.util.JwtUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.WebSocketExtension;
import org.springframework.web.socket.WebSocketMessage;
import org.springframework.web.socket.WebSocketSession;

import java.io.IOException;
import java.lang.reflect.Method;
import java.net.InetSocketAddress;
import java.net.URI;
import java.security.Principal;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.test.context.ActiveProfiles;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
public class GameServerTests {

    @Autowired
    private DatabaseService databaseService;

    @Autowired
    private MatchmakingService matchmakingService;

    @Autowired
    private GameSessionService gameSessionService;

    @Autowired
    private com.cozydating.server.handler.GameWebSocketHandler gameWebSocketHandler;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    public void cleanAndSeedDb() {
        jdbcTemplate.execute("DELETE FROM user_blocks");
        jdbcTemplate.execute("DELETE FROM mailbox_matches");
        jdbcTemplate.execute("DELETE FROM users");
        
        // Seed users
        jdbcTemplate.update("INSERT INTO users (id, username, tickets_balance, is_verified) VALUES (?, ?, ?, true)", "userA", "Alice", 5);
        jdbcTemplate.update("INSERT INTO users (id, username, tickets_balance, is_verified) VALUES (?, ?, ?, true)", "userB", "Bob", 3);
        jdbcTemplate.update("INSERT INTO users (id, username, tickets_balance, is_verified) VALUES (?, ?, ?, true)", "userC", "Charlie", 0);
        jdbcTemplate.update("INSERT INTO users (id, username, tickets_balance, is_verified) VALUES (?, ?, ?, true)", "userD", "David", 1);

        // Reset stateful singletons
        matchmakingService.clearQueue();
        gameSessionService.clearSessions();
    }

    @Test
    public void testDatabaseTicketAtomicTransactions() {
        // Assert initial balance
        assertEquals(5, databaseService.getTicketBalance("userA"));
        
        // Reserve ticket atomically
        boolean success = databaseService.reserveVoiceTicket("userA");
        assertTrue(success);
        assertEquals(4, databaseService.getTicketBalance("userA"));
        
        // Refund ticket atomically
        databaseService.refundVoiceTicket("userA");
        assertEquals(5, databaseService.getTicketBalance("userA"));

        // Charlie has 0 tickets, reservation should fail
        boolean failedReservation = databaseService.reserveVoiceTicket("userC");
        assertFalse(failedReservation);
        assertEquals(0, databaseService.getTicketBalance("userC"));
    }

    @Test
    public void testAuthenticationTokens() {
        String token = jwtUtil.generateToken("userA", "Alice", 10000);
        assertNotNull(token);

        String userId = jwtUtil.verifyTokenAndGetUserId(token);
        assertEquals("userA", userId);

        // Invalid token test
        String invalidToken = token + "corrupt";
        assertNull(jwtUtil.verifyTokenAndGetUserId(invalidToken));
    }

    @Test
    public void testReciprocalBlocks() {
        assertFalse(databaseService.isMutuallyBlocked("userA", "userB"));

        // Alice blocks Bob
        databaseService.blockUser("userA", "userB");

        // Verify mutual block holds bidirectional
        assertTrue(databaseService.isMutuallyBlocked("userA", "userB"));
        assertTrue(databaseService.isMutuallyBlocked("userB", "userA"));
    }

    @Test
    public void testMatchmakingAndTicketReservation() {
        WebSocketSession sessionA = new TestWebSocketSession("sessionA");
        WebSocketSession sessionB = new TestWebSocketSession("sessionB");

        // Join queue VOICE mode: Alice has 5 tickets, Bob has 3 tickets
        boolean joinedA = matchmakingService.joinQueue("userA", "Santiago", "20", "VOICE", sessionA);
        boolean joinedB = matchmakingService.joinQueue("userB", "Santiago", "20", "VOICE", sessionB);

        assertTrue(joinedA);
        assertTrue(joinedB);

        // Verify they were matched and tickets deducted
        assertEquals(4, databaseService.getTicketBalance("userA"));
        assertEquals(2, databaseService.getTicketBalance("userB"));

        GameRoom room = gameSessionService.getRoomForUser("userA");
        assertNotNull(room);
        assertEquals("VOICE", room.getMode());
    }

    @Test
    public void testBlocklistExcludesMatch() {
        WebSocketSession sessionA = new TestWebSocketSession("sessionA");
        WebSocketSession sessionB = new TestWebSocketSession("sessionB");

        // Create mutual block
        databaseService.blockUser("userA", "userB");

        // Try to match: should NOT form a match because of the block
        matchmakingService.joinQueue("userA", "Santiago", "20", "VOICE", sessionA);
        matchmakingService.joinQueue("userB", "Santiago", "20", "VOICE", sessionB);

        // Verify no room is created
        assertNull(gameSessionService.getRoomForUser("userA"));
        assertNull(gameSessionService.getRoomForUser("userB"));

        // Tickets should NOT be reserved/deducted
        assertEquals(5, databaseService.getTicketBalance("userA"));
        assertEquals(3, databaseService.getTicketBalance("userB"));
    }

    @Test
    public void testEmergencyDisconnectAndPermanentBlock() {
        WebSocketSession sessionA = new TestWebSocketSession("sessionA");
        WebSocketSession sessionB = new TestWebSocketSession("sessionB");

        // Match Alice and Bob
        matchmakingService.joinQueue("userA", "Santiago", "20", "SILENT", sessionA);
        matchmakingService.joinQueue("userB", "Santiago", "20", "SILENT", sessionB);

        GameRoom room = gameSessionService.getRoomForUser("userA");
        assertNotNull(room);

        // Alice triggers EMERGENCY_DISCONNECT
        gameSessionService.handleEmergencyDisconnect("userA");

        // Verify room is destroyed
        assertNull(gameSessionService.getRoomForUser("userA"));
        assertNull(gameSessionService.getRoomForUser("userB"));

        // Verify reciprocal blocks are registered permanently
        assertTrue(databaseService.isMutuallyBlocked("userA", "userB"));
    }

    @Test
    public void testWaitingReconnectGraceTimeoutRefunds() throws Exception {
        WebSocketSession sessionA = new TestWebSocketSession("sessionA");
        WebSocketSession sessionD = new TestWebSocketSession("sessionD");

        // Match Alice and David in VOICE
        matchmakingService.joinQueue("userA", "Santiago", "20", "VOICE", sessionA);
        matchmakingService.joinQueue("userD", "Santiago", "20", "VOICE", sessionD);

        // Ticket check: Alice: 5->4, David: 1->0
        assertEquals(4, databaseService.getTicketBalance("userA"));
        assertEquals(0, databaseService.getTicketBalance("userD"));

        GameRoom room = gameSessionService.getRoomForUser("userA");
        assertNotNull(room);

        // Alice disconnects (transient network cut)
        gameSessionService.handleDisconnect("userA");
        assertTrue(room.isPaused());

        // Invoke the private timeout expiration callback directly via reflection
        Method handler = GameSessionService.class.getDeclaredMethod("handleGracePeriodExpiry", String.class);
        handler.setAccessible(true);
        handler.invoke(gameSessionService, room.getRoomId());

        // Verify session is terminated
        assertNull(gameSessionService.getRoomForUser("userA"));

        // Verify that tickets are refunded automatically because they never confirmed starting
        assertEquals(5, databaseService.getTicketBalance("userA"));
        assertEquals(1, databaseService.getTicketBalance("userD"));
    }

    @Test
    public void testNoRefundIfGameStarted() throws Exception {
        WebSocketSession sessionA = new TestWebSocketSession("sessionA");
        WebSocketSession sessionD = new TestWebSocketSession("sessionD");

        // Match Alice and David in VOICE
        matchmakingService.joinQueue("userA", "Santiago", "20", "VOICE", sessionA);
        matchmakingService.joinQueue("userD", "Santiago", "20", "VOICE", sessionD);

        GameRoom room = gameSessionService.getRoomForUser("userA");
        assertNotNull(room);

        // Both players confirm starting the game
        gameSessionService.handleGameReady("userA");
        gameSessionService.handleGameReady("userD");

        // Alice disconnects
        gameSessionService.handleDisconnect("userA");

        // Expire grace period
        Method handler = GameSessionService.class.getDeclaredMethod("handleGracePeriodExpiry", String.class);
        handler.setAccessible(true);
        handler.invoke(gameSessionService, room.getRoomId());

        // Verify room destroyed, but NO tickets refunded (tickets spent because game started)
        assertNull(gameSessionService.getRoomForUser("userA"));
        assertEquals(4, databaseService.getTicketBalance("userA"));
        assertEquals(0, databaseService.getTicketBalance("userD"));
    }

    @Test
    public void testMatchmakingExcludesPreviouslyMetOrMatchedUsers() {
        WebSocketSession sessionA = new TestWebSocketSession("sessionA");
        WebSocketSession sessionB = new TestWebSocketSession("sessionB");

        // Pre-insert an existing mailbox match between userA and userB
        jdbcTemplate.update(
            "INSERT INTO mailbox_matches (id, user_a_id, user_b_id, user_a_name, user_b_name, decision_a, decision_b, matched) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            "match_test_prev", "userA", "userB", "Alice", "Bob", "KEEP_IN_TOUCH", "KEEP_IN_TOUCH", true
        );

        assertTrue(databaseService.haveUsersMetOrMatched("userA", "userB"));
        assertTrue(databaseService.haveUsersMetOrMatched("userB", "userA"));
        assertFalse(databaseService.haveUsersMetOrMatched("userA", "userD"));

        // Both join queue for Buscar Cita
        matchmakingService.joinQueue("userA", "Santiago", "20", "SILENT", sessionA);
        matchmakingService.joinQueue("userB", "Santiago", "20", "SILENT", sessionB);

        // They must NOT be matched because they already have a match/baul record
        assertNull(gameSessionService.getRoomForUser("userA"));
        assertNull(gameSessionService.getRoomForUser("userB"));

        // Now a new user enters who hasn't met userA
        WebSocketSession sessionD = new TestWebSocketSession("sessionD");
        matchmakingService.joinQueue("userD", "Santiago", "20", "SILENT", sessionD);

        // userA and userD should be matched!
        assertNotNull(gameSessionService.getRoomForUser("userA"));
        assertNotNull(gameSessionService.getRoomForUser("userD"));
    }

    @Test
    public void testHomeVisitDateRoomCreation() {
        TestWebSocketSession sessionA = new TestWebSocketSession("sessionA");
        TestWebSocketSession sessionB = new TestWebSocketSession("sessionB");

        gameSessionService.createRoom(
            "room_home_visit",
            "userA", sessionA, null, null, "Alice", "[]",
            "userB", sessionB, null, null, "Bob", "[]",
            "HOME"
        );

        GameRoom room = gameSessionService.getRoomForUser("userA");
        assertNotNull(room);
        assertEquals("HOME", room.getMode());

        // Verify SESSION_INIT dispatched with isHomeVisitActive and hostUserId
        assertFalse(sessionA.sentMessages.isEmpty());
        String msgA = sessionA.sentMessages.get(0);
        assertTrue(msgA.contains("\"isHomeVisitActive\":true"));
        assertTrue(msgA.contains("\"hostUserId\":\"userA\""));
        assertTrue(msgA.contains("\"mode\":\"HOME\""));

        assertFalse(sessionB.sentMessages.isEmpty());
        String msgB = sessionB.sentMessages.get(0);
        assertTrue(msgB.contains("\"isHomeVisitActive\":true"));
        assertTrue(msgB.contains("\"hostUserId\":\"userA\""));
        assertTrue(msgB.contains("\"mode\":\"HOME\""));
    }

    @Test
    public void testCampfireChatRelaying() throws Exception {
        TestWebSocketSession sessionA = new TestWebSocketSession("ws_chat_a");
        TestWebSocketSession sessionB = new TestWebSocketSession("ws_chat_b");

        // Authenticate users
        gameWebSocketHandler.handleMessage(sessionA, new org.springframework.web.socket.TextMessage("{\"type\":\"USER_ONLINE\",\"userId\":\"userA\"}"));
        gameWebSocketHandler.handleMessage(sessionB, new org.springframework.web.socket.TextMessage("{\"type\":\"USER_ONLINE\",\"userId\":\"userB\"}"));

        // Create game room
        gameSessionService.createRoom(
            "room_campfire_chat",
            "userA", sessionA, null, null, "Alice", "[]",
            "userB", sessionB, null, null, "Bob", "[]",
            "CAMPFIRE"
        );

        // Clear sent messages from sessionB
        sessionB.sentMessages.clear();

        // User A sends CAMPFIRE_CHAT
        gameWebSocketHandler.handleMessage(sessionA, new org.springframework.web.socket.TextMessage("{\"type\":\"CAMPFIRE_CHAT\",\"text\":\"¡Qué linda noche en la fogata!\"}"));

        // Verify partner (User B) received the forwarded message
        assertEquals(1, sessionB.sentMessages.size());
        assertTrue(sessionB.sentMessages.get(0).contains("\"type\":\"CAMPFIRE_CHAT\""));
        assertTrue(sessionB.sentMessages.get(0).contains("¡Qué linda noche en la fogata!"));
    }

    @Test
    public void testGenderFilteringReciprocal() {
        TestWebSocketSession sessionA = new TestWebSocketSession("ws_a");
        TestWebSocketSession sessionB = new TestWebSocketSession("ws_b");
        TestWebSocketSession sessionD = new TestWebSocketSession("ws_d");

        // userA is MAN, seeking WOMAN
        // userB is MAN, seeking WOMAN
        // They must NOT match each other
        matchmakingService.joinQueue("userA", "Santiago", "20", "SILENT", sessionA, null, null, "Alice", "[]", 25.0, "MAN", "WOMAN", false, null, null);
        matchmakingService.joinQueue("userB", "Santiago", "20", "SILENT", sessionB, null, null, "Bob", "[]", 25.0, "MAN", "WOMAN", false, null, null);

        assertNull(gameSessionService.getRoomForUser("userA"));
        assertNull(gameSessionService.getRoomForUser("userB"));

        // userD is WOMAN, seeking MAN -> Should match userA!
        matchmakingService.joinQueue("userD", "Santiago", "20", "SILENT", sessionD, null, null, "Dayana", "[]", 25.0, "WOMAN", "MAN", false, null, null);

        assertNotNull(gameSessionService.getRoomForUser("userA"));
        assertNotNull(gameSessionService.getRoomForUser("userD"));
        assertNull(gameSessionService.getRoomForUser("userB")); // Bob still waiting
    }

    @Test
    public void testProximityPrioritization() {
        TestWebSocketSession sessionA = new TestWebSocketSession("ws_prox_a");
        TestWebSocketSession sessionB = new TestWebSocketSession("ws_prox_b");
        TestWebSocketSession sessionD = new TestWebSocketSession("ws_prox_d");

        // userA in Santiago Centro (-33.4489, -70.6693)
        matchmakingService.joinQueue("userA", "Santiago", "20", "SILENT", sessionA, null, null, "Alice", "[]", 100.0, "OTHER", "ANY", false, -33.4489, -70.6693);

        // userB in Rancagua (~80 km away)
        matchmakingService.joinQueue("userB", "Rancagua", "20", "SILENT", sessionB, null, null, "Bob", "[]", 100.0, "OTHER", "ANY", false, -34.1708, -70.7444);

        // userD in Providencia (~5 km away)
        matchmakingService.joinQueue("userD", "Providencia", "20", "SILENT", sessionD, null, null, "Dayana", "[]", 100.0, "OTHER", "ANY", false, -33.4314, -70.6093);

        // userA should match with the closest candidate (userD in Providencia), NOT userB in Rancagua
        GameRoom roomA = gameSessionService.getRoomForUser("userA");
        assertNotNull(roomA);
        assertTrue(roomA.getExplorerId().equals("userD") || roomA.getGuideId().equals("userD"));
        assertNull(gameSessionService.getRoomForUser("userB"));

        // And verify distanceKm is dispatched in SESSION_INIT
        assertTrue(sessionA.sentMessages.get(0).contains("\"distanceKm\":"));
    }

    /**
     * Lightweight custom implementation of WebSocketSession for tests to bypass Byte Buddy Java 25 compatibility issues.
     */
    private static class TestWebSocketSession implements WebSocketSession {
        private final String id;
        private boolean open = true;
        private final Map<String, Object> attributes = new HashMap<>();
        public final List<String> sentMessages = new ArrayList<>();

        public TestWebSocketSession(String id) {
            this.id = id;
        }

        @Override public String getId() { return id; }
        @Override public URI getUri() { return null; }
        @Override public HttpHeaders getHandshakeHeaders() { return null; }
        @Override public Map<String, Object> getAttributes() { return attributes; }
        @Override public Principal getPrincipal() { return null; }
        @Override public InetSocketAddress getLocalAddress() { return null; }
        @Override public InetSocketAddress getRemoteAddress() { return null; }
        @Override public String getAcceptedProtocol() { return null; }
        @Override public void setTextMessageSizeLimit(int sizeLimit) {}
        @Override public int getTextMessageSizeLimit() { return 0; }
        @Override public void setBinaryMessageSizeLimit(int sizeLimit) {}
        @Override public int getBinaryMessageSizeLimit() { return 0; }
        @Override public List<WebSocketExtension> getExtensions() { return Collections.emptyList(); }
        @Override public void sendMessage(WebSocketMessage<?> message) throws IOException {
            sentMessages.add(message.getPayload().toString());
        }
        @Override public boolean isOpen() { return open; }
        @Override public void close() throws IOException { open = false; }
        @Override public void close(CloseStatus status) throws IOException { open = false; }
    }
}
