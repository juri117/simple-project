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
    
    switch ($_SERVER['REQUEST_METHOD']) {
        case 'GET':
            // Get all tags (not disabled)
            $stmt = $pdo->prepare("
                SELECT id, short_name, description, color, created_at, updated_at
                FROM tags
                WHERE disabled = 0
                ORDER BY short_name ASC
            ");
            $stmt->execute();
            $tags = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true,
                'tags' => $tags
            ]);
            break;
            
        case 'POST':
            // Create new tag
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!$input || !isset($input['short_name'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Tag short name is required']);
                exit();
            }
            
            $shortName = trim($input['short_name']);
            $description = isset($input['description']) ? trim($input['description']) : '';
            $color = isset($input['color']) ? trim($input['color']) : '#3B82F6'; // Default blue color
            
            if (empty($shortName)) {
                http_response_code(400);
                echo json_encode(['error' => 'Tag short name cannot be empty']);
                exit();
            }
            
            // Check if tag with same short name already exists
            $stmt = $pdo->prepare("SELECT id FROM tags WHERE short_name = ? AND disabled = 0");
            $stmt->execute([$shortName]);
            if ($stmt->fetch()) {
                http_response_code(400);
                echo json_encode(['error' => 'Tag with this short name already exists']);
                exit();
            }
            
            $stmt = $pdo->prepare("INSERT INTO tags (short_name, description, color) VALUES (?, ?, ?)");
            $stmt->execute([$shortName, $description, $color]);
            
            $tagId = $pdo->lastInsertId();
            
            // Get the created tag
            $stmt = $pdo->prepare("SELECT id, short_name, description, color, created_at, updated_at FROM tags WHERE id = ?");
            $stmt->execute([$tagId]);
            $tag = $stmt->fetch(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true,
                'message' => 'Tag created successfully',
                'tag' => $tag
            ]);
            break;
            
        case 'PUT':
            // Update tag
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!$input || !isset($input['id'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Tag ID is required']);
                exit();
            }
            
            $id = $input['id'];
            $shortName = isset($input['short_name']) ? trim($input['short_name']) : '';
            $description = isset($input['description']) ? trim($input['description']) : '';
            $color = isset($input['color']) ? trim($input['color']) : '#3B82F6';
            
            if (empty($shortName)) {
                http_response_code(400);
                echo json_encode(['error' => 'Tag short name cannot be empty']);
                exit();
            }
            
            // Check if tag with same short name already exists (excluding current tag)
            $stmt = $pdo->prepare("SELECT id FROM tags WHERE short_name = ? AND id != ? AND disabled = 0");
            $stmt->execute([$shortName, $id]);
            if ($stmt->fetch()) {
                http_response_code(400);
                echo json_encode(['error' => 'Tag with this short name already exists']);
                exit();
            }
            
            $stmt = $pdo->prepare("UPDATE tags SET short_name = ?, description = ?, color = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND disabled = 0");
            $result = $stmt->execute([$shortName, $description, $color, $id]);
            
            if ($stmt->rowCount() === 0) {
                http_response_code(404);
                echo json_encode(['error' => 'Tag not found']);
                exit();
            }
            
            // Get the updated tag
            $stmt = $pdo->prepare("SELECT id, short_name, description, color, created_at, updated_at FROM tags WHERE id = ?");
            $stmt->execute([$id]);
            $tag = $stmt->fetch(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true,
                'message' => 'Tag updated successfully',
                'tag' => $tag
            ]);
            break;
            
        case 'DELETE':
            // Soft delete tag (set disabled = 1)
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!$input || !isset($input['id'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Tag ID is required']);
                exit();
            }
            
            $id = $input['id'];
            
            $stmt = $pdo->prepare("UPDATE tags SET disabled = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND disabled = 0");
            $result = $stmt->execute([$id]);
            
            if ($stmt->rowCount() === 0) {
                http_response_code(404);
                echo json_encode(['error' => 'Tag not found or already disabled']);
                exit();
            }
            
            echo json_encode([
                'success' => true,
                'message' => 'Tag disabled successfully'
            ]);
            break;
            
        default:
            http_response_code(405);
            echo json_encode(['error' => 'Method not allowed']);
            break;
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Internal server error: ' . $e->getMessage()]);
}
?>
