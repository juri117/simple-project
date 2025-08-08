<?php
require_once 'db_helper.php';

class SessionManager {
    private static function getConnection() {
        return DatabaseHelper::getConnection();
    }
    
    public static function createSession($userId, $username) {
        try {
            $pdo = self::getConnection();
            
            // Create sessions table if it doesn't exist
            $pdo->exec("CREATE TABLE IF NOT EXISTS sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                session_token TEXT UNIQUE NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                expires_at DATETIME NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )");
            
            // Generate a unique session token
            $sessionToken = bin2hex(random_bytes(32));
            
            // Set expiration time (24 hours from now)
            $expiresAt = date('Y-m-d H:i:s', strtotime('+24 hours'));
            
            // Store session in database with retry logic
            $maxRetries = 3;
            $retryCount = 0;
            
            while ($retryCount < $maxRetries) {
                try {
                    $stmt = $pdo->prepare("INSERT INTO sessions (user_id, session_token, expires_at) VALUES (?, ?, ?)");
                    $stmt->execute([$userId, $sessionToken, $expiresAt]);
                    return $sessionToken;
                } catch (PDOException $e) {
                    $retryCount++;
                    if ($retryCount >= $maxRetries) {
                        throw $e;
                    }
                    // Wait a bit before retrying
                    usleep(100000); // 100ms
                }
            }
            
            return false;
            
        } catch (PDOException $e) {
            error_log("Session creation error: " . $e->getMessage());
            return false;
        }
    }
    
    public static function validateSession($sessionToken) {
        if (!$sessionToken) {
            return false;
        }
        
        try {
            $pdo = self::getConnection();
            
            // Check if session exists and is not expired
            $stmt = $pdo->prepare("
                SELECT s.user_id, s.session_token, u.username 
                FROM sessions s 
                JOIN users u ON s.user_id = u.id 
                WHERE s.session_token = ? AND s.expires_at > datetime('now')
            ");
            $stmt->execute([$sessionToken]);
            $session = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($session) {
                return [
                    'user_id' => $session['user_id'],
                    'username' => $session['username'],
                    'session_token' => $session['session_token']
                ];
            }
            
            return false;
            
        } catch (PDOException $e) {
            error_log("Session validation error: " . $e->getMessage());
            return false;
        }
    }
    
    public static function destroySession($sessionToken) {
        if (!$sessionToken) {
            return false;
        }
        
        try {
            $pdo = self::getConnection();
            
            $stmt = $pdo->prepare("DELETE FROM sessions WHERE session_token = ?");
            $stmt->execute([$sessionToken]);
            
            return true;
            
        } catch (PDOException $e) {
            error_log("Session destruction error: " . $e->getMessage());
            return false;
        }
    }
    
    public static function cleanupExpiredSessions() {
        try {
            $pdo = self::getConnection();
            
            $stmt = $pdo->prepare("DELETE FROM sessions WHERE expires_at <= datetime('now')");
            $stmt->execute();
            
            return true;
            
        } catch (PDOException $e) {
            error_log("Session cleanup error: " . $e->getMessage());
            return false;
        }
    }
}
?>
