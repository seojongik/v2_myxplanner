# AutoGolf Platform

골프장 통합 관리 플랫폼 - Monorepo

## 📍 진입점

### 개발자
```bash
git clone https://github.com/seojongik/autogolf-project.git
cd autogolf-project/  # ← 여기서 시작
```

### 사용자
- 웹사이트: https://autogolfcrm.com
- 첫 페이지: 랜딩 페이지 (landing/)
- CRM 앱: /app (crm/)

## 📁 프로젝트 구조

```
autogolf-project/
├── landing/              # 랜딩 페이지 (HTML/CSS/JS)
│   ├── landing_push.py  # 랜딩만 push
│   └── landing_pull.py  # 랜딩만 pull
│
├── crm/                 # CRM 메인 앱 (Flutter)
│   ├── crm_push.py     # CRM만 push
│   ├── crm_pull.py     # CRM만 pull
│   └── lib/
│
├── myxplanner/          # 골프 플래너 (Flutter)
│   ├── planner_push.py # 플래너만 push
│   ├── planner_pull.py # 플래너만 pull
│   └── lib/
│
├── push_all.py          # 전체 한 번에 push
├── pull_all.py          # 전체 한 번에 pull
├── status_all.py        # 전체 상태 확인
│
├── test_run_landing.py     # 🧪 랜딩 페이지 테스트 실행
├── test_run_crm.py         # 🧪 CRM 앱 테스트 실행
└── test_run_myxplanner.py  # 🧪 플래너 앱 테스트 실행
```

## 🚀 빠른 시작

### 🧪 간편 테스트 실행 (권장)

각 프로젝트를 쉽게 테스트할 수 있는 스크립트가 제공됩니다:

```bash
# 랜딩 페이지 테스트 (포트 8000)
python3 test_run_landing.py --open

# CRM 앱 테스트 (웹 브라우저)
python3 test_run_crm.py

# MyXPlanner 앱 테스트 (웹 브라우저)
python3 test_run_myxplanner.py
```

### 📱 모바일/데스크톱 테스트

```bash
# iOS 시뮬레이터에서 테스트
python3 test_run_crm.py --ios
python3 test_run_myxplanner.py --ios

# Android 에뮬레이터에서 테스트
python3 test_run_crm.py --android
python3 test_run_myxplanner.py --android

# 연결된 디바이스에서 테스트
python3 test_run_crm.py --mobile
python3 test_run_myxplanner.py --mobile
```

### 🔧 상세 옵션

```bash
# Flutter 클린 빌드
python3 test_run_crm.py --clean

# 빌드만 수행 (실행 안함)
python3 test_run_crm.py --build

# 사용 가능한 디바이스 목록 확인
python3 test_run_crm.py --devices

# Firebase 설정 확인
python3 test_run_myxplanner.py --check

# 파일 구조 확인
python3 test_run_landing.py --check

# 도움말 보기
python3 test_run_crm.py --help
```

### 랜딩 페이지 개발
```bash
cd landing/
python3 -m http.server 8000
# 또는
python3 ../test_run_landing.py --open
```

### CRM 개발
```bash
cd crm/
flutter pub get
flutter run -d chrome
# 또는
python3 ../test_run_crm.py
```

### 플래너 개발
```bash
cd myxplanner/
flutter pub get
flutter run -d chrome
# 또는
python3 ../test_run_myxplanner.py
```

## 🧪 테스트 스크립트 상세

### test_run_landing.py

랜딩 페이지를 로컬 HTTP 서버로 실행합니다.

```bash
# 기본 실행 (포트 8000)
python3 test_run_landing.py

# 브라우저 자동 열기
python3 test_run_landing.py --open

# 다른 포트 사용
python3 test_run_landing.py --port 3000

# 파일 구조 확인
python3 test_run_landing.py --check
```

### test_run_crm.py

CRM Flutter 앱을 다양한 플랫폼에서 실행합니다.

```bash
# 웹 브라우저 실행 (포트 8080)
python3 test_run_crm.py
python3 test_run_crm.py --web

# 모바일 디바이스 실행
python3 test_run_crm.py --mobile
python3 test_run_crm.py --ios
python3 test_run_crm.py --android

# 빌드/정리
python3 test_run_crm.py --build
python3 test_run_crm.py --clean

# 디바이스 목록 확인
python3 test_run_crm.py --devices
```

