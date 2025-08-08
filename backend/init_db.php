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
    
    // Create issues table
    $sql = "CREATE TABLE IF NOT EXISTS issues (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        status TEXT DEFAULT 'open',
        priority TEXT DEFAULT 'medium',
        tags TEXT,
        creator_id INTEGER NOT NULL,
        assignee_id INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        deleted_at DATETIME NULL,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (project_id) REFERENCES projects (id),
        FOREIGN KEY (creator_id) REFERENCES users (id),
        FOREIGN KEY (assignee_id) REFERENCES users (id)
    )";
    
    $pdo->exec($sql);
    
    // Create time_tracking table
    $sql = "CREATE TABLE IF NOT EXISTS time_tracking (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        issue_id INTEGER NOT NULL,
        start_time INTEGER NOT NULL,
        stop_time INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (issue_id) REFERENCES issues (id)
    )";
    
    $pdo->exec($sql);
    
    // Insert sample user (password: admin123)
    $username = 'admin';
    $password = password_hash('admin123', PASSWORD_DEFAULT);
    
    $stmt = $pdo->prepare("INSERT OR IGNORE INTO users (username, password) VALUES (?, ?)");
    $stmt->execute([$username, $password]);
    
    // Insert additional sample users
    $sample_users = [
        ['john', 'password123'],
        ['jane', 'password123'],
        ['mike', 'password123']
    ];
    
    foreach ($sample_users as $user) {
        $stmt = $pdo->prepare("INSERT OR IGNORE INTO users (username, password) VALUES (?, ?)");
        $stmt->execute([$user[0], password_hash($user[1], PASSWORD_DEFAULT)]);
    }
    
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
    
    // Insert sample issues
    $issues = [
        [
            'project_id' => 1,
            'title' => 'Implement user authentication',
            'description' => 'Add secure user authentication system with JWT tokens and password hashing.',
            'status' => 'in_progress',
            'priority' => 'high',
            'tags' => 'auth,security,backend',
            'creator_id' => 1,
            'assignee_id' => 2
        ],
        [
            'project_id' => 1,
            'title' => 'Fix responsive design issues',
            'description' => 'Mobile layout is broken on smaller screens. Need to fix CSS media queries.',
            'status' => 'open',
            'priority' => 'medium',
            'tags' => 'frontend,responsive,css',
            'creator_id' => 1,
            'assignee_id' => 3
        ],
        [
            'project_id' => 1,
            'title' => 'Add unit tests',
            'description' => 'Implement comprehensive unit tests for all backend API endpoints.',
            'status' => 'open',
            'priority' => 'medium',
            'tags' => 'testing,backend,quality',
            'creator_id' => 2,
            'assignee_id' => 1
        ],
        [
            'project_id' => 2,
            'title' => 'Database backup system',
            'description' => 'Set up automated daily database backups with retention policy.',
            'status' => 'completed',
            'priority' => 'high',
            'tags' => 'database,backup,devops',
            'creator_id' => 1,
            'assignee_id' => 1
        ],
        [
            'project_id' => 2,
            'title' => 'Update documentation',
            'description' => 'Update API documentation and user guides for the latest features.',
            'status' => 'open',
            'priority' => 'low',
            'tags' => 'documentation,user-guide',
            'creator_id' => 3,
            'assignee_id' => 2
        ]
    ];
    
    foreach ($issues as $issue) {
        $stmt = $pdo->prepare("INSERT OR IGNORE INTO issues (project_id, title, description, status, priority, tags, creator_id, assignee_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
        $stmt->execute([
            $issue['project_id'],
            $issue['title'],
            $issue['description'],
            $issue['status'],
            $issue['priority'],
            $issue['tags'],
            $issue['creator_id'],
            $issue['assignee_id']
        ]);
    }
    
    echo "Database initialized successfully!\n";
    echo "Sample users created:\n";
    echo "Username: admin, Password: admin123\n";
    echo "Username: john, Password: password123\n";
    echo "Username: jane, Password: password123\n";
    echo "Username: mike, Password: password123\n";
    echo "\nSample projects created:\n";
    echo "- Software\n";
    echo "- BAU\n";
    echo "\nSample issues created for both projects!\n";
    echo "\nTime tracking table created!\n";
    
} catch (PDOException $e) {
    echo "Database initialization failed: " . $e->getMessage() . "\n";
}
?> 