<?php
/**
 * 일반 SMS/LMS 발송 API
 * 
 * POST /send_sms.php
 * Headers: X-Proxy-Secret: golfcrm_aligo_2024!
 * Body: { "phone": "010-1234-5678", "message": "메시지 내용", "msg_type": "SMS" }
 * 
 * msg_type: SMS (단문, 90바이트), LMS (장문), MMS (멀티미디어)
 * 
 * Response:
 * - 성공: { "success": true, "message": "문자가 발송되었습니다." }
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
$message = $input['message'] ?? '';
$msgType = strtoupper($input['msg_type'] ?? 'SMS');

// 전화번호 검증 및 정규화
$normalizedPhone = normalizePhone($phone);
if (!$normalizedPhone) {
    jsonResponse(['success' => false, 'error' => '유효하지 않은 전화번호입니다.'], 400);
}

// 메시지 검증
if (empty(trim($message))) {
    jsonResponse(['success' => false, 'error' => '메시지 내용이 없습니다.'], 400);
}

// 메시지 타입 검증
$validMsgTypes = ['SMS', 'LMS', 'MMS'];
if (!in_array($msgType, $validMsgTypes)) {
    $msgType = 'SMS';
}

// 메시지 길이에 따라 자동으로 LMS 전환 (90바이트 초과 시)
$messageBytes = strlen($message);
if ($msgType === 'SMS' && $messageBytes > 90) {
    $msgType = 'LMS';
    writeLog("메시지 길이 초과({$messageBytes}bytes), LMS로 자동 전환", 'info');
}

try {
    // 알리고 SMS 발송 파라미터
    $aligoParams = [
        'key' => ALIGO_API_KEY,
        'user_id' => ALIGO_USER_ID,
        'sender' => ALIGO_SENDER,
        'receiver' => str_replace('-', '', $normalizedPhone),
        'msg' => $message,
        'msg_type' => $msgType,
    ];
    
    // LMS/MMS의 경우 제목 추가 (첫 줄 사용)
    if ($msgType === 'LMS' || $msgType === 'MMS') {
        $lines = explode("\n", $message);
        $title = trim($lines[0]);
        // 제목이 너무 길면 자르기 (44바이트 제한)
        if (strlen($title) > 44) {
            $title = mb_substr($title, 0, 20, 'UTF-8');
        }
        $aligoParams['title'] = $title;
    }
    
    writeLog("SMS 발송 시작 - 수신: {$normalizedPhone}, 타입: {$msgType}, 길이: {$messageBytes}bytes", 'info');
    
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
        writeLog("알리고 API cURL 오류: {$curlError}", 'error');
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
    
    writeLog("SMS 발송 성공 - 수신: {$normalizedPhone}, msg_id: " . ($aligoResult['msg_id'] ?? 'N/A'), 'info');
    jsonResponse([
        'success' => true, 
        'message' => '문자가 발송되었습니다.',
        'msg_type' => $msgType,
        'msg_id' => $aligoResult['msg_id'] ?? null,
    ]);
    
} catch (Exception $e) {
    writeLog("오류: " . $e->getMessage(), 'error');
    jsonResponse(['success' => false, 'error' => '서버 오류가 발생했습니다.'], 500);
}

