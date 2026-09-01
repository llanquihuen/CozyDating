package com.cozydating.server.service;

import com.cozydating.server.model.User;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.ResultSet;
import java.sql.SQLException;

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
            user.setRoomConfig(rs.getString("room_config"));
            return user;
        }
    };

    @PostConstruct
    public void init() {
        logger.info("[DB INIT] Initializing MySQL database schema and tables...");

        // Create users table with full profile, credentials, avatar, tastes and room config
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
            "  room_config LONGTEXT," +
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

        seedData();
    }

    private void migrateSchemaIfNecessary() {
        String[] columns = {
            "email VARCHAR(255)",
            "password_hash VARCHAR(255)",
            "age INT DEFAULT 0",
            "commune VARCHAR(255)",
            "avatar_config LONGTEXT",
            "tastes LONGTEXT",
            "room_config LONGTEXT",
            "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
            "updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
        };

        for (String col : columns) {
            try {
                jdbcTemplate.execute("ALTER TABLE users ADD COLUMN " + col);
            } catch (Exception ignored) {
                // Column already exists
            }
        }
    }

    private void seedData() {
        Integer userCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM users", Integer.class);
        if (userCount != null && userCount == 0) {
            logger.info("[DB SEED] Seeding default test accounts with initial rooms and avatars...");
            String defaultHash = passwordEncoder.encode("password123");

            // Seed userA: Alice
            jdbcTemplate.update(
                "INSERT INTO users (id, username, email, password_hash, age, commune, tickets_balance) VALUES (?, ?, ?, ?, ?, ?, ?)",
                "userA", "Alice", "alice@example.com", defaultHash, 24, "Santiago", 5
            );

            // Seed userB: Bob
            jdbcTemplate.update(
                "INSERT INTO users (id, username, email, password_hash, age, commune, tickets_balance) VALUES (?, ?, ?, ?, ?, ?, ?)",
                "userB", "Bob", "bob@example.com", defaultHash, 26, "Providencia", 3
            );

            // Seed userC: Charlie
            jdbcTemplate.update(
                "INSERT INTO users (id, username, email, password_hash, age, commune, tickets_balance) VALUES (?, ?, ?, ?, ?, ?, ?)",
                "userC", "Charlie", "charlie@example.com", defaultHash, 28, "Las Condes", 0
            );

            // Seed userD: David
            jdbcTemplate.update(
                "INSERT INTO users (id, username, email, password_hash, age, commune, tickets_balance) VALUES (?, ?, ?, ?, ?, ?, ?)",
                "userD", "David", "david@example.com", defaultHash, 25, "Ñuñoa", 10
            );

            logger.info("[DB SEED] Seeding complete: Alice(5), Bob(3), Charlie(0), David(10).");
        }
    }

    public BCryptPasswordEncoder getPasswordEncoder() {
        return passwordEncoder;
    }

    @Transactional
    public void createUser(User user) {
        jdbcTemplate.update(
            "INSERT INTO users (id, username, email, password_hash, age, commune, tickets_balance, avatar_config, tastes, room_config) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            user.getId(),
            user.getUsername(),
            user.getEmail(),
            user.getPasswordHash(),
            user.getAge(),
            user.getCommune(),
            user.getTicketsBalance(),
            user.getAvatarConfig(),
            user.getTastes(),
            user.getRoomConfig()
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
}
