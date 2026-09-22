package com.cozydating.server.service;

import com.cozydating.server.model.User;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import com.cozydating.server.model.ChatMessage;

@Service
public class DatabaseService {

    private static final Logger logger = LoggerFactory.getLogger(DatabaseService.class);
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private final RowMapper<User> userRowMapper = new RowMapper<User>() {
        @Override
        public User mapRow(ResultSet rs, int rowNum) throws SQLException {
            User user = new User();
            user.setId(rs.getString("id"));
            user.setUsername(rs.getString("username"));
            user.setEmail(rs.getString("email"));
            user.setPasswordHash(rs.getString("password_hash"));
            user.setAge(rs.getInt("age"));
            user.setCommune(rs.getString("commune"));
            user.setTicketsBalance(rs.getInt("tickets_balance"));
            user.setAvatarConfig(rs.getString("avatar_config"));
            user.setTastes(rs.getString("tastes"));
            user.setProfilePhoto(rs.getString("profile_photo"));
            try {
                user.setPhotos(rs.getString("photos"));
            } catch (Exception ignored) {}
            try {
                user.setVerified(rs.getBoolean("is_verified"));
                user.setVerificationSelfie(rs.getString("verification_selfie"));
            } catch (Exception ignored) {}
            user.setRoomConfig(rs.getString("room_config"));
            try {
                user.setGender(rs.getString("gender"));
                user.setSeekingGender(rs.getString("seeking_gender"));
                user.setInternational(rs.getBoolean("is_international"));
                user.setLatitude(rs.getObject("latitude") != null ? rs.getDouble("latitude") : null);
                user.setLongitude(rs.getObject("longitude") != null ? rs.getDouble("longitude") : null);
                if (rs.getObject("max_distance_km") != null) {
                    user.setMaxDistanceKm(rs.getDouble("max_distance_km"));
                }
            } catch (Exception ignored) {}
            return user;
        }
    };

    private final RowMapper<com.cozydating.server.model.MailboxMatch> mailboxRowMapper = new RowMapper<com.cozydating.server.model.MailboxMatch>() {
        @Override
        public com.cozydating.server.model.MailboxMatch mapRow(ResultSet rs, int rowNum) throws SQLException {
            com.cozydating.server.model.MailboxMatch m = new com.cozydating.server.model.MailboxMatch();
            m.setId(rs.getString("id"));
            m.setUserAId(rs.getString("user_a_id"));
            m.setUserBId(rs.getString("user_b_id"));
            m.setUserAName(rs.getString("user_a_name"));
            m.setUserBName(rs.getString("user_b_name"));
            m.setUserAAvatar(rs.getString("user_a_avatar"));
            m.setUserBAvatar(rs.getString("user_b_avatar"));
            m.setUserAPhoto(rs.getString("user_a_photo"));
            m.setUserBPhoto(rs.getString("user_b_photo"));
            m.setUserAAge(rs.getInt("user_a_age"));
            m.setUserBAge(rs.getInt("user_b_age"));
            m.setUserACommune(rs.getString("user_a_commune"));
            m.setUserBCommune(rs.getString("user_b_commune"));
            m.setCommonTastes(rs.getString("common_tastes"));
            m.setDecisionA(rs.getString("decision_a"));
            m.setNoteA(rs.getString("note_a"));
            m.setDecisionB(rs.getString("decision_b"));
            m.setNoteB(rs.getString("note_b"));
            m.setMatched(rs.getBoolean("matched"));
            try {
                m.setMatchType(rs.getString("match_type"));
            } catch (Exception ignored) {}
            try {
                m.setCelebratedA(rs.getBoolean("celebrated_a"));
                m.setCelebratedB(rs.getBoolean("celebrated_b"));
            } catch (Exception ignored) {}
            m.setCreatedAt(rs.getString("created_at"));
            m.setUpdatedAt(rs.getString("updated_at"));
            return m;
        }
    };

    private final RowMapper<ChatMessage> chatMessageRowMapper = new RowMapper<ChatMessage>() {
        @Override
        public ChatMessage mapRow(ResultSet rs, int rowNum) throws SQLException {
            ChatMessage m = new ChatMessage();
            m.setId(rs.getString("id"));
            m.setMatchId(rs.getString("match_id"));
            m.setSenderId(rs.getString("sender_id"));
            m.setReceiverId(rs.getString("receiver_id"));
            m.setText(rs.getString("text"));
            m.setDateType(rs.getString("date_type"));
            m.setCreatedAt(rs.getString("created_at"));
            return m;
        }
    };

