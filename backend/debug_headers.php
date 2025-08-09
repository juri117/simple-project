<?php
require_once 'cors_helper.php';

// Set CORS headers
setCorsHeaders();
setJsonHeaders();

// Debug endpoint to check headers
echo json_encode([
    'success' => true,
    'message' => 'Header debug endpoint',
    'method' => $_SERVER['REQUEST_METHOD'],
    'headers' => function_exists('getallheaders') ? getallheaders() : 'getallheaders() not available',
    'server_vars' => [
        'HTTP_AUTHORIZATION' => isset($_SERVER['HTTP_AUTHORIZATION']) ? $_SERVER['HTTP_AUTHORIZATION'] : 'Not set',
        'HTTP_AUTH' => isset($_SERVER['HTTP_AUTH']) ? $_SERVER['HTTP_AUTH'] : 'Not set',
        'HTTP_ORIGIN' => isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : 'Not set',
        'HTTP_REFERER' => isset($_SERVER['HTTP_REFERER']) ? $_SERVER['HTTP_REFERER'] : 'Not set',
        'REQUEST_METHOD' => $_SERVER['REQUEST_METHOD'],
        'CONTENT_TYPE' => isset($_SERVER['CONTENT_TYPE']) ? $_SERVER['CONTENT_TYPE'] : 'Not set'
    ],
    'all_server_vars' => $_SERVER
]);
?>
