package com.cozydating.server.util;

import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.interfaces.DecodedJWT;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Date;

@Component
public class JwtUtil {

    private static final Logger logger = LoggerFactory.getLogger(JwtUtil.class);

    private final Algorithm algorithm;
    private final JWTVerifier verifier;

    public JwtUtil(@Value("${jwt.secret}") String secret) {
        this.algorithm = Algorithm.HMAC256(secret);
        this.verifier = JWT.require(algorithm).build();
    }

    /**
     * Helper to generate a token for test and verification clients.
     */
    public String generateToken(String userId, String username, long expirationMs) {
        return JWT.create()
                .withSubject(userId)
                .withClaim("username", username)
                .withIssuedAt(new Date())
                .withExpiresAt(new Date(System.currentTimeMillis() + expirationMs))
                .sign(algorithm);
    }

    /**
     * Verifies the token and extracts the userId (subject).
     * Returns null if token is invalid or expired.
     */
    public String verifyTokenAndGetUserId(String token) {
        try {
            DecodedJWT jwt = verifier.verify(token);
            return jwt.getSubject();
        } catch (Exception e) {
            logger.warn("JWT token verification failed: {}", e.getMessage());
            return null;
        }
    }
}
