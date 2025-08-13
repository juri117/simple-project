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
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Database connection failed']);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'POST':
        // Start timer
        if (isset($input['action']) && $input['action'] === 'start') {
            startTimer($pdo, $input);
        } elseif (isset($input['action']) && $input['action'] === 'stop') {
            stopTimer($pdo, $input);
        } elseif (isset($input['action']) && $input['action'] === 'stop_manual') {
            stopTimerManual($pdo, $input);
        } elseif (isset($input['action']) && $input['action'] === 'create_entry') {
            createTimerEntry($pdo, $input);
        } elseif (isset($input['action']) && $input['action'] === 'update_entry') {
            updateTimerEntry($pdo, $input);
        } elseif (isset($input['action']) && $input['action'] === 'delete_entry') {
            deleteTimerEntry($pdo, $input);
        } elseif (isset($input['action']) && $input['action'] === 'abort') {
            abortTimer($pdo, $input);
        } else {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Invalid action']);
        }
        break;
        
    case 'GET':
        if (isset($_GET['action'])) {
            switch ($_GET['action']) {
                case 'active':
                    getActiveTimer($pdo, $_GET);
                    break;
                case 'stats':
                    getTimeStats($pdo, $_GET);
                    break;
                case 'entries':
                    getTimerEntries($pdo, $_GET);
                    break;
                default:
                    http_response_code(400);
                    echo json_encode(['success' => false, 'error' => 'Invalid action']);
            }
        } else {
            http_response_code(400);
            echo json_encode(['success' => false, 'error' => 'Action parameter required']);
        }
        break;
        
    default:
        http_response_code(405);
        echo json_encode(['success' => false, 'error' => 'Method not allowed']);
}

function startTimer($pdo, $input) {
    if (!isset($input['user_id']) || !isset($input['issue_id'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'user_id and issue_id are required']);
        return;
    }
    
    $userId = (int)$input['user_id'];
    $issueId = (int)$input['issue_id'];
    $startTime = time();
    
    try {
        // First, stop any active timers for this user
        $stmt = $pdo->prepare("UPDATE time_tracking SET stop_time = ? WHERE user_id = ? AND stop_time IS NULL");
        $stmt->execute([$startTime, $userId]);
        
        // Start new timer
        $stmt = $pdo->prepare("INSERT INTO time_tracking (user_id, issue_id, start_time) VALUES (?, ?, ?)");
        $stmt->execute([$userId, $issueId, $startTime]);
        
        echo json_encode([
            'success' => true,
            'message' => 'Timer started successfully',
            'timer_id' => $pdo->lastInsertId(),
            'start_time' => $startTime
        ]);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Failed to start timer: ' . $e->getMessage()]);
    }
}

function stopTimer($pdo, $input) {
    if (!isset($input['user_id'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'user_id is required']);
        return;
    }
    
    $userId = (int)$input['user_id'];
    $stopTime = time();
    
    try {
        $stmt = $pdo->prepare("UPDATE time_tracking SET stop_time = ? WHERE user_id = ? AND stop_time IS NULL");
        $result = $stmt->execute([$stopTime, $userId]);
        
        if ($stmt->rowCount() > 0) {
            echo json_encode([
                'success' => true,
                'message' => 'Timer stopped successfully',
                'stop_time' => $stopTime
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'error' => 'No active timer found for this user'
            ]);
        }
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Failed to stop timer: ' . $e->getMessage()]);
    }
}

function stopTimerManual($pdo, $input) {
    if (!isset($input['user_id']) || !isset($input['hours']) || !isset($input['minutes'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'user_id, hours, and minutes are required']);
        return;
    }
    
    $userId = (int)$input['user_id'];
    $hours = (int)$input['hours'];
    $minutes = (int)$input['minutes'];
    
    // Validate input
    if ($hours < 0 || $hours > 24 || $minutes < 0 || $minutes > 59) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Invalid hours or minutes. Hours: 0-24, Minutes: 0-59']);
        return;
    }
    
    try {
        // Get the active timer
        $stmt = $pdo->prepare("
            SELECT id, start_time 
            FROM time_tracking 
            WHERE user_id = ? AND stop_time IS NULL 
            ORDER BY start_time DESC 
            LIMIT 1
        ");
        $stmt->execute([$userId]);
        $timer = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$timer) {
            echo json_encode([
                'success' => false,
                'error' => 'No active timer found for this user'
            ]);
            return;
        }
        
        // Calculate stop time based on start time + hours + minutes
        $startTime = (int)$timer['start_time'];
        $durationSeconds = ($hours * 3600) + ($minutes * 60);
        $stopTime = $startTime + $durationSeconds;
        
        // Update the timer with the calculated stop time
        $stmt = $pdo->prepare("UPDATE time_tracking SET stop_time = ? WHERE id = ?");
        $result = $stmt->execute([$stopTime, $timer['id']]);
        
        if ($stmt->rowCount() > 0) {
            echo json_encode([
                'success' => true,
                'message' => 'Timer stopped manually successfully',
                'stop_time' => $stopTime,
                'duration_hours' => $hours,
                'duration_minutes' => $minutes,
                'duration_seconds' => $durationSeconds
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'error' => 'Failed to update timer'
            ]);
        }
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Failed to stop timer manually: ' . $e->getMessage()]);
    }
}

