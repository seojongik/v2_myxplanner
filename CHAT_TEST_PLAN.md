# 채팅 시스템 테스트 계획

## 📋 현재 설정 상태

### ✅ 완료된 설정

1. **Firebase 프로젝트**
   - 프로젝트 ID: `autogolfcrm-messaging`
   - 프로젝트 번호: `101436238734`
   - Android 앱: `1:101436238734:android:79880c733be09b34ff92df`
   - iOS 앱: `1:101436238734:ios:e2e727d584fd95b0ff92df`
   - Web 앱: `1:101436238734:web:3a082e5d671e4d39ff92df`

2. **Supabase 테이블**
   - `chat_rooms` - 채팅방 정보
   - `chat_messages` - 메시지 데이터
   - `fcm_tokens` - FCM 토큰 저장 (user_type, user_id 구조)

3. **Supabase Edge Function**
   - 함수명: `send-chat-notification`
   - 상태: ACTIVE (버전 5)
   - 환경 변수:
     - `FIREBASE_PROJECT_ID` = `autogolfcrm-messaging`
     - `FIREBASE_SERVICE_ACCOUNT_KEY` = (서비스 계정 키 JSON)
     - `PROJECT_URL` = `https://yejialakeivdhwntmagf.supabase.co`
     - `SERVICE_ROLE_KEY` = (Service Role 키)

4. **PostgreSQL Trigger**
   - `chat_messages` INSERT 시 Edge Function 자동 호출
   - `pg_net` 확장 사용

5. **Firebase 설정 파일**
   - iOS: `myxplanner/ios/Runner/GoogleService-Info.plist`
   - Android: `myxplanner/android/app/google-services.json`
   - Web: `myxplanner/lib/firebase_options.dart`

---

## 🧪 테스트 계획

### 1단계: 기본 설정 확인

#### 1.1 Firebase 설정 확인
- [ ] iOS 앱에서 Firebase 초기화 확인
- [ ] Android 앱에서 Firebase 초기화 확인
- [ ] Web 앱에서 Firebase 초기화 확인
- [ ] FCM 토큰 발급 확인 (각 플랫폼)

#### 1.2 Supabase 테이블 확인
```sql
-- 채팅방 테이블 확인
SELECT * FROM chat_rooms LIMIT 5;

-- 메시지 테이블 확인
SELECT * FROM chat_messages LIMIT 5;

-- FCM 토큰 테이블 확인
SELECT * FROM fcm_tokens LIMIT 5;
```

#### 1.3 Edge Function 환경 변수 확인
- [ ] Supabase 대시보드 > Edge Functions > send-chat-notification > Settings > Secrets
- [ ] 모든 환경 변수가 설정되어 있는지 확인

---

### 2단계: FCM 토큰 저장 테스트

#### 2.1 회원 앱 (myxplanner)
**테스트 시나리오:**
1. 앱 실행
2. FCM 토큰 발급 확인
3. Supabase `fcm_tokens` 테이블에 저장 확인

**확인 방법:**
```sql
SELECT * FROM fcm_tokens 
WHERE user_type = 'member' 
ORDER BY updated_at DESC 
LIMIT 1;
```

**예상 결과:**
- `user_type` = `'member'`
- `user_id` = 회원 ID
- `branch_id` = 지점 ID
- `token` = FCM 토큰 (비어있지 않음)
- `platform` = `'android'` 또는 `'ios'`

#### 2.2 관리자 앱 (CRM/CRM Lite Pro)
**테스트 시나리오:**
1. 앱 실행
2. FCM 토큰 발급 확인
3. Supabase `fcm_tokens` 테이블에 저장 확인

**확인 방법:**
```sql
SELECT * FROM fcm_tokens 
WHERE user_type = 'admin' 
ORDER BY updated_at DESC 
LIMIT 1;
```

