package com.cozydating.server.service.storage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3ClientBuilder;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.ObjectCannedACL;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.IOException;
import java.net.URI;
import java.util.UUID;

@Service
@ConditionalOnProperty(name = "storage.type", havingValue = "s3")
public class LightsailStorageService implements StorageService {

    private static final Logger logger = LoggerFactory.getLogger(LightsailStorageService.class);

    private final String bucketName;
    private final String publicBaseUrl;
    private final S3Client s3Client;

    public LightsailStorageService(
            @Value("${storage.s3.bucket-name}") String bucketName,
            @Value("${storage.s3.region:us-east-1}") String region,
            @Value("${storage.s3.endpoint:}") String endpoint,
            @Value("${storage.s3.access-key:}") String accessKey,
            @Value("${storage.s3.secret-key:}") String secretKey,
            @Value("${storage.s3.public-base-url:}") String publicBaseUrl) {

        this.bucketName = bucketName;
        this.publicBaseUrl = publicBaseUrl != null && !publicBaseUrl.isBlank()
                ? (publicBaseUrl.endsWith("/") ? publicBaseUrl.substring(0, publicBaseUrl.length() - 1) : publicBaseUrl)
                : null;

        S3ClientBuilder builder = S3Client.builder()
                .region(Region.of(region));

        if (accessKey != null && !accessKey.isBlank() && secretKey != null && !secretKey.isBlank()) {
            builder.credentialsProvider(StaticCredentialsProvider.create(
                    AwsBasicCredentials.create(accessKey, secretKey)
            ));
        }

        if (endpoint != null && !endpoint.isBlank()) {
            builder.endpointOverride(URI.create(endpoint));
            builder.serviceConfiguration(S3Configuration.builder()
                    .pathStyleAccessEnabled(true)
                    .build());
        }

        this.s3Client = builder.build();
        logger.info("[LightsailStorageService] Configured for bucket '{}' in region '{}'", bucketName, region);
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

        String key = (folder != null && !folder.isEmpty())
                ? folder + "/" + UUID.randomUUID() + extension
                : UUID.randomUUID() + extension;

        String contentType = file.getContentType() != null ? file.getContentType() : "image/jpeg";

        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(bucketName)
                .key(key)
                .contentType(contentType)
                .acl(ObjectCannedACL.PUBLIC_READ)
                .build();

        try {
            s3Client.putObject(putRequest, RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
        } catch (Exception e) {
            // Si el bucket tiene Object Ownership = Bucket Owner Enforced (ACLs deshabilitadas), intentamos sin ACL
            logger.warn("[LightsailStorageService] PutObject with ACL failed ({}), retrying without ACL...", e.getMessage());
            PutObjectRequest retryRequest = PutObjectRequest.builder()
                    .bucket(bucketName)
                    .key(key)
                    .contentType(contentType)
                    .build();
            s3Client.putObject(retryRequest, RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
        }

        String fileUrl;
        if (publicBaseUrl != null) {
            fileUrl = publicBaseUrl + "/" + key;
        } else {
            fileUrl = String.format("https://%s.s3.amazonaws.com/%s", bucketName, key);
        }

        logger.info("[LightsailStorageService] Uploaded to S3: {} -> URL: {}", key, fileUrl);
        return fileUrl;
    }

    @Override
    public void deleteFile(String fileUrl) {
        if (fileUrl == null || fileUrl.isBlank()) return;
        try {
            String key;
            if (publicBaseUrl != null && fileUrl.startsWith(publicBaseUrl)) {
                key = fileUrl.substring(publicBaseUrl.length());
            } else {
                key = fileUrl.substring(fileUrl.lastIndexOf("/") + 1);
            }
            if (key.startsWith("/")) {
                key = key.substring(1);
            }

            DeleteObjectRequest deleteRequest = DeleteObjectRequest.builder()
                    .bucket(bucketName)
                    .key(key)
                    .build();
            s3Client.deleteObject(deleteRequest);
            logger.info("[LightsailStorageService] Deleted object with key: {}", key);
        } catch (Exception e) {
            logger.warn("[LightsailStorageService] Error deleting object from S3: {}", e.getMessage());
        }
    }
}
