<?php
require_once 'session_manager.php';

function requireAuth() {
    // Get the Authorization header
    $headers = getallheaders();
    $authHeader = isset($headers['authorization']) ? $headers['authorization'] : '';
    
    // Check if Authorization header starts with "Bearer "
    if (!preg_match('/^Bearer\s+(.*)$/i', $authHeader, $matches)) {
        http_response_code(401);
        echo json_encode(['error' => 'Authorization header required']);
        exit();
    }
    
    $sessionToken = $matches[1];
    
    // Validate the session
    $session = SessionManager::validateSession($sessionToken);
    
    if (!$session) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired session']);
        exit();
    }
    
    // Return the authenticated user data
    return $session;
}

function getAuthHeader() {
    $headers = getallheaders();
    return isset($headers['authorization']) ? $headers['authorization'] : '';
}

function getSessionToken() {
    $authHeader = getAuthHeader();
    if (preg_match('/^Bearer\s+(.*)$/i', $authHeader, $matches)) {
        return $matches[1];
    }
    return null;
}
?>
