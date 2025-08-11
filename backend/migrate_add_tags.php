<?php
// Migration script to add tags and project_tags tables
$db_path = 'database.sqlite';

try {
    // Create SQLite database connection
    $pdo = new PDO("sqlite:$db_path");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create tags table
    $sql = "CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        short_name TEXT UNIQUE NOT NULL,
        description TEXT,
        color TEXT DEFAULT '#3B82F6',
        disabled INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )";
    
    $pdo->exec($sql);
    
    // Create project_tags relationship table
    $sql = "CREATE TABLE IF NOT EXISTS project_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (project_id) REFERENCES projects (id),
        FOREIGN KEY (tag_id) REFERENCES tags (id),
        UNIQUE(project_id, tag_id)
    )";
    
    $pdo->exec($sql);
    
    // Insert sample tags
    $sample_tags = [
        ['bug', 'Bug reports and issues', '#EF4444'],
        ['feature', 'New feature requests', '#10B981'],
        ['enhancement', 'Improvements to existing features', '#3B82F6'],
        ['documentation', 'Documentation updates', '#8B5CF6'],
        ['testing', 'Testing related tasks', '#F59E0B'],
        ['security', 'Security related issues', '#DC2626'],
        ['performance', 'Performance improvements', '#7C3AED'],
        ['ui', 'User interface changes', '#06B6D4'],
        ['backend', 'Backend development tasks', '#059669'],
        ['frontend', 'Frontend development tasks', '#0EA5E9'],
        ['database', 'Database related tasks', '#7C2D12'],
        ['devops', 'DevOps and deployment tasks', '#1E40AF']
    ];
    
    foreach ($sample_tags as $tag) {
        $stmt = $pdo->prepare("INSERT OR IGNORE INTO tags (short_name, description, color) VALUES (?, ?, ?)");
        $stmt->execute([$tag[0], $tag[1], $tag[2]]);
    }
    
    // Assign some tags to existing projects
    // Get project IDs
    $stmt = $pdo->prepare("SELECT id FROM projects WHERE deleted = 0");
    $stmt->execute();
    $projects = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Get tag IDs
    $stmt = $pdo->prepare("SELECT id FROM tags WHERE disabled = 0");
    $stmt->execute();
    $tags = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (!empty($projects) && !empty($tags)) {
        // Assign some tags to the first project (Software)
        $softwareProjectId = $projects[0]['id'];
        $softwareTags = [1, 2, 3, 5, 8, 9, 10]; // bug, feature, enhancement, testing, ui, backend, frontend
        
        foreach ($softwareTags as $tagId) {
            if ($tagId <= count($tags)) {
                $stmt = $pdo->prepare("INSERT OR IGNORE INTO project_tags (project_id, tag_id) VALUES (?, ?)");
                $stmt->execute([$softwareProjectId, $tagId]);
            }
        }
        
        // Assign some tags to the second project (BAU)
        if (count($projects) > 1) {
            $bauProjectId = $projects[1]['id'];
            $bauTags = [1, 4, 6, 7, 11, 12]; // bug, documentation, security, performance, database, devops
            
            foreach ($bauTags as $tagId) {
                if ($tagId <= count($tags)) {
                    $stmt = $pdo->prepare("INSERT OR IGNORE INTO project_tags (project_id, tag_id) VALUES (?, ?)");
                    $stmt->execute([$bauProjectId, $tagId]);
                }
            }
        }
    }
    
    echo "Tags migration completed successfully!\n";
    echo "Created tags table and project_tags relationship table.\n";
    echo "Added " . count($sample_tags) . " sample tags.\n";
    echo "Assigned tags to existing projects.\n";
    
} catch (PDOException $e) {
    echo "Tags migration failed: " . $e->getMessage() . "\n";
}
?>
