# MyXPlanner UI 벤치마크 가이드

> 비즈니스 로직을 제외한 순수 UI/UX 구조 분석 문서
> 다른 프로젝트에서 동일한 디자인 시스템을 재현할 수 있도록 상세히 기술

---

## 1. 전체 아키텍처 개요

### 1.1 프로젝트 구조
```
lib/
├── main_page.dart              # 메인 앱 골격 (Bottom Navigation 포함)
├── login_page.dart             # 로그인 화면
├── login_branch_select.dart    # 지점 선택 화면
├── index.dart                  # 모듈 Export 파일
│
├── pages/                      # 주요 화면들
│   ├── home/                   # 홈 탭
│   ├── search/                 # 조회 탭
│   ├── reservation/            # 예약 탭
│   ├── membership/             # 회원권 탭
│   └── account/                # 계정관리 탭
│
├── widgets/                    # 공통 위젯
│   ├── branch_header.dart      # 지점 표시 헤더
│   ├── custom_stepper.dart     # 커스텀 스테퍼
│   └── global_chat_button.dart # 플로팅 채팅 버튼
│
└── services/                   # 디자인 서비스
    ├── tab_design_service.dart   # 탭/앱바 디자인 시스템
    ├── tile_design_service.dart  # 타일 그리드 디자인 시스템
    └── stepper/                  # 스테퍼 시스템
        ├── stepper_service.dart
        └── step_model.dart
```

### 1.2 의존성 (UI 관련)
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  cupertino_icons: ^1.0.0
  flutter_svg: ^2.0.7
  table_calendar: ^3.0.9     # 캘린더 컴포넌트
  provider: ^6.1.2           # 상태관리
  intl: ^0.20.2              # 다국어/날짜 포맷
```

---

## 2. 색상 시스템

### 2.1 Primary Colors
```dart
// 주요 브랜드 컬러
Color primaryGreen = Color(0xFF00704A);    // 스타벅스 그린 (로그인 등)
Color primaryCyan = Color(0xFF06B6D4);     // 시안 (탭바 인디케이터)
Color primaryBlue = Color(0xFF2196F3);     // 블루 (네비게이션 선택)
Color accentGreen = Color(0xFF00A86B);     // 액센트 그린 (버튼, 아이콘)
```

### 2.2 Neutral Colors
```dart
// 배경 및 텍스트
Color backgroundColor = Color(0xFFF8F9FA);   // 스캐폴드 배경
Color cardBackground = Colors.white;
Color textPrimary = Color(0xFF1A1A1A);       // 진한 텍스트
Color textSecondary = Color(0xFF4A5568);     // 중간 텍스트
Color textTertiary = Color(0xFF64748B);      // 연한 텍스트
Color borderColor = Color(0xFFE2E8F0);       // 테두리
```

### 2.3 Dynamic Color Palette (Tile용)
```dart
static final List<Color> colorPalette = [
  Color(0xFF00A86B),  // 초록색
  Color(0xFF2196F3),  // 파란색
  Color(0xFFFF8C00),  // 주황색
  Color(0xFF8E44AD),  // 보라색
  Color(0xFFE74C3C),  // 빨간색
  Color(0xFF1ABC9C),  // 청록색
  Color(0xFFF39C12),  // 노란색
  Color(0xFF9B59B6),  // 자주색
];
```

---

## 3. 네비게이션 구조

### 3.1 Bottom Navigation Bar
**파일**: `main_page.dart` (704-781 라인)

```dart
// 네비게이션 아이템 정의
final List<NavigationItem> _navigationItems = [
  NavigationItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: '홈',
  ),
  NavigationItem(
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
    label: '조회',
  ),
  NavigationItem(
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
    label: '예약',
  ),
  NavigationItem(
    icon: Icons.card_membership_outlined,
    selectedIcon: Icons.card_membership,
    label: '회원권',
  ),
  NavigationItem(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: '계정관리',
  ),
];
```

**스타일 사양**:
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10.0,
        offset: Offset(0, -2),  // 위쪽 그림자
      ),
    ],
  ),
  child: SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(left: 8.0, right: 8.0, top: 4.0, bottom: 8.0),
      // ... 아이템들
    ),
  ),
)
```

