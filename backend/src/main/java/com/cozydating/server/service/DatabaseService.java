package com.cozydating.server.service;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DatabaseService {

    private static final Logger logger = LoggerFactory.getLogger(DatabaseService.class);

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PostConstruct
    public void init() {
        logger.info("[DB INIT] Initializing MySQL database schema and tables...");

        // Create users table
        jdbcTemplate.execute(
            "CREATE TABLE IF NOT EXISTS users (" +
            "  id VARCHAR(255) PRIMARY KEY," +
            "  username VARCHAR(255) NOT NULL," +
            "  tickets_balance INT DEFAULT 0" +
            ")"
        );

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

    private void seedData() {
        Integer userCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM users", Integer.class);
        if (userCount != null && userCount == 0) {
            logger.info("[DB SEED] Seeding default test accounts into MySQL...");
            
            // userA: 5 tickets
            jdbcTemplate.update("INSERT INTO users (id, username, tickets_balance) VALUES (?, ?, ?)",
                    "userA", "Alice", 5);
            // userB: 3 tickets
            jdbcTemplate.update("INSERT INTO users (id, username, tickets_balance) VALUES (?, ?, ?)",
                    "userB", "Bob", 3);
            // userC: 0 tickets (insufficient balance test)
            jdbcTemplate.update("INSERT INTO users (id, username, tickets_balance) VALUES (?, ?, ?)",
                    "userC", "Charlie", 0);
            // userD: 10 tickets
            jdbcTemplate.update("INSERT INTO users (id, username, tickets_balance) VALUES (?, ?, ?)",
                    "userD", "David", 10);
            
            logger.info("[DB SEED] Seeding complete: Alice(5), Bob(3), Charlie(0), David(10).");
        }
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
