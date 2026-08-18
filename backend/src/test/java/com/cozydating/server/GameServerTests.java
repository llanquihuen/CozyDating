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
    private JwtUtil jwtUtil;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    public void cleanAndSeedDb() {
        jdbcTemplate.execute("DELETE FROM user_blocks");
        jdbcTemplate.execute("DELETE FROM users");
        
        // Seed users
        jdbcTemplate.update("INSERT INTO users (id, username, tickets_balance) VALUES (?, ?, ?)", "userA", "Alice", 5);
        jdbcTemplate.update("INSERT INTO users (id, username, tickets_balance) VALUES (?, ?, ?)", "userB", "Bob", 3);
        jdbcTemplate.update("INSERT INTO users (id, username, tickets_balance) VALUES (?, ?, ?)", "userC", "Charlie", 0);
        jdbcTemplate.update("INSERT INTO users (id, username, tickets_balance) VALUES (?, ?, ?)", "userD", "David", 1);

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

    /**
     * Lightweight custom implementation of WebSocketSession for tests to bypass Byte Buddy Java 25 compatibility issues.
     */
    private static class TestWebSocketSession implements WebSocketSession {
        private final String id;
        private boolean open = true;
        private final Map<String, Object> attributes = new HashMap<>();

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
        @Override public void sendMessage(WebSocketMessage<?> message) throws IOException {}
        @Override public boolean isOpen() { return open; }
        @Override public void close() throws IOException { open = false; }
        @Override public void close(CloseStatus status) throws IOException { open = false; }
    }
}
