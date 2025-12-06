<?php
header('Content-Type: application/json; charset=utf-8');

// 에러 표시
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo json_encode([
    'step' => '1. PHP 실행 OK',
    'php_version' => phpversion(),
]);

// DB 연결 테스트
try {
    $dsn = 'mysql:host=localhost;dbname=golfcrm;charset=utf8mb4';
    $pdo = new PDO($dsn, 'golfcrm', 'he0900874*', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    ]);
    echo json_encode([
        'step' => '2. DB 연결 OK',
    ]);
    
    // 테이블 확인
    $stmt = $pdo->query("SHOW TABLES LIKE 'sms_verification'");
    $table = $stmt->fetch();
    echo json_encode([
        'step' => '3. 테이블 존재: ' . ($table ? 'YES' : 'NO'),
    ]);
    
} catch (PDOException $e) {
    echo json_encode([
        'step' => '2. DB 연결 실패',
        'error' => $e->getMessage(),
    ]);
}

