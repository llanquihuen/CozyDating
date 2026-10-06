package com.cozydating.server;

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
public class AuthAndRoomPersistenceTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DatabaseService databaseService;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    public void cleanAndSeed() {
        jdbcTemplate.execute("DELETE FROM user_blocks");
        jdbcTemplate.execute("DELETE FROM users");
    }

    @Test
    public void testUserRegistrationAndLoginFlow() throws Exception {
        String registerPayload = "{" +
                "\"username\":\"cozyGamer\"," +
                "\"password\":\"secret123\"," +
                "\"email\":\"gamer@cozy.com\"," +
                "\"age\":23," +
                "\"commune\":\"Providencia\"," +
                "\"avatarConfig\":\"{\\\"hairStyle\\\":\\\"long_flow\\\"}\"," +
                "\"tastes\":\"[\\\"cozy_games\\\",\\\"lofi\\\",\\\"cats\\\"]\"," +
                "\"roomConfig\":\"{\\\"wallpaper\\\":\\\"solid_sage_green\\\"}\"" +
                "}";

        // 1. Register
        mockMvc.perform(post("/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(registerPayload))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.user.username").value("cozyGamer"))
                .andExpect(jsonPath("$.user.ticketsBalance").value(5));

        // Verify in DB
        User user = databaseService.findUserByUsername("cozyGamer");
        assertNotNull(user);
        assertEquals("gamer@cozy.com", user.getEmail());
        assertTrue(databaseService.getPasswordEncoder().matches("secret123", user.getPasswordHash()));

        // 2. Login with correct password
        String loginPayload = "{\"username\":\"cozyGamer\",\"password\":\"secret123\"}";
        mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginPayload))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.user.username").value("cozyGamer"));

        // 3. Login with wrong password
        String badLoginPayload = "{\"username\":\"cozyGamer\",\"password\":\"wrongPass\"}";
        mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(badLoginPayload))
                .andExpect(status().isUnauthorized());
    }

    @Test
    public void testProfileCardStyleAndAgeRangePersistence() throws Exception {
        User user = new User("user_card_1", "cardMaker", "card@test.com",
                databaseService.getPasswordEncoder().encode("pass123"), 27, "Ñuñoa", 5, "{}", "[]", "{}");
        databaseService.createUser(user);
        String token = jwtUtil.generateToken("user_card_1", "cardMaker", 100000);

        // New accounts: no card style and no age filter
        User fresh = databaseService.findUserById("user_card_1");
        assertNull(fresh.getCardStyle());
        assertNull(fresh.getSeekingAgeMin());
        assertNull(fresh.getSeekingAgeMax());

        String style = "{\"themeId\":\"arcade\",\"accent\":\"#00F0FF\",\"phrase\":\"Speedruns y ramen\",\"featuredTastes\":[\"tech_pc_gamer\"]}";
        mockMvc.perform(post("/auth/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"bio\":\"  Hago el mejor ramen  \",\"cardStyle\":\"" + style.replace("\"", "\\\"") + "\",\"seekingAgeMin\":30,\"seekingAgeMax\":24}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.bio").value("Hago el mejor ramen"))
                .andExpect(jsonPath("$.cardStyle").value(style))
                .andExpect(jsonPath("$.seekingAgeMin").value(24))   // swapped into order
                .andExpect(jsonPath("$.seekingAgeMax").value(30));

        User saved = databaseService.findUserById("user_card_1");
        assertEquals(style, saved.getCardStyle());
        assertEquals("Hago el mejor ramen", saved.getBio());
        assertEquals(24, saved.getSeekingAgeMin());
        assertEquals(30, saved.getSeekingAgeMax());

        // Out-of-range bounds are clamped to 18..99; an unrelated update keeps the card fields
        mockMvc.perform(post("/auth/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"seekingAgeMin\":12,\"seekingAgeMax\":140}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seekingAgeMin").value(18))
                .andExpect(jsonPath("$.seekingAgeMax").value(99));
        mockMvc.perform(post("/auth/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"commune\":\"Providencia\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.cardStyle").value(style))
                .andExpect(jsonPath("$.seekingAgeMax").value(99));

        // Null clears the filter again (no limit)
        mockMvc.perform(post("/auth/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"seekingAgeMin\":null,\"seekingAgeMax\":null}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seekingAgeMin").doesNotExist());
        User cleared = databaseService.findUserById("user_card_1");
        assertNull(cleared.getSeekingAgeMin());
        assertNull(cleared.getSeekingAgeMax());
    }

    @Test
    public void testRegistrationAcceptsCardStyle() throws Exception {
        String payload = "{\"username\":\"newCard\",\"password\":\"secret123\",\"email\":\"new@card.com\",\"age\":30," +
                "\"cardStyle\":\"{\\\"themeId\\\":\\\"matcha\\\"}\",\"seekingAgeMin\":25}";
        mockMvc.perform(post("/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(payload))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.cardStyle").value("{\"themeId\":\"matcha\"}"))
                .andExpect(jsonPath("$.user.seekingAgeMin").value(25));
        User user = databaseService.findUserByUsername("newCard");
        assertEquals("{\"themeId\":\"matcha\"}", user.getCardStyle());
        assertEquals(25, user.getSeekingAgeMin());
        assertNull(user.getSeekingAgeMax());
    }

    @Test
    public void testRoomConfigPersistence() throws Exception {
        User user = new User(
                "user_test_1",
                "roomDesigner",
                "designer@test.com",
                databaseService.getPasswordEncoder().encode("pass123"),
                25,
                "Santiago",
                5,
                "{}",
                "[]",
                "{\"wallpaper\":\"rustic_wood\",\"furniture\":[]}"
        );
        databaseService.createUser(user);

        String token = jwtUtil.generateToken("user_test_1", "roomDesigner", 100000);

        // Fetch initial room
        mockMvc.perform(get("/api/user/room")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.roomConfig").value("{\"wallpaper\":\"rustic_wood\",\"furniture\":[]}"));

        // Update room with customized furniture (e.g. gaming PC + cat tree)
        String updatedRoom = "{\"wallpaper\":\"starry_night\",\"furniture\":[{\"id\":\"gaming_pc\",\"typeName\":\"gaming_pc_desk\"}]}";
        String updatePayload = "{\"roomConfig\":\"" + updatedRoom.replace("\"", "\\\"") + "\"}";

        mockMvc.perform(put("/api/user/room")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(updatePayload))
                .andExpect(status().isOk());

        // Verify DB update
        User updatedUser = databaseService.findUserById("user_test_1");
        assertNotNull(updatedUser);
        assertEquals(updatedRoom, updatedUser.getRoomConfig());
    }
}
