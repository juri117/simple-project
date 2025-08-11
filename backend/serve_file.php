<?php
require_once 'auth_middleware.php';
require_once 'db_helper.php';
require_once 'cors_handler.php';

// Handle CORS first
handleCors();

// Require authentication
$session = requireAuth();

try {
    $pdo = DatabaseHelper::getConnection();
    
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
        exit();
    }
    
    $attachment_id = isset($_GET['id']) ? (int)$_GET['id'] : null;
    
    if (!$attachment_id) {
        http_response_code(400);
        echo json_encode(['error' => 'Attachment ID is required']);
        exit();
    }
    
    // Get attachment info
    $stmt = $pdo->prepare("
        SELECT 
            fa.id, fa.issue_id, fa.original_filename, fa.stored_filename, 
            fa.file_size, fa.mime_type, fa.created_at
        FROM file_attachments fa
        WHERE fa.id = ?
    ");
    $stmt->execute([$attachment_id]);
    $attachment = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$attachment) {
        http_response_code(404);
        echo json_encode(['error' => 'Attachment not found']);
        exit();
    }
    
    $filePath = 'uploads/' . $attachment['stored_filename'];
    
    if (!file_exists($filePath)) {
        http_response_code(404);
        echo json_encode(['error' => 'File not found on disk']);
        exit();
    }
    
    // Set appropriate headers
    header('Content-Type: ' . $attachment['mime_type']);
    header('Content-Disposition: inline; filename="' . $attachment['original_filename'] . '"');
    header('Content-Length: ' . $attachment['file_size']);
    header('Cache-Control: public, max-age=3600'); // Cache for 1 hour
    
    // Output the file
    readfile($filePath);
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Server error: ' . $e->getMessage()]);
}
?>
