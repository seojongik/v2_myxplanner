# 안드로이드 로그 확인 가이드

USB로 연결된 안드로이드 기기의 로그를 확인하는 방법입니다.

## 빠른 시작

### 1. 기본 로그 확인 (MainActivity 관련만)
```bash
python3 check_logs.py
```

### 2. 현대카드 관련 로그만 확인
```bash
python3 check_logs.py hyundai
```

### 3. 모든 로그 확인
```bash
adb logcat
```

### 4. MainActivity 로그만 확인
```bash
adb logcat MainActivity:* *:S
```

### 5. 현대카드 관련 키워드 필터링
```bash
adb logcat | grep -i "hyundai\|hdcard\|MainActivity"
```

## 직접 ADB 명령어 사용

### 로그 버퍼 클리어
```bash
adb logcat -c
```

### 실시간 로그 확인
```bash
adb logcat
```

### 특정 태그만 확인
```bash
# MainActivity만
adb logcat MainActivity:* *:S

# Flutter 관련만
adb logcat flutter:* *:S

# 여러 태그
adb logcat MainActivity:* flutter:* *:S
```

### 로그 레벨 필터링
- `V`: Verbose (모든 로그)
- `D`: Debug
- `I`: Info
- `W`: Warning
- `E`: Error
- `S`: Silent (해당 태그 숨김)

예시:
```bash
# Info 레벨 이상만 표시
adb logcat *:I

# MainActivity는 Debug 이상, 나머지는 Error만
adb logcat MainActivity:D *:E
```

### 로그 파일로 저장
```bash
adb logcat > logs.txt
```

### 특정 시간 이후 로그만 확인
```bash
# 최근 10초간 로그
adb logcat -t 10

# 최근 100줄만
adb logcat -t 100
```

## 현대카드 결제 테스트 시 확인할 로그

현대카드 앱카드 결제 테스트 시 다음 로그를 확인하세요:

```bash
# 현대카드 관련 로그만 필터링
python3 check_logs.py hyundai
```

또는:

```bash
adb logcat | grep -E "MainActivity|hyundai|hdcard|Intent|scheme"
```

## 문제 해결

### ADB를 찾을 수 없음
- Android SDK가 설치되어 있는지 확인
- `adb` 명령어가 PATH에 있는지 확인
- `install_android.py`의 환경 설정을 참고

### 기기가 연결되지 않음
- USB 디버깅이 활성화되어 있는지 확인
- USB 케이블이 데이터 전송을 지원하는지 확인
- `adb devices`로 기기 확인

### 로그가 너무 많음
- 필터를 사용하여 필요한 로그만 확인
- `check_logs.py` 스크립트 사용 권장

