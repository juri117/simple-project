<?php
// Simple CORS test file
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

// Return simple test data
echo json_encode([
    'success' => true,
    'message' => 'CORS test successful',
    'method' => $_SERVER['REQUEST_METHOD'],
    'timestamp' => date('Y-m-d H:i:s'),
    'headers' => [
        'origin' => $_SERVER['HTTP_ORIGIN'] ?? 'not set',
        'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'not set'
    ]
]);
?>
