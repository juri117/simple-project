<?php
require_once 'auth_middleware.php';
require_once 'cors_handler.php';

// Handle CORS first
handleCors();
setJsonHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

// Require authentication
$session = requireAuth();

// Destroy the session
$sessionToken = getSessionToken();
if (SessionManager::destroySession($sessionToken)) {
    echo json_encode([
        'success' => true,
        'message' => 'Logout successful'
    ]);
} else {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to logout']);
}
?>
