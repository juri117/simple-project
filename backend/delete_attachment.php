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
    
    if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
        exit();
    }
    
    $input = json_decode(file_get_contents('php://input'), true);
    $attachment_id = isset($input['id']) ? (int)$input['id'] : null;
    
    if (!$attachment_id) {
        http_response_code(400);
        echo json_encode(['error' => 'Attachment ID is required']);
        exit();
    }
    
    // Get attachment info first
    $stmt = $pdo->prepare("
        SELECT fa.stored_filename, fa.issue_id, i.creator_id, i.assignee_id
        FROM file_attachments fa
        JOIN issues i ON fa.issue_id = i.id
        WHERE fa.id = ? AND i.deleted = 0
    ");
    $stmt->execute([$attachment_id]);
    $attachment = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$attachment) {
        http_response_code(404);
        echo json_encode(['error' => 'Attachment not found']);
        exit();
    }
    
    // Check if user has permission to delete (creator, assignee, or admin)
    $user_id = $session['user_id'];
    $user_role = $session['user_role'];
    
    if ($user_role !== 'admin' && 
        $attachment['creator_id'] != $user_id && 
        $attachment['assignee_id'] != $user_id) {
        http_response_code(403);
        echo json_encode(['error' => 'Permission denied']);
        exit();
    }
    
    // Delete the file from disk
    $filePath = 'uploads/' . $attachment['stored_filename'];
    if (file_exists($filePath)) {
        unlink($filePath);
    }
    
    // Delete from database
    $stmt = $pdo->prepare("DELETE FROM file_attachments WHERE id = ?");
    $stmt->execute([$attachment_id]);
    
    if ($stmt->rowCount() === 0) {
        http_response_code(404);
        echo json_encode(['error' => 'Attachment not found']);
        exit();
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Attachment deleted successfully'
    ]);
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Server error: ' . $e->getMessage()]);
}
?>
