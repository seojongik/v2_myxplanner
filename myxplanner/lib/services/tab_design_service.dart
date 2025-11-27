import 'package:flutter/material.dart';
import '../widgets/branch_header.dart';
import 'api_service.dart';

class TabDesignService {
  // 공통 탭바 디자인 (둥근 배경 스타일 - 레거시)
  static PreferredSize buildTabBar({
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
          labelPadding: EdgeInsets.symmetric(horizontal: 3),
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Color(0xFF4F46E5),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Color(0xFF666666),
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: tabs.map((tab) => Tab(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab['icon'], size: 16),
                  SizedBox(width: 2),
                  Text(tab['title']),
                ],
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  // 언더라인 스타일 탭바 (시안색 테마)
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
          labelColor: Color(0xFF06B6D4), // 시안색
          unselectedLabelColor: Color(0xFF64748B), // 회색
          indicatorColor: Color(0xFF06B6D4), // 시안색
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

  // 공통 앱바 디자인
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
        if (showBranchHeader) ...[
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(child: BranchHeader()),
          ),
        ],
        if (actions != null) ...actions,
      ],
    );
  }

  // 공통 스캐폴드 배경색
  static Color get backgroundColor => Color(0xFFF8F9FA);

  // 하단 네비게이션 바 빌드 (회원권 탭 선택 상태)
  static Widget buildBottomNavigationBar({
    required BuildContext context,
    int selectedIndex = 3, // 기본값: 회원권 탭 (인덱스 3)
    Function(int)? onTap,
  }) {
    final navigationItems = [
      {'icon': Icons.home_outlined, 'selectedIcon': Icons.home, 'label': '홈'},
      {'icon': Icons.search_outlined, 'selectedIcon': Icons.search, 'label': '조회'},
      {'icon': Icons.calendar_today_outlined, 'selectedIcon': Icons.calendar_today, 'label': '예약'},
      {'icon': Icons.card_membership_outlined, 'selectedIcon': Icons.card_membership, 'label': '회원권'},
      {'icon': Icons.person_outline, 'selectedIcon': Icons.person, 'label': '계정관리'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10.0,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false, // 상단 SafeArea는 사용하지 않음
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = selectedIndex == index;

              return GestureDetector(
                onTap: () {
                  // 관리자 로그인으로 계정 탭 접근 시 차단
                  if (index == 4 && ApiService.isAdminLogin()) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('접근 제한'),
                        content: Text('관리자 모드에서는 계정관리 메뉴를 사용할 수 없습니다.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('확인'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  if (onTap != null) {
                    onTap(index);
                  } else {
                    // 기본 동작: 모든 페이지를 닫고 MainPage로 돌아가기
                    // MainPage까지 모든 페이지를 닫기
                    Navigator.of(context).popUntil((route) {
                      // MainPage가 있는지 확인 (route.settings.arguments나 route.settings.name으로 확인)
                      // 또는 첫 번째 페이지까지 돌아가기
                      return route.isFirst;
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item['selectedIcon'] as IconData : item['icon'] as IconData,
                        color: isSelected
                            ? Colors.blue
                            : Colors.grey[600],
                        size: 24.0,
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? Colors.blue
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
} 