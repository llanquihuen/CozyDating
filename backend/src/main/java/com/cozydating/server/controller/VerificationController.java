package com.cozydating.server.controller;

import com.cozydating.server.model.User;
import com.cozydating.server.service.DatabaseService;
import com.cozydating.server.service.verification.FaceVerificationService;
import com.cozydating.server.util.JwtUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.Map;

@RestController
@CrossOrigin(origins = "*")
@RequestMapping("/api/verification")
public class VerificationController {

    private static final Logger logger = LoggerFactory.getLogger(VerificationController.class);

    @Autowired
    private FaceVerificationService faceVerificationService;

    @Autowired
    private DatabaseService databaseService;

    @Autowired
    private JwtUtil jwtUtil;

    /**
     * Submit a real-time selfie to verify against user's profile photo.
     */
    @PostMapping(value = "/verify", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> verifyIdentity(
            @RequestParam("selfie") MultipartFile selfie,
            @RequestParam(value = "userId", required = false) String userId,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {

        String resolvedUserId = userId;
        if ((resolvedUserId == null || resolvedUserId.isBlank()) && authHeader != null && authHeader.startsWith("Bearer ")) {
            resolvedUserId = jwtUtil.verifyTokenAndGetUserId(authHeader.substring(7));
        }

        if (resolvedUserId == null || resolvedUserId.isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "Se requiere identificación de usuario o token válido"));
        }

        String dbUserId = databaseService.resolveDbUserId(resolvedUserId);
        User user = databaseService.findUserById(dbUserId);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", "Usuario no encontrado"));
        }

        if (user.getProfilePhoto() == null || user.getProfilePhoto().isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "Debes tener una foto de perfil antes de poder verificar tu identidad."
            ));
        }

        try {
            FaceVerificationService.VerificationResult result =
                    faceVerificationService.verifyFaces(dbUserId, user.getProfilePhoto(), selfie);

            if (result.verified()) {
                databaseService.updateVerificationStatus(dbUserId, true, result.selfieUrl());
                user.setVerified(true);
                user.setVerificationSelfie(result.selfieUrl());

                Map<String, Object> response = new HashMap<>();
                response.put("success", true);
                response.put("verified", true);
                response.put("isVerified", true);
                response.put("selfieUrl", result.selfieUrl());
                response.put("similarity", result.similarity());
                response.put("message", result.message());
                response.put("userId", dbUserId);
                return ResponseEntity.ok(response);
            } else {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of(
                        "success", false,
                        "verified", false,
                        "isVerified", false,
                        "similarity", result.similarity(),
                        "message", result.message(),
                        "error", result.message()
                ));
            }

        } catch (Exception e) {
            logger.error("[VerificationController] Error verifying face: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("error", "Error interno durante la verificación facial: " + e.getMessage()));
        }
    }

    /**
     * Check current verification status for a user.
     */
    @GetMapping("/status")
    public ResponseEntity<?> getVerificationStatus(
            @RequestParam(value = "userId", required = false) String userId,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {

        String resolvedUserId = userId;
        if ((resolvedUserId == null || resolvedUserId.isBlank()) && authHeader != null && authHeader.startsWith("Bearer ")) {
            resolvedUserId = jwtUtil.verifyTokenAndGetUserId(authHeader.substring(7));
        }

        if (resolvedUserId == null || resolvedUserId.isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Token requerido"));
        }

        String dbUserId = databaseService.resolveDbUserId(resolvedUserId);
        User user = databaseService.findUserById(dbUserId);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Usuario no encontrado"));
        }

        return ResponseEntity.ok(Map.of(
                "userId", dbUserId,
                "isVerified", user.isVerified()
        ));
    }
}
