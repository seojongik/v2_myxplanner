import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'services/api_service.dart';
import 'services/aligo_sms_service.dart';
import 'services/chatting/chatting_service.dart';
import 'member_select_page.dart';
import 'pages/home/home_page.dart';
import 'pages/search/search_page.dart';
import 'pages/reservation/reservation_page.dart';
import 'pages/membership/membership_page.dart';
import 'pages/membership/contract_setup_page.dart';
import 'pages/account/account_page.dart';
import 'pages/phone_auth/phone_auth_popup.dart';
import 'pages/auth/password_change_page.dart';
import 'widgets/global_chat_button.dart';
import '../stubs/html_stub.dart' if (dart.library.html) 'dart:html' as html;

class MainPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final int initialIndex; // 초기 탭 인덱스

  const MainPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.initialIndex = 0, // 기본값 0 (홈)
  }) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int _selectedIndex;
  Map<String, dynamic>? _currentMember;
  String? _currentBranchId;

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

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex; // 초기 탭 인덱스 설정
    _initializePageData();
  }

  @override
  void dispose() {
    // 글로벌 채팅 알림 리스너 중지
    ChattingService.stopGlobalNotificationListener();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleRouteArguments();
  }

  void _initializePageData() async {
    _currentMember = widget.selectedMember;
    _currentBranchId = widget.branchId;

    // 관리자 로그인이 아닌 경우에만 API 서비스 초기화
    // 관리자 로그인은 이미 admin_member_select에서 완전한 branchData로 설정됨
    if (!ApiService.isAdminLogin()) {
      // CRM에서 전달받은 브랜치 ID로 골프 플래너 앱의 API 서비스 초기화
      if (_currentBranchId != null) {
        print('골프 플래너 앱 API 서비스 초기화 - 브랜치 ID: $_currentBranchId');
        await ApiService.initializeReservationSystem(branchId: _currentBranchId);
      } else {
        print('브랜치 ID가 없어 기본값으로 초기화');
        await ApiService.initializeReservationSystem();
      }
    } else {
      print('🔑 관리자 로그인 - API 서비스 초기화 스킵 (이미 설정됨)');
      print('🔑 현재 브랜치: ${ApiService.getCurrentBranch()}');
    }

    // 로그인 직후 바로 전화번호 인증 및 비밀번호 확인
    _checkPhoneAuthStatus();

    // 글로벌 채팅 알림 리스너 시작
    ChattingService.startGlobalNotificationListener();
    
    // 웹 환경에서 결제 완료 후 리디렉션 결과 확인
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkPendingPayment();
      });
    }
  }
  
  // 결제 완료 후 리디렉션 결과 확인 및 처리
  void _checkPendingPayment() async {
    if (!kIsWeb) return; // 웹 환경에서만 실행
    
    try {
      final storage = html.window.localStorage;
      final paymentId = storage['mgp_pending_payment_paymentId'];
      final txId = storage['mgp_pending_payment_txId'];
      final status = storage['mgp_pending_payment_status'];
      
      // 결제 정보 확인
      final contractJson = storage['mgp_payment_contract'];
      final membershipType = storage['mgp_payment_membershipType'];
      final memberId = storage['mgp_payment_memberId'];
      final memberName = storage['mgp_payment_memberName'];
      final channelKey = storage['mgp_payment_channelKey'];
      final orderName = storage['mgp_payment_orderName'];
      final totalAmount = storage['mgp_payment_totalAmount'];
      
      if (paymentId != null && paymentId.isNotEmpty && status == 'success' && mounted) {
        debugPrint('💳 대기 중인 결제 결과 확인: $paymentId');
        debugPrint('📱 모바일 웹 브라우저: ${_isMobileBrowser()}');
        
        // 결제 정보가 모두 있으면 결제 처리 진행
        if (contractJson != null && membershipType != null) {
          debugPrint('✅ 결제 정보 확인 완료 - 결제 처리 시작');
          
          // 회원권 탭으로 이동
          setState(() {
            _selectedIndex = 3; // 회원권 탭 인덱스
          });
          
          // 약간의 딜레이 후 결제 처리 페이지로 이동
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              _processPendingPayment(
                paymentId: paymentId,
                txId: txId,
                contractJson: contractJson,
                membershipType: membershipType,
                memberId: memberId,
                memberName: memberName,
                channelKey: channelKey,
                orderName: orderName,
                totalAmount: totalAmount,
              );
            }
          });
        } else {
          // 결제 정보가 없으면 알림만 표시
          debugPrint('⚠️ 결제 정보가 불완전합니다. 회원권 페이지로 이동합니다.');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('결제가 완료되었습니다. 회원권 페이지로 이동합니다.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // 회원권 탭으로 이동
          setState(() {
            _selectedIndex = 3;
          });
          
          // localStorage에서 결제 결과 제거
          _clearPendingPayment(storage);
        }
      }
    } catch (e) {
      debugPrint('⚠️ 대기 중인 결제 결과 확인 오류: $e');
      // localStorage 접근 실패 시에도 앱은 정상 작동해야 함
    }
  }
  
  // 대기 중인 결제 처리
  void _processPendingPayment({
    required String paymentId,
    String? txId,
    required String contractJson,
    required String membershipType,
    String? memberId,
    String? memberName,
    String? channelKey,
    String? orderName,
    String? totalAmount,
  }) async {
    try {
      final contract = jsonDecode(contractJson) as Map<String, dynamic>;
      
      // 회원 정보 구성
      Map<String, dynamic>? selectedMember;
      if (memberId != null && memberName != null) {
        selectedMember = {
          'member_id': int.tryParse(memberId) ?? 1,
          'member_name': memberName,
        };
      }
      
      // 회원권 설정 페이지로 이동하여 결제 처리
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ContractSetupPage(
            contract: contract,
            membershipType: membershipType,
            selectedMember: selectedMember,
            branchId: _currentBranchId,
            isAdminMode: widget.isAdminMode,
          ),
        ),
      ).then((_) {
        // 페이지에서 돌아온 후 결제 정보 정리
        if (kIsWeb) {
          try {
            final storage = html.window.localStorage;
            _clearPendingPayment(storage);
            // 결제 시작 정보도 정리
            storage.remove('mgp_payment_contract');
            storage.remove('mgp_payment_membershipType');
            storage.remove('mgp_payment_memberId');
            storage.remove('mgp_payment_memberName');
            storage.remove('mgp_payment_channelKey');
            storage.remove('mgp_payment_orderName');
            storage.remove('mgp_payment_totalAmount');
            storage.remove('mgp_payment_paymentId');
            storage.remove('mgp_payment_proId');
            storage.remove('mgp_payment_proName');
            storage.remove('mgp_payment_termStartDate');
            storage.remove('mgp_payment_termEndDate');
          } catch (e) {
            print('⚠️ localStorage 정리 오류: $e');
          }
        }
      });
      
      // ContractSetupPage에서 결제 처리하도록 알림
      // 결제 정보를 ContractSetupPage에 전달하여 자동으로 처리하도록 함
      // 이는 ContractSetupPage의 initState에서 확인하도록 해야 함
      
    } catch (e) {
      debugPrint('❌ 결제 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('결제 처리 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
  
  // localStorage에서 대기 중인 결제 결과 제거
  void _clearPendingPayment(html.Storage storage) {
    try {
      storage.remove('mgp_pending_payment_paymentId');
      storage.remove('mgp_pending_payment_txId');
      storage.remove('mgp_pending_payment_status');
      storage.remove('mgp_pending_payment_expectedId');
    } catch (e) {
      debugPrint('⚠️ localStorage 제거 오류: $e');
    }
  }
  
  // 모바일 브라우저 감지
  bool _isMobileBrowser() {
    if (!kIsWeb) return false;
    try {
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      return userAgent.contains('mobile') || 
             userAgent.contains('android') || 
             userAgent.contains('iphone') || 
             userAgent.contains('ipad') ||
             userAgent.contains('ipod');
    } catch (e) {
      return false;
    }
  }
  
  // 관리자 권한 확인
  bool _isAdminUser(Map<String, dynamic> user) {
    final memberType = user['member_type']?.toString().toLowerCase();
    return memberType == 'admin' || 
           memberType == '관리자' || 
           memberType == 'administrator' ||
           memberType == 'staff' ||
           memberType == '스태프';
  }

  // 전화번호 인증 상태 확인 및 안내
  void _checkPhoneAuthStatus() async {
    final currentUser = ApiService.getCurrentUser();
    if (currentUser != null && currentUser['member_id'] != null) {
      
      // 관리자 로그인인 경우 전화번호 인증 프로세스 스킵
      if (ApiService.isAdminLogin()) {
        print('🔑 관리자 로그인 - 전화번호 인증 프로세스 스킵');
        // 관리자 로그인이어도 기본 비밀번호 확인은 스킵
        return;
      }
      
      // 전화번호가 없는 회원(주니어, 대리 예약 회원 등)은 인증 스킵
      final memberPhone = currentUser['member_phone']?.toString();
      if (memberPhone == null || memberPhone.isEmpty || memberPhone == 'null') {
        print('📱 전화번호 없는 회원 - 인증 프로세스 스킵');
        return;
      }
      
      // 관리자 계정이어도 일반 로그인인 경우 인증 필요 (선택적)
      if (_isAdminUser(currentUser)) {
        print('🔑 관리자 계정이지만 일반 로그인 - 인증 프로세스 진행');
      }
      
      final isVerified = await AligoSmsService.isPhoneVerified(memberPhone);
      
      if (!isVerified && mounted) {
        _showPhoneAuthGuide();
      } else {
        // 전화번호 인증이 완료된 경우 기본 비밀번호 확인
        _checkDefaultPassword();
      }
    }
  }
  
  // 기본 비밀번호 확인 및 안내
  void _checkDefaultPassword() async {
    // 관리자 로그인인 경우 비밀번호 변경 안내 스킵
    if (ApiService.isAdminLogin()) {
      return;
    }
    
    final currentUser = ApiService.getCurrentUser();
    if (currentUser != null) {
      final phoneNumber = currentUser['member_phone']?.toString() ?? '';
      
      // 현재 로그인한 전화번호로 모든 지점 계정 조회해서 기본 비밀번호 확인
      try {
        final allMembers = await ApiService.getData(
          table: 'v3_members',
          where: [
            {'field': 'member_phone', 'operator': '=', 'value': phoneNumber}
          ],
          fields: ['member_id', 'member_password', 'branch_id'],
        );
        
        print('🔍 비밀번호 확인 - 전체 계정: $allMembers');
        
        // 하나라도 기본 비밀번호를 사용하는 계정이 있으면 변경 안내
        bool hasDefaultPassword = false;
        for (final member in allMembers) {
          final password = member['member_password']?.toString() ?? '';
          print('지점 ${member['branch_id']} 비밀번호: "$password"');
          
          if (_isDefaultPassword(password, phoneNumber)) {
            print('⚠️ 기본 비밀번호 발견: ${member['branch_id']} 지점');
            hasDefaultPassword = true;
            break;
          }
        }
        
        if (hasDefaultPassword) {
          print('🚨 기본 비밀번호 사용 중 - 변경 안내 표시');
          _showPasswordChangeGuide();
        } else {
          print('✅ 모든 계정이 안전한 비밀번호 사용 중');
        }
      } catch (e) {
        print('비밀번호 확인 오류: $e');
      }
    }
  }
  
  // 기본 비밀번호 확인 (1111 또는 전화번호 뒤 4자리)
  bool _isDefaultPassword(String password, String phoneNumber) {
    if (password == '1111') return true;
    
    // 전화번호 뒤 4자리 추출
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length >= 4) {
      final lastFour = cleanPhone.substring(cleanPhone.length - 4);
      return password == lastFour;
    }
    
    return false;
  }
  
  // 전화번호 인증 - 전체화면 팝업 (전체 플로우 포함)
  void _showPhoneAuthGuide() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PhoneAuthPopup.show(
          context: context,
          onComplete: () {
            // 인증 완료 후 비밀번호 변경 확인
            _checkDefaultPassword();
          },
        );
      }
    });
  }
  
  // 비밀번호 변경 안내 다이얼로그
  void _showPasswordChangeGuide() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning,
                      color: Colors.red.shade700,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '비밀번호 변경이 필요합니다',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '보안을 위해 기본 비밀번호를\n새로운 비밀번호로 변경해주세요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('나중에'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PasswordChangePage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('변경하기'),
                ),
              ],
            );
          },
        );
      }
    });
  }

  void _handleRouteArguments() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    print('메인 페이지 라우트 인수: $args');
    
    if (args != null) {
      print('회원 정보 업데이트: ${args['selectedMember']}');
      print('브랜치 ID: ${args['branchId']}');
      print('관리자 모드: ${args['isAdminMode']}');
      
      setState(() {
        _currentMember = args['selectedMember'];
        _currentBranchId = args['branchId'];
      });
      
      // 브랜치 ID가 업데이트되면 API 서비스 재초기화
      if (_currentBranchId != null) {
        print('라우트 인수로 인한 API 서비스 재초기화 - 브랜치 ID: $_currentBranchId');
        ApiService.initializeReservationSystem(branchId: _currentBranchId);
      }
    } else {
      print('라우트 인수가 없습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          _buildCurrentPage(),
          // 하단 네비게이션 바 - Stack 안에 배치
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNavigationBar(),
          ),
          // 글로벌 채팅 버튼 - 드래그 가능 (네비게이션 바보다 위)
          GlobalChatButton(),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return HomePage(
          isAdminMode: widget.isAdminMode,
          selectedMember: _currentMember,
          branchId: _currentBranchId,
        );
      case 1:
        return SearchPage(
          isAdminMode: widget.isAdminMode,
          selectedMember: _currentMember,
          branchId: _currentBranchId,
        );
      case 2:
        return ReservationPage(
          isAdminMode: widget.isAdminMode,
          selectedMember: _currentMember,
          branchId: _currentBranchId,
        );
      case 3:
        return MembershipPage(
          isAdminMode: widget.isAdminMode,
          selectedMember: _currentMember,
          branchId: _currentBranchId,
        );
      case 4:
        return AccountPage(
          isAdminMode: widget.isAdminMode,
          selectedMember: _currentMember,
          branchId: _currentBranchId,
        );
      default:
        return HomePage(
          isAdminMode: widget.isAdminMode,
          selectedMember: _currentMember,
          branchId: _currentBranchId,
        );
    }
  }

  // 관리자 접근 차단 다이얼로그
  void _showAdminAccessDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.block,
                  color: Colors.red.shade700,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '접근 제한',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '관리자 로그인 상태에서는\n고객 계정 정보에 접근할 수 없습니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '개인정보 보호를 위한 조치입니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
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
        top: false,
        child: Padding(
          padding: EdgeInsets.only(left: 8.0, right: 8.0, top: 4.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = _selectedIndex == index;

              return GestureDetector(
                onTap: () {
                  // 관리자 로그인으로 계정 탭 접근 시 차단
                  if (index == 4 && ApiService.isAdminLogin()) {
                    _showAdminAccessDeniedDialog();
                    return;
                  }
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                child: Container(
                  padding: EdgeInsets.only(
                    left: 12.0,
                    right: 12.0,
                    top: 4.0,
                    bottom: 6.0,
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
                        isSelected ? item.selectedIcon : item.icon,
                        color: isSelected
                            ? Colors.blue
                            : Colors.grey[600],
                        size: 24.0,
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        item.label,
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

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}