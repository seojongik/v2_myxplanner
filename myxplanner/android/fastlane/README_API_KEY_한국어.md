# Google Play Console API 키 설정 가이드 (상세)

## 📍 API 액세스 메뉴 찾기

Google Play Console에서 API 키를 설정하려면:

### 방법 1: 직접 URL 접근
1. [Google Play Console API 액세스 페이지](https://play.google.com/console/developers/api-access)로 직접 이동

### 방법 2: 설정 메뉴에서 찾기
1. [Google Play Console](https://play.google.com/console) 접속
2. 왼쪽 사이드바에서 **설정** (⚙️ 아이콘) 클릭
3. 설정 페이지에서:
   - **"API 액세스"** 섹션을 찾거나
   - 페이지 상단의 탭에서 **"API 액세스"** 탭 클릭
   - 또는 **"개발자 계정"** 섹션 안에 있을 수 있습니다

### 방법 3: 검색 사용
1. Google Play Console 상단의 검색창에 **"API"** 또는 **"API 액세스"** 입력
2. 검색 결과에서 **"API 액세스"** 선택

---

## 🔑 API 키 생성 단계

### 1단계: API 액세스 페이지 접근
- 위의 방법 중 하나로 API 액세스 페이지로 이동

### 2단계: 새 서비스 계정 생성
1. **"새 서비스 계정 만들기"** 또는 **"서비스 계정 만들기"** 버튼 클릭
2. Google Cloud Console로 리디렉션됩니다

### 3단계: Google Cloud Console에서 서비스 계정 생성
1. **서비스 계정 이름** 입력 (예: `fastlane-deploy` 또는 `mygolfplanner-deploy`)
2. **서비스 계정 ID**는 자동 생성됩니다 (변경 가능)
3. **설명** (선택사항): "Fastlane 자동 배포용" 등
4. **만들기** 또는 **만들고 계속하기** 클릭

### 4단계: 역할 및 권한 설정
1. **역할 선택** (선택사항):
   - Google Cloud 역할은 필요 없을 수 있습니다
   - Google Play Console에서 별도로 권한을 부여합니다
2. **완료** 또는 **계속** 클릭

### 5단계: JSON 키 다운로드
1. 생성된 서비스 계정 페이지에서:
   - **"키"** 탭 클릭
   - **"키 추가"** → **"새 키 만들기"** 클릭
   - **키 유형**: JSON 선택
   - **만들기** 클릭
2. **JSON 키 파일이 자동으로 다운로드됩니다** ⚠️ **이 파일은 한 번만 다운로드 가능합니다!**

### 6단계: Google Play Console로 돌아가서 권한 부여
1. Google Play Console의 **API 액세스** 페이지로 돌아갑니다
2. 방금 생성한 서비스 계정을 찾습니다
3. 서비스 계정을 클릭하거나 **"권한 부여"** 버튼 클릭
4. **앱 액세스** 섹션에서:
   - **"MyGolfPlanner"** 앱 선택
   - **권한** 선택:
     - ✅ **"앱 및 주문 관리"** (권장) 또는
     - ✅ **"릴리스 관리"** (배포만 필요한 경우)
5. **저장** 또는 **변경사항 저장** 클릭

---

## 📁 API 키 파일 배치

다운로드한 JSON 키 파일을 다음 위치에 저장:

```
myxplanner/android/fastlane/api-key.json
```

**파일 이름이 다를 경우** (예: `mygolfplanner-xxxxx.json`):
- 파일 이름을 `api-key.json`으로 변경하거나
- 또는 `Fastfile`의 `setup_google_play_api_key` 함수에서 경로를 수정

---

## ✅ 테스트

API 키 설정이 완료되면:

```bash
cd myxplanner
python3 deploy_android.py build  # 먼저 빌드만 테스트
```

빌드가 성공하면:

```bash
python3 deploy_android.py release  # 업로드 테스트 (제출 없음)
```

---

## ❓ 문제 해결

### "API 액세스" 메뉴를 찾을 수 없습니다
- **권한 확인**: 개발자 계정의 소유자 또는 관리자 권한이 필요합니다
- **직접 URL 사용**: https://play.google.com/console/developers/api-access
- **Google Cloud Console 확인**: 프로젝트가 연결되어 있는지 확인

### "서비스 계정 만들기" 버튼이 없습니다
- 이미 서비스 계정이 생성되어 있을 수 있습니다
- 기존 서비스 계정에 JSON 키를 추가할 수 있습니다

### 권한 부여 후에도 업로드가 실패합니다
- 서비스 계정에 앱 권한이 제대로 부여되었는지 확인
- JSON 키 파일 경로가 올바른지 확인
- Google Play Console에서 서비스 계정 상태 확인

### JSON 키 파일을 잃어버렸습니다
- Google Cloud Console에서 새 키를 생성해야 합니다
- 기존 키는 삭제하고 새 키를 생성하세요

---

## 🔒 보안 주의사항

⚠️ **중요**:
- `api-key.json` 파일은 **절대 Git에 커밋하지 마세요!**
- `.gitignore`에 추가되어 있는지 확인하세요
- 프로젝트 루트의 `non-git/` 디렉토리에 백업 보관을 권장합니다
- 키가 유출되면 즉시 Google Cloud Console에서 삭제하세요

---

## 📚 참고 자료

- [Google Play Console API 액세스 공식 문서](https://support.google.com/googleplay/android-developer/answer/6112435)
- [Fastlane supply 문서](https://docs.fastlane.tools/actions/upload_to_play_store/)