    @PostConstruct
    public void init() {
        logger.info("[DB INIT] Initializing MySQL database schema and tables...");

        // Create users table with full profile, credentials, avatar, tastes, photo and room config
        jdbcTemplate.execute(
            "CREATE TABLE IF NOT EXISTS users (" +
            "  id VARCHAR(255) PRIMARY KEY," +
            "  username VARCHAR(255) NOT NULL UNIQUE," +
            "  email VARCHAR(255)," +
            "  password_hash VARCHAR(255)," +
            "  age INT DEFAULT 0," +
            "  commune VARCHAR(255)," +
            "  tickets_balance INT DEFAULT 5," +
            "  avatar_config LONGTEXT," +
            "  tastes LONGTEXT," +
            "  profile_photo LONGTEXT," +
            "  photos LONGTEXT," +
            "  is_verified BOOLEAN DEFAULT FALSE," +
            "  verification_selfie LONGTEXT," +
            "  room_config LONGTEXT," +
            "  gender VARCHAR(50) DEFAULT 'OTHER'," +
            "  seeking_gender VARCHAR(50) DEFAULT 'ANY'," +
            "  is_international BOOLEAN DEFAULT FALSE," +
            "  latitude DOUBLE," +
            "  longitude DOUBLE," +
            "  max_distance_km DOUBLE DEFAULT 25.0," +
            "  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP," +
            "  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP" +
            ")"
        );

        try {
            jdbcTemplate.execute("ALTER TABLE users ADD COLUMN photos LONGTEXT");
        } catch (Exception ignored) {}

        try {
            jdbcTemplate.execute("ALTER TABLE users ADD COLUMN is_verified BOOLEAN DEFAULT FALSE");
        } catch (Exception ignored) {}

        try {
            jdbcTemplate.execute("ALTER TABLE users ADD COLUMN verification_selfie LONGTEXT");
        } catch (Exception ignored) {}

        // Create mailbox_matches table for asynchronous letterbox post-game decisions
        jdbcTemplate.execute(
            "CREATE TABLE IF NOT EXISTS mailbox_matches (" +
            "  id VARCHAR(255) PRIMARY KEY," +
            "  user_a_id VARCHAR(255) NOT NULL," +
            "  user_b_id VARCHAR(255) NOT NULL," +
            "  user_a_name VARCHAR(255)," +
            "  user_b_name VARCHAR(255)," +
            "  user_a_avatar LONGTEXT," +
            "  user_b_avatar LONGTEXT," +
            "  user_a_photo LONGTEXT," +
            "  user_b_photo LONGTEXT," +
            "  user_a_age INT DEFAULT 0," +
            "  user_b_age INT DEFAULT 0," +
            "  user_a_commune VARCHAR(255)," +
            "  user_b_commune VARCHAR(255)," +
            "  common_tastes LONGTEXT," +
            "  decision_a VARCHAR(50) DEFAULT 'PENDING'," +
            "  note_a TEXT," +
            "  decision_b VARCHAR(50) DEFAULT 'PENDING'," +
            "  note_b TEXT," +
            "  matched BOOLEAN DEFAULT FALSE," +
            "  match_type VARCHAR(50) DEFAULT 'NONE'," +
            "  celebrated_a BOOLEAN DEFAULT FALSE," +
            "  celebrated_b BOOLEAN DEFAULT FALSE," +
            "  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP," +
            "  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP" +
            ")"
        );

        // Safe migration check for preexisting databases (add columns if not present)
        migrateSchemaIfNecessary();

        // Create user_blocks table (user_id blocks blocked_user_id)
        jdbcTemplate.execute(
            "CREATE TABLE IF NOT EXISTS user_blocks (" +
            "  user_id VARCHAR(255) NOT NULL," +
            "  blocked_user_id VARCHAR(255) NOT NULL," +
            "  PRIMARY KEY (user_id, blocked_user_id)" +
            ")"
        );

        // Create chat_messages table for persistent chat and interactive date invites
        jdbcTemplate.execute(
            "CREATE TABLE IF NOT EXISTS chat_messages (" +
            "  id VARCHAR(255) PRIMARY KEY," +
            "  match_id VARCHAR(255) NOT NULL," +
            "  sender_id VARCHAR(255) NOT NULL," +
            "  receiver_id VARCHAR(255) NOT NULL," +
            "  text TEXT NOT NULL," +
            "  date_type VARCHAR(50)," +
            "  is_read BOOLEAN DEFAULT FALSE," +
            "  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP" +
            ")"
        );

        seedData();
    }

    private void migrateSchemaIfNecessary() {
        String[] userCols = {
            "email VARCHAR(255)",
            "password_hash VARCHAR(255)",
            "age INT DEFAULT 0",
            "commune VARCHAR(255)",
            "avatar_config LONGTEXT",
            "tastes LONGTEXT",
            "profile_photo LONGTEXT",
            "room_config LONGTEXT",
            "gender VARCHAR(50) DEFAULT 'OTHER'",
            "seeking_gender VARCHAR(50) DEFAULT 'ANY'",
            "is_international BOOLEAN DEFAULT FALSE",
            "latitude DOUBLE",
            "longitude DOUBLE",
            "max_distance_km DOUBLE DEFAULT 25.0",
            "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
            "updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
        };

        for (String col : userCols) {
            try {
                jdbcTemplate.execute("ALTER TABLE users ADD COLUMN " + col);
            } catch (Exception ignored) {}
        }

        try {
            jdbcTemplate.execute("ALTER TABLE mailbox_matches ADD COLUMN celebrated_a BOOLEAN DEFAULT FALSE");
        } catch (Exception ignored) {}
        try {
            jdbcTemplate.execute("ALTER TABLE mailbox_matches ADD COLUMN celebrated_b BOOLEAN DEFAULT FALSE");
        } catch (Exception ignored) {}
        try {
            jdbcTemplate.execute("ALTER TABLE mailbox_matches ADD COLUMN match_type VARCHAR(50) DEFAULT 'NONE'");
        } catch (Exception ignored) {}

        try {
            jdbcTemplate.execute("ALTER TABLE chat_messages ADD COLUMN is_read BOOLEAN DEFAULT FALSE");
        } catch (Exception ignored) {}

        try {
            // Clean up any previously corrupted inverted records from the role swap bug
            jdbcTemplate.update("UPDATE mailbox_matches SET user_a_name = 'Alice', user_b_name = 'Bob' WHERE user_a_id = 'userA' AND user_b_id = 'userB' AND user_a_name = 'Bob'");
            jdbcTemplate.update("UPDATE mailbox_matches SET user_a_name = 'Bob', user_b_name = 'Alice' WHERE user_a_id = 'userB' AND user_b_id = 'userA' AND user_a_name = 'Alice'");
        } catch (Exception ignored) {}
    }

    private void seedData() {
        String defaultTastesA = "[\"game_coop\",\"cinema_ghibli\",\"life_coffee_tea\",\"pet_cat\",\"vibe_night_owl\",\"intent_slow\"]";
        String defaultTastesB = "[\"game_coop\",\"game_roguelike\",\"cinema_ghibli\",\"pet_dog\",\"vibe_early_bird\",\"intent_slow\"]";
        String defaultTastesC = "[\"game_rpg\",\"cinema_scifi\",\"tech_pc_gamer\",\"vibe_introvert\",\"intent_gaming_duo\"]";
        String defaultTastesD = "[\"game_tabletop\",\"music_rock_metal\",\"life_coffee_tea\",\"vibe_adventurer\",\"intent_cozy_chats\"]";

        // Seed aesthetic profile photos for test users
        String photoA = "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=80"; // Alice
        String photoB = "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop&q=80"; // Bob
        String photoC = "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=500&auto=format&fit=crop&q=80"; // Charlie
        String photoD = "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=500&auto=format&fit=crop&q=80"; // David / Dayana

        Integer userCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM users", Integer.class);
        if (userCount != null && userCount == 0) {
            logger.info("[DB SEED] Seeding default test accounts with initial rooms, tastes, photos and avatars...");
            String defaultHash = passwordEncoder.encode("password123");

            // Seed userA: Alice
            jdbcTemplate.update(
                "INSERT INTO users (id, username, email, password_hash, age, commune, tickets_balance, tastes, profile_photo, is_verified) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                "userA", "Alice", "alice@example.com", defaultHash, 24, "Santiago", 5, defaultTastesA, photoA, true
            );

            // Seed userB: Bob
            jdbcTemplate.update(
                "INSERT INTO users (id, username, email, password_hash, age, commune, tickets_balance, tastes, profile_photo, is_verified) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                "userB", "Bob", "bob@example.com", defaultHash, 26, "Providencia", 3, defaultTastesB, photoB, true
            );

            // Seed userC: Charlie
            jdbcTemplate.update(
                "INSERT INTO users (id, username, email, password_hash, age, commune, tickets_balance, tastes, profile_photo, is_verified) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                "userC", "Charlie", "charlie@example.com", defaultHash, 28, "Las Condes", 0, defaultTastesC, photoC, true
            );

            // Seed userD: David
            jdbcTemplate.update(
                "INSERT INTO users (id, username, email, password_hash, age, commune, tickets_balance, tastes, profile_photo, is_verified) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                "userD", "David", "david@example.com", defaultHash, 25, "Ñuñoa", 10, defaultTastesD, photoD, true
            );

            logger.info("[DB SEED] Seeding complete: Alice(5), Bob(3), Charlie(0), David(10).");
        } else {
            try {
                jdbcTemplate.update("UPDATE users SET is_verified = TRUE WHERE id IN ('userA', 'userB', 'userC', 'userD')");
            } catch (Exception ignored) {}
            // Update existing users if tastes or photos are null or empty
            try {
                jdbcTemplate.update("UPDATE users SET age = 24, commune = 'Santiago' WHERE id = 'userA' AND (age IS NULL OR age = 0)");
                jdbcTemplate.update("UPDATE users SET age = 26, commune = 'Providencia' WHERE id = 'userB' AND (age IS NULL OR age = 0)");
                jdbcTemplate.update("UPDATE users SET age = 28, commune = 'Las Condes' WHERE id = 'userC' AND (age IS NULL OR age = 0)");
                jdbcTemplate.update("UPDATE users SET age = 25, commune = 'Ñuñoa' WHERE id = 'userD' AND (age IS NULL OR age = 0)");

                jdbcTemplate.update("UPDATE users SET tastes = ? WHERE id = 'userA' AND (tastes IS NULL OR tastes = '' OR tastes = '[]')", defaultTastesA);
                jdbcTemplate.update("UPDATE users SET tastes = ? WHERE id = 'userB' AND (tastes IS NULL OR tastes = '' OR tastes = '[]')", defaultTastesB);
                jdbcTemplate.update("UPDATE users SET tastes = ? WHERE id = 'userC' AND (tastes IS NULL OR tastes = '' OR tastes = '[]')", defaultTastesC);
                jdbcTemplate.update("UPDATE users SET tastes = ? WHERE id = 'userD' AND (tastes IS NULL OR tastes = '' OR tastes = '[]')", defaultTastesD);

                jdbcTemplate.update("UPDATE users SET profile_photo = ? WHERE id = 'userA' AND (profile_photo IS NULL OR profile_photo = '')", photoA);
                jdbcTemplate.update("UPDATE users SET profile_photo = ? WHERE id = 'userB' AND (profile_photo IS NULL OR profile_photo = '')", photoB);
                jdbcTemplate.update("UPDATE users SET profile_photo = ? WHERE id = 'userC' AND (profile_photo IS NULL OR profile_photo = '')", photoC);
                jdbcTemplate.update("UPDATE users SET profile_photo = ? WHERE id = 'userD' AND (profile_photo IS NULL OR profile_photo = '')", photoD);
            } catch (Exception ignored) {}
        }
    }

