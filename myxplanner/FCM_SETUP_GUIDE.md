# FCM 백그라운드 알림 설정 가이드

## 개요
채팅 메시지가 전송되면 Firebase Cloud Functions가 자동으로 FCM 푸시 알림을 발송합니다.

## 설정 단계

### 1. Firebase CLI 설치
```bash
npm install -g firebase-tools
```

### 2. Firebase 로그인
```bash
firebase login
```

### 3. Firebase 프로젝트 초기화 (이미 되어 있다면 생략)
```bash
firebase init functions
```

다음과 같이 선택:
- Use an existing project: **Y**
- Select a project: **mgpfunctions** (또는 해당 프로젝트)
- Language: **JavaScript**
- ESLint: **Y** (선택사항)
- Install dependencies: **Y**

### 4. Cloud Functions 배포
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 5. Firestore 보안 규칙 배포 (선택사항)
```bash
firebase deploy --only firestore:rules
```

## 동작 방식

1. **회원이 메시지 전송**
   - Firestore `messages` 컬렉션에 메시지 추가
   - Cloud Functions `sendChatNotification` 트리거
   - 해당 지점의 관리자 FCM 토큰 조회
   - 관리자에게 푸시 알림 발송

2. **관리자가 메시지 전송**
   - Firestore `messages` 컬렉션에 메시지 추가
   - Cloud Functions `sendChatNotification` 트리거
   - 해당 채팅방의 회원 FCM 토큰 조회
   - 회원에게 푸시 알림 발송

## FCM 토큰 저장 구조

### Firestore 컬렉션: `fcmTokens`
- 문서 ID: `{branchId}_{memberId}` 또는 `{branchId}_{adminId}`
- 필드:
  - `token`: FCM 토큰
  - `branchId`: 지점 ID
  - `memberId`: 회원/관리자 ID
  - `isAdmin`: 관리자 여부 (true/false)
  - `updatedAt`: 업데이트 시간
  - `platform`: 플랫폼 (android/ios/web)

## 문제 해결

### Cloud Functions가 트리거되지 않는 경우
1. Firebase Console > Functions에서 함수가 배포되었는지 확인
2. Firestore에 메시지가 실제로 추가되었는지 확인
3. Functions 로그 확인: `firebase functions:log`

### 푸시 알림이 발송되지 않는 경우
1. FCM 토큰이 Firestore에 저장되었는지 확인
2. 관리자/회원이 로그인했는지 확인
3. Cloud Functions 로그에서 에러 확인

### 토큰이 저장되지 않는 경우
1. FCM 서비스가 초기화되었는지 확인 (`main.dart`에서 `FCMService.initialize()` 호출)
2. 알림 권한이 허용되었는지 확인 (Android 13+)
3. Firebase 프로젝트 설정 확인

## 참고사항

- Cloud Functions는 무료 플랜에서도 일부 사용량 제공
- Firestore 읽기/쓰기 비용 발생
- FCM 푸시 알림은 무료

