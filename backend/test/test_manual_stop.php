<?php
// Test script for manual stop timer functionality

$base_url = 'http://localhost:8000';

echo "Testing Manual Stop Timer API\n";
echo "=============================\n\n";

// Test 1: Start timer for user 1, issue 1
echo "1. Starting timer for user 1, issue 1...\n";
$data = [
    'action' => 'start',
    'user_id' => 1,
    'issue_id' => 1
];

$context = stream_context_create([
    'http' => [
        'method' => 'POST',
        'header' => 'Content-Type: application/json',
        'content' => json_encode($data)
    ]
]);

$response = file_get_contents($base_url . '/time_tracking.php', false, $context);
echo "Response: " . $response . "\n\n";

// Test 2: Get active timer
echo "2. Getting active timer...\n";
$response = file_get_contents($base_url . '/time_tracking.php?action=active&user_id=1');
echo "Response: " . $response . "\n\n";

// Test 3: Stop timer manually with 2 hours 30 minutes
echo "3. Stopping timer manually with 2h 30m...\n";
$data = [
    'action' => 'stop_manual',
    'user_id' => 1,
    'hours' => 2,
    'minutes' => 30
];

$context = stream_context_create([
    'http' => [
        'method' => 'POST',
        'header' => 'Content-Type: application/json',
        'content' => json_encode($data)
    ]
]);

$response = file_get_contents($base_url . '/time_tracking.php', false, $context);
echo "Response: " . $response . "\n\n";

// Test 4: Get active timer (should be null now)
echo "4. Getting active timer (should be null)...\n";
$response = file_get_contents($base_url . '/time_tracking.php?action=active&user_id=1');
echo "Response: " . $response . "\n\n";

// Test 5: Get time statistics
echo "5. Getting time statistics...\n";
$response = file_get_contents($base_url . '/time_tracking.php?action=stats');
echo "Response: " . $response . "\n\n";

echo "Test completed!\n";
?>
