<?php
// Test script for time tracking functionality

$base_url = 'http://localhost:8000';

echo "Testing Time Tracking API\n";
echo "========================\n\n";

// Test 1: Start timer for user 1, issue 1
echo "1. Starting timer for user 1, issue 1...\n";
$data = [
    'action' => 'start',
    'user_id' => 1,
    'issue_id' => 1
];

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $base_url . '/time_tracking.php');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "Response ($http_code): " . $response . "\n\n";

// Test 2: Get active timer for user 1
echo "2. Getting active timer for user 1...\n";
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $base_url . '/time_tracking.php?action=active&user_id=1');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "Response ($http_code): " . $response . "\n\n";

// Test 3: Start timer for user 1, issue 2 (should stop the previous timer)
echo "3. Starting timer for user 1, issue 2 (should stop previous timer)...\n";
$data = [
    'action' => 'start',
    'user_id' => 1,
    'issue_id' => 2
];

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $base_url . '/time_tracking.php');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "Response ($http_code): " . $response . "\n\n";

// Test 4: Get active timer for user 1
echo "4. Getting active timer for user 1...\n";
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $base_url . '/time_tracking.php?action=active&user_id=1');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "Response ($http_code): " . $response . "\n\n";

// Test 5: Stop timer for user 1
echo "5. Stopping timer for user 1...\n";
$data = [
    'action' => 'stop',
    'user_id' => 1
];

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $base_url . '/time_tracking.php');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "Response ($http_code): " . $response . "\n\n";

// Test 6: Get time statistics
echo "6. Getting time statistics...\n";
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $base_url . '/time_tracking.php?action=stats');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "Response ($http_code): " . $response . "\n\n";

echo "Test completed!\n";
?>
