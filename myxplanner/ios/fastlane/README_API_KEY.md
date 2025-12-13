# App Store Connect API 키 설정 가이드

## 자동 배포를 위한 API 키 설정

### 1. App Store Connect에서 API 키 생성

1. [App Store Connect](https://appstoreconnect.apple.com)에 로그인
2. **사용자 및 액세스** → **키** 탭으로 이동
3. **+** 버튼 클릭하여 새 키 생성
4. 키 이름 입력 (예: "Fastlane CI/CD")
5. **App Manager** 또는 **Admin** 권한 선택
6. 키 생성 후 **다운로드** (`.p8` 파일, 한 번만 다운로드 가능!)

### 2. API 키 파일 배치

다운로드한 `.p8` 파일을 다음 위치에 배치:
```
myxplanner/ios/fastlane/AuthKey.p8
```

### 3. 환경 변수 설정

터미널에서 다음 환경 변수를 설정하거나, `~/.zshrc` 또는 `~/.bash_profile`에 추가:

```bash
export APP_STORE_CONNECT_API_KEY_ID="your-key-id"  # 키 ID (예: ABC123DEFG)
export APP_STORE_CONNECT_ISSUER_ID="your-issuer-id"  # Issuer ID (예: 12345678-1234-1234-1234-123456789012)
```

또는 `.env` 파일 생성 (fastlane 디렉토리에):
```
APP_STORE_CONNECT_API_KEY_ID=your-key-id
APP_STORE_CONNECT_ISSUER_ID=your-issuer-id
```

### 4. 배포 실행

API 키 설정 후:
```bash
cd myxplanner/ios
fastlane release  # App Store에 제출
fastlane beta     # TestFlight에 제출
```

### 5. API 키 없이 배포 (수동 업로드)

API 키가 없으면 빌드만 완료되고, IPA 파일 위치가 표시됩니다.
Transporter 앱을 사용하여 수동으로 업로드할 수 있습니다.
