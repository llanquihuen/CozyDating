package com.cozydating.server.service.verification;

import com.cozydating.server.service.storage.StorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

@Service
@ConditionalOnProperty(name = "verification.type", havingValue = "mock", matchIfMissing = true)
public class MockFaceVerificationService implements FaceVerificationService {

    private static final Logger logger = LoggerFactory.getLogger(MockFaceVerificationService.class);

    @Autowired
    private StorageService storageService;

    @Override
    public VerificationResult verifyFaces(String userId, String profilePhotoUrl, MultipartFile selfieFile) throws IOException {
        if (selfieFile == null || selfieFile.isEmpty()) {
            return new VerificationResult(false, 0.0, "No se proporcionó selfie para verificación", null);
        }

        if (profilePhotoUrl == null || profilePhotoUrl.isBlank()) {
            return new VerificationResult(false, 0.0, "Debes tener una foto de perfil antes de verificarte", null);
        }

        // 1. Guardar la selfie privada en la carpeta segura de almacenamiento "verification"
        String selfieUrl = storageService.uploadFile(selfieFile, "verification");
        logger.info("[MockFaceVerification] Saved verification selfie for user '{}' at '{}'", userId, selfieUrl);

        // 2. Simulación de procesamiento biométrico
        // En un escenario real con AWS Rekognition aquí se invoca CompareFaces
        double simulatedSimilarity = 95.5 + (Math.random() * 3.5); // 95.5% - 99.0%
        double roundedSimilarity = Math.round(simulatedSimilarity * 10.0) / 10.0;
        logger.info("[MockFaceVerification] Compared profilePhoto='{}' with selfie='{}'. Simulated similarity: {}%",
                profilePhotoUrl, selfieUrl, roundedSimilarity);

        return new VerificationResult(true, roundedSimilarity, "Identidad verificada exitosamente", selfieUrl);
    }
}
