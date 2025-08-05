<?php
// Database initialization script
$db_path = 'database.sqlite';

try {
    // Create SQLite database
    $pdo = new PDO("sqlite:$db_path");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create users table
    $sql = "CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )";
    
    $pdo->exec($sql);
    
    // Create projects table
    $sql = "CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        status TEXT DEFAULT 'active',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        deleted_at DATETIME NULL,
        deleted INTEGER DEFAULT 0
    )";
    
    $pdo->exec($sql);
    
    // Insert sample user (password: admin123)
    $username = 'admin';
    $password = password_hash('admin123', PASSWORD_DEFAULT);
    
    $stmt = $pdo->prepare("INSERT OR IGNORE INTO users (username, password) VALUES (?, ?)");
    $stmt->execute([$username, $password]);
    
    // Insert sample projects
    $projects = [
        [
            'name' => 'Software',
            'description' => 'Software development project for new application features',
            'status' => 'active'
        ],
        [
            'name' => 'BAU',
            'description' => 'Business As Usual maintenance and support tasks',
            'status' => 'active'
        ]
    ];
    
    foreach ($projects as $project) {
        $stmt = $pdo->prepare("INSERT OR IGNORE INTO projects (name, description, status) VALUES (?, ?, ?)");
        $stmt->execute([$project['name'], $project['description'], $project['status']]);
    }
    
    echo "Database initialized successfully!\n";
    echo "Sample user created:\n";
    echo "Username: admin\n";
    echo "Password: admin123\n";
    echo "\nSample projects created:\n";
    echo "- Software\n";
    echo "- BAU\n";
    
} catch (PDOException $e) {
    echo "Database initialization failed: " . $e->getMessage() . "\n";
}
?> 