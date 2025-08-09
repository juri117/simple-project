<?php
function setCorsHeaders() {
    // Get the origin from the request
    $origin = isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : '';
    
    // Debug logging
    error_log("CORS: Request origin: $origin");
    
    // List of allowed origins
    $allowedOrigins = [
        'http://localhost:3000',
        'http://localhost:8080',
        'http://localhost:8000',
        'http://localhost:9000',
        'http://127.0.0.1:3000',
        'http://127.0.0.1:8080',
        'http://127.0.0.1:8000',
        'http://127.0.0.1:9000',
        'https://diaven.de',
        'https://www.diaven.de',
        'http://sp-be.diaven.de',
        'https://sp-be.diaven.de',
        // Flutter web app domains
        'https://diaven.de',
        'https://www.diaven.de',
        'https://sp.diaven.de',
        'https://www.sp.diaven.de',
        '*'
    ];
    
    // For now, allow all origins and enable credentials
    // This is more permissive but will work for the current setup
    if ($origin) {
        header("Access-Control-Allow-Origin: $origin");
        header('Access-Control-Allow-Credentials: true');
        error_log("CORS: Allowing origin with credentials: $origin");
    } else {
        header('Access-Control-Allow-Origin: *');
        error_log("CORS: No origin found, using wildcard");
    }
    
    // Set other CORS headers
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept, Origin');
    header('Access-Control-Max-Age: 86400'); // 24 hours
    
    // Handle preflight OPTIONS request
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        error_log("CORS: Handling preflight OPTIONS request");
        http_response_code(200);
        exit();
    }
}

function setJsonHeaders() {
    header('Content-Type: application/json; charset=utf-8');
}
?>
