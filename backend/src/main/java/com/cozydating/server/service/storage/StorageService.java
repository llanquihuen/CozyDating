package com.cozydating.server.service.storage;

import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

public interface StorageService {
    /**
     * Upload a multipart file into a specific folder/prefix.
     *
     * @param file the multipart file to upload
     * @param folder logical folder/prefix (e.g. "avatars", "photos")
     * @return the publicly accessible URL of the uploaded file
     * @throws IOException if saving or uploading fails
     */
    String uploadFile(MultipartFile file, String folder) throws IOException;

    /**
     * Delete an existing file using its public URL or key.
     *
     * @param fileUrl the public URL or file path to delete
     */
    void deleteFile(String fileUrl);
}
