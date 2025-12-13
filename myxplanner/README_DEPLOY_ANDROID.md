# Android 배포 가이드

Python 스크립트를 사용하여 간편하게 Android 앱을 Google Play Store에 배포할 수 있습니다.

## 빠른 시작

```bash
cd myxplanner

# Google Play에 업로드 (제출은 수동)
python3 deploy_android.py release

# Google Play에 업로드 + 자동 제출
python3 deploy_android.py submit

# 내부 테스트 트랙에 배포
python3 deploy_android.py internal

# 빌드만 수행 (업로드 없음)
python3 deploy_android.py build
```

## 주요 기능

- ✅ **자동 AAB 빌드**: Flutter를 사용하여 App Bundle 자동 생성
- ✅ **계정 정보 자동 읽기**: `non-git/ACCOUNT_INFO_MYGOLFPLANNER.md`에서 패키지명 자동 읽기
- ✅ **릴리즈 노트 자동 설정**: 한국어 릴리즈 노트 자동 포함
- ✅ **간단한 명령어**: 복잡한 Fastlane 명령어 대신 간단한 Python 스크립트 사용

## 사용 방법

### 기본 사용 (권장)

```bash
python3 deploy_android.py release
```

스크립트가 자동으로:
1. Flutter AAB 빌드 실행
2. `non-git/ACCOUNT_INFO_MYGOLFPLANNER.md`에서 패키지명 읽기
3. Fastlane을 사용하여 Google Play Console에 업로드

### 옵션 사용

```bash
# 패키지명 직접 지정
python3 deploy_android.py release --package-name app.mygolfplanner

# 빌드 건너뛰기 (이미 빌드된 AAB 사용)
python3 deploy_android.py release --skip-build
```

## 배포 타입

| 명령어 | 설명 |
|--------|------|
| `release` | Google Play에 업로드만 (제출은 수동) |
| `submit` | Google Play에 업로드 + 자동 제출 (프로덕션 트랙) |
| `internal` | 내부 테스트 트랙에 배포 |
| `build` | 빌드만 수행 (업로드 없음) |

### release vs submit

- **`release`**: 빌드 → 업로드만 수행. Google Play Console에서 수동으로 제출해야 합니다.
- **`submit`**: 빌드 → 업로드 → 자동 제출까지 모두 수행. 프로덕션 트랙에 바로 제출됩니다.

> ⚠️ **주의**: `submit`은 자동으로 프로덕션 트랙에 제출되므로, 충분한 테스트 후 사용하세요.

## Google Play Console API 키 설정 (선택사항)

자동 업로드를 위해서는 Google Play Console API 키가 필요합니다:

1. [Google Play Console](https://play.google.com/console) 접속
2. 설정 → API 액세스 → 새 서비스 계정 생성
3. JSON 키 파일 다운로드
4. `android/fastlane/api-key.json`에 저장

API 키가 없으면 빌드만 완료되고, AAB 파일 위치가 표시됩니다.
Google Play Console 웹사이트에서 수동으로 업로드할 수 있습니다.

## 파일 구조

```
myxplanner/
├── deploy_android.py          # 배포 스크립트
├── android/
│   ├── app/
│   │   └── upload-keystore.jks  # 서명 키 파일
│   └── fastlane/
│       ├── Fastfile          # Fastlane 설정
│       └── Appfile           # 앱 정보
└── build/
    └── app/
        └── outputs/
            └── bundle/
                └── release/
                    └── app-release.aab  # 빌드된 AAB 파일
```

## 문제 해결

### AAB 파일을 찾을 수 없습니다

1. 먼저 빌드를 실행하세요: `python3 deploy_android.py build`
2. 또는 `flutter build appbundle --release` 직접 실행

### Keystore 파일을 찾을 수 없습니다

1. `android/app/upload-keystore.jks` 파일이 있는지 확인
2. `non-git/ACCOUNT_INFO_MYGOLFPLANNER.md`에 Keystore 경로가 올바르게 설정되어 있는지 확인

### Google Play Console 업로드 실패

1. Google Play Console API 키가 설정되어 있는지 확인
2. API 키에 필요한 권한이 있는지 확인
3. 수동 업로드: Google Play Console 웹사이트에서 AAB 파일 업로드

## 기존 Fastlane 사용

Python 스크립트 없이 직접 Fastlane을 사용할 수도 있습니다:

```bash
cd myxplanner/android

# 배포 실행
fastlane release
fastlane submit
fastlane internal
```

## 참고

- 배포 후 Google Play Console에서 빌드 처리를 확인하세요: https://play.google.com/console
- 빌드 처리는 몇 분 정도 소요될 수 있습니다
- Keystore 파일은 안전하게 보관하세요 (분실 시 앱 업데이트 불가능)
