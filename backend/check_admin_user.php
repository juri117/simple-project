<?php
require_once 'db_helper.php';

try {
    $pdo = DatabaseHelper::getConnection();
    
    // Check the admin user specifically
    $stmt = $pdo->prepare("SELECT id, username, role FROM users WHERE username = 'admin'");
    $stmt->execute();
    $admin = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($admin) {
        echo "Admin user found:\n";
        echo "ID: {$admin['id']}\n";
        echo "Username: {$admin['username']}\n";
        echo "Role: {$admin['role']}\n";
    } else {
        echo "Admin user not found!\n";
    }
    
    // Check all users
    echo "\nAll users:\n";
    $stmt = $pdo->query("SELECT id, username, role FROM users ORDER BY id");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($users as $user) {
        echo "ID: {$user['id']}, Username: {$user['username']}, Role: {$user['role']}\n";
    }
    
} catch (PDOException $e) {
    echo "Database error: " . $e->getMessage() . "\n";
}
?>