    public BCryptPasswordEncoder getPasswordEncoder() {
        return passwordEncoder;
    }

    @Transactional
    public void createUser(User user) {
        jdbcTemplate.update(
            "INSERT INTO users (id, username, email, password_hash, age, commune, tickets_balance, avatar_config, tastes, profile_photo, photos, is_verified, verification_selfie, room_config, gender, seeking_gender, is_international, latitude, longitude, max_distance_km) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            user.getId(),
            user.getUsername(),
            user.getEmail(),
            user.getPasswordHash(),
            user.getAge(),
            user.getCommune(),
            user.getTicketsBalance(),
            user.getAvatarConfig(),
            user.getTastes(),
            user.getProfilePhoto(),
            user.getPhotos(),
            user.isVerified(),
            user.getVerificationSelfie(),
            user.getRoomConfig(),
            user.getGender(),
            user.getSeekingGender(),
            user.isInternational(),
            user.getLatitude(),
            user.getLongitude(),
            user.getMaxDistanceKm()
        );
    }

    public User findUserById(String id) {
        try {
            return jdbcTemplate.queryForObject("SELECT * FROM users WHERE id = ?", userRowMapper, id);
        } catch (EmptyResultDataAccessException e) {
            return null;
        }
    }

    public User findUserByUsername(String username) {
        try {
            return jdbcTemplate.queryForObject("SELECT * FROM users WHERE LOWER(username) = LOWER(?)", userRowMapper, username);
        } catch (EmptyResultDataAccessException e) {
            return null;
        }
    }

    public User findUserByEmail(String email) {
        try {
            return jdbcTemplate.queryForObject("SELECT * FROM users WHERE LOWER(email) = LOWER(?)", userRowMapper, email);
        } catch (EmptyResultDataAccessException e) {
            return null;
        }
    }

    @Transactional
    public void updateRoomConfig(String userId, String roomConfigJson) {
        jdbcTemplate.update("UPDATE users SET room_config = ? WHERE id = ?", roomConfigJson, userId);
    }

    @Transactional
    public void updateAvatarConfig(String userId, String avatarConfigJson) {
        jdbcTemplate.update("UPDATE users SET avatar_config = ? WHERE id = ?", avatarConfigJson, userId);
    }

    @Transactional
    public void updateUserProfile(String userId, int age, String commune, String tastesJson) {
        jdbcTemplate.update("UPDATE users SET age = ?, commune = ?, tastes = ? WHERE id = ?", age, commune, tastesJson, userId);
    }

    @Transactional
    public void updateUserProfile(String userId, int age, String commune, String tastesJson,
                                  String gender, String seekingGender, Boolean isInternational,
                                  Double latitude, Double longitude, Double maxDistanceKm) {
        jdbcTemplate.update(
            "UPDATE users SET age = ?, commune = ?, tastes = ?, gender = ?, seeking_gender = ?, is_international = ?, latitude = ?, longitude = ?, max_distance_km = ? WHERE id = ?",
            age, commune, tastesJson,
            gender != null ? gender : "OTHER",
            seekingGender != null ? seekingGender : "ANY",
            isInternational != null ? isInternational : false,
            latitude, longitude,
            maxDistanceKm != null ? maxDistanceKm : 25.0,
            userId
        );
    }

    @Transactional
    public void unblockAllUsers() {
        logger.info("[DB UNBLOCK ALL] Clearing all user blocks and resetting ticket balances...");
        jdbcTemplate.execute("DELETE FROM user_blocks");
        jdbcTemplate.update("UPDATE users SET tickets_balance = 5 WHERE id = 'userA'");
        jdbcTemplate.update("UPDATE users SET tickets_balance = 3 WHERE id = 'userB'");
        jdbcTemplate.update("UPDATE users SET tickets_balance = 10 WHERE id = 'userD'");
        logger.info("[DB UNBLOCK ALL] Reset complete. All blocks removed.");
    }

    @Transactional
    public boolean reserveVoiceTicket(String userId) {
        try {
            logger.info("[DB TRANSACTION] Starting atomic ticket reservation for userId: {}", userId);
            Integer balance = jdbcTemplate.queryForObject(
                "SELECT tickets_balance FROM users WHERE id = ?", Integer.class, userId);
            
            if (balance != null && balance >= 1) {
                int updated = jdbcTemplate.update(
                    "UPDATE users SET tickets_balance = tickets_balance - 1 WHERE id = ? AND tickets_balance >= 1", 
                    userId
                );
                if (updated > 0) {
                    logger.info("[DB TRANSACTION SUCCESS] Reserved 1 voice ticket for userId: {}. New Balance: {}", userId, balance - 1);
                    return true;
                }
            }
            logger.warn("[DB TRANSACTION REJECT] Cannot reserve ticket for userId: {}. Current Balance: {}", userId, balance);
            return false;
        } catch (Exception e) {
            logger.error("[DB TRANSACTION ERROR] Failed atomic reservation for userId: " + userId, e);
            throw e;
        }
    }

    @Transactional
    public void refundVoiceTicket(String userId) {
        try {
            logger.info("[DB TRANSACTION] Starting ticket refund process for userId: {}", userId);
            jdbcTemplate.update("UPDATE users SET tickets_balance = tickets_balance + 1 WHERE id = ?", userId);
            
            Integer newBalance = jdbcTemplate.queryForObject(
                "SELECT tickets_balance FROM users WHERE id = ?", Integer.class, userId);
            logger.info("[DB TRANSACTION REFUNDED] Refunded 1 voice ticket to userId: {}. Updated Balance: {}", userId, newBalance);
        } catch (Exception e) {
            logger.error("[DB TRANSACTION ERROR] Failed ticket refund for userId: " + userId, e);
            throw e;
        }
    }

