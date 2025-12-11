import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../flutter_flow/flutter_flow_theme.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../services/chat_notification_service.dart';
import '../crm2_member/crm2_member_widget.dart';
import 'change_password_widget.dart';
import '../../services/password_service.dart';

/// 로그인 역할 선택 페이지
/// 
/// 전화번호로 로그인 시 여러 지점/역할이 있는 경우
/// 사용자가 원하는 지점과 역할을 선택할 수 있는 페이지
class LoginRoleSelectPage extends StatefulWidget {
  final List<Map<String, dynamic>> staffOptions;
  final String phoneNumber;

  const LoginRoleSelectPage({
    Key? key,
    required this.staffOptions,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  State<LoginRoleSelectPage> createState() => _LoginRoleSelectPageState();
}

class _LoginRoleSelectPageState extends State<LoginRoleSelectPage>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;

  // 애니메이션 컨트롤러
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late List<Animation<Offset>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // 카드 애니메이션 초기화
    _cardAnimations = List.generate(
      widget.staffOptions.length,
      (index) => Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Interval(
          index * 0.1,
          (index * 0.1) + 0.5,
          curve: Curves.easeOutCubic,
        ),
      )),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _selectOption(Map<String, dynamic> option) async {
    final branchId = option['branch_id']?.toString() ?? '';
    final branchName = option['branch_name']?.toString() ?? '';
    final role = option['role']?.toString() ?? '';
    final roleDisplay = option['role_display']?.toString() ?? '';
    final staffName = option['staff_name']?.toString() ?? '';
    final staffData = option['staffData'] as Map<String, dynamic>?;
    final branchInfo = option['branch_info'] as Map<String, dynamic>?;

    if (staffData == null) {
      setState(() {
        _errorMessage = '직원 정보를 불러올 수 없습니다.';
      });
      return;
    }

    // 확인 다이얼로그 표시
    final confirmed = await _showConfirmDialog(
      branchName: branchName,
      roleDisplay: roleDisplay,
      staffName: staffName,
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Firebase Anonymous 인증
      print('🔐 Firebase Anonymous 인증 시작...');
      try {
        await FirebaseAuth.instance.signInAnonymously();
        print('✅ Firebase Anonymous 인증 성공');
      } catch (e) {
        print('⚠️ Firebase Anonymous 인증 실패: $e');
      }

      // 직원 정보 전역 설정
      ApiService.setCurrentStaff(
        staffData['staff_access_id'] as String? ?? '',
        role,
        staffData,
      );

      // 지점 정보 설정
      final branchData = branchInfo ?? {'branch_id': branchId, 'branch_name': branchName};
      ApiService.setCurrentBranch(branchId, branchData);

      // 채팅 알림 서비스 활성화
      print('🔔 채팅 알림 서비스 구독 시작...');
      ChatNotificationService().setupSubscriptions();

      // 권한 설정 조회
      await _queryAndSetAccessSettings(staffData['staff_access_id'], branchId);

      // 세션 시작
      SessionManager.instance.startSession();

      print('✅ 로그인 성공!');
      print('  - 지점: $branchName ($branchId)');
      print('  - 역할: $roleDisplay');
      print('  - 이름: $staffName');

      // 초기 비밀번호 체크
      final storedPassword = staffData['staff_access_password']?.toString() ?? '';
      String phoneNumber = '';
      if (role == 'manager') {
        phoneNumber = staffData['manager_phone']?.toString() ?? '';
      } else if (role == 'pro') {
        phoneNumber = staffData['pro_phone']?.toString() ?? '';
      }

      final isInitial = PasswordService.isInitialPassword(storedPassword, phoneNumber);
      
      if (isInitial && phoneNumber.isNotEmpty) {
        print('⚠️ 초기 비밀번호 감지 - 비밀번호 변경 필요');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ChangePasswordWidget(
                staffAccessId: staffData['staff_access_id'],
                isInitialPasswordChange: true,
              ),
            ),
          );
        }
        return;
      }

      // 메인 페이지로 이동
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const Crm2MemberWidget(),
          ),
        );
      }

    } catch (e) {
      print('❌ 로그인 오류: $e');
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<bool?> _showConfirmDialog({
    required String branchName,
    required String roleDisplay,
    required String staffName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF6366F1), size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              '로그인 확인',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '다음 정보로 로그인하시겠습니까?',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.business, '지점', branchName),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.badge, '역할', roleDisplay),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person, '이름', staffName),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('로그인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6366F1)),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Future<void> _queryAndSetAccessSettings(String? staffAccessId, String branchId) async {
    if (staffAccessId == null) return;

    try {
      final accessSettings = await ApiService.getDataList(
        table: 'v2_staff_access_setting',
        where: [
          {'field': 'staff_access_id', 'operator': '=', 'value': staffAccessId},
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
      );

      if (accessSettings.isNotEmpty) {
        ApiService.setCurrentAccessSettings(accessSettings[0]);
        print('✅ 권한 설정 로드 완료');
      }
    } catch (e) {
      print('⚠️ 권한 설정 조회 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF6366F1),
              const Color(0xFF6366F1).withOpacity(0.8),
              Colors.white,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500), // 데스크탑에서 최대 너비 제한
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // 상단 헤더
                    _buildHeader(isMobile),

                    // 옵션 목록
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(isMobile ? 24 : 32),
                            topRight: Radius.circular(isMobile ? 24 : 32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: _isLoading
                            ? _buildLoadingState(isMobile)
                            : _buildOptionList(isMobile),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final headerPadding = isMobile ? 20.0 : 32.0;
    final titleSize = isMobile ? 20.0 : 24.0;
    final descSize = isMobile ? 14.0 : 16.0;
    final badgeSize = isMobile ? 10.0 : 12.0;

    return Container(
      padding: EdgeInsets.all(headerPadding),
      child: Column(
        children: [
          // 뒤로가기 버튼과 타이틀
          Row(
            children: [
              Container(
                width: isMobile ? 40 : 48,
                height: isMobile ? 40 : 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: isMobile ? 16 : 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Text(
                  '계정 선택',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 40 : 48),
            ],
          ),

          SizedBox(height: isMobile ? 16 : 24),

          // 안내 카드
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                  ),
                  child: Icon(
                    Icons.account_circle,
                    color: const Color(0xFF6366F1),
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '로그인할 계정을 선택해주세요',
                        style: TextStyle(
                          fontSize: descSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        '${widget.phoneNumber}로 등록된 계정입니다',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: isMobile ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                  ),
                  child: Text(
                    '${widget.staffOptions.length}개 계정',
                    style: TextStyle(
                      fontSize: badgeSize,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 20 : 24),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Color(0xFF6366F1),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Text(
            '로그인 중...',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4A5568),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionList(bool isMobile) {
    final listPadding = isMobile ? 16.0 : 24.0;

    return Column(
      children: [
        // 에러 메시지
        if (_errorMessage != null)
          Container(
            margin: EdgeInsets.all(listPadding),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        // 옵션 리스트
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(listPadding),
            physics: const BouncingScrollPhysics(),
            itemCount: widget.staffOptions.length,
            itemBuilder: (context, index) {
              final option = widget.staffOptions[index];

              return SlideTransition(
                position: _cardAnimations.isNotEmpty && index < _cardAnimations.length
                    ? _cardAnimations[index]
                    : const AlwaysStoppedAnimation(Offset.zero),
                child: _buildOptionCard(option, index, isMobile),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard(Map<String, dynamic> option, int index, bool isMobile) {
    final branchName = option['branch_name']?.toString() ?? '알 수 없는 지점';
    final roleDisplay = option['role_display']?.toString() ?? '';
    final role = option['role']?.toString() ?? '';
    final staffName = option['staff_name']?.toString() ?? '';

    // 역할별 색상 테마
    Color primaryColor;
    Color accentColor;
    IconData roleIcon;

    if (role == 'pro') {
      primaryColor = const Color(0xFF6366F1);
      accentColor = const Color(0xFF8B5CF6);
      roleIcon = Icons.sports_golf;
    } else if (role == 'manager') {
      primaryColor = const Color(0xFF10B981);
      accentColor = const Color(0xFF34D399);
      roleIcon = Icons.manage_accounts;
    } else {
      primaryColor = const Color(0xFF6366F1);
      accentColor = const Color(0xFF8B5CF6);
      roleIcon = Icons.person;
    }

    final cardPadding = isMobile ? 16.0 : 24.0;
    final iconSize = isMobile ? 48.0 : 64.0;
    final titleSize = isMobile ? 16.0 : 20.0;
    final subSize = isMobile ? 13.0 : 15.0;
    final spacing = isMobile ? 12.0 : 20.0;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          onTap: () => _selectOption(option),
          child: Container(
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              children: [
                // 역할 아이콘
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryColor, accentColor],
                    ),
                    borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    roleIcon,
                    color: Colors.white,
                    size: isMobile ? 24 : 28,
                  ),
                ),

                SizedBox(width: spacing),

                // 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 지점명
                      Text(
                        branchName,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2D3748),
                        ),
                        maxLines: isMobile ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: isMobile ? 6 : 8),

                      // 역할 뱃지
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8 : 12,
                              vertical: isMobile ? 4 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                            ),
                            child: Text(
                              roleDisplay,
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: isMobile ? 8 : 12),
                          Icon(
                            Icons.person,
                            size: isMobile ? 14 : 16,
                            color: const Color(0xFF718096),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            staffName,
                            style: TextStyle(
                              fontSize: subSize,
                              color: const Color(0xFF4A5568),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(width: isMobile ? 8 : 12),

                // 화살표
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: primaryColor,
                    size: isMobile ? 12 : 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

