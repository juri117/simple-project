<?php
require_once 'cors_handler.php';

// Handle CORS first
handleCors();
setJsonHeaders();

// Test endpoint to check Authorization header specifically
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Get headers using multiple methods
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $authHeader = '';
    
    // Try to get Authorization header from different sources
    if (isset($headers['authorization'])) {
        $authHeader = $headers['authorization'];
    } elseif (isset($headers['Authorization'])) {
        $authHeader = $headers['Authorization'];
    } elseif (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
    } elseif (isset($_SERVER['HTTP_AUTH'])) {
        $authHeader = $_SERVER['HTTP_AUTH'];
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Authorization header test',
        'method' => $_SERVER['REQUEST_METHOD'],
        'auth_header' => $authHeader,
        'auth_header_length' => strlen($authHeader),
        'headers' => $headers,
        'server_vars' => [
            'HTTP_AUTHORIZATION' => isset($_SERVER['HTTP_AUTHORIZATION']) ? $_SERVER['HTTP_AUTHORIZATION'] : 'Not set',
            'HTTP_AUTH' => isset($_SERVER['HTTP_AUTH']) ? $_SERVER['HTTP_AUTH'] : 'Not set',
            'HTTP_ORIGIN' => isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : 'Not set',
            'REQUEST_METHOD' => $_SERVER['REQUEST_METHOD']
        ]
    ]);
} else {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
}
?>
