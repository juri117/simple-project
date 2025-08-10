<?php
require_once 'auth_middleware.php';
require_once 'db_helper.php';
require_once 'cors_handler.php';

// Handle CORS first
handleCors();
setJsonHeaders();

// Require authentication
$session = requireAuth();

try {
    $pdo = DatabaseHelper::getConnection();
    
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        // Get all users with role
        $stmt = $pdo->prepare("SELECT id, username, role, created_at, updated_at FROM users ORDER BY username");
        $stmt->execute();
        $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode([
            'success' => true,
            'users' => $users
        ]);
    } else if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // Create new user (admin only)
        if ($session['role'] !== 'admin') {
            http_response_code(403);
            echo json_encode(['error' => 'Admin access required']);
            exit();
        }
        
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!$input || !isset($input['username']) || !isset($input['password']) || !isset($input['role'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Username, password, and role are required']);
            exit();
        }
        
        $username = trim($input['username']);
        $password = $input['password'];
        $role = $input['role'];
        
        if (empty($username) || empty($password)) {
            http_response_code(400);
            echo json_encode(['error' => 'Username and password cannot be empty']);
            exit();
        }
        
        if (!in_array($role, ['normal', 'admin', 'deactivated'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Invalid role']);
            exit();
        }
        
        // Check if username already exists
        $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
        $stmt->execute([$username]);
        if ($stmt->fetch()) {
            http_response_code(400);
            echo json_encode(['error' => 'Username already exists']);
            exit();
        }
        
        // Create new user
        $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
        $stmt = $pdo->prepare("INSERT INTO users (username, password, role) VALUES (?, ?, ?)");
        $stmt->execute([$username, $hashedPassword, $role]);
        
        $userId = $pdo->lastInsertId();
        
        echo json_encode([
            'success' => true,
            'message' => 'User created successfully',
            'user' => [
                'id' => $userId,
                'username' => $username,
                'role' => $role
            ]
        ]);
        
    } else if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        // Update user (admin only)
        if ($session['role'] !== 'admin') {
            http_response_code(403);
            echo json_encode(['error' => 'Admin access required']);
            exit();
        }
        
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!$input || !isset($input['id'])) {
            http_response_code(400);
            echo json_encode(['error' => 'User ID is required']);
            exit();
        }
        
        $userId = $input['id'];
        $updates = [];
        $params = [];
        
        if (isset($input['role'])) {
            if (!in_array($input['role'], ['normal', 'admin', 'deactivated'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Invalid role']);
                exit();
            }
            $updates[] = "role = ?";
            $params[] = $input['role'];
        }
        
        if (isset($input['password']) && !empty($input['password'])) {
            $updates[] = "password = ?";
            $params[] = password_hash($input['password'], PASSWORD_DEFAULT);
        }
        
        if (empty($updates)) {
            http_response_code(400);
            echo json_encode(['error' => 'No valid fields to update']);
            exit();
        }
        
        $updates[] = "updated_at = CURRENT_TIMESTAMP";
        $params[] = $userId;
        
        $sql = "UPDATE users SET " . implode(', ', $updates) . " WHERE id = ?";
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        
        if ($stmt->rowCount() > 0) {
            echo json_encode([
                'success' => true,
                'message' => 'User updated successfully'
            ]);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'User not found']);
        }
        
    } else if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        // Delete user (admin only)
        if ($session['role'] !== 'admin') {
            http_response_code(403);
            echo json_encode(['error' => 'Admin access required']);
            exit();
        }
        
        $userId = $_GET['id'] ?? null;
        
        if (!$userId) {
            http_response_code(400);
            echo json_encode(['error' => 'User ID is required']);
            exit();
        }
        
        // Prevent admin from deleting themselves
        if ($userId == $session['user_id']) {
            http_response_code(400);
            echo json_encode(['error' => 'Cannot delete your own account']);
            exit();
        }
        
        $stmt = $pdo->prepare("DELETE FROM users WHERE id = ?");
        $stmt->execute([$userId]);
        
        if ($stmt->rowCount() > 0) {
            echo json_encode([
                'success' => true,
                'message' => 'User deleted successfully'
            ]);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'User not found']);
        }
        
    } else {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
    }
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
}
?> 