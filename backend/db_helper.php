<?php
class DatabaseHelper {
    private static $db_path = 'database.sqlite';
    private static $pdo = null;
    
    public static function getConnection() {
        if (self::$pdo === null) {
            self::$pdo = new PDO("sqlite:" . self::$db_path);
            self::$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            // Enable WAL mode for better concurrency
            self::$pdo->exec("PRAGMA journal_mode=WAL");
            self::$pdo->exec("PRAGMA busy_timeout=5000");
            self::$pdo->exec("PRAGMA synchronous=NORMAL");
        }
        return self::$pdo;
    }
    
    public static function closeConnection() {
        if (self::$pdo !== null) {
            self::$pdo = null;
        }
    }
}
?>
