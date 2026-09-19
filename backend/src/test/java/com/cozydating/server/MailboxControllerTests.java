package com.cozydating.server;

import com.cozydating.server.model.MailboxMatch;
import com.cozydating.server.model.User;
import com.cozydating.server.service.DatabaseService;
import com.cozydating.server.util.JwtUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class MailboxControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DatabaseService databaseService;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    public void cleanTables() {
        jdbcTemplate.execute("DELETE FROM mailbox_matches");
        jdbcTemplate.execute("DELETE FROM users");
    }

    @Test
    public void testMailboxZeroRejectionAndMutualMatchFlow() throws Exception {
        // Create userA (Alice) and userB (Bob)
        User userA = new User("userA", "Alice", "alice@test.com", "hash", 24, "Santiago", 5, "{}", "[\"game_coop\"]", "photoA", "{}");
        User userB = new User("userB", "Bob", "bob@test.com", "hash", 26, "Providencia", 3, "{}", "[\"game_coop\"]", "photoB", "{}");
        databaseService.createUser(userA);
        databaseService.createUser(userB);

        // Generate a post-date mailbox match letter
        String matchId = "match_100";
        MailboxMatch match = new MailboxMatch(
            matchId,
            "userA",
            "userB",
            "Alice",
            "Bob",
            "{}",
            "{}",
            "photoA",
            "photoB",
            24,
            26,
            "Santiago",
            "Providencia",
            "[\"game_coop\"]",
            "PENDING",
            null,
            "PENDING",
            null,
            false
        );
        databaseService.createMailboxMatch(match);

        // 1. Check badge count for Alice
        mockMvc.perform(get("/api/mailbox/badge-count?userId=userA"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unreadCount").value(1));

        // 2. Alice fetches her mailbox: sees Bob's photo, age, commune, and PENDING status
        mockMvc.perform(get("/api/mailbox?userId=userA"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].partnerName").value("Bob"))
                .andExpect(jsonPath("$[0].partnerPhoto").value("photoB"))
                .andExpect(jsonPath("$[0].partnerAge").value(26))
                .andExpect(jsonPath("$[0].myDecision").value("PENDING"))
                .andExpect(jsonPath("$[0].isMutualMatch").value(false));

        // 3. Alice submits "KEEP_IN_TOUCH" with a note
        String aliceDecision = "{\"userId\":\"userA\",\"matchId\":\"match_100\",\"decision\":\"KEEP_IN_TOUCH\",\"note\":\"Me encanto la mazmorra 🗡️\"}";
        mockMvc.perform(post("/api/mailbox/decision")
                .contentType(MediaType.APPLICATION_JSON)
                .content(aliceDecision))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.myDecision").value("KEEP_IN_TOUCH"))
                .andExpect(jsonPath("$.isMutualMatch").value(false)); // Bob has not decided yet

        // 4. Bob submits "KEEP_IN_TOUCH" with a note -> MUTUAL MATCH UNLOCKED!
        String bobDecision = "{\"userId\":\"userB\",\"matchId\":\"match_100\",\"decision\":\"KEEP_IN_TOUCH\",\"note\":\"Ojala juguemos de nuevo! 🎮\"}";
        mockMvc.perform(post("/api/mailbox/decision")
                .contentType(MediaType.APPLICATION_JSON)
                .content(bobDecision))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.myDecision").value("KEEP_IN_TOUCH"))
                .andExpect(jsonPath("$.isMutualMatch").value(true))
                .andExpect(jsonPath("$.partnerNote").value("Me encanto la mazmorra 🗡️"));

        // 5. Alice checks her mailbox again: sees isMutualMatch == true and Bob's note
        mockMvc.perform(get("/api/mailbox?userId=userA"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].isMutualMatch").value(true))
                .andExpect(jsonPath("$[0].partnerNote").value("Ojala juguemos de nuevo! 🎮"));

        // 6. Check badge count for Alice: now 0 because decision is made
        mockMvc.perform(get("/api/mailbox/badge-count?userId=userA"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unreadCount").value(0));
    }

    @Test
    public void testTernaryRomanceMeetsFriendshipAsymmetricPrivacy() throws Exception {
        User userA = new User("userA", "Alice", "alice@test.com", "hash", 24, "Santiago", 5, "{}", "[\"game_coop\"]", "photoA", "{}");
        User userB = new User("userB", "Bob", "bob@test.com", "hash", 26, "Providencia", 3, "{}", "[\"game_coop\"]", "photoB", "{}");
        databaseService.createUser(userA);
        databaseService.createUser(userB);

        String matchId = "match_ternary_1";
        MailboxMatch match = new MailboxMatch(
            matchId, "userA", "userB", "Alice", "Bob", "{}", "{}", "photoA", "photoB",
            24, 26, "Santiago", "Providencia", "[]", "PENDING", null, "PENDING", null, false
        );
        databaseService.createMailboxMatch(match);

        // Alice votes ROMANCE
        mockMvc.perform(post("/api/mailbox/decision")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"userId\":\"userA\",\"matchId\":\"match_ternary_1\",\"decision\":\"ROMANCE\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.isMutualMatch").value(false));

        // Bob votes FRIENDSHIP -> Mutual Match downgraded gracefully to FRIENDSHIP!
        mockMvc.perform(post("/api/mailbox/decision")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"userId\":\"userB\",\"matchId\":\"match_ternary_1\",\"decision\":\"FRIENDSHIP\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.isMutualMatch").value(true))
                .andExpect(jsonPath("$.matchType").value("FRIENDSHIP"));

        // Bob fetches his mailbox: PRIVACY SHIELD!
        // Bob must NOT see that Alice voted ROMANCE. He must only see FRIENDSHIP!
        mockMvc.perform(get("/api/mailbox?userId=userB"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].isMutualMatch").value(true))
                .andExpect(jsonPath("$[0].matchType").value("FRIENDSHIP"))
                .andExpect(jsonPath("$[0].partnerDecision").value("FRIENDSHIP"));
    }

    @Test
    public void testTernaryBothRomanceMatch() throws Exception {
        User userA = new User("userA", "Alice", "alice@test.com", "hash", 24, "Santiago", 5, "{}", "[\"game_coop\"]", "photoA", "{}");
        User userB = new User("userB", "Bob", "bob@test.com", "hash", 26, "Providencia", 3, "{}", "[\"game_coop\"]", "photoB", "{}");
        databaseService.createUser(userA);
        databaseService.createUser(userB);

        String matchId = "match_romance_spark";
        MailboxMatch match = new MailboxMatch(
            matchId, "userA", "userB", "Alice", "Bob", "{}", "{}", "photoA", "photoB",
            24, 26, "Santiago", "Providencia", "[]", "PENDING", null, "PENDING", null, false
        );
        databaseService.createMailboxMatch(match);

        // Alice votes ROMANCE
        mockMvc.perform(post("/api/mailbox/decision")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"userId\":\"userA\",\"matchId\":\"match_romance_spark\",\"decision\":\"ROMANCE\"}"))
                .andExpect(status().isOk());

        // Bob votes ROMANCE -> SPARK MUTUAL MATCH!
        mockMvc.perform(post("/api/mailbox/decision")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"userId\":\"userB\",\"matchId\":\"match_romance_spark\",\"decision\":\"ROMANCE\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.isMutualMatch").value(true))
                .andExpect(jsonPath("$.matchType").value("ROMANCE"));

        mockMvc.perform(get("/api/mailbox?userId=userA"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].isMutualMatch").value(true))
                .andExpect(jsonPath("$[0].matchType").value("ROMANCE"));
    }

    @Test
    public void testTernaryPassResultsInZeroMatch() throws Exception {
        User userA = new User("userA", "Alice", "alice@test.com", "hash", 24, "Santiago", 5, "{}", "[\"game_coop\"]", "photoA", "{}");
        User userB = new User("userB", "Bob", "bob@test.com", "hash", 26, "Providencia", 3, "{}", "[\"game_coop\"]", "photoB", "{}");
        databaseService.createUser(userA);
        databaseService.createUser(userB);

        String matchId = "match_pass_1";
        MailboxMatch match = new MailboxMatch(
            matchId, "userA", "userB", "Alice", "Bob", "{}", "{}", "photoA", "photoB",
            24, 26, "Santiago", "Providencia", "[]", "PENDING", null, "PENDING", null, false
        );
        databaseService.createMailboxMatch(match);

        // Alice votes ROMANCE
        mockMvc.perform(post("/api/mailbox/decision")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"userId\":\"userA\",\"matchId\":\"match_pass_1\",\"decision\":\"ROMANCE\"}"))
                .andExpect(status().isOk());

        // Bob votes PASS
        mockMvc.perform(post("/api/mailbox/decision")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"userId\":\"userB\",\"matchId\":\"match_pass_1\",\"decision\":\"PASS\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.isMutualMatch").value(false))
                .andExpect(jsonPath("$.matchType").value("NONE"));
    }
}
