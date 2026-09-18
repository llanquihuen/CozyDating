package com.cozydating.server;

import com.cozydating.server.model.User;
import com.cozydating.server.service.DatabaseService;
import com.cozydating.server.service.MatchmakingService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class VerificationControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DatabaseService databaseService;

    @Autowired
    private MatchmakingService matchmakingService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    public void setup() {
        jdbcTemplate.execute("DELETE FROM users");
    }

    @Test
    public void testVerifyIdentitySuccess() throws Exception {
        User user = new User("user_verif", "pedro", "pedro@test.com", "hash", 24, "Santiago", 5, "{}", "[]", "http://localhost:8080/media/photos/photo.jpg", "{}");
        user.setVerified(false);
        databaseService.createUser(user);

        MockMultipartFile selfie = new MockMultipartFile(
                "selfie",
                "selfie_live.jpg",
                "image/jpeg",
                "simulated live selfie bytes".getBytes()
        );

        mockMvc.perform(multipart("/api/verification/verify")
                        .file(selfie)
                        .param("userId", "user_verif"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.isVerified").value(true))
                .andExpect(jsonPath("$.similarity").exists());

        User updated = databaseService.findUserById("user_verif");
        assertNotNull(updated);
        assertTrue(updated.isVerified());
        assertNotNull(updated.getVerificationSelfie());
    }

    @Test
    public void testVerifyFailsWithoutProfilePhoto() throws Exception {
        User user = new User("user_no_photo", "lucia", "lucia@test.com", "hash", 23, "Santiago", 5, "{}", "[]", null, "{}");
        user.setVerified(false);
        databaseService.createUser(user);

        MockMultipartFile selfie = new MockMultipartFile(
                "selfie",
                "selfie.jpg",
                "image/jpeg",
                "selfie bytes".getBytes()
        );

        mockMvc.perform(multipart("/api/verification/verify")
                        .file(selfie)
                        .param("userId", "user_no_photo"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").exists());
    }

    @Test
    public void testGetVerificationStatus() throws Exception {
        User user = new User("user_status", "camilo", "camilo@test.com", "hash", 25, "Santiago", 5, "{}", "[]", null, "{}");
        user.setVerified(true);
        databaseService.createUser(user);

        mockMvc.perform(get("/api/verification/status")
                        .param("userId", "user_status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.isVerified").value(true));
    }

    @Test
    public void testMatchmakingRejectsUnverifiedUser() {
        User unverified = new User("user_unverified", "unver", "unver@test.com", "hash", 22, "Santiago", 5, "{}", "[]", null, "{}");
        unverified.setVerified(false);
        databaseService.createUser(unverified);

        boolean joined = matchmakingService.joinQueue("user_unverified", "Santiago", "20", "SILENT", null);
        assertFalse(joined, "Matchmaking should reject unverified users");
    }
}
