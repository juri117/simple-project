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
            // Get tags for a specific project
            $projectId = $_GET['project_id'] ?? null;
            
            if (!$projectId) {
                http_response_code(400);
                echo json_encode(['error' => 'Project ID is required']);
                exit();
            }
            
            $stmt = $pdo->prepare("
                SELECT t.id, t.short_name, t.description, t.color
                FROM tags t
                INNER JOIN project_tags pt ON t.id = pt.tag_id
                WHERE pt.project_id = ? AND t.disabled = 0
                ORDER BY t.short_name ASC
            ");
            $stmt->execute([$projectId]);
            $tags = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true,
                'tags' => $tags
            ]);
            break;
            
        case 'POST':
            // Assign tags to a project
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!$input || !isset($input['project_id']) || !isset($input['tag_ids'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Project ID and tag IDs are required']);
                exit();
            }
            
            $projectId = $input['project_id'];
            $tagIds = $input['tag_ids'];
            
            if (!is_array($tagIds)) {
                http_response_code(400);
                echo json_encode(['error' => 'Tag IDs must be an array']);
                exit();
            }
            
            // Verify project exists
            $stmt = $pdo->prepare("SELECT id FROM projects WHERE id = ? AND deleted = 0");
            $stmt->execute([$projectId]);
            if (!$stmt->fetch()) {
                http_response_code(404);
                echo json_encode(['error' => 'Project not found']);
                exit();
            }
            
            // Verify all tags exist and are not disabled
            $placeholders = str_repeat('?,', count($tagIds) - 1) . '?';
            $stmt = $pdo->prepare("SELECT id FROM tags WHERE id IN ($placeholders) AND disabled = 0");
            $stmt->execute($tagIds);
            $validTagIds = $stmt->fetchAll(PDO::FETCH_COLUMN);
            
            if (count($validTagIds) !== count($tagIds)) {
                http_response_code(400);
                echo json_encode(['error' => 'One or more tags not found or disabled']);
                exit();
            }
            
            // Remove existing tags for this project
            $stmt = $pdo->prepare("DELETE FROM project_tags WHERE project_id = ?");
            $stmt->execute([$projectId]);
            
            // Add new tags
            $stmt = $pdo->prepare("INSERT INTO project_tags (project_id, tag_id) VALUES (?, ?)");
            foreach ($validTagIds as $tagId) {
                $stmt->execute([$projectId, $tagId]);
            }
            
            echo json_encode([
                'success' => true,
                'message' => 'Tags assigned to project successfully'
            ]);
            break;
            
        case 'DELETE':
            // Remove specific tags from a project
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!$input || !isset($input['project_id']) || !isset($input['tag_ids'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Project ID and tag IDs are required']);
                exit();
            }
            
            $projectId = $input['project_id'];
            $tagIds = $input['tag_ids'];
            
            if (!is_array($tagIds)) {
                http_response_code(400);
                echo json_encode(['error' => 'Tag IDs must be an array']);
                exit();
            }
            
            $placeholders = str_repeat('?,', count($tagIds) - 1) . '?';
            $stmt = $pdo->prepare("DELETE FROM project_tags WHERE project_id = ? AND tag_id IN ($placeholders)");
            $params = array_merge([$projectId], $tagIds);
            $stmt->execute($params);
            
            echo json_encode([
                'success' => true,
                'message' => 'Tags removed from project successfully'
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