**예상 결과:**
- `user_type` = `'admin'`
- `user_id` = 관리자 ID
- `branch_id` = 지점 ID
- `token` = FCM 토큰 (비어있지 않음)
- `platform` = `'android'` 또는 `'ios'`

---

### 3단계: 실시간 채팅 테스트

#### 3.1 채팅방 생성 테스트
**테스트 시나리오:**
1. 회원 앱에서 관리자에게 채팅 시작
2. 채팅방 생성 확인

**확인 방법:**
```sql
SELECT * FROM chat_rooms 
WHERE branch_id = 'YOUR_BRANCH_ID' 
ORDER BY created_at DESC 
LIMIT 1;
```

**예상 결과:**
- `id` = `{branchId}_{memberId}` 형식
- `branch_id`, `member_id`, `member_name` 등 필수 필드 채워짐
- `created_at` = 현재 시간

#### 3.2 메시지 전송 테스트 (회원 → 관리자)
**테스트 시나리오:**
1. 회원 앱에서 관리자에게 메시지 전송
2. 메시지가 `chat_messages` 테이블에 저장되는지 확인
3. 관리자 앱에서 실시간으로 메시지 수신 확인

**확인 방법:**
```sql
SELECT * FROM chat_messages 
WHERE sender_type = 'member' 
ORDER BY created_at DESC 
LIMIT 1;
```

**예상 결과:**
- `sender_type` = `'member'`
- `message` = 전송한 메시지 내용
- `chat_room_id` = 채팅방 ID
- `timestamp` = 현재 시간

#### 3.3 메시지 전송 테스트 (관리자 → 회원)
**테스트 시나리오:**
1. 관리자 앱에서 회원에게 메시지 전송
2. 메시지가 `chat_messages` 테이블에 저장되는지 확인
3. 회원 앱에서 실시간으로 메시지 수신 확인

**확인 방법:**
```sql
SELECT * FROM chat_messages 
WHERE sender_type = 'admin' 
ORDER BY created_at DESC 
LIMIT 1;
```

**예상 결과:**
- `sender_type` = `'admin'`
- `message` = 전송한 메시지 내용
- `chat_room_id` = 채팅방 ID
- `timestamp` = 현재 시간

---

### 4단계: 백그라운드 푸시 알림 테스트

#### 4.1 회원 → 관리자 알림 테스트
**테스트 시나리오:**
1. 관리자 앱을 백그라운드로 전환 (홈 버튼)
2. 회원 앱에서 관리자에게 메시지 전송
3. 관리자 기기에서 푸시 알림 수신 확인

**확인 사항:**
- [ ] Edge Function 로그 확인
  - Supabase 대시보드 > Edge Functions > send-chat-notification > Logs
  - "🔔 [Edge Function] 회원 메시지 - 관리자에게 알림 발송" 로그 확인
  - "✅ [Edge Function] FCM 발송 완료" 로그 확인
- [ ] 관리자 기기에서 푸시 알림 수신 확인
- [ ] 알림 제목: `{회원명}님의 메시지`
- [ ] 알림 내용: 메시지 내용 (50자 제한)

**Edge Function 로그 확인:**
```
Supabase 대시보드 > Edge Functions > send-chat-notification > Logs
```

**예상 로그:**
```
🔔 [Edge Function] 새 메시지 수신: {message_id}
🔔 [Edge Function] 발신자: member {sender_id}
🔔 [Edge Function] 회원 메시지 - 관리자에게 알림 발송
✅ [Edge Function] FCM 발송 완료: {token_prefix}...
```

#### 4.2 관리자 → 회원 알림 테스트
**테스트 시나리오:**
1. 회원 앱을 백그라운드로 전환 (홈 버튼)
2. 관리자 앱에서 회원에게 메시지 전송
3. 회원 기기에서 푸시 알림 수신 확인

**확인 사항:**
- [ ] Edge Function 로그 확인
  - "🔔 [Edge Function] 관리자 메시지 - 회원에게 알림 발송" 로그 확인
  - "✅ [Edge Function] FCM 발송 완료" 로그 확인
