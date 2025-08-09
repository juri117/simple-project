<?php
require_once 'session_manager.php';

function requireAuth() {
    // Get the Authorization header - try multiple methods
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
    
    // Debug logging
    error_log("Auth: All headers: " . print_r($headers, true));
    error_log("Auth: SERVER vars: " . print_r($_SERVER, true));
    error_log("Auth: Authorization header: '$authHeader'");
    
    // Check if Authorization header starts with "Bearer "
    if (!preg_match('/^Bearer\s+(.*)$/i', $authHeader, $matches)) {
        error_log("Auth: Authorization header validation failed");
        http_response_code(401);
        echo json_encode(['error' => 'Authorization header required']);
        exit();
    }
    
    $sessionToken = $matches[1];
    error_log("Auth: Session token extracted: $sessionToken");
    
    // Validate the session
    $session = SessionManager::validateSession($sessionToken);
    
    if (!$session) {
        error_log("Auth: Session validation failed for token: $sessionToken");
        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired session']);
        exit();
    }
    
    error_log("Auth: Session validated successfully for user: " . $session['username']);
    
    // Return the authenticated user data
    return $session;
}

function getAuthHeader() {
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    
    if (isset($headers['authorization'])) {
        return $headers['authorization'];
    } elseif (isset($headers['Authorization'])) {
        return $headers['Authorization'];
    } elseif (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        return $_SERVER['HTTP_AUTHORIZATION'];
    } elseif (isset($_SERVER['HTTP_AUTH'])) {
        return $_SERVER['HTTP_AUTH'];
    }
    
    return '';
}

function getSessionToken() {
    $authHeader = getAuthHeader();
    if (preg_match('/^Bearer\s+(.*)$/i', $authHeader, $matches)) {
        return $matches[1];
    }
    return null;
}
?>
