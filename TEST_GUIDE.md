# 🧪 테스트 실행 가이드

이 문서는 각 프로젝트를 쉽게 테스트할 수 있는 방법을 설명합니다.

## 📋 목차

- [빠른 시작](#빠른-시작)
- [랜딩 페이지 테스트](#랜딩-페이지-테스트)
- [CRM 앱 테스트](#crm-앱-테스트)
- [MyXPlanner 앱 테스트](#myxplanner-앱-테스트)
- [문제 해결](#문제-해결)

## 🚀 빠른 시작

### 사전 요구사항

#### 랜딩 페이지
- Python 3.x

#### Flutter 앱 (CRM, MyXPlanner)
- Flutter SDK (3.0 이상)
- Chrome 브라우저 (웹 테스트용)
- Xcode (iOS 테스트용, macOS만)
- Android Studio (Android 테스트용)

### Flutter 설치 확인

```bash
flutter --version
flutter doctor
```

## 🌐 랜딩 페이지 테스트

### 기본 실행

```bash
# 프로젝트 루트에서
python3 test_run_landing.py

# 또는 landing 폴더에서
cd landing
python3 ../test_run_landing.py
```

브라우저에서 `http://localhost:8000` 접속

### 옵션

```bash
# 자동으로 브라우저 열기
python3 test_run_landing.py --open

# 다른 포트 사용
python3 test_run_landing.py --port 3000

# 다른 호스트 사용 (네트워크에서 접근)
python3 test_run_landing.py --host 0.0.0.0

# 파일 구조 확인
python3 test_run_landing.py --check

# 도움말
python3 test_run_landing.py --help
```

### 테스트 체크리스트

- [ ] 메인 페이지가 정상적으로 표시되는가?
- [ ] 모든 이미지가 로드되는가?
- [ ] CSS 스타일이 적용되는가?
- [ ] JavaScript 기능이 작동하는가?
- [ ] 반응형 디자인이 작동하는가? (모바일/태블릿/데스크톱)

## 📱 CRM 앱 테스트

### 웹 브라우저 테스트 (권장)

```bash
# 프로젝트 루트에서
python3 test_run_crm.py

# 또는
python3 test_run_crm.py --web
```

브라우저에서 `http://localhost:8080` 자동 실행

### 모바일 테스트

#### iOS 시뮬레이터 (macOS만)

```bash
# iOS 시뮬레이터 열기 (터미널에서)
open -a Simulator

# CRM 앱 실행
python3 test_run_crm.py --ios
```

#### Android 에뮬레이터

```bash
# Android Studio에서 에뮬레이터 실행 또는
emulator -avd Pixel_5_API_31

# CRM 앱 실행
python3 test_run_crm.py --android
```

#### 실제 디바이스

```bash
# 디바이스를 USB로 연결한 후
# iOS: Xcode에서 서명 설정 필요
# Android: 개발자 모드 활성화 필요

# 연결된 디바이스 확인
python3 test_run_crm.py --devices

# 앱 실행
python3 test_run_crm.py --mobile
```

### 빌드 및 정리

```bash
# Flutter 클린 빌드 (문제 발생 시)
python3 test_run_crm.py --clean

# 빌드만 수행 (실행 안함)
python3 test_run_crm.py --build
```

### 테스트 체크리스트

- [ ] 로그인 화면이 표시되는가?
- [ ] 네트워크 요청이 정상 작동하는가?
- [ ] 데이터베이스 연결이 정상인가?
- [ ] Firebase 연동이 정상인가?
- [ ] 결제 기능이 작동하는가?
- [ ] 채팅 기능이 작동하는가?

## 📅 MyXPlanner 앱 테스트

### 웹 브라우저 테스트 (권장)

```bash
# 프로젝트 루트에서
python3 test_run_myxplanner.py

# 또는
python3 test_run_myxplanner.py --web
```

브라우저에서 `http://localhost:8081` 자동 실행

### Firebase 설정 확인

```bash
python3 test_run_myxplanner.py --check
```

### 모바일 테스트

CRM과 동일한 방법으로 테스트:

```bash
# iOS
python3 test_run_myxplanner.py --ios

# Android
python3 test_run_myxplanner.py --android

# 연결된 디바이스
python3 test_run_myxplanner.py --mobile
```

### 테스트 체크리스트

- [ ] 로그인 화면이 표시되는가?
- [ ] Firebase 인증이 작동하는가?
- [ ] Firestore 데이터베이스 연결이 정상인가?
- [ ] 플래너 기능이 작동하는가?
- [ ] 예약 시스템이 정상인가?
- [ ] 푸시 알림이 작동하는가?

## 🔍 동시에 여러 프로젝트 테스트

각 프로젝트는 다른 포트를 사용하므로 동시에 실행 가능:

```bash
# 터미널 1
python3 test_run_landing.py --open

# 터미널 2
python3 test_run_crm.py

# 터미널 3
python3 test_run_myxplanner.py
```

각각 다음 URL에서 접근:
- Landing: `http://localhost:8000`
- CRM: `http://localhost:8080`
- MyXPlanner: `http://localhost:8081`

## 🐛 문제 해결

### Flutter를 찾을 수 없음

```bash
# Flutter 설치 확인
which flutter

# PATH에 Flutter 추가 (zsh)
echo 'export PATH="$PATH:/path/to/flutter/bin"' >> ~/.zshrc
source ~/.zshrc

# PATH에 Flutter 추가 (bash)
echo 'export PATH="$PATH:/path/to/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

### 포트가 이미 사용 중

```bash
# 다른 포트 사용
python3 test_run_landing.py --port 8001

# 또는 사용 중인 프로세스 종료
lsof -ti:8000 | xargs kill -9
```

### Flutter 빌드 오류

```bash
# 클린 빌드 시도
python3 test_run_crm.py --clean

# 패키지 수동 업데이트
cd crm
flutter clean
flutter pub get
flutter pub upgrade
```

### iOS 빌드 오류

```bash
cd crm/ios
# 또는 cd myxplanner/ios

# CocoaPods 재설치
pod deintegrate
pod install

# 또는
pod install --repo-update
```

### Android 빌드 오류

```bash
cd crm/android
# 또는 cd myxplanner/android

# Gradle 정리
./gradlew clean

# Gradle wrapper 업데이트
./gradlew wrapper --gradle-version 7.5
```

### Firebase 연결 오류

```bash
# Firebase CLI 설치 확인
firebase --version

# Firebase 로그인
firebase login

# Firebase 프로젝트 재설정
cd myxplanner
flutterfire configure
```

### 개발모드 데이터 문제

**중요**: 개발모드에서도 가상데이터를 사용하지 마세요. 항상 실제 데이터를 사용해야 합니다.

## 💡 팁

### 1. Hot Reload 사용

Flutter 앱 실행 중에 코드를 수정하면:
- `r` 키: Hot Reload (빠른 재시작)
- `R` 키: Hot Restart (완전 재시작)
- `q` 키: 종료

### 2. 디바이스 전환

```bash
# 사용 가능한 디바이스 확인
flutter devices

# 특정 디바이스로 실행
flutter run -d <device-id>
```

### 3. 디버그 모드

```bash
# Flutter DevTools 열기
flutter pub global activate devtools
flutter pub global run devtools
```

### 4. 성능 프로파일링

```bash
# 프로파일 모드로 실행
cd crm
flutter run --profile -d chrome
```

## 📚 추가 리소스

- [Flutter 공식 문서](https://flutter.dev/docs)
- [Firebase 문서](https://firebase.google.com/docs)
- [Flutter DevTools](https://flutter.dev/docs/development/tools/devtools)
- [프로젝트 README](README.md)

## 🆘 도움말

각 스크립트의 상세 도움말:

```bash
python3 test_run_landing.py --help
python3 test_run_crm.py --help
python3 test_run_myxplanner.py --help
```

## 📞 문의

문제가 계속되면 이슈를 등록하거나 팀에 문의하세요.


