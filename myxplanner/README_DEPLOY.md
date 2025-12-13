# iOS 배포 가이드

Python 스크립트를 사용하여 간편하게 iOS 앱을 배포할 수 있습니다.

## 빠른 시작

```bash
cd myxplanner

# App Store에 업로드 (제출은 수동)
python3 deploy_ios.py release

# App Store에 업로드 + 자동 제출
python3 deploy_ios.py submit

# TestFlight에 배포
python3 deploy_ios.py beta

# 빌드만 수행 (업로드 없음)
python3 deploy_ios.py build
```

## 주요 기능

- ✅ **자동 API 키 설정**: 프로젝트 루트 `non-git/` 디렉토리에서 API 키 파일 자동 감지 및 복사
- ✅ **계정 정보 자동 읽기**: `non-git/ACCOUNT_INFO_MYGOLFPLANNER.md`에서 API Key ID와 Issuer ID 자동 읽기
- ✅ **간단한 명령어**: 복잡한 Fastlane 명령어 대신 간단한 Python 스크립트 사용
- ✅ **색상 출력**: 성공/경고/오류를 색상으로 구분하여 표시

## 사용 방법

### 기본 사용 (권장)

```bash
python3 deploy_ios.py release
```

스크립트가 자동으로:
1. 프로젝트 루트 `non-git/` 디렉토리에서 API 키 파일 찾기
2. `non-git/ACCOUNT_INFO_MYGOLFPLANNER.md`에서 API Key ID와 Issuer ID 읽기
3. Fastlane 실행

### 옵션 사용

```bash
# API Key ID 직접 지정
python3 deploy_ios.py release --api-key-id HW699DC545

# Issuer ID 직접 지정
python3 deploy_ios.py release --issuer-id 9dd4bee4-0107-4c6c-b8e3-191244666173

# API 키 파일 설정 건너뛰기
python3 deploy_ios.py release --skip-setup
```

## 배포 타입

| 명령어 | 설명 |
|--------|------|
| `release` | App Store에 업로드만 (제출은 수동) |
| `submit` | App Store에 업로드 + 자동 제출 (리뷰 제출 포함) |
| `beta` | TestFlight에 배포 |
| `testflight` | TestFlight에 배포 (beta와 동일) |
| `build` | 빌드만 수행 (업로드 없음) |

### release vs submit

- **`release`**: 빌드 → 업로드만 수행. App Store Connect에서 빌드가 처리된 후 수동으로 제출해야 합니다.
- **`submit`**: 빌드 → 업로드 → 자동 제출까지 모두 수행. 리뷰 제출까지 자동으로 진행됩니다.

> ⚠️ **주의**: `submit`은 자동으로 리뷰에 제출되므로, 메타데이터와 스크린샷이 준비되어 있는지 확인하세요.

## 파일 구조

```
v2_autogolf-project/
├── non-git/                          # 프로젝트 루트 (공유 리소스)
│   ├── ACCOUNT_INFO_MYGOLFPLANNER.md # 계정 정보 (자동 읽기)
│   ├── AuthKey_*.p8                  # API 키 파일 (자동 감지)
│   ├── google-services.json
│   └── supabase_keys.json
└── myxplanner/
    ├── deploy_ios.py                 # 배포 스크립트
    └── ios/
        └── fastlane/
            ├── Fastfile             # Fastlane 설정
            └── AuthKey.p8           # 복사된 API 키 파일
```

## 환경 변수 (선택사항)

스크립트는 다음 환경 변수를 사용할 수 있습니다:

```bash
export APP_STORE_CONNECT_API_KEY_ID="HW699DC545"
export APP_STORE_CONNECT_ISSUER_ID="9dd4bee4-0107-4c6c-b8e3-191244666173"
```

환경 변수가 설정되어 있으면 `ACCOUNT_INFO.md`보다 우선적으로 사용됩니다.

## 문제 해결

### API 키 파일을 찾을 수 없습니다

1. 프로젝트 루트 `non-git/` 디렉토리에 `AuthKey_*.p8` 또는 `ApiKey_*.p8` 파일이 있는지 확인
2. 파일 이름 형식: `AuthKey_HW699DC545.p8` (Key ID 포함)
3. 경로: `v2_autogolf-project/non-git/AuthKey_*.p8`

### 계정 정보를 읽을 수 없습니다

1. `non-git/ACCOUNT_INFO_MYGOLFPLANNER.md` 파일이 있는지 확인 (프로젝트 루트)
2. 파일에 다음 형식으로 정보가 있는지 확인:
   ```markdown
   | **API Key ID** | `HW699DC545` |
   | **Issuer ID** | `9dd4bee4-0107-4c6c-b8e3-191244666173` |
   ```

### Fastlane 오류

기존 Fastlane 명령어를 직접 사용할 수도 있습니다:

```bash
cd ios
fastlane release
```

## 기존 Fastlane 사용

Python 스크립트 없이 직접 Fastlane을 사용할 수도 있습니다:

```bash
cd myxplanner/ios

# 환경 변수 설정
export APP_STORE_CONNECT_API_KEY_ID="HW699DC545"
export APP_STORE_CONNECT_ISSUER_ID="9dd4bee4-0107-4c6c-b8e3-191244666173"

# 배포 실행
fastlane release
```

## 참고

- 배포 후 App Store Connect에서 빌드 처리를 확인하세요: https://appstoreconnect.apple.com
- 빌드 처리는 몇 분 정도 소요될 수 있습니다
- API 키는 프로젝트 루트 `non-git/` 디렉토리에 저장되어 Git에 커밋되지 않습니다
- 여러 프로젝트에서 공유할 수 있는 리소스는 프로젝트 루트 `non-git/`에 저장됩니다
