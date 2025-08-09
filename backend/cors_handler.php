<?php
function handleCors() {
    // Get the origin from the request
    $origin = isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : '';
    
    // Debug logging
    error_log("CORS Handler: Request origin: $origin");
    error_log("CORS Handler: Request method: " . $_SERVER['REQUEST_METHOD']);
    
    // Always allow the origin if it's set
    if ($origin) {
        header("Access-Control-Allow-Origin: $origin");
        header('Access-Control-Allow-Credentials: true');
        error_log("CORS Handler: Set origin to: $origin");
    } else {
        // Fallback for requests without origin
        header('Access-Control-Allow-Origin: *');
        error_log("CORS Handler: No origin, using wildcard");
    }
    
    // Set CORS headers
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept, Origin');
    header('Access-Control-Max-Age: 86400'); // 24 hours
    
    // Handle preflight OPTIONS request
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        error_log("CORS Handler: Handling preflight OPTIONS request");
        http_response_code(200);
        exit();
    }
}

function setJsonHeaders() {
    header('Content-Type: application/json; charset=utf-8');
}
?>
