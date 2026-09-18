package com.cozydating.server.service.verification;

import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;

public interface FaceVerificationService {

    record VerificationResult(boolean verified, double similarity, String message, String selfieUrl) {}

    VerificationResult verifyFaces(String userId, String profilePhotoUrl, MultipartFile selfieFile) throws IOException;
}