### test_run_myxplanner.py

MyXPlanner Flutter 앱을 다양한 플랫폼에서 실행합니다.

```bash
# 웹 브라우저 실행 (포트 8081)
python3 test_run_myxplanner.py
python3 test_run_myxplanner.py --web

# 모바일 디바이스 실행
python3 test_run_myxplanner.py --mobile
python3 test_run_myxplanner.py --ios
python3 test_run_myxplanner.py --android

# Firebase 설정 확인
python3 test_run_myxplanner.py --check

# 빌드/정리
python3 test_run_myxplanner.py --build
python3 test_run_myxplanner.py --clean
```

### 🌟 테스트 스크립트 장점

1. **간편함**: 복잡한 명령어를 기억할 필요 없음
2. **자동화**: 필요한 설정과 확인을 자동으로 수행
3. **에러 처리**: 문제 발생 시 명확한 에러 메시지 제공
4. **멀티 플랫폼**: 웹, iOS, Android를 쉽게 전환
5. **포트 관리**: 각 앱이 다른 포트를 사용 (충돌 방지)
   - Landing: 8000
   - CRM: 8080
   - MyXPlanner: 8081

## 📦 독립 작업

### 랜딩만 작업
```bash
cd landing/

# HTML/CSS 수정...

# 랜딩만 push
python3 landing_push.py "랜딩 페이지 디자인 수정"
```

### CRM만 작업
```bash
cd crm/

# Flutter 코드 수정...

# CRM만 push
python3 crm_push.py "회원 관리 기능 추가"
```

### 플래너만 작업
```bash
cd myxplanner/

# Flutter 코드 수정...

# 플래너만 push
python3 planner_push.py "예약 기능 개선"
```

### 전체 업데이트
```bash
# 루트 디렉토리에서
python3 push_all.py "전체 프로젝트 업데이트"
```

## 🎯 각 프로젝트 설명

### landing/ - 랜딩 페이지
- **기술**: HTML/CSS/JS
- **URL**: `/`
- **용도**: 서비스 소개, 마케팅
- **디자인**: 피그마 → HTML

### crm/ - CRM 메인 앱
- **기술**: Flutter
- **URL**: `/app`
- **용도**: 골프장 관리 시스템
- **플랫폼**: Web, iOS, Android, Desktop

### myxplanner/ - 골프 플래너
- **기술**: Flutter
- **용도**: CRM의 플래너 기능
- **참조**: crm/pubspec.yaml에서 로컬 패키지로 참조

## 🔧 의존성 관계

```
landing/     → (독립)
crm/         → myxplanner/ 참조
myxplanner/  → (독립)
```

## 🌐 배포 구조

```
autogolfcrm.com/               → landing/ 폴더 배포
autogolfcrm.com/app/           → crm/ 빌드 결과 배포
```

## 📝 개발 워크플로우

1. **독립 개발**
   - 각 프로젝트 폴더에서 독립적으로 개발
   - 각자의 push 스크립트 사용

2. **통합 테스트**
   - 전체 프로젝트를 함께 테스트
   - `push_all.py`로 한 번에 커밋/푸시

3. **배포**
   - GitHub Actions 자동 빌드/배포
   - 또는 수동으로 각 프로젝트 배포

## 🤝 팀 협업

- **디자이너**: landing/ 폴더만 작업
- **백엔드 개발자**: crm/ 폴더 작업
- **플래너 개발자**: myxplanner/ 폴더 작업
- **팀장**: push_all.py로 전체 관리

## 📊 Git 전략

### 브랜치 구조
- `main`: 프로덕션
- `develop`: 개발
- `feature/*`: 기능 개발

### 커밋 메시지 규칙
- `[Landing] 메시지`: 랜딩 페이지
- `[CRM] 메시지`: CRM 앱
- `[Planner] 메시지`: 플래너
- `[All] 메시지`: 전체 변경

## 🔗 참고 링크

- GitHub: https://github.com/seojongik/autogolf-project
- 랜딩 리포: https://github.com/seojongik/crm_landing_page
- CRM 리포: https://github.com/seojongik/autogolfcrm.com
- 플래너 리포: https://github.com/seojongik/myxplanner_app

## 📞 문의

프로젝트 관련 문의사항이 있으시면 이슈를 등록해주세요.


