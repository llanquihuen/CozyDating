package com.cozydating.server.controller;

import com.cozydating.server.service.DatabaseService;
import com.cozydating.server.service.storage.StorageService;
import com.cozydating.server.util.JwtUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@CrossOrigin(origins = "*")
@RequestMapping("/api/media")
public class MediaController {

    private static final Logger logger = LoggerFactory.getLogger(MediaController.class);

    private static final List<String> ALLOWED_EXTENSIONS = Arrays.asList(
            ".jpg", ".jpeg", ".png", ".webp", ".gif"
    );

    private static final List<String> ALLOWED_CONTENT_TYPES = Arrays.asList(
            "image/jpeg",
            "image/png",
            "image/webp",
            "image/jpg",
            "image/gif",
            "image/pjpeg",
            "image/x-png"
    );

    private boolean isImage(MultipartFile file) {
        String contentType = file.getContentType();
        if (contentType != null && ALLOWED_CONTENT_TYPES.contains(contentType.toLowerCase())) {
            return true;
        }
        String originalFilename = file.getOriginalFilename();
        if (originalFilename != null && originalFilename.contains(".")) {
            String ext = originalFilename.substring(originalFilename.lastIndexOf(".")).toLowerCase();
            return ALLOWED_EXTENSIONS.contains(ext);
        }
        return false;
    }

    @Autowired
    private StorageService storageService;

    @Autowired
    private DatabaseService databaseService;

    @Autowired
    private JwtUtil jwtUtil;

    /**
     * Upload an image file (multipart/form-data).
     *
     * @param file the image binary file
     * @param folder target subfolder ("photos", "avatars", etc.)
     * @param setAsProfile if true and userId/token is provided, automatically updates user's profilePhoto
     */
    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> uploadImage(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "folder", required = false, defaultValue = "photos") String folder,
            @RequestParam(value = "userId", required = false) String userId,
            @RequestParam(value = "setAsProfile", required = false, defaultValue = "false") boolean setAsProfile,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {

        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "No se proporcionó ningún archivo o el archivo está vacío"));
        }

        if (!isImage(file)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "Formato de imagen no soportado. Permitidos: JPG, PNG, WEBP, GIF"
            ));
        }

        try {
            String fileUrl = storageService.uploadFile(file, folder);

            String resolvedUserId = userId;
            if ((resolvedUserId == null || resolvedUserId.isBlank()) && authHeader != null && authHeader.startsWith("Bearer ")) {
                resolvedUserId = jwtUtil.verifyTokenAndGetUserId(authHeader.substring(7));
            }

            if (setAsProfile && resolvedUserId != null && !resolvedUserId.isBlank()) {
                databaseService.updateProfilePhoto(resolvedUserId, fileUrl);
                logger.info("[MediaController] Updated profilePhoto for user {} to {}", resolvedUserId, fileUrl);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("url", fileUrl);
            if (resolvedUserId != null) {
                response.put("userId", resolvedUserId);
            }

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("[MediaController] Error uploading file: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("error", "Error al subir la imagen: " + e.getMessage()));
        }
    }

    /**
     * Delete an uploaded image by URL.
     */
    @DeleteMapping
    public ResponseEntity<?> deleteImage(@RequestParam("url") String fileUrl) {
        if (fileUrl == null || fileUrl.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Parámetro 'url' es requerido"));
        }

        try {
            storageService.deleteFile(fileUrl);
            return ResponseEntity.ok(Map.of("success", true, "message", "Imagen eliminada si existía"));
        } catch (Exception e) {
            logger.error("[MediaController] Error deleting file: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("error", "Error al eliminar la imagen: " + e.getMessage()));
        }
    }
}