**선택된 아이템 스타일**:
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
  decoration: BoxDecoration(
    color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
    borderRadius: BorderRadius.circular(12.0),
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        isSelected ? item.selectedIcon : item.icon,
        color: isSelected ? Colors.blue : Colors.grey[600],
        size: 24.0,
      ),
      SizedBox(height: 4.0),
      Text(
        item.label,
        style: TextStyle(
          fontSize: 11.0,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.blue : Colors.grey[600],
        ),
      ),
    ],
  ),
)
```

---

## 4. 앱바 시스템

### 4.1 기본 AppBar
**파일**: `tab_design_service.dart`

```dart
static AppBar buildAppBar({
  required String title,
  PreferredSizeWidget? bottom,
  Widget? leading,
  List<Widget>? actions,
  bool showBranchHeader = true,
}) {
  return AppBar(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF1A1A1A),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
      ),
    ),
    centerTitle: true,
    elevation: 0,
    bottom: bottom,
    leading: leading,
    actions: [
      if (showBranchHeader)
        Padding(
          padding: EdgeInsets.only(right: 16.0),
          child: Center(child: BranchHeader()),
        ),
      if (actions != null) ...actions,
    ],
  );
}
```

### 4.2 Branch Header 위젯
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: Colors.black.withOpacity(0.05),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Colors.black.withOpacity(0.1),
      width: 0.5,
    ),
  ),
  child: Text(
    branchName,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.black.withOpacity(0.7),
      letterSpacing: -0.2,
    ),
  ),
)
```

---

## 5. 탭바 시스템

### 5.1 언더라인 스타일 TabBar
**파일**: `tab_design_service.dart`

```dart
static PreferredSize buildUnderlineTabBar({
  required TabController controller,
  required List<Map<String, dynamic>> tabs,
}) {
  return PreferredSize(
    preferredSize: Size.fromHeight(60),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        indicatorPadding: EdgeInsets.zero,
        labelPadding: EdgeInsets.symmetric(horizontal: 16),
        labelColor: Color(0xFF06B6D4),           // 시안색
        unselectedLabelColor: Color(0xFF64748B), // 회색
        indicatorColor: Color(0xFF06B6D4),
        indicatorWeight: 3.0,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        tabs: tabs.map((tab) => Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab['icon'], size: 16),
              SizedBox(width: 6),
              Text(tab['title']),
            ],
          ),
        )).toList(),
      ),
    ),
  );
}
```

### 5.2 탭 데이터 구조
```dart
final List<Map<String, dynamic>> tabs = [
  {
    'title': '예약내역',
    'type': 'reservation_history',
    'icon': Icons.history,
    'color': Color(0xFF00A86B),
  },
  {
    'title': '쿠폰',
    'type': 'coupon',
    'icon': Icons.local_offer,
    'color': Color(0xFFE91E63),
  },
  // ...
];
```

---

## 6. 타일 그리드 시스템

### 6.1 기본 타일 위젯
**파일**: `tile_design_service.dart`

```dart
static Widget buildTile({
  required String title,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
  bool isEnabled = true,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: isEnabled ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 원형 아이콘 배경
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
                SizedBox(height: 12),
                // 타이틀
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
```

### 6.2 그리드 레이아웃
```dart
static Widget buildGrid({
  required List<Map<String, dynamic>> items,
  required Function(String) onItemTap,
}) {
  return Padding(
    padding: EdgeInsets.all(16),
    child: GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,          // 2열
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,      // 정사각형
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final color = colorPalette[index % colorPalette.length];
        return buildTile(
          title: item['title'],
          icon: item['icon'],
          color: color,
          onTap: () => onItemTap(item['type']),
        );
      },
    ),
  );
}
```

---

## 7. 커스텀 스테퍼 시스템

### 7.1 Step Model
```dart
class StepModel {
  final String title;
  final String icon;        // 이모지 아이콘
  final Color color;
  final Widget content;
  final String? selectedValue;
  final bool isCompleted;
}
```

### 7.2 Stepper Service
```dart
class StepperService extends ChangeNotifier {
  List<StepModel> _steps = [];
  int _currentStep = 0;

  // 상태 접근자
  List<StepModel> get steps => _steps;
  int get currentStep => _currentStep;
  bool get isFirstStep => _currentStep == 0;
  bool get isLastStep => _currentStep == _steps.length - 1;

  // 네비게이션
  void nextStep() { ... }
  void previousStep() { ... }
  void goToStep(int stepIndex) { ... }

  // 값 업데이트
  void updateStepValue(int stepIndex, String? value) { ... }
}
```

### 7.3 스테퍼 UI 구조
```dart
// 스텝 아이콘 (좌측)
Container(
  width: 56,
  height: 56,
  decoration: BoxDecoration(
    color: isCompletedStep || isCurrentStep
        ? step.color.withOpacity(0.1)
        : Color(0xFFF8FAFC),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: isCompletedStep || isCurrentStep
          ? step.color
          : Color(0xFFE2E8F0),
      width: 2,
    ),
    boxShadow: isCurrentStep ? [
      BoxShadow(
        color: step.color.withOpacity(0.2),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ] : null,
  ),
  child: Center(
    child: isCompletedStep
        ? Icon(Icons.check_circle, color: step.color, size: 28)
        : Text(step.icon, style: TextStyle(fontSize: 24)),
  ),
)
```

### 7.4 네비게이션 버튼 스타일
```dart
// 다음/완료 버튼
Container(
  height: 50,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    gradient: LinearGradient(
      colors: [Color(0xFF00A86B), Color(0xFF00A86B).withOpacity(0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: Color(0xFF00A86B).withOpacity(0.3),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    child: Text(
      stepperService.isLastStep ? '완료' : '다음',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    ),
  ),
)

// 이전 버튼
Container(
  height: 50,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Color(0xFFE2E8F0), width: 1.5),
  ),
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    child: Text(
      '이전',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF4A5568),
      ),
    ),
  ),
)
```

---

## 8. 로그인 화면

### 8.1 전체 레이아웃
```dart
Scaffold(
  body: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor,
          primaryColor.withOpacity(0.8),
          Colors.white,
        ],
        stops: [0.0, 0.3, 1.0],
      ),
    ),
    child: SafeArea(
      child: Column(
        children: [
          // 상단 로고 영역 (flex: 2)
          Expanded(
            flex: 2,
            child: _buildHeader(),
          ),
          // 로그인 폼 영역 (flex: 3)
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: _buildLoginForm(),
            ),
          ),
        ],
      ),
    ),
  ),
)
```

### 8.2 로고 영역
```dart
Container(
  width: 80,  // 또는 100 (큰 화면)
  height: 80,
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 20,
        offset: Offset(0, 10),
      ),
    ],
  ),
  child: Image.asset('assets/images/applogo.png'),
)
```

### 8.3 텍스트 입력 필드
```dart
Container(
  decoration: BoxDecoration(
    color: Color(0xFFF7FAFC),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Color(0xFFE2E8F0),
      width: 1.5,
    ),
  ),
  child: TextFormField(
    style: TextStyle(
      fontSize: 16,
      color: Color(0xFF2D3748),
      fontWeight: FontWeight.w500,
    ),
    decoration: InputDecoration(
      hintText: 'hint...',
      hintStyle: TextStyle(
        color: Color(0xFFA0AEC0),
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Container(
        margin: EdgeInsets.all(8),
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Color(0xFF4A5568), size: 18),
      ),
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  ),
)
```

### 8.4 체크박스 스타일
```dart
Container(
  width: 20,
  height: 20,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(4),
    border: Border.all(
      color: isChecked ? Color(0xFF00704A) : Color(0xFFCBD5E0),
      width: 2,
    ),
    color: isChecked ? Color(0xFF00704A) : Colors.transparent,
  ),
  child: isChecked
      ? Icon(Icons.check, size: 14, color: Colors.white)
      : null,
)
```

### 8.5 로그인 버튼
```dart
Container(
  width: double.infinity,
  height: 50,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    gradient: LinearGradient(
      colors: [primaryColor, primaryColor.withOpacity(0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: primaryColor.withOpacity(0.3),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    child: Text(
      '로그인',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    ),
  ),
)
```

---

## 9. 홈 화면 구조

### 9.1 AppBar (홈 전용)
```dart
AppBar(
  backgroundColor: Colors.white,
  elevation: 0.5,
  title: Row(
    children: [
      Icon(Icons.home, color: Colors.blue, size: 24),
      SizedBox(width: 8),
      Text(
        '$memberName님',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      // 관리자 모드 배지
      if (isAdminMode)
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '관리자',
            style: TextStyle(fontSize: 10, color: Colors.white),
          ),
        ),
    ],
  ),
  actions: [BranchHeader()],
)
```

### 9.2 오늘의 예약 위젯
```dart
// 섹션 헤더
Row(
  children: [
    Icon(Icons.calendar_today, size: 24, color: Color(0xFF00A86B)),
    SizedBox(width: 10),
    Text(
      '오늘의 예약',
      style: TextStyle(
        fontSize: 18,  // 또는 20 (큰 화면)
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
    SizedBox(width: 8),
    // 카운트 배지
    if (reservations.isNotEmpty)
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Color(0xFF00A86B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${reservations.length}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF00A86B),
          ),
        ),
      ),
  ],
)
```

### 9.3 예약 타일 스타일
```dart
Container(
  margin: EdgeInsets.only(bottom: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Row(
      children: [
        // 타입 아이콘 (좌측)
        Container(
          width: 56,
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: typeColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(typeIcon, size: 24, color: typeColor),
              SizedBox(height: 4),
              Text(
                typeName,
                style: TextStyle(
                  fontSize: 11,
                  color: typeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 16),
        // 정보 (우측)
        Expanded(
          child: Column(...),
        ),
      ],
    ),
  ),
)
```

---

## 10. 게시판 탭바

### 10.1 탭바 컨테이너
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: Offset(0, 2),
      ),
    ],
  ),
  child: TabBar(
    isScrollable: true,
    tabAlignment: TabAlignment.start,
    labelColor: Color(0xFF06B6D4),
    unselectedLabelColor: Color(0xFF64748B),
    indicatorColor: Color(0xFF06B6D4),
    indicatorWeight: 3.0,
    indicatorSize: TabBarIndicatorSize.label,
    dividerColor: Colors.transparent,
    // tabs...
  ),
)
```

### 10.2 게시글 아이템
```dart
InkWell(
  borderRadius: BorderRadius.circular(16),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Row(
      children: [
        // 게시판 타입 아이콘
        Container(
          width: 56,
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: tagColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: tagColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(boardIcon, size: 24, color: tagColor),
              SizedBox(height: 4),
              Text(
                boardType,
                style: TextStyle(
                  fontSize: 11,
                  color: tagColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        // 게시글 정보
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // NEW 배지
                  if (isToday)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 4),
              // 작성자, 날짜, 댓글 수
              Row(
                children: [
                  Text(memberName, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  Text(' • ', style: TextStyle(color: Colors.grey[400])),
                  Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (commentCount > 0) ...[
                    Text(' • ', style: TextStyle(color: Colors.grey[400])),
                    Icon(Icons.comment, size: 12, color: Colors.grey[500]),
                    SizedBox(width: 4),
                    Text('$commentCount', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ],
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
      ],
    ),
  ),
)
```

---

## 11. 페이지네이션

```dart
Container(
  margin: EdgeInsets.only(top: 16),
  padding: EdgeInsets.symmetric(vertical: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: Offset(0, 2),
      ),
    ],
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // 이전 버튼
      IconButton(
        icon: Icon(Icons.chevron_left),
        color: currentPage > 1 ? Color(0xFF64748B) : Colors.grey[300],
      ),
      // 페이지 번호
      GestureDetector(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: isCurrentPage
              ? Border(bottom: BorderSide(color: Color(0xFF06B6D4), width: 2))
              : null,
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
              color: isCurrentPage ? Color(0xFF06B6D4) : Color(0xFF64748B),
            ),
          ),
        ),
      ),
      // 다음 버튼
      IconButton(
        icon: Icon(Icons.chevron_right),
        color: hasMorePages ? Color(0xFF64748B) : Colors.grey[300],
      ),
    ],
  ),
)
```

---

## 12. 플로팅 채팅 버튼

### 12.1 드래그 가능한 버튼
```dart
Positioned(
  left: position.dx,
  top: position.dy,
  child: GestureDetector(
    onPanStart: (details) { ... },
    onPanUpdate: (details) {
      // 드래그로 위치 업데이트
      position = Offset(
        (currentX + delta.dx).clamp(0.0, maxX),
        (currentY + delta.dy).clamp(0.0, maxY),
      );
    },
    onPanEnd: (details) {
      // 위치 저장
      _savePosition(position);
    },
    child: Container(
      width: 75,
      height: 75,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0xFF4A90E2).withOpacity(0.4),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat, color: Colors.white, size: 26),
                SizedBox(height: 3),
                Text(
                  '1:1문의',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // 안읽은 메시지 배지
          if (unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                constraints: BoxConstraints(minWidth: 22, minHeight: 22),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    ),
  ),
)
```

---

## 13. 다이얼로그 스타일

### 13.1 확인 다이얼로그
```dart
AlertDialog(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // 아이콘 원형 배경
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.orange.shade100,  // 또는 red, blue 등
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.security,
          color: Colors.orange.shade700,
          size: 40,
        ),
      ),
      SizedBox(height: 24),
      Text(
        '제목',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.orange.shade700,
        ),
      ),
      SizedBox(height: 16),
      Text(
        '본문 내용',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.grey[600],
        ),
      ),
    ],
  ),
  actions: [
    TextButton(
      child: Text('취소'),
    ),
    ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      child: Text('확인'),
    ),
  ],
)
```

---

## 14. 로딩 및 에러 상태

### 14.1 로딩 위젯
```dart
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A86B)),
      strokeWidth: 2.5,
    ),
    SizedBox(height: 20),
    Text(
      '로딩 메시지...',
      style: TextStyle(
        fontSize: 14,
        color: Color(0xFF8E8E8E),
      ),
    ),
  ],
)
```

### 14.2 에러 위젯
```dart
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Icon(
      Icons.error_outline,
      size: 48,
      color: Color(0xFFE74C3C),
    ),
    SizedBox(height: 16),
    Text(
      '문제가 발생했습니다',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A1A1A),
      ),
    ),
    SizedBox(height: 8),
    Text(
      errorMessage,
      style: TextStyle(
        fontSize: 12,
        color: Color(0xFF8E8E8E),
      ),
      textAlign: TextAlign.center,
    ),
    SizedBox(height: 20),
    ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF00A86B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: Text(
        '다시 시도',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ],
)
```

### 14.3 빈 상태 위젯
```dart
Container(
  width: double.infinity,
  padding: EdgeInsets.all(24),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.grey[200]!),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: Offset(0, 2),
      ),
    ],
  ),
  child: Column(
    children: [
      Icon(
        Icons.event_available,
        size: 36,
        color: Colors.grey[300],
      ),
      SizedBox(height: 12),
      Text(
        '데이터가 없습니다',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
    ],
  ),
)
```

---

## 15. 반응형 디자인

### 15.1 화면 크기 분기점
```dart
final screenSize = MediaQuery.of(context).size;
final isSmallScreen = screenSize.width < 600;

