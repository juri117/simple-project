<?php
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

try {
    $db_path = 'database.sqlite';
    $pdo = new PDO("sqlite:$db_path");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    switch ($_SERVER['REQUEST_METHOD']) {
        case 'GET':
            // Get all projects (not deleted) with time statistics
            $stmt = $pdo->prepare("
                SELECT 
                    p.id, p.name, p.description, p.status, p.created_at, p.updated_at,
                    COALESCE(SUM(CASE WHEN tt.stop_time IS NOT NULL THEN tt.stop_time - tt.start_time ELSE 0 END), 0) as total_time_seconds
                FROM projects p
                LEFT JOIN issues i ON p.id = i.project_id AND i.deleted = 0
                LEFT JOIN time_tracking tt ON i.id = tt.issue_id
                WHERE p.deleted = 0
                GROUP BY p.id, p.name, p.description, p.status, p.created_at, p.updated_at
                ORDER BY p.created_at DESC
            ");
            $stmt->execute();
            $projects = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true,
                'projects' => $projects
            ]);
            break;
            
        case 'POST':
            // Create new project
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!$input || !isset($input['name'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Project name is required']);
                exit();
            }
            
            $name = trim($input['name']);
            $description = isset($input['description']) ? trim($input['description']) : '';
            $status = isset($input['status']) ? $input['status'] : 'active';
            
            if (empty($name)) {
                http_response_code(400);
                echo json_encode(['error' => 'Project name cannot be empty']);
                exit();
            }
            
            $stmt = $pdo->prepare("INSERT INTO projects (name, description, status) VALUES (?, ?, ?)");
            $stmt->execute([$name, $description, $status]);
            
            $projectId = $pdo->lastInsertId();
            
            // Get the created project
            $stmt = $pdo->prepare("SELECT id, name, description, status, created_at, updated_at FROM projects WHERE id = ?");
            $stmt->execute([$projectId]);
            $project = $stmt->fetch(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true,
                'message' => 'Project created successfully',
                'project' => $project
            ]);
            break;
            
        case 'PUT':
            // Update project
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!$input || !isset($input['id'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Project ID is required']);
                exit();
            }
            
            $id = $input['id'];
            $name = isset($input['name']) ? trim($input['name']) : '';
            $description = isset($input['description']) ? trim($input['description']) : '';
            $status = isset($input['status']) ? $input['status'] : 'active';
            
            if (empty($name)) {
                http_response_code(400);
                echo json_encode(['error' => 'Project name cannot be empty']);
                exit();
            }
            
            $stmt = $pdo->prepare("UPDATE projects SET name = ?, description = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND deleted = 0");
            $result = $stmt->execute([$name, $description, $status, $id]);
            
            if ($stmt->rowCount() === 0) {
                http_response_code(404);
                echo json_encode(['error' => 'Project not found']);
                exit();
            }
            
            // Get the updated project
            $stmt = $pdo->prepare("SELECT id, name, description, status, created_at, updated_at FROM projects WHERE id = ?");
            $stmt->execute([$id]);
            $project = $stmt->fetch(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true,
                'message' => 'Project updated successfully',
                'project' => $project
            ]);
            break;
            
        case 'DELETE':
            // Soft delete project
            $input = json_decode(file_get_contents('php://input'), true);
            
            if (!$input || !isset($input['id'])) {
                http_response_code(400);
                echo json_encode(['error' => 'Project ID is required']);
                exit();
            }
            
            $id = $input['id'];
            
            $stmt = $pdo->prepare("UPDATE projects SET deleted = 1, deleted_at = CURRENT_TIMESTAMP WHERE id = ? AND deleted = 0");
            $result = $stmt->execute([$id]);
            
            if ($stmt->rowCount() === 0) {
                http_response_code(404);
                echo json_encode(['error' => 'Project not found']);
                exit();
            }
            
            echo json_encode([
                'success' => true,
                'message' => 'Project deleted successfully'
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