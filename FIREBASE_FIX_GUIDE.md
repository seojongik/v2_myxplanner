# Firebase 채널 에러 해결 가이드

## 문제 상황
- 웹: ✅ 정상 작동
- 안드로이드: ❌ `PlatformException(channel-error, Unable to establish connection on channel.)`
- 에러 위치: `FirebaseCoreHostApi.initializeCore` → Pigeon 채널 통신 실패

## 해결 방법 (순서대로 시도)

### 방법 1: Firebase 플러그인 버전 업데이트

```bash
# pubspec.yaml에서 Firebase 버전 업데이트
flutter pub upgrade firebase_core cloud_firestore

# 또는 최신 버전으로 직접 업데이트
flutter pub add firebase_core:^4.2.1 cloud_firestore:^6.1.0
```

### 방법 2: FlutterFire CLI로 Firebase 재설정

```bash
# FlutterFire CLI 설치 (없는 경우)
dart pub global activate flutterfire_cli

# Firebase 재설정 (기존 설정 덮어쓰기)
flutterfire configure --platforms=android

# 이 과정에서 google-services.json 파일이 자동으로 업데이트됩니다
```

### 방법 3: google-services.json 파일 재다운로드

1. Firebase Console (https://console.firebase.google.com/) 접속
2. 프로젝트 선택: `mgpfunctions`
3. 프로젝트 설정 > 일반 탭
4. "내 앱" 섹션에서 Android 앱 선택
5. `google-services.json` 파일 다운로드
6. `android/app/google-services.json` 파일 교체

### 방법 4: Flutter 및 Firebase 플러그인 완전 재설치

```bash
# 1. Flutter 캐시 정리
flutter clean

# 2. pub 캐시 정리
flutter pub cache repair

# 3. 의존성 재설치
flutter pub get

# 4. Android 빌드 캐시 정리
cd android
./gradlew clean
cd ..

# 5. 다시 빌드
flutter build apk --release
```

### 방법 5: Firebase 플러그인 완전 제거 후 재설치

```bash
# 1. pubspec.yaml에서 Firebase 의존성 제거
# (firebase_core, cloud_firestore, firebase_core_web 주석 처리)

# 2. 의존성 제거
flutter pub get

# 3. Firebase 의존성 다시 추가
flutter pub add firebase_core cloud_firestore

# 4. FlutterFire CLI로 재설정
flutterfire configure --platforms=android

# 5. 빌드
flutter build apk --release
```

## 가장 가능성 높은 해결책

**방법 2 (FlutterFire CLI 재설정)**이 가장 효과적일 가능성이 높습니다.

```bash
# 1. FlutterFire CLI 설치 확인
dart pub global activate flutterfire_cli

# 2. Firebase 재설정
flutterfire configure --platforms=android

# 3. 빌드 및 테스트
flutter clean
flutter pub get
flutter build apk --release
```

## 확인 사항

재설정 후 다음을 확인하세요:

1. `android/app/google-services.json` 파일이 최신인지 확인
2. `lib/firebase_options.dart` 파일이 업데이트되었는지 확인
3. `android/app/build.gradle.kts`에 `id("com.google.gms.google-services")` 플러그인이 있는지 확인

## 여전히 안 되면

다음 정보를 확인해주세요:
- Flutter 버전: `flutter --version`
- Firebase 플러그인 버전: `flutter pub deps | grep firebase`
- Android SDK 버전: `android/app/build.gradle.kts`의 `compileSdk` 확인

