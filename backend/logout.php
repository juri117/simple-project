<?php
require_once 'auth_middleware.php';

// CORS headers
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Allow-Credentials: true');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

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
