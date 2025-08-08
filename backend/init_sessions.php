<?php
// Initialize sessions table for authentication system
try {
    $db_path = 'database.sqlite';
    $pdo = new PDO("sqlite:$db_path");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create sessions table
    $pdo->exec("CREATE TABLE IF NOT EXISTS sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        session_token TEXT UNIQUE NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        expires_at DATETIME NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
    )");
    
    // Create index on session_token for faster lookups
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions (session_token)");
    
    // Create index on expires_at for cleanup operations
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions (expires_at)");
    
    echo "Sessions table initialized successfully!\n";
    echo "Authentication system is ready to use.\n";
    
} catch (PDOException $e) {
    echo "Error initializing sessions table: " . $e->getMessage() . "\n";
    exit(1);
}
?>
