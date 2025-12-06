<?php
/**
 * SMS 인증번호 발송 API
 * 
 * POST /send_code.php
 * Headers: X-Proxy-Secret: golfcrm_aligo_2024!
 * Body: { "phone": "010-1234-5678" }
 * 
 * Response:
 * - 성공: { "success": true, "message": "인증번호가 발송되었습니다." }
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

// 전화번호 검증 및 정규화
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
    // 기존 미사용 코드 만료 처리
    $stmt = $pdo->prepare("
        UPDATE sms_verification 
        SET status = 'expired' 
        WHERE phone = ? AND status = 'pending' AND expires_at > NOW()
    ");
    $stmt->execute([$normalizedPhone]);
    
    // 인증번호 생성 (6자리)
    $code = str_pad(random_int(0, 999999), CODE_LENGTH, '0', STR_PAD_LEFT);
    
    // 만료 시간 계산
    $expiresAt = date('Y-m-d H:i:s', strtotime('+' . CODE_EXPIRES_MINUTES . ' minutes'));
    
    // DB에 저장
    $stmt = $pdo->prepare("
        INSERT INTO sms_verification (phone, code, expires_at, status) 
        VALUES (?, ?, ?, 'pending')
    ");
    $stmt->execute([$normalizedPhone, $code, $expiresAt]);
    
    // 알리고 SMS 발송
    $message = "[마이엑스플래너] 인증번호: {$code}\n3분 내로 입력해주세요.";
    
    $aligoParams = [
        'key' => ALIGO_API_KEY,
        'user_id' => ALIGO_USER_ID,
        'sender' => ALIGO_SENDER,
        'receiver' => str_replace('-', '', $normalizedPhone),
        'msg' => $message,
    ];
    
    // 알리고 API 호출
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => ALIGO_API_URL,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => http_build_query($aligoParams),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_SSL_VERIFYPEER => true,
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);
    
    if ($curlError) {
        writeLog("알리고 API 오류: {$curlError}", 'error');
        jsonResponse(['success' => false, 'error' => 'SMS 발송에 실패했습니다.'], 500);
    }
    
    $aligoResult = json_decode($response, true);
    writeLog("알리고 응답: {$response}", 'info');
    
    // 알리고 결과 확인 (result_code가 1이면 성공)
    if (($aligoResult['result_code'] ?? '-1') != '1') {
        $errorMsg = $aligoResult['message'] ?? '알 수 없는 오류';
        writeLog("알리고 발송 실패: {$errorMsg}", 'error');
        jsonResponse(['success' => false, 'error' => 'SMS 발송에 실패했습니다: ' . $errorMsg], 500);
    }
    
    writeLog("SMS 발송 성공: {$normalizedPhone}", 'info');
    jsonResponse([
        'success' => true, 
        'message' => '인증번호가 발송되었습니다.',
        'expires_in' => CODE_EXPIRES_MINUTES * 60,  // 초 단위
    ]);
    
} catch (Exception $e) {
    writeLog("오류: " . $e->getMessage(), 'error');
    jsonResponse(['success' => false, 'error' => '서버 오류가 발생했습니다.'], 500);
}

