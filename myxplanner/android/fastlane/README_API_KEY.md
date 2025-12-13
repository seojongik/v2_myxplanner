# Google Play Console API 키 설정 가이드

## 자동 배포를 위한 API 키 설정

### 1. Google Play Console에서 API 키 생성

1. [Google Play Console](https://play.google.com/console)에 로그인
2. **설정** (왼쪽 사이드바) 클릭
3. **API 액세스** 섹션 찾기
   - 설정 페이지에서 아래로 스크롤하면 "API 액세스" 섹션이 있습니다
   - 또는 설정 페이지 상단의 탭에서 "API 액세스" 탭을 찾을 수 있습니다
4. **새 서비스 계정 만들기** 또는 **서비스 계정 만들기** 버튼 클릭
5. Google Cloud Console로 리디렉션됩니다
6. 서비스 계정 생성:
   - **서비스 계정 이름** 입력 (예: "fastlane-deploy")
   - **역할**: "Google Play Console 관리자" 또는 "릴리스 관리자" 선택
   - **만들기** 클릭
7. 생성된 서비스 계정에서 **JSON 키 만들기** 클릭
8. JSON 키 파일 다운로드 (한 번만 다운로드 가능!)

### 2. API 키 파일 배치

다운로드한 JSON 키 파일을 다음 위치에 배치:
```
myxplanner/android/fastlane/api-key.json
```

### 3. 권한 설정

Google Play Console에서:
1. **설정** → **API 액세스**로 다시 이동
2. 생성한 서비스 계정을 찾아 클릭
3. **권한** 탭 또는 **앱 액세스** 섹션에서:
   - **앱 액세스**: "MyGolfPlanner" 앱 선택
   - **권한**: "앱 및 주문 관리" 또는 "릴리스 관리" 선택
   - **저장** 또는 **변경사항 저장** 클릭

**중요**: 서비스 계정을 생성한 후 반드시 Google Play Console로 돌아와서 앱에 대한 권한을 부여해야 합니다!

### 4. 배포 실행

API 키 설정 후:
```bash
cd myxplanner
python3 deploy_android.py submit  # Google Play에 제출
python3 deploy_android.py release # 업로드만
python3 deploy_android.py internal # 내부 테스트
```

### 5. API 키 없이 배포 (수동 업로드)

API 키가 없으면 빌드만 완료되고, AAB 파일 위치가 표시됩니다.
Google Play Console 웹사이트에서 수동으로 업로드할 수 있습니다.

## 파일 구조

```
myxplanner/android/fastlane/
├── Fastfile          # Fastlane 설정
├── Appfile           # 앱 정보
├── api-key.json      # Google Play Console API 키 (Git에 커밋하지 마세요!)
└── metadata/         # 메타데이터 (changelog 포함)
    └── android/
        └── ko-KR/
            └── changelogs/
                └── default.txt
```

## 보안 주의사항

⚠️ **중요**: `api-key.json` 파일은 절대 Git에 커밋하지 마세요!
- `.gitignore`에 추가되어 있는지 확인
- 프로젝트 루트의 `non-git/` 디렉토리에 백업 보관 권장
