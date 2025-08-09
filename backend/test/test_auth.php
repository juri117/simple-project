<?php
require_once 'cors_helper.php';
require_once 'auth_middleware.php';
require_once 'db_helper.php';

// Set CORS headers
setCorsHeaders();
setJsonHeaders();

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Test endpoint to check authentication
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    try {
        // Check if we can get the Authorization header
        $headers = getallheaders();
        $authHeader = isset($headers['authorization']) ? $headers['authorization'] : 'No Authorization header';
        
        echo json_encode([
            'success' => true,
            'message' => 'Auth test endpoint',
            'method' => $_SERVER['REQUEST_METHOD'],
            'auth_header' => $authHeader,
            'headers' => $headers,
            'server' => [
                'HTTP_ORIGIN' => isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : 'No Origin',
                'HTTP_REFERER' => isset($_SERVER['HTTP_REFERER']) ? $_SERVER['HTTP_REFERER'] : 'No Referer',
                'REQUEST_METHOD' => $_SERVER['REQUEST_METHOD']
            ]
        ]);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'error' => 'Test failed: ' . $e->getMessage()
        ]);
    }
} elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Test authentication
    try {
        $session = requireAuth();
        echo json_encode([
            'success' => true,
            'message' => 'Authentication successful',
            'user' => $session
        ]);
    } catch (Exception $e) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'error' => 'Authentication failed: ' . $e->getMessage()
        ]);
    }
} else {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
}
?>
