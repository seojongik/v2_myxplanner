# 카페24 SMS 인증 프록시

알리고 SMS API를 위한 고정 IP 프록시 서버

## 📁 파일 구조

```
cafe24_php/
├── config.php        # 설정 파일 (DB, 알리고 API)
├── send_code.php     # 인증번호 발송 API
├── verify_code.php   # 인증번호 검증 API
├── create_table.sql  # DB 테이블 생성 SQL
├── .htaccess         # 보안 설정
└── README.md         # 이 파일
```

## 🚀 배포 순서

### 1. 카페24 phpMyAdmin에서 테이블 생성

```sql
-- create_table.sql 내용 실행
```

### 2. config.php 수정

```php
define('DB_PASS', 'YOUR_DB_PASSWORD');  // ⚠️ 실제 비밀번호로 변경
```

### 3. 알리고에 IP 등록

- 알리고 관리자 → API 문자발송 → 발신 IP 설정
- IP: `183.110.224.221`

### 4. FTP 업로드

```bash
# FTP 접속 정보
호스트: golfcrm.mycafe24.com
포트: 21
아이디: golfcrm

# 업로드 위치
/www/sms/
├── config.php
├── send_code.php
├── verify_code.php
└── .htaccess
```

### 5. 테스트

```bash
# 405 응답 확인 (GET 요청)
curl https://golfcrm.mycafe24.com/sms/send_code.php
# 예상 응답: {"success":false,"error":"Method Not Allowed"}

# 403 응답 확인 (Secret 없이)
curl -X POST https://golfcrm.mycafe24.com/sms/send_code.php
# 예상 응답: {"success":false,"error":"Forbidden"}
```

## 📡 API 명세

### POST /sms/send_code.php - 인증번호 발송

**Headers:**
```
Content-Type: application/json
X-Proxy-Secret: golfcrm_aligo_2024!
```

**Body:**
```json
{
  "phone": "010-1234-5678"
}
```

**Response (성공):**
```json
{
  "success": true,
  "message": "인증번호가 발송되었습니다.",
  "expires_in": 180
}
```

### POST /sms/verify_code.php - 인증번호 검증

**Headers:**
```
Content-Type: application/json
X-Proxy-Secret: golfcrm_aligo_2024!
```

**Body:**
```json
{
  "phone": "010-1234-5678",
  "code": "123456"
}
```

**Response (성공):**
```json
{
  "success": true,
  "message": "인증이 완료되었습니다.",
  "phone": "010-1234-5678"
}
```

## 🔒 보안

- `X-Proxy-Secret` 헤더 필수
- `.htaccess`로 config.php 직접 접근 차단
- 인증 시도 5회 제한
- 인증번호 3분 만료

## 📊 DB 테이블

```
sms_verification
├── id (PK)
├── phone (전화번호)
├── code (6자리 인증번호)
├── created_at (생성시간)
├── expires_at (만료시간)
├── verified_at (인증완료시간)
├── attempts (시도횟수)
└── status (pending/verified/expired)
```