- [ ] 회원 기기에서 푸시 알림 수신 확인
- [ ] 알림 제목: `골프연습장과의 1:1대화`
- [ ] 알림 내용: 메시지 내용 (50자 제한)

**예상 로그:**
```
🔔 [Edge Function] 새 메시지 수신: {message_id}
🔔 [Edge Function] 발신자: admin {sender_id}
🔔 [Edge Function] 관리자 메시지 - 회원에게 알림 발송
✅ [Edge Function] FCM 발송 완료: {token_prefix}...
```

#### 4.3 종료 상태 알림 테스트
**테스트 시나리오:**
1. 회원 앱을 완전히 종료 (스와이프로 종료)
2. 관리자 앱에서 회원에게 메시지 전송
3. 회원 기기에서 푸시 알림 수신 확인

**확인 사항:**
- [ ] 앱이 완전히 종료된 상태에서도 알림 수신 확인
- [ ] 알림 클릭 시 앱이 열리고 해당 채팅방으로 이동하는지 확인

---

### 5단계: Edge Function 에러 처리 테스트

#### 5.1 유효하지 않은 토큰 처리
**테스트 시나리오:**
1. `fcm_tokens` 테이블에 유효하지 않은 토큰 추가
2. 메시지 전송
3. Edge Function이 실패한 토큰을 자동 삭제하는지 확인

**확인 방법:**
```sql
-- 유효하지 않은 토큰 추가 (테스트용)
INSERT INTO fcm_tokens (id, branch_id, user_id, user_type, token, platform)
VALUES ('test_invalid', 'YOUR_BRANCH_ID', 'test_user', 'member', 'invalid_token', 'android');

-- 메시지 전송 후 확인
SELECT * FROM fcm_tokens WHERE token = 'invalid_token';
-- 결과: 삭제되어야 함
```

**예상 로그:**
```
❌ [Edge Function] FCM 발송 실패 (토큰: invalid_token...): {error}
🗑️ [Edge Function] 유효하지 않은 토큰 삭제: 1
```

#### 5.2 채팅방 없음 처리
**테스트 시나리오:**
1. 존재하지 않는 `chat_room_id`로 메시지 전송 시도
2. Edge Function이 적절히 처리하는지 확인

**예상 로그:**
```
⚠️ [Edge Function] 채팅방을 찾을 수 없음
```

#### 5.3 토큰 없음 처리
**테스트 시나리오:**
1. FCM 토큰이 없는 사용자에게 메시지 전송
2. Edge Function이 적절히 처리하는지 확인

**예상 로그:**
```
⚠️ [Edge Function] 관리자 토큰 없음
또는
⚠️ [Edge Function] 회원 토큰 없음
```

---

### 6단계: 성능 테스트

#### 6.1 동시 메시지 전송 테스트
**테스트 시나리오:**
1. 여러 회원이 동시에 관리자에게 메시지 전송
2. 모든 알림이 정상적으로 발송되는지 확인
3. Edge Function 로그에서 에러 확인

**확인 사항:**
- [ ] 모든 메시지가 정상적으로 처리됨
- [ ] 알림 지연 시간 확인 (1초 이내 권장)
- [ ] 에러 없음

#### 6.2 대량 메시지 전송 테스트
**테스트 시나리오:**
1. 짧은 시간 내에 많은 메시지 전송 (예: 1분에 10개)
2. 모든 알림이 정상적으로 발송되는지 확인

**확인 사항:**
- [ ] 모든 메시지가 정상적으로 처리됨
- [ ] Edge Function 타임아웃 없음
- [ ] FCM API 호출 제한 초과 없음

---

## 🔍 문제 해결 가이드

### 문제 1: FCM 토큰이 저장되지 않음

**확인 사항:**
1. 앱에서 FCM 토큰 발급 확인
2. `fcm_service.dart`에서 Supabase 저장 로직 확인
3. Supabase RLS 정책 확인

