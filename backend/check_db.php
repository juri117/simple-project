<?php
$db_path = 'database.sqlite';

try {
    $pdo = new PDO("sqlite:$db_path");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Check if users table exists
    $stmt = $pdo->query("SELECT name FROM sqlite_master WHERE type='table' AND name='users'");
    $tableExists = $stmt->fetch();
    
    if ($tableExists) {
        echo "✅ Users table exists!\n";
        
        // Count users
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM users");
        $count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        echo "📊 Number of users: $count\n";
        
        // Show user details (without password)
        $stmt = $pdo->query("SELECT id, username, created_at FROM users");
        $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo "👥 Users in database:\n";
        foreach ($users as $user) {
            echo "  - ID: {$user['id']}, Username: {$user['username']}, Created: {$user['created_at']}\n";
        }
    } else {
        echo "❌ Users table does not exist!\n";
    }
    
} catch (PDOException $e) {
    echo "❌ Database error: " . $e->getMessage() . "\n";
}
?> 