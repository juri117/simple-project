<?php
// Database migration script to add file_attachments table
// This script safely adds the new table without affecting existing data

$db_path = 'database.sqlite';

try {
    // Connect to existing database
    $pdo = new PDO("sqlite:$db_path");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo "Starting migration to add file_attachments table...\n";
    
    // Check if table already exists
    $stmt = $pdo->prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='file_attachments'");
    $stmt->execute();
    
    if ($stmt->fetch()) {
        echo "Table 'file_attachments' already exists. Migration not needed.\n";
    } else {
        // Create file_attachments table
        $sql = "CREATE TABLE file_attachments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            issue_id INTEGER NOT NULL,
            original_filename TEXT NOT NULL,
            stored_filename TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            mime_type TEXT NOT NULL,
            uploaded_by INTEGER NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (issue_id) REFERENCES issues (id),
            FOREIGN KEY (uploaded_by) REFERENCES users (id)
        )";
        
        $pdo->exec($sql);
        echo "Successfully created 'file_attachments' table.\n";
        
        // Create index for better performance
        $pdo->exec("CREATE INDEX idx_file_attachments_issue_id ON file_attachments(issue_id)");
        echo "Created index on issue_id for better performance.\n";
    }
    
    echo "Migration completed successfully!\n";
    
} catch (PDOException $e) {
    echo "Migration failed: " . $e->getMessage() . "\n";
}
?>