function getActiveTimer($pdo, $params) {
    if (!isset($params['user_id'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'user_id is required']);
        return;
    }
    
    $userId = (int)$params['user_id'];
    
    try {
        $stmt = $pdo->prepare("
            SELECT tt.*, i.title as issue_title, p.name as project_name
            FROM time_tracking tt
            JOIN issues i ON tt.issue_id = i.id
            JOIN projects p ON i.project_id = p.id
            WHERE tt.user_id = ? AND tt.stop_time IS NULL
            ORDER BY tt.start_time DESC
            LIMIT 1
        ");
        $stmt->execute([$userId]);
        $timer = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($timer) {
            echo json_encode([
                'success' => true,
                'timer' => $timer
            ]);
        } else {
            echo json_encode([
                'success' => true,
                'timer' => null
            ]);
        }
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Failed to get active timer: ' . $e->getMessage()]);
    }
}

function getTimeStats($pdo, $params) {
    $userId = isset($params['user_id']) ? (int)$params['user_id'] : null;
    $issueId = isset($params['issue_id']) ? (int)$params['issue_id'] : null;
    $projectId = isset($params['project_id']) ? (int)$params['project_id'] : null;
    
    try {
        $whereConditions = [];
        $params = [];
        
        if ($userId !== null) {
            $whereConditions[] = "tt.user_id = ?";
            $params[] = $userId;
        }
        
        if ($issueId !== null) {
            $whereConditions[] = "tt.issue_id = ?";
            $params[] = $issueId;
        }
        
        if ($projectId !== null) {
            $whereConditions[] = "i.project_id = ?";
            $params[] = $projectId;
        }
        
        $whereClause = !empty($whereConditions) ? "WHERE " . implode(" AND ", $whereConditions) : "";
        
        // Get total time for issues
        $sql = "
            SELECT 
                tt.issue_id,
                i.title as issue_title,
                p.name as project_name,
                SUM(CASE WHEN tt.stop_time IS NOT NULL THEN tt.stop_time - tt.start_time ELSE 0 END) as total_seconds
            FROM time_tracking tt
            JOIN issues i ON tt.issue_id = i.id
            JOIN projects p ON i.project_id = p.id
            $whereClause
            GROUP BY tt.issue_id, i.title, p.name
            ORDER BY total_seconds DESC
        ";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $issueStats = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Get project totals
        $sql = "
            SELECT 
                p.id as project_id,
                p.name as project_name,
                SUM(CASE WHEN tt.stop_time IS NOT NULL THEN tt.stop_time - tt.start_time ELSE 0 END) as total_seconds
            FROM time_tracking tt
            JOIN issues i ON tt.issue_id = i.id
            JOIN projects p ON i.project_id = p.id
            $whereClause
            GROUP BY p.id, p.name
            ORDER BY total_seconds DESC
        ";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $projectStats = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Calculate total time
        $totalSeconds = 0;
        foreach ($issueStats as $stat) {
            $totalSeconds += (int)$stat['total_seconds'];
        }
        
        echo json_encode([
            'success' => true,
            'stats' => [
                'total_seconds' => $totalSeconds,
                'total_hours' => round($totalSeconds / 3600, 2),
                'issues' => $issueStats,
                'projects' => $projectStats
            ]
        ]);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Failed to get time stats: ' . $e->getMessage()]);
    }
}

function createTimerEntry($pdo, $input) {
    if (!isset($input['user_id']) || !isset($input['issue_id']) || !isset($input['start_time']) || !isset($input['stop_time'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'user_id, issue_id, start_time, and stop_time are required']);
        return;
    }
    
    $userId = (int)$input['user_id'];
    $issueId = (int)$input['issue_id'];
    $startTime = (int)$input['start_time'];
    $stopTime = (int)$input['stop_time'];
    
    // Validate that stop_time is after start_time
    if ($stopTime <= $startTime) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'stop_time must be after start_time']);
        return;
    }
    
    try {
        $stmt = $pdo->prepare("INSERT INTO time_tracking (user_id, issue_id, start_time, stop_time) VALUES (?, ?, ?, ?)");
        $stmt->execute([$userId, $issueId, $startTime, $stopTime]);
        
        echo json_encode([
            'success' => true,
            'message' => 'Timer entry created successfully',
            'entry_id' => $pdo->lastInsertId()
        ]);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Failed to create timer entry: ' . $e->getMessage()]);
    }
}

function updateTimerEntry($pdo, $input) {
    if (!isset($input['entry_id']) || !isset($input['start_time']) || !isset($input['stop_time'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'entry_id, start_time, and stop_time are required']);
        return;
    }
    
    $entryId = (int)$input['entry_id'];
    $startTime = (int)$input['start_time'];
    $stopTime = (int)$input['stop_time'];
    
    // Validate that stop_time is after start_time
    if ($stopTime <= $startTime) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'stop_time must be after start_time']);
        return;
    }
    
    try {
        $stmt = $pdo->prepare("UPDATE time_tracking SET start_time = ?, stop_time = ? WHERE id = ?");
        $result = $stmt->execute([$startTime, $stopTime, $entryId]);
        
        if ($stmt->rowCount() > 0) {
            echo json_encode([
                'success' => true,
                'message' => 'Timer entry updated successfully'
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'error' => 'Timer entry not found'
            ]);
        }
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Failed to update timer entry: ' . $e->getMessage()]);
    }
}

function deleteTimerEntry($pdo, $input) {
    if (!isset($input['entry_id'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'entry_id is required']);
        return;
    }
    
    $entryId = (int)$input['entry_id'];
    
    try {
        $stmt = $pdo->prepare("DELETE FROM time_tracking WHERE id = ?");
        $result = $stmt->execute([$entryId]);
        
        if ($stmt->rowCount() > 0) {
            echo json_encode([
                'success' => true,
                'message' => 'Timer entry deleted successfully'
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'error' => 'Timer entry not found'
            ]);
        }
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Failed to delete timer entry: ' . $e->getMessage()]);
    }
}

function getTimerEntries($pdo, $params) {
    if (!isset($params['issue_id'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'issue_id is required']);
        return;
    }
    
    $issueId = (int)$params['issue_id'];
    
    try {
        $stmt = $pdo->prepare("
            SELECT 
                tt.id,
                tt.user_id,
                tt.issue_id,
                tt.start_time,
                tt.stop_time,
                tt.created_at,

                u.username as user_name,
                i.title as issue_title,
                p.name as project_name,
                CASE 
                    WHEN tt.stop_time IS NOT NULL 
                    THEN tt.stop_time - tt.start_time 
                    ELSE 0 
                END as duration_seconds
            FROM time_tracking tt
            JOIN users u ON tt.user_id = u.id
            JOIN issues i ON tt.issue_id = i.id
            JOIN projects p ON i.project_id = p.id
            WHERE tt.issue_id = ?
            ORDER BY tt.start_time DESC
        ");
        $stmt->execute([$issueId]);
        $entries = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode([
            'success' => true,
            'entries' => $entries
        ]);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Failed to get timer entries: ' . $e->getMessage()]);
    }
}

function abortTimer($pdo, $input) {
    if (!isset($input['user_id'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'user_id is required']);
        return;
    }
    
    $userId = (int)$input['user_id'];
    
    try {
        // Delete the active timer for this user (where stop_time IS NULL)
        $stmt = $pdo->prepare("DELETE FROM time_tracking WHERE user_id = ? AND stop_time IS NULL");
        $result = $stmt->execute([$userId]);
        
        if ($stmt->rowCount() > 0) {
            echo json_encode([
                'success' => true,
                'message' => 'Timer aborted successfully'
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'error' => 'No active timer found to abort'
            ]);
        }
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Failed to abort timer: ' . $e->getMessage()]);
    }
}
?>
