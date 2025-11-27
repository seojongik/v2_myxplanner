# MyGolfPlanner App - 골프 예약 관리 시스템 v2.0

독립적으로 실행 가능한 골프장 예약 관리 시스템입니다.

## 🚀 주요 기능

### 1. **관리자 모드**
- 회원 선택을 통한 직접 접근
- 회원별 개별 페이지 관리
- 관리자 전용 기능 및 UI

### 2. **고객 모드**
- 로그인을 통한 정상적인 접근
- 개인 정보 및 예약 관리
- 고객 중심의 사용자 경험

### 3. **독립 실행 환경**
- 메인 CRM 시스템과 분리된 독립 프로젝트
- 자체 API 서비스 포함
- dynamic_api.php와 직접 통신

## 📁 프로젝트 구조

```
lib/pages/mygolfplanner_app/
├── lib/
│   ├── main.dart                 # 독립 프로젝트 진입점
│   ├── main_page.dart           # 메인 페이지
│   ├── login_page.dart          # 로그인 페이지
│   ├── login_by_admin.dart      # 관리자 회원 선택 페이지
│   ├── login_branch_select.dart # 지점 선택 페이지
│   ├── index.dart               # 독립 프로젝트용 Export 파일
│   └── services/
│       └── api_service.dart     # 독립 API 서비스
├── index.dart                   # CRM 연동용 Export 파일
├── pubspec.yaml                # 독립 프로젝트 의존성 설정
├── dynamic_api.php             # API 백엔드
├── web/                        # 웹 지원 파일들
├── build/                      # 빌드 출력 폴더
└── README.md                   # 프로젝트 문서
```

## 🔧 설치 및 실행

### 1. **독립 프로젝트 실행**
```bash
cd lib/pages/mygolfplanner_app
flutter pub get
flutter run -d chrome
```

### 2. **CRM에서 플로팅 버튼으로 접근**
```dart
// CRM 코드에서
import 'package:your_app/pages/mygolfplanner_app/index.dart';

// 관리자 모드
FloatingActionButton(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => LoginByAdminPage()),
  ),
  child: Icon(Icons.add),
)

// 또는 플로팅 서비스 사용
import 'package:your_app/services/floating_reservation_service.dart';

FloatingReservationButton(isAdminMode: true)
```

## 🌐 API 서비스

### 독립 API 서비스 특징
- **자체 포함**: 메인 CRM의 api_service.dart에 의존하지 않음
- **핵심 기능**: 기본 CRUD 작업 및 예약 시스템 전용 함수들
- **자동 브랜치 필터링**: branch_id 자동 추가 및 관리
- **오류 처리**: 네트워크 및 API 오류 통합 처리

### 주요 API 함수들
```dart
// 기본 CRUD
ApiService.getData(table: 'v3_members')
ApiService.addData(table: 'v3_members', data: {...})
ApiService.updateData(table: 'v3_members', data: {...}, where: [...])
ApiService.deleteData(table: 'v3_members', where: [...])

// 예약 시스템 전용
ApiService.getMembers(searchQuery: '검색어')
ApiService.getMemberById('회원ID')
ApiService.getTsInfo()
ApiService.getTsReservations(date: '2024-01-01')
ApiService.getBoardData()
ApiService.getOptionSettings(category: '타석종류', ...)

// 초기화 및 설정
ApiService.initializeReservationSystem(branchId: 'test')
ApiService.setCurrentBranch('branchId', {...})
ApiService.logout()
```

## 🔐 접근 방식

### CRM 관리자 접근
1. **플로팅 버튼 클릭** → `LoginByAdminPage`
2. **회원 선택** → `MainPage` (관리자 모드)
3. **회원별 개별 관리** 가능

### 독립 프로젝트 고객 접근
1. **독립 실행** → `LoginPage`
2. **로그인 인증** → `LoginBranchSelectPage`
3. **지점 선택** → `MainPage` (고객 모드)

## 🎨 UI/UX 특징

### 관리자 모드
- 빨간색 "관리자" 배지 표시
- 회원 정보 상단 표시
- 회원 변경 및 로그아웃 버튼
- 관리자 전용 메뉴 및 기능

### 고객 모드
- 일반적인 환영 메시지
- 개인화된 사용자 경험
- 고객 중심의 기능 배치

## 🔧 설정 및 커스터마이징

### 브랜치 설정
```dart
// 기본 브랜치 변경
ApiService.initializeReservationSystem(branchId: '원하는_브랜치_ID');
```

### API 엔드포인트 변경
```dart
// lib/services/api_service.dart
static const String baseUrl = 'https://your-domain.com/dynamic_api.php';
```

## 🚨 주요 변경사항 (v2.0)

1. **독립 프로젝트 구조**: 완전한 Flutter 프로젝트로 분리
2. **파일 구조 개선**: `/lib` 폴더로 모든 Dart 파일 이동
3. **CRM 연동 유지**: `index.dart`를 통한 re-export로 기존 연동 보장
4. **지점 선택 기능**: 독립 실행 시 지점 선택 단계 추가

## 🚨 주의사항

1. **네트워크 연결**: 인터넷 연결이 필요합니다
2. **브랜치 설정**: 올바른 branch_id 설정이 중요합니다
3. **API 권한**: dynamic_api.php 접근 권한 확인 필요
4. **데이터 동기화**: 실시간 데이터 반영을 위해 새로고침 기능 활용
5. **파일 경로**: CRM 연동 시 새로운 파일 구조 확인 필요

## 📞 지원 및 문의

- 기술적 문제: 개발팀 문의
- 기능 요청: 프로젝트 이슈 등록
- 버그 리포트: GitHub 이슈 트래커 활용

---

**MyGolfPlanner App**  
**Version**: 2.0.0  
**Last Updated**: 2025년 1월  
**Developer**: FAMD Development Team

# 레슨 시간 검증기 (Lesson Duration Checker)

Flutter 앱의 `ls_step4_select_duration.dart` 로직을 Python으로 구현한 레슨 시간 선택 가능 여부 판별 프로그램입니다.

## 📋 기능

- **필수 전제조건 체크**: 날짜, 프로 ID, 시작시간 입력 검증
- **프로 정보 조회**: 최소 레슨시간, 레슨시간 단위, 예약 가능 일수 확인
- **프로 스케줄 조회**: 해당 날짜의 근무시간 확인
- **기존 예약 조회**: 기존 예약과의 충돌 여부 확인
- **최대 레슨시간 계산**: 근무시간, 다음 예약, 시스템 제한을 고려한 최대 시간 계산
- **레슨시간 검증**: 요청된 레슨시간의 유효성 검증

## 🔍 검증 로직

### 1. 최대 레슨시간 계산
다음 3가지 조건 중 **최소값**을 선택:
- **근무시간 종료까지 남은 시간**
- **다음 예약까지 남은 시간**
- **시스템 최대 허용시간 (90분)**

### 2. 레슨시간 단위 조정
- 최소 레슨시간부터 시작
- 레슨시간 단위(기본 5분)로 증가
- 계산된 최대값 이내에서 조정

### 3. 요청된 레슨시간 검증
- 최소 레슨시간 이상인지 확인
- 최대 가능 시간 이내인지 확인
- 올바른 레슨시간 단위인지 확인

## 📦 설치 및 설정

### 필요한 패키지 설치
```bash
pip install requests
```

## 🚀 사용법

### 기본 사용법
```bash
python lesson_duration_checker.py --date 2024-01-15 --instructor PRO001 --time 14:00 --duration 60
```

### 파라미터 설명
- `--date`: 선택된 날짜 (YYYY-MM-DD 형식)
- `--instructor`: 선택된 프로 ID
- `--time`: 선택된 시작시간 (HH:MM 형식)
- `--duration`: 요청된 레슨시간 (분 단위)

### 사용 예시

#### ✅ 성공적인 예약
```bash
python lesson_duration_checker.py --date 2024-01-15 --instructor PRO001 --time 14:00 --duration 60
```

#### ❌ 최소 시간 미만
```bash
python lesson_duration_checker.py --date 2024-01-15 --instructor PRO001 --time 14:00 --duration 15
```

#### ❌ 근무시간 초과
```bash
python lesson_duration_checker.py --date 2024-01-15 --instructor PRO001 --time 17:30 --duration 90
```

## 📊 출력 결과

### 성공 시
```json
{
  "success": true,
  "message": "레슨시간 선택이 가능합니다: 14:00 ~ 15:00 (60분)",
  "validation_details": {
    "requested_duration": 60,
    "min_duration": 30,
    "max_duration": 90,
    "time_unit": 5,
    "start_time": "14:00",
    "end_time": "15:00"
  }
}
```

### 실패 시
```json
{
  "success": false,
  "error": "요청된 레슨시간(15분)이 최소 레슨시간(30분)보다 작습니다.",
  "validation_details": {
    "requested_duration": 15,
    "min_duration": 30,
    "max_duration": 90,
    "time_unit": 5
  }
}
```

## 🔧 API 연동

이 프로그램은 다음 API 테이블을 사용합니다:

- `v2_staff_pro`: 프로 정보 조회
- `v2_weekly_schedule_pro`: 프로 스케줄 조회
- `v2_LS_orders`: 기존 예약 조회

## 🔄 Flutter 앱과의 동일성

이 Python 프로그램은 Flutter 앱의 `ls_step4_select_duration.dart` 파일과 완전히 동일한 로직을 구현합니다:

1. **필수 전제조건 체크** (`didUpdateWidget` 로직)
2. **프로 정보 조회** (`_initializeDurationData` 로직)
3. **기존 예약 조회** (`_loadReservations` 로직)
4. **최대 레슨시간 계산** (`_calculateMaxDuration` 로직)
5. **시간 변환 함수** (`_timeToMinutes`, `_minutesToTime` 로직)
6. **레슨시간 검증** (슬라이더 제약 조건 로직)

## 🚨 주의사항

1. **네트워크 연결**: API 호출을 위해 인터넷 연결이 필요합니다.
2. **API 권한**: 해당 API에 대한 접근 권한이 있어야 합니다.
3. **데이터 형식**: 날짜와 시간 형식을 정확히 입력해야 합니다.
4. **실제 데이터**: 실제 프로 ID와 날짜를 사용해야 정확한 결과를 얻을 수 있습니다.

## 🤝 문의사항

프로그램 사용 중 문제가 발생하거나 개선사항이 있으시면 언제든지 문의해 주세요.
