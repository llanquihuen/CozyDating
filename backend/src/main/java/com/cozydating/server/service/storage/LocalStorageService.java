package com.cozydating.server.service.storage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.UUID;

@Service
@ConditionalOnProperty(name = "storage.type", havingValue = "local", matchIfMissing = true)
public class LocalStorageService implements StorageService {

    private static final Logger logger = LoggerFactory.getLogger(LocalStorageService.class);

    private final String baseDir;
    private final String baseUrl;

    public LocalStorageService(
            @Value("${storage.local.dir:uploads/}") String baseDir,
            @Value("${storage.local.base-url:http://localhost:8080/media}") String baseUrl) {
        this.baseDir = baseDir;
        this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        logger.info("[LocalStorageService] Initialized with baseDir='{}' and baseUrl='{}'", this.baseDir, this.baseUrl);
    }

    @Override
    public String uploadFile(MultipartFile file, String folder) throws IOException {
        if (file.isEmpty()) {
            throw new IllegalArgumentException("Cannot upload empty file");
        }

        String originalFilename = file.getOriginalFilename();
        String extension = "";
        if (originalFilename != null && originalFilename.contains(".")) {
            extension = originalFilename.substring(originalFilename.lastIndexOf(".")).toLowerCase();
        } else {
            extension = ".jpg";
        }

        String uniqueFilename = UUID.randomUUID().toString() + extension;
        Path targetDirectory = Paths.get(baseDir, folder != null ? folder : "misc");
        Files.createDirectories(targetDirectory);

        Path targetPath = targetDirectory.resolve(uniqueFilename);
        Files.copy(file.getInputStream(), targetPath, StandardCopyOption.REPLACE_EXISTING);

        String relativePath = (folder != null && !folder.isEmpty())
                ? folder + "/" + uniqueFilename
                : uniqueFilename;

        String fileUrl = baseUrl + "/" + relativePath;
        logger.info("[LocalStorageService] File saved locally to: {} -> URL: {}", targetPath, fileUrl);
        return fileUrl;
    }

    @Override
    public void deleteFile(String fileUrl) {
        if (fileUrl == null || !fileUrl.startsWith(baseUrl)) {
            return;
        }
        try {
            String relativePath = fileUrl.substring(baseUrl.length());
            if (relativePath.startsWith("/")) {
                relativePath = relativePath.substring(1);
            }
            Path targetPath = Paths.get(baseDir, relativePath);
            File f = targetPath.toFile();
            if (f.exists()) {
                boolean deleted = f.delete();
                logger.info("[LocalStorageService] Deleted file {}: {}", targetPath, deleted);
            }
        } catch (Exception e) {
            logger.warn("[LocalStorageService] Could not delete file: {}", e.getMessage());
        }
    }
}