// 사용 예시
Padding(
  padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
  child: Text(
    '제목',
    style: TextStyle(
      fontSize: isSmallScreen ? 18.0 : 20.0,
    ),
  ),
)
```

### 15.2 Safe Area 처리
```dart
// Bottom Navigation과 함께 사용 시
SafeArea(
  top: false,  // 상단 SafeArea는 AppBar가 처리
  child: Padding(
    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
    child: // content
  ),
)
```

---

## 16. 애니메이션

### 16.1 페이드 + 슬라이드 진입 애니메이션
```dart
// 컨트롤러 초기화
late AnimationController _fadeController;
late AnimationController _slideController;
late Animation<double> _fadeAnimation;
late Animation<Offset> _slideAnimation;

@override
void initState() {
  _fadeController = AnimationController(
    duration: Duration(milliseconds: 1200),
    vsync: this,
  );
  _slideController = AnimationController(
    duration: Duration(milliseconds: 800),
    vsync: this,
  );

  _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
  );

  _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
    CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
  );

  _fadeController.forward();
  _slideController.forward();
}

// 사용
FadeTransition(
  opacity: _fadeAnimation,
  child: SlideTransition(
    position: _slideAnimation,
    child: content,
  ),
)
```

---

## 17. 사용 방법

### 17.1 새 프로젝트에서 재현하기

1. **디자인 서비스 파일 복사**
   - `tab_design_service.dart`
   - `tile_design_service.dart`
   - `stepper/stepper_service.dart`
   - `stepper/step_model.dart`

2. **색상 상수 정의**
```dart
// constants/colors.dart
class AppColors {
  static const primaryGreen = Color(0xFF00704A);
  static const primaryCyan = Color(0xFF06B6D4);
  static const primaryBlue = Color(0xFF2196F3);
  static const accentGreen = Color(0xFF00A86B);
  static const backgroundColor = Color(0xFFF8F9FA);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF4A5568);
  static const borderColor = Color(0xFFE2E8F0);
}
```

3. **공통 위젯 복사**
   - `widgets/branch_header.dart`
   - `widgets/custom_stepper.dart`
   - `widgets/global_chat_button.dart`

4. **의존성 추가**
```yaml
dependencies:
  table_calendar: ^3.0.9
  provider: ^6.1.2
  intl: ^0.20.2
```

5. **MainPage 구조 적용**
   - Bottom Navigation 구현
   - Stack 기반 레이아웃 (플로팅 버튼 포함)
   - 탭 전환 로직

---

## 18. 핵심 디자인 원칙

1. **일관된 Border Radius**: 주로 12, 16을 사용
2. **그림자**: `Colors.black.withOpacity(0.05~0.1)`, blurRadius 10~15
3. **간격**: 8, 12, 16, 24의 배수 사용
4. **폰트 가중치**: w500(보통), w600(중간 강조), w700(강조)
5. **아이콘 크기**: 16(탭바), 24(일반), 36(타일)
6. **버튼 높이**: 50px 표준
7. **컨테이너 패딩**: 16px 표준, 모서리는 12~16 radius
