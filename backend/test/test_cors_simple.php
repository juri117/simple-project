<?php
require_once 'cors_helper.php';

// Set CORS headers
setCorsHeaders();
setJsonHeaders();

// Simple test endpoint
echo json_encode([
    'success' => true,
    'message' => 'CORS test successful',
    'timestamp' => date('Y-m-d H:i:s'),
    'method' => $_SERVER['REQUEST_METHOD'],
    'origin' => isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : 'No origin'
]);
?>
