package com.cozydating.server.util;

import com.auth0.jwt.JWT;
import com.auth0.jwt.algorithms.Algorithm;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Date;
import java.util.HashMap;
import java.util.Map;

@Component
public class LiveKitTokenGenerator {

    @Value("${livekit.api.key}")
    private String apiKey;

    @Value("${livekit.api.secret}")
    private String apiSecret;

    public String createToken(String userId, String roomId) {
        Algorithm algorithm = Algorithm.HMAC256(apiSecret);
        
        Map<String, Object> videoClaims = new HashMap<>();
        videoClaims.put("roomJoin", true);
        videoClaims.put("room", roomId);
        videoClaims.put("canPublish", true);
        videoClaims.put("canSubscribe", true);
        videoClaims.put("canPublishData", true);

        return JWT.create()
                .withIssuer(apiKey)
                .withSubject(userId)
                .withClaim("video", videoClaims)
                .withClaim("metadata", "User: " + userId)
                .withIssuedAt(new Date())
                .withExpiresAt(new Date(System.currentTimeMillis() + 6 * 3600 * 1000)) // 6 hours expiration
                .sign(algorithm);
    }
}
