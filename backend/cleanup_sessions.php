<?php
require_once 'session_manager.php';

// Clean up expired sessions
try {
    $cleaned = SessionManager::cleanupExpiredSessions();
    
    if ($cleaned) {
        echo "Expired sessions cleaned up successfully!\n";
    } else {
        echo "No expired sessions found or cleanup failed.\n";
    }
    
} catch (Exception $e) {
    echo "Error during cleanup: " . $e->getMessage() . "\n";
    exit(1);
}
?>
