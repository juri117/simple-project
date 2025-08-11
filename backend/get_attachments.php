<?php
require_once 'auth_middleware.php';
require_once 'db_helper.php';
require_once 'cors_handler.php';

// Handle CORS first
handleCors();
setJsonHeaders();

// Require authentication
$session = requireAuth();

try {
    $pdo = DatabaseHelper::getConnection();
    
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
        exit();
    }
    
    $issue_id = isset($_GET['issue_id']) ? (int)$_GET['issue_id'] : null;
    
    if (!$issue_id) {
        http_response_code(400);
        echo json_encode(['error' => 'Issue ID is required']);
        exit();
    }
    
    // Validate issue exists
    $stmt = $pdo->prepare("SELECT id FROM issues WHERE id = ? AND deleted = 0");
    $stmt->execute([$issue_id]);
    if (!$stmt->fetch()) {
        http_response_code(404);
        echo json_encode(['error' => 'Issue not found']);
        exit();
    }
    
    // Get attachments for the issue
    $stmt = $pdo->prepare("
        SELECT 
            fa.id, fa.issue_id, fa.original_filename, fa.stored_filename, 
            fa.file_size, fa.mime_type, fa.created_at,
            COALESCE(u.username, 'Unknown') as uploaded_by_name
        FROM file_attachments fa
        LEFT JOIN users u ON fa.uploaded_by = u.id
        WHERE fa.issue_id = ?
        ORDER BY fa.created_at DESC
    ");
    $stmt->execute([$issue_id]);
    $attachments = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'attachments' => $attachments
    ]);
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
}
?>
