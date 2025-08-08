<?php
require_once 'auth_middleware.php';
require_once 'db_helper.php';

// CORS headers
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Allow-Credentials: true');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Require authentication
$session = requireAuth();

try {
    $pdo = DatabaseHelper::getConnection();
    
    switch ($_SERVER['REQUEST_METHOD']) {
        case 'GET':
            // Get issues - either for a specific project or all issues
            $project_id = isset($_GET['project_id']) ? (int)$_GET['project_id'] : null;
            
            if ($project_id) {
                // Get issues for a specific project
                $stmt = $pdo->prepare("
                    SELECT 
                        i.id, i.project_id, i.title, i.description, i.status, i.priority, i.tags,
                        i.created_at, i.updated_at,
                        c.username as creator_name,
                        a.username as assignee_name
                    FROM issues i
                    LEFT JOIN users c ON i.creator_id = c.id
                    LEFT JOIN users a ON i.assignee_id = a.id
                    WHERE i.project_id = ? AND i.deleted = 0
                    ORDER BY 
                        CASE i.priority 
                            WHEN 'high' THEN 1 
                            WHEN 'medium' THEN 2 
                            WHEN 'low' THEN 3 
                        END,
                        i.created_at DESC
                ");
                $stmt->execute([$project_id]);
            } else {
                // Get all issues from all projects
                $stmt = $pdo->prepare("
                    SELECT 
                        i.id, i.project_id, i.title, i.description, i.status, i.priority, i.tags,
                        i.created_at, i.updated_at,
                        c.username as creator_name,
                        a.username as assignee_name,
                        p.name as project_name,
                        COALESCE(SUM(CASE WHEN tt.stop_time IS NOT NULL THEN tt.stop_time - tt.start_time ELSE 0 END), 0) as total_time_seconds
                    FROM issues i
                    LEFT JOIN users c ON i.creator_id = c.id
                    LEFT JOIN users a ON i.assignee_id = a.id
                    LEFT JOIN projects p ON i.project_id = p.id
                    LEFT JOIN time_tracking tt ON i.id = tt.issue_id
                    WHERE i.deleted = 0
                    GROUP BY i.id, i.project_id, i.title, i.description, i.status, i.priority, i.tags, i.created_at, i.updated_at, c.username, a.username, p.name
                    ORDER BY 
                        CASE i.priority 
                            WHEN 'high' THEN 1 
                            WHEN 'medium' THEN 2 
                            WHEN 'low' THEN 3 
                        END,
                        i.created_at DESC
                ");
                $stmt->execute();
            }
            
            $issues = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true,
                'issues' => $issues
            ]);
            break;
            
        case 'POST':
            // Create new issue
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!$input || !isset($input['project_id']) || !isset($input['title'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Project ID and title are required']);
                exit();
            }
            
            $project_id = (int)$input['project_id'];
            $title = trim($input['title']);
            $description = isset($input['description']) ? trim($input['description']) : '';
            $status = isset($input['status']) ? $input['status'] : 'open';
            $priority = isset($input['priority']) ? $input['priority'] : 'medium';
            $tags = isset($input['tags']) ? trim($input['tags']) : '';
            $creator_id = isset($input['creator_id']) ? (int)$input['creator_id'] : 1; // Default to admin
            $assignee_id = isset($input['assignee_id']) ? (int)$input['assignee_id'] : null;
            
            if (empty($title)) {
                http_response_code(400);
                echo json_encode(['error' => 'Issue title cannot be empty']);
                exit();
            }
            
            // Validate project exists
            $stmt = $pdo->prepare("SELECT id FROM projects WHERE id = ? AND deleted = 0");
            $stmt->execute([$project_id]);
            if (!$stmt->fetch()) {
                http_response_code(404);
                echo json_encode(['error' => 'Project not found']);
                exit();
            }
            
            $stmt = $pdo->prepare("
                INSERT INTO issues (project_id, title, description, status, priority, tags, creator_id, assignee_id) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ");
            $stmt->execute([$project_id, $title, $description, $status, $priority, $tags, $creator_id, $assignee_id]);
            
            $issueId = $pdo->lastInsertId();
            
            // Get the created issue with user names
            $stmt = $pdo->prepare("
                SELECT 
                    i.id, i.project_id, i.title, i.description, i.status, i.priority, i.tags,
                    i.created_at, i.updated_at,
                    c.username as creator_name,
                    a.username as assignee_name
                FROM issues i
                LEFT JOIN users c ON i.creator_id = c.id
                LEFT JOIN users a ON i.assignee_id = a.id
                WHERE i.id = ?
            ");
            $stmt->execute([$issueId]);
            $issue = $stmt->fetch(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true,
                'message' => 'Issue created successfully',
                'issue' => $issue
            ]);
            break;
            
        case 'PUT':
            // Update issue
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!$input || !isset($input['id'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Issue ID is required']);
                exit();
            }
            
            $id = (int)$input['id'];
            $title = isset($input['title']) ? trim($input['title']) : '';
            $description = isset($input['description']) ? trim($input['description']) : '';
            $status = isset($input['status']) ? $input['status'] : 'open';
            $priority = isset($input['priority']) ? $input['priority'] : 'medium';
            $tags = isset($input['tags']) ? trim($input['tags']) : '';
            $assignee_id = isset($input['assignee_id']) ? (int)$input['assignee_id'] : null;
            $project_id = isset($input['project_id']) ? (int)$input['project_id'] : null;
            
            if (empty($title)) {
                http_response_code(400);
                echo json_encode(['error' => 'Issue title cannot be empty']);
                exit();
            }
            
            // Validate project exists if project_id is provided
            if ($project_id !== null) {
                $stmt = $pdo->prepare("SELECT id FROM projects WHERE id = ? AND deleted = 0");
                $stmt->execute([$project_id]);
                if (!$stmt->fetch()) {
                    http_response_code(404);
                    echo json_encode(['error' => 'Project not found']);
                    exit();
                }
            }
            
            // Build the UPDATE query based on whether project_id is provided
            if ($project_id !== null) {
                $stmt = $pdo->prepare("
                    UPDATE issues 
                    SET title = ?, description = ?, status = ?, priority = ?, tags = ?, assignee_id = ?, project_id = ?, updated_at = CURRENT_TIMESTAMP 
                    WHERE id = ? AND deleted = 0
                ");
                $result = $stmt->execute([$title, $description, $status, $priority, $tags, $assignee_id, $project_id, $id]);
            } else {
                $stmt = $pdo->prepare("
                    UPDATE issues 
                    SET title = ?, description = ?, status = ?, priority = ?, tags = ?, assignee_id = ?, updated_at = CURRENT_TIMESTAMP 
                    WHERE id = ? AND deleted = 0
                ");
                $result = $stmt->execute([$title, $description, $status, $priority, $tags, $assignee_id, $id]);
            }
            
            if ($stmt->rowCount() === 0) {
                http_response_code(404);
                echo json_encode(['error' => 'Issue not found']);
                exit();
            }
            
            // Get the updated issue with user names
            $stmt = $pdo->prepare("
                SELECT 
                    i.id, i.project_id, i.title, i.description, i.status, i.priority, i.tags,
                    i.created_at, i.updated_at,
                    c.username as creator_name,
                    a.username as assignee_name
                FROM issues i
                LEFT JOIN users c ON i.creator_id = c.id
                LEFT JOIN users a ON i.assignee_id = a.id
                WHERE i.id = ?
            ");
            $stmt->execute([$id]);
            $issue = $stmt->fetch(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true,
                'message' => 'Issue updated successfully',
                'issue' => $issue
            ]);
            break;
            
        case 'DELETE':
            // Soft delete issue
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!$input || !isset($input['id'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Issue ID is required']);
                exit();
            }
            
            $id = (int)$input['id'];
            
            $stmt = $pdo->prepare("UPDATE issues SET deleted = 1, deleted_at = CURRENT_TIMESTAMP WHERE id = ? AND deleted = 0");
            $result = $stmt->execute([$id]);
            
            if ($stmt->rowCount() === 0) {
                http_response_code(404);
                echo json_encode(['error' => 'Issue not found']);
                exit();
            }
            
            echo json_encode([
                'success' => true,
                'message' => 'Issue deleted successfully'
            ]);
            break;
            
        default:
            http_response_code(405);
            echo json_encode(['error' => 'Method not allowed']);
            break;
    }
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
}
?> 