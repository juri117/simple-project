<?php
$db_path = 'database.sqlite';

try {
    $pdo = new PDO("sqlite:$db_path");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Check if projects table exists
    $stmt = $pdo->query("SELECT name FROM sqlite_master WHERE type='table' AND name='projects'");
    $tableExists = $stmt->fetch();
    
    if ($tableExists) {
        echo "✅ Projects table exists!\n";
        
        // Count projects
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM projects WHERE deleted = 0");
        $count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        echo "📊 Number of active projects: $count\n";
        
        // Show project details
        $stmt = $pdo->query("SELECT id, name, description, status, created_at FROM projects WHERE deleted = 0 ORDER BY created_at DESC");
        $projects = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo "📋 Projects in database:\n";
        foreach ($projects as $project) {
            echo "  - ID: {$project['id']}, Name: {$project['name']}, Status: {$project['status']}\n";
            echo "    Description: {$project['description']}\n";
            echo "    Created: {$project['created_at']}\n\n";
        }
    } else {
        echo "❌ Projects table does not exist!\n";
    }
    
} catch (PDOException $e) {
    echo "❌ Database error: " . $e->getMessage() . "\n";
}
?> 