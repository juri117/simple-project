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
    
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
        exit();
    }
    
    // Check if file was uploaded
    if (!isset($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
        http_response_code(400);
        echo json_encode(['error' => 'No file uploaded or upload error']);
        exit();
    }
    
    $file = $_FILES['file'];
    $issue_id = isset($_POST['issue_id']) ? (int)$_POST['issue_id'] : null;
    
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
    
    // Validate file size (10MB max)
    $maxSize = 10 * 1024 * 1024; // 10MB in bytes
    if ($file['size'] > $maxSize) {
        http_response_code(400);
        echo json_encode(['error' => 'File size exceeds 10MB limit']);
        exit();
    }
    
    // Validate file type (basic check)
    $allowedTypes = [
        'image/jpeg', 'image/png', 'image/gif', 'image/webp',
        'application/pdf', 'text/plain', 'text/csv',
        'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/zip', 'application/x-rar-compressed'
    ];
    
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mimeType = finfo_file($finfo, $file['tmp_name']);
    finfo_close($finfo);
    
    if (!in_array($mimeType, $allowedTypes)) {
        http_response_code(400);
        echo json_encode(['error' => 'File type not allowed']);
        exit();
    }
    
    // Generate unique filename to prevent overwrites
    $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $storedFilename = uniqid() . '_' . time() . '.' . $extension;
    $uploadPath = 'uploads/' . $storedFilename;
    
    // Move uploaded file
    if (!move_uploaded_file($file['tmp_name'], $uploadPath)) {
        http_response_code(500);
        echo json_encode(['error' => 'Failed to save file']);
        exit();
    }
    
    // Save file info to database
    $stmt = $pdo->prepare("
        INSERT INTO file_attachments (issue_id, original_filename, stored_filename, file_size, mime_type, uploaded_by)
        VALUES (?, ?, ?, ?, ?, ?)
    ");
    $stmt->execute([
        $issue_id,
        $file['name'],
        $storedFilename,
        $file['size'],
        $mimeType,
        $session['user_id']
    ]);
    
    $attachmentId = $pdo->lastInsertId();
    
    // Get the created attachment
    $stmt = $pdo->prepare("
        SELECT 
            fa.id, fa.issue_id, fa.original_filename, fa.stored_filename, 
            fa.file_size, fa.mime_type, fa.created_at,
            COALESCE(u.username, 'Unknown') as uploaded_by_name
        FROM file_attachments fa
        LEFT JOIN users u ON fa.uploaded_by = u.id
        WHERE fa.id = ?
    ");
    $stmt->execute([$attachmentId]);
    $attachment = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // Debug: Log the attachment data
    error_log("Attachment data: " . json_encode($attachment));
    
    echo json_encode([
        'success' => true,
        'message' => 'File uploaded successfully',
        'attachment' => $attachment
    ]);
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Server error: ' . $e->getMessage()]);
}
?>
