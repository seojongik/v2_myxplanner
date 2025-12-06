<?php
/**
 * SMS 인증번호 검증 API
 * 
 * POST /verify_code.php
 * Headers: X-Proxy-Secret: golfcrm_aligo_2024!
 * Body: { "phone": "010-1234-5678", "code": "123456" }
 * 
 * Response:
 * - 성공: { "success": true, "message": "인증이 완료되었습니다." }
 * - 실패: { "success": false, "error": "에러 메시지" }
 */

require_once __DIR__ . '/config.php';

// CORS Preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    jsonResponse(null, 204);
}

// POST만 허용
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(['success' => false, 'error' => 'Method Not Allowed'], 405);
}

// 보안 검증
validateProxySecret();

// 요청 데이터 파싱
$input = json_decode(file_get_contents('php://input'), true);
$phone = $input['phone'] ?? '';
$code = $input['code'] ?? '';

// 입력 검증
if (empty($code) || strlen($code) !== CODE_LENGTH) {
    jsonResponse(['success' => false, 'error' => '인증번호는 6자리입니다.'], 400);
}

// 전화번호 정규화
$normalizedPhone = normalizePhone($phone);
if (!$normalizedPhone) {
    jsonResponse(['success' => false, 'error' => '유효하지 않은 전화번호입니다.'], 400);
}

// DB 연결
$pdo = getDBConnection();
if (!$pdo) {
    jsonResponse(['success' => false, 'error' => '서버 오류가 발생했습니다.'], 500);
}

try {
    // 해당 전화번호의 가장 최근 pending 코드 조회
    $stmt = $pdo->prepare("
        SELECT id, code, expires_at, attempts 
        FROM sms_verification 
        WHERE phone = ? AND status = 'pending' 
        ORDER BY created_at DESC 
        LIMIT 1
    ");
    $stmt->execute([$normalizedPhone]);
    $record = $stmt->fetch();
    
    if (!$record) {
        jsonResponse(['success' => false, 'error' => '인증 요청 내역이 없습니다. 다시 인증번호를 요청해주세요.'], 400);
    }
    
    // 만료 확인
    if (strtotime($record['expires_at']) < time()) {
        // 만료 처리
        $stmt = $pdo->prepare("UPDATE sms_verification SET status = 'expired' WHERE id = ?");
        $stmt->execute([$record['id']]);
        jsonResponse(['success' => false, 'error' => '인증번호가 만료되었습니다. 다시 요청해주세요.'], 400);
    }
    
    // 시도 횟수 확인
    if ($record['attempts'] >= MAX_ATTEMPTS) {
        $stmt = $pdo->prepare("UPDATE sms_verification SET status = 'expired' WHERE id = ?");
        $stmt->execute([$record['id']]);
        jsonResponse(['success' => false, 'error' => '인증 시도 횟수를 초과했습니다. 다시 요청해주세요.'], 400);
    }
    
    // 시도 횟수 증가
    $stmt = $pdo->prepare("UPDATE sms_verification SET attempts = attempts + 1 WHERE id = ?");
    $stmt->execute([$record['id']]);
    
    // 코드 검증
    if ($record['code'] !== $code) {
        $remainingAttempts = MAX_ATTEMPTS - $record['attempts'] - 1;
        writeLog("인증 실패: {$normalizedPhone} (남은 시도: {$remainingAttempts})", 'warn');
        jsonResponse([
            'success' => false, 
            'error' => "인증번호가 일치하지 않습니다. (남은 시도: {$remainingAttempts}회)"
        ], 400);
    }
    
    // 인증 성공 - 상태 업데이트
    $stmt = $pdo->prepare("
        UPDATE sms_verification 
        SET status = 'verified', verified_at = NOW() 
        WHERE id = ?
    ");
    $stmt->execute([$record['id']]);
    
    writeLog("인증 성공: {$normalizedPhone}", 'info');
    jsonResponse([
        'success' => true, 
        'message' => '인증이 완료되었습니다.',
        'phone' => $normalizedPhone,
    ]);
    
} catch (Exception $e) {
    writeLog("오류: " . $e->getMessage(), 'error');
    jsonResponse(['success' => false, 'error' => '서버 오류가 발생했습니다.'], 500);
}

