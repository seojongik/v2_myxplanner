<?php
/**
 * 카페24 SMS 인증 시스템 설정 파일
 * 
 * ⚠️ 보안 주의: 이 파일은 웹 루트 외부에 저장하거나,
 *    .htaccess로 직접 접근을 차단하세요.
 * 
 * 권장 위치: /home/golfcrm/config.php (웹 루트 외부)
 * 웹 루트: /home/golfcrm/www/
 */

// ===== 데이터베이스 설정 =====
define('DB_HOST', 'localhost');
define('DB_NAME', 'golfcrm');           // 카페24 DB명 (확인 필요)
define('DB_USER', 'golfcrm');           // 카페24 DB 사용자
define('DB_PASS', 'he0900874*');
define('DB_CHARSET', 'utf8mb4');

// ===== 알리고 API 설정 =====
define('ALIGO_API_URL', 'https://apis.aligo.in/send/');
define('ALIGO_API_KEY', 'djcg4vyirxyswndxi1xjobnoa93h76jr');
define('ALIGO_USER_ID', 'enables');
define('ALIGO_SENDER', '01023643612');  // 하이픈 없이

// ===== 프록시 보안 설정 =====
define('PROXY_SECRET', 'golfcrm_aligo_2024!');  // Flutter 앱과 동일하게

// ===== 인증 설정 =====
define('CODE_LENGTH', 6);               // 인증번호 길이
define('CODE_EXPIRES_MINUTES', 3);      // 만료 시간 (분)
define('MAX_ATTEMPTS', 5);              // 최대 검증 시도 횟수

// ===== 로그 설정 =====
define('LOG_DIR', __DIR__ . '/logs/');  // 로그 저장 경로

// ===== DB 연결 함수 =====
function getDBConnection() {
    try {
        $dsn = 'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=' . DB_CHARSET;
        $pdo = new PDO($dsn, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        return $pdo;
    } catch (PDOException $e) {
        error_log('DB 연결 실패: ' . $e->getMessage());
        return null;
    }
}

// ===== 로그 함수 =====
function writeLog($message, $type = 'info') {
    if (!is_dir(LOG_DIR)) {
        mkdir(LOG_DIR, 0755, true);
    }
    $logFile = LOG_DIR . 'sms_' . date('Y-m') . '.txt';
    $logLine = sprintf("[%s] [%s] %s\n", date('Y-m-d H:i:s'), strtoupper($type), $message);
    file_put_contents($logFile, $logLine, FILE_APPEND | LOCK_EX);
}

// ===== 응답 함수 =====
function jsonResponse($data, $statusCode = 200) {
    http_response_code($statusCode);
    header('Content-Type: application/json; charset=utf-8');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, X-Proxy-Secret');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

// ===== 보안 검증 함수 =====
function validateProxySecret() {
    $secret = $_SERVER['HTTP_X_PROXY_SECRET'] ?? '';
    if (!hash_equals(PROXY_SECRET, $secret)) {
        writeLog('잘못된 Proxy Secret 시도', 'warn');
        jsonResponse(['success' => false, 'error' => 'Forbidden'], 403);
    }
}

// ===== 전화번호 정규화 =====
function normalizePhone($phone) {
    // 숫자만 추출
    $digits = preg_replace('/[^0-9]/', '', $phone);
    
    // 010-1234-5678 형식으로 변환
    if (strlen($digits) === 11 && substr($digits, 0, 3) === '010') {
        return substr($digits, 0, 3) . '-' . substr($digits, 3, 4) . '-' . substr($digits, 7);
    }
    
    return null;  // 유효하지 않은 번호
}