**해결 방법:**
```sql
-- RLS 정책 확인
SELECT * FROM pg_policies WHERE tablename = 'fcm_tokens';

-- 필요시 RLS 정책 수정
```

### 문제 2: 백그라운드 알림이 오지 않음

**확인 사항:**
1. Edge Function 환경 변수 확인
2. Edge Function 로그 확인
3. FCM 토큰이 `fcm_tokens` 테이블에 저장되어 있는지 확인
4. PostgreSQL Trigger가 활성화되어 있는지 확인

**해결 방법:**
```sql
-- Trigger 확인
SELECT * FROM pg_trigger WHERE tgname = 'on_chat_message_created';

-- Edge Function 로그 확인
-- Supabase 대시보드 > Edge Functions > send-chat-notification > Logs
```

### 문제 3: Edge Function 에러 발생

**확인 사항:**
1. Edge Function 로그에서 에러 메시지 확인
2. 환경 변수 값 확인
3. FCM API 호출 성공 여부 확인

**일반적인 에러:**
- `FIREBASE_SERVICE_ACCOUNT_KEY` 형식 오류 → JSON 형식 확인
- `FIREBASE_PROJECT_ID` 불일치 → 프로젝트 ID 확인
- FCM API 인증 실패 → 서비스 계정 키 확인

---

## 📝 테스트 체크리스트

### 기본 설정
- [ ] Firebase 프로젝트 설정 확인
- [ ] Supabase 테이블 확인
- [ ] Edge Function 환경 변수 확인
- [ ] PostgreSQL Trigger 확인

### FCM 토큰 저장
- [ ] 회원 앱 FCM 토큰 저장 확인
- [ ] 관리자 앱 FCM 토큰 저장 확인
- [ ] 토큰 갱신 시 자동 업데이트 확인

### 실시간 채팅
- [ ] 채팅방 생성 확인
- [ ] 회원 → 관리자 메시지 전송 확인
- [ ] 관리자 → 회원 메시지 전송 확인
- [ ] 실시간 메시지 수신 확인 (양방향)

### 백그라운드 알림
- [ ] 회원 → 관리자 백그라운드 알림 확인
- [ ] 관리자 → 회원 백그라운드 알림 확인
- [ ] 종료 상태 알림 확인
- [ ] 알림 클릭 시 앱 열림 확인

### 에러 처리
- [ ] 유효하지 않은 토큰 자동 삭제 확인
- [ ] 채팅방 없음 처리 확인
- [ ] 토큰 없음 처리 확인

### 성능
- [ ] 동시 메시지 전송 테스트
- [ ] 대량 메시지 전송 테스트
- [ ] 알림 지연 시간 확인

---

## 📊 테스트 결과 기록

### 테스트 일시
- 날짜: _______________
- 테스터: _______________

### 테스트 결과

| 테스트 항목 | 결과 | 비고 |
|------------|------|------|
| FCM 토큰 저장 (회원) | ☐ 성공 ☐ 실패 | |
| FCM 토큰 저장 (관리자) | ☐ 성공 ☐ 실패 | |
| 채팅방 생성 | ☐ 성공 ☐ 실패 | |
| 실시간 채팅 (회원→관리자) | ☐ 성공 ☐ 실패 | |
| 실시간 채팅 (관리자→회원) | ☐ 성공 ☐ 실패 | |
| 백그라운드 알림 (회원→관리자) | ☐ 성공 ☐ 실패 | |
| 백그라운드 알림 (관리자→회원) | ☐ 성공 ☐ 실패 | |
| 종료 상태 알림 | ☐ 성공 ☐ 실패 | |
| 에러 처리 | ☐ 성공 ☐ 실패 | |

### 발견된 문제
1. 
2. 
3. 

### 다음 조치 사항
1. 
2. 
3. 

---

**작성일:** 2025년 1월  
**버전:** 1.0  
**상태:** 테스트 준비 완료