    public boolean isMutuallyBlocked(String userId1, String userId2) {
        Integer count = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM user_blocks WHERE " +
            "(user_id = ? AND blocked_user_id = ?) OR (user_id = ? AND blocked_user_id = ?)",
            Integer.class, userId1, userId2, userId2, userId1
        );
        boolean blocked = count != null && count > 0;
        if (blocked) {
            logger.info("[DB BLOCK CHECK] Block check between {} and {}: BLOCKED (Match Excluded)", userId1, userId2);
        } else {
            logger.info("[DB BLOCK CHECK] Block check between {} and {}: NO BLOCKS FOUND (Clean)", userId1, userId2);
        }
        return blocked;
    }

    @Transactional
    public void blockUser(String userId, String blockedUserId) {
        try {
            logger.info("[DB BLOCK INSERT] Creating directional block entry: {} -> {}", userId, blockedUserId);
            jdbcTemplate.update(
                "INSERT IGNORE INTO user_blocks (user_id, blocked_user_id) VALUES (?, ?)", 
                userId, blockedUserId
            );
            logger.info("[DB BLOCK SUCCESS] Directional block entry committed to MySQL database.");
        } catch (Exception e) {
            logger.error("[DB BLOCK ERROR] Failed to record block from " + userId + " to " + blockedUserId, e);
            throw e;
        }
    }

    public int getTicketBalance(String userId) {
        try {
            Integer balance = jdbcTemplate.queryForObject(
                "SELECT tickets_balance FROM users WHERE id = ?", Integer.class, userId);
            return balance != null ? balance : 0;
        } catch (Exception e) {
            return 0;
        }
    }

    @Transactional
    public void updateProfilePhoto(String userId, String photoData) {
        if (userId == null || userId.isBlank()) return;
        String dbUserId = resolveDbUserId(userId);

        User current = findUserById(dbUserId);
        if (current != null && photoData != null && photoData.trim().equals(current.getProfilePhoto())) {
            logger.info("[DB UPDATE PHOTO] Profile photo unchanged for userId='{}' (dbUserId='{}'). Preserving is_verified={}",
                    userId, dbUserId, current.isVerified());
            return;
        }

        // Al cambiar efectivamente la foto de perfil oficial por otra distinta, se invalida la certificación anterior
        int rows = jdbcTemplate.update("UPDATE users SET profile_photo = ?, is_verified = FALSE WHERE id = ?", photoData, dbUserId);
        logger.info("[DB UPDATE PHOTO] Updated profile photo for userId='{}' (dbUserId='{}') to '{}'. Verification revoked (rows={})",
                userId, dbUserId, photoData, rows);
    }

    public String resolveDbUserId(String userId) {
        if (userId == null) return null;
        User user = findUserByUsername(userId);
        if (user != null) return user.getId();
        return userId;
    }

    @Transactional
    public void updateUserPhotos(String userId, String photosJson) {
        if (userId == null || userId.isBlank()) return;
        String dbUserId = resolveDbUserId(userId);
        int rows = jdbcTemplate.update("UPDATE users SET photos = ? WHERE id = ?", photosJson, dbUserId);
        logger.info("[DB UPDATE PHOTOS] Updated photos array for userId='{}' (dbUserId='{}') (rows={})",
                userId, dbUserId, rows);
    }

    @Transactional
    public void updateVerificationStatus(String userId, boolean isVerified, String selfieUrl) {
        if (userId == null || userId.isBlank()) return;
        String dbUserId = resolveDbUserId(userId);

        int rows = jdbcTemplate.update(
                "UPDATE users SET is_verified = ?, verification_selfie = ? WHERE id = ?",
                isVerified, selfieUrl, dbUserId);
        logger.info("[DB UPDATE VERIFICATION] Updated verification for userId='{}' (dbUserId='{}'): isVerified={}, rows={}",
                userId, dbUserId, isVerified, rows);
    }

    @Transactional
    public void createMailboxMatch(com.cozydating.server.model.MailboxMatch match) {
        try {
            jdbcTemplate.update(
                "INSERT INTO mailbox_matches (id, user_a_id, user_b_id, user_a_name, user_b_name, " +
                "user_a_avatar, user_b_avatar, user_a_photo, user_b_photo, user_a_age, user_b_age, " +
                "user_a_commune, user_b_commune, common_tastes, decision_a, note_a, decision_b, note_b, matched) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                match.getId(),
                match.getUserAId(),
                match.getUserBId(),
                match.getUserAName(),
                match.getUserBName(),
                match.getUserAAvatar(),
                match.getUserBAvatar(),
                match.getUserAPhoto(),
                match.getUserBPhoto(),
                match.getUserAAge(),
                match.getUserBAge(),
                match.getUserACommune(),
                match.getUserBCommune(),
                match.getCommonTastes(),
                match.getDecisionA() != null ? match.getDecisionA() : "PENDING",
                match.getNoteA(),
                match.getDecisionB() != null ? match.getDecisionB() : "PENDING",
                match.getNoteB(),
                match.isMatched()
            );
            logger.info("[DB MAILBOX] Created new mailbox match letter: {} between {} and {}", match.getId(), match.getUserAId(), match.getUserBId());
        } catch (org.springframework.dao.DuplicateKeyException e) {
            logger.info("[DB MAILBOX] Match {} already exists in mailbox, ignoring duplicate creation.", match.getId());
        }
    }

    public com.cozydating.server.model.MailboxMatch findMailboxMatchById(String matchId) {
        try {
            return jdbcTemplate.queryForObject("SELECT * FROM mailbox_matches WHERE id = ?", mailboxRowMapper, matchId);
        } catch (EmptyResultDataAccessException e) {
            return null;
        }
    }

    public java.util.List<com.cozydating.server.model.MailboxMatch> getUserMailboxMatches(String userId) {
        String dbUserId = resolveDbUserId(userId);
        return jdbcTemplate.query(
            "SELECT * FROM mailbox_matches WHERE user_a_id = ? OR user_b_id = ? OR user_a_id = ? OR user_b_id = ? ORDER BY created_at DESC",
            mailboxRowMapper,
            dbUserId,
            dbUserId,
            userId,
            userId
        );
    }

    @Transactional
    public void saveOrUpdateMailboxMatch(com.cozydating.server.model.MailboxMatch match) {
        com.cozydating.server.model.MailboxMatch existing = findMailboxMatchById(match.getId());
        if (existing == null) {
            createMailboxMatch(match);
        } else {
            String resolvedExistingA = resolveDbUserId(existing.getUserAId());
            String resolvedExistingB = resolveDbUserId(existing.getUserBId());
            String incomingA = resolveDbUserId(match.getUserAId());

            boolean incomingIsUserB = incomingA != null && 
                (incomingA.equals(existing.getUserBId()) || incomingA.equals(resolvedExistingB));

            if (incomingIsUserB) {
                // Incoming caller is User B: match.userA fields belong to existing User B, and match.userB fields belong to existing User A!
                jdbcTemplate.update(
                    "UPDATE mailbox_matches SET " +
                    "user_b_name = COALESCE(?, user_b_name), " +
                    "user_b_avatar = COALESCE(?, user_b_avatar), " +
                    "user_b_photo = COALESCE(?, user_b_photo), " +
                    "user_b_age = CASE WHEN ? > 0 THEN ? ELSE user_b_age END, " +
                    "user_b_commune = COALESCE(?, user_b_commune), " +
                    "user_a_name = COALESCE(?, user_a_name), " +
                    "user_a_avatar = COALESCE(?, user_a_avatar), " +
                    "user_a_photo = COALESCE(?, user_a_photo), " +
                    "user_a_age = CASE WHEN ? > 0 THEN ? ELSE user_a_age END, " +
                    "user_a_commune = COALESCE(?, user_a_commune) " +
                    "WHERE id = ?",
                    match.getUserAName(),
                    match.getUserAAvatar(),
                    match.getUserAPhoto(),
                    match.getUserAAge(), match.getUserAAge(),
                    match.getUserACommune(),
                    match.getUserBName(),
                    match.getUserBAvatar(),
                    match.getUserBPhoto(),
                    match.getUserBAge(), match.getUserBAge(),
                    match.getUserBCommune(),
                    match.getId()
                );
            } else {
                // Incoming caller is User A: direct alignment
                jdbcTemplate.update(
                    "UPDATE mailbox_matches SET " +
                    "user_a_name = COALESCE(?, user_a_name), " +
                    "user_b_name = COALESCE(?, user_b_name), " +
                    "user_a_avatar = COALESCE(?, user_a_avatar), " +
                    "user_b_avatar = COALESCE(?, user_b_avatar), " +
                    "user_a_photo = COALESCE(?, user_a_photo), " +
                    "user_b_photo = COALESCE(?, user_b_photo), " +
                    "user_a_age = CASE WHEN ? > 0 THEN ? ELSE user_a_age END, " +
                    "user_a_commune = COALESCE(?, user_a_commune), " +
                    "user_b_age = CASE WHEN ? > 0 THEN ? ELSE user_b_age END, " +
                    "user_b_commune = COALESCE(?, user_b_commune) " +
                    "WHERE id = ?",
                    match.getUserAName(), match.getUserBName(),
                    match.getUserAAvatar(), match.getUserBAvatar(),
                    match.getUserAPhoto(), match.getUserBPhoto(),
                    match.getUserAAge(), match.getUserAAge(),
                    match.getUserACommune(),
                    match.getUserBAge(), match.getUserBAge(),
                    match.getUserBCommune(),
                    match.getId()
                );
            }
        }
    }

    @Transactional
    public com.cozydating.server.model.MailboxMatch submitMailboxDecision(String matchId, String userId, String decision, String note) {
        com.cozydating.server.model.MailboxMatch match = findMailboxMatchById(matchId);
        if (match == null) {
            return null;
        }

        String resolvedUserId = resolveDbUserId(userId);
        String resolvedUserA = resolveDbUserId(match.getUserAId());
        String resolvedUserB = resolveDbUserId(match.getUserBId());

        boolean isUserA = (userId != null && userId.equals(match.getUserAId())) ||
                          (resolvedUserId != null && (resolvedUserId.equals(match.getUserAId()) || resolvedUserId.equals(resolvedUserA)));
        boolean isUserB = (userId != null && userId.equals(match.getUserBId())) ||
                          (resolvedUserId != null && (resolvedUserId.equals(match.getUserBId()) || resolvedUserId.equals(resolvedUserB)));
        if (!isUserA && !isUserB) {
            return null;
        }

        if (isUserA) {
            match.setDecisionA(decision);
            if (note != null) match.setNoteA(note);
        } else {
            match.setDecisionB(decision);
            if (note != null) match.setNoteB(note);
        }

        String decA = match.getDecisionA();
        String decB = match.getDecisionB();

        boolean isRomanceA = "ROMANCE".equalsIgnoreCase(decA) || "KEEP_IN_TOUCH".equalsIgnoreCase(decA);
        boolean isRomanceB = "ROMANCE".equalsIgnoreCase(decB) || "KEEP_IN_TOUCH".equalsIgnoreCase(decB);
        boolean isFriendshipA = "FRIENDSHIP".equalsIgnoreCase(decA);
        boolean isFriendshipB = "FRIENDSHIP".equalsIgnoreCase(decB);
        boolean isPassA = "PASS".equalsIgnoreCase(decA) || "ARCHIVE".equalsIgnoreCase(decA);
        boolean isPassB = "PASS".equalsIgnoreCase(decB) || "ARCHIVE".equalsIgnoreCase(decB);

        boolean mutualMatch = false;
        String matchType = "NONE";

        if (isPassA || isPassB) {
            mutualMatch = false;
            matchType = "NONE";
        } else if (isRomanceA && isRomanceB) {
            mutualMatch = true;
            matchType = "ROMANCE";
        } else if ((isRomanceA && isFriendshipB) || (isFriendshipA && isRomanceB) || (isFriendshipA && isFriendshipB)) {
            mutualMatch = true;
            matchType = "FRIENDSHIP";
        }

        match.setMatched(mutualMatch);
        match.setMatchType(matchType);

        jdbcTemplate.update(
            "UPDATE mailbox_matches SET decision_a = ?, note_a = ?, decision_b = ?, note_b = ?, matched = ?, match_type = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            match.getDecisionA(),
            match.getNoteA(),
            match.getDecisionB(),
            match.getNoteB(),
            match.isMatched(),
            match.getMatchType(),
            match.getId()
        );

        logger.info("[DB MAILBOX] Updated decision for match: {} by user {}: {}. Mutual match: {}, matchType: {}", matchId, userId, decision, mutualMatch, matchType);
        return match;
    }

    public void markMatchCelebrated(String matchId, String userId) {
        com.cozydating.server.model.MailboxMatch match = findMailboxMatchById(matchId);
        if (match == null) return;
        String resolvedUserId = resolveDbUserId(userId);
        String resolvedUserA = resolveDbUserId(match.getUserAId());
        String resolvedUserB = resolveDbUserId(match.getUserBId());

        boolean isUserA = (userId != null && userId.equals(match.getUserAId())) ||
                          (resolvedUserId != null && (resolvedUserId.equals(match.getUserAId()) || resolvedUserId.equals(resolvedUserA)));
        boolean isUserB = (userId != null && userId.equals(match.getUserBId())) ||
                          (resolvedUserId != null && (resolvedUserId.equals(match.getUserBId()) || resolvedUserId.equals(resolvedUserB)));
        if (isUserA) {
            jdbcTemplate.update("UPDATE mailbox_matches SET celebrated_a = TRUE WHERE id = ?", matchId);
        } else if (isUserB) {
            jdbcTemplate.update("UPDATE mailbox_matches SET celebrated_b = TRUE WHERE id = ?", matchId);
        }
        logger.info("[DB MAILBOX] Marked match {} celebrated for user {}", matchId, userId);
    }

    public int getUnreadMailboxCount(String userId) {
        try {
            Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM mailbox_matches WHERE (user_a_id = ? AND decision_a = 'PENDING') OR (user_b_id = ? AND decision_b = 'PENDING')",
                Integer.class,
                userId,
                userId
            );
            int chatCount = getUnreadChatCount(userId);
            return (count != null ? count : 0) + chatCount;
        } catch (Exception e) {
            return 0;
        }
    }

    public int getUnreadChatCount(String userId) {
        try {
            Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM chat_messages WHERE receiver_id = ? AND is_read = FALSE",
                Integer.class,
                userId
            );
            return count != null ? count : 0;
        } catch (Exception e) {
            return 0;
        }
    }

    public Map<String, Integer> getUnreadChatCountsByMatch(String userId) {
        Map<String, Integer> map = new HashMap<>();
        try {
            List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                "SELECT match_id, COUNT(*) as cnt FROM chat_messages WHERE receiver_id = ? AND is_read = FALSE GROUP BY match_id",
                userId
            );
            for (Map<String, Object> row : rows) {
                String matchId = (String) row.get("match_id");
                Number count = (Number) row.get("cnt");
                if (matchId != null && count != null) {
                    map.put(matchId, count.intValue());
                }
            }
        } catch (Exception e) {
            logger.error("[DB CHAT ERROR] Failed to fetch unread counts by match", e);
        }
        return map;
    }

    public void markChatMessagesAsRead(String matchId, String userId) {
        try {
            jdbcTemplate.update(
                "UPDATE chat_messages SET is_read = TRUE WHERE match_id = ? AND receiver_id = ?",
                matchId,
                userId
            );
            logger.info("[DB CHAT] Marked chat messages as read for match {} and user {}", matchId, userId);
        } catch (Exception e) {
            logger.error("[DB CHAT ERROR] Failed to mark messages as read", e);
        }
    }

    public boolean haveUsersMetOrMatched(String userA, String userB) {
        try {
            Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM mailbox_matches WHERE (user_a_id = ? AND user_b_id = ?) OR (user_a_id = ? AND user_b_id = ?)",
                Integer.class,
                userA, userB, userB, userA
            );
            return count != null && count > 0;
        } catch (Exception e) {
            return false;
        }
    }

    public void saveChatMessage(ChatMessage msg) {
        try {
            jdbcTemplate.update(
                "INSERT INTO chat_messages (id, match_id, sender_id, receiver_id, text, date_type, is_read, created_at) " +
                "VALUES (?, ?, ?, ?, ?, ?, FALSE, CURRENT_TIMESTAMP) " +
                "ON DUPLICATE KEY UPDATE text = VALUES(text), date_type = VALUES(date_type)",
                msg.getId(),
                msg.getMatchId(),
                msg.getSenderId(),
                msg.getReceiverId(),
                msg.getText(),
                msg.getDateType()
            );
            logger.info("[DB CHAT] Saved chat message {} for match {}", msg.getId(), msg.getMatchId());
        } catch (DuplicateKeyException e) {
            logger.debug("[DB CHAT] Message {} already persisted (duplicate ignored)", msg.getId());
        } catch (Exception e) {
            logger.error("[DB CHAT ERROR] Failed to save chat message " + msg.getId(), e);
        }
    }

    public List<ChatMessage> getChatMessages(String matchId) {
        try {
            return jdbcTemplate.query(
                "SELECT * FROM chat_messages WHERE match_id = ? ORDER BY created_at ASC",
                chatMessageRowMapper,
                matchId
            );
        } catch (Exception e) {
            logger.error("[DB CHAT ERROR] Failed to fetch chat messages for match " + matchId, e);
            return new ArrayList<>();
        }
    }
}
