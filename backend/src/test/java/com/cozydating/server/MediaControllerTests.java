package com.cozydating.server;

import com.cozydating.server.model.User;
import com.cozydating.server.service.DatabaseService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
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
public class MediaControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DatabaseService databaseService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    public void setup() {
        jdbcTemplate.execute("DELETE FROM users");
    }

    @Test
    public void testUploadImageSuccessAndSetProfilePhoto() throws Exception {
        User user = new User("user_photo_test", "photouser", "photo@test.com", "hash", 25, "Santiago", 5, "{}", "[]", null, "{}");
        databaseService.createUser(user);

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "test-avatar.png",
                "image/png",
                "fake image content bytes".getBytes()
        );

        mockMvc.perform(multipart("/api/media/upload")
                        .file(file)
                        .param("folder", "photos")
                        .param("userId", "user_photo_test")
                        .param("setAsProfile", "true"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.url").exists())
                .andExpect(jsonPath("$.userId").value("user_photo_test"));

        User updated = databaseService.findUserById("user_photo_test");
        assertNotNull(updated);
        assertNotNull(updated.getProfilePhoto());
        assertTrue(updated.getProfilePhoto().contains("/media/photos/"));
    }

    @Test
    public void testUploadInvalidFileTypeRejected() throws Exception {
        MockMultipartFile invalidFile = new MockMultipartFile(
                "file",
                "malicious.exe",
                "application/octet-stream",
                "bad bytes".getBytes()
        );

        mockMvc.perform(multipart("/api/media/upload")
                        .file(invalidFile))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").exists());
    }

    @Test
    public void testUploadWithOctetStreamContentTypeAndJpgExtensionSuccess() throws Exception {
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "my_picture.jpg",
                "application/octet-stream",
                "binary image data".getBytes()
        );

        mockMvc.perform(multipart("/api/media/upload")
                        .file(file))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.url").exists());
    }

    @Test
    public void testDeleteImage() throws Exception {
        mockMvc.perform(delete("/api/media")
                        .param("url", "http://localhost:8080/media/photos/sample.jpg"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
    }
}
