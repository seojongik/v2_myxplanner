import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'login_branch_select.dart';
import 'main_page.dart';
import 'services/api_service.dart';
import 'services/login_storage_service.dart';
import 'services/fcm_service.dart';
import 'admin_branch_select.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _savePhoneNumber = false; // 전화번호 저장 체크박스
  bool _autoLogin = false; // 자동 로그인 체크박스
  bool _isAutoLoginAttempted = false; // 자동 로그인 시도 여부 (무한 루프 방지)

  // 동적 브랜드 설정을 위한 변수들
  Map<String, dynamic>? _currentBranchConfig;
  bool _isLoadingBranch = true;

  // 애니메이션 컨트롤러
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadBranchConfig();
    _initAnimations();
    _loadSavedLoginInfo();
  }

  // 저장된 로그인 정보 불러오기
  Future<void> _loadSavedLoginInfo() async {
    try {
      // 자동 로그인 정보 확인 (우선순위: 자동 로그인 > 전화번호만 저장)
      final autoLoginInfo = await LoginStorageService.getAutoLoginInfo();
      if (autoLoginInfo != null) {
        // 자동 로그인 정보가 있으면 전화번호와 비밀번호 모두 불러오기
        setState(() {
          _autoLogin = true;
          _savePhoneNumber = true; // 자동 로그인 시 전화번호 저장도 체크
          _phoneController.text = autoLoginInfo['phone'] ?? '';
          _passwordController.text = autoLoginInfo['password'] ?? '';
        });
        
        print('✅ 저장된 자동 로그인 정보 불러오기 완료');
        
        // 자동 로그인 시도
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _tryAutoLogin();
        });
      } else {
        // 자동 로그인 정보가 없으면 전화번호만 확인
        final savedPhone = await LoginStorageService.getSavedPhone();
        if (savedPhone != null) {
          setState(() {
            _phoneController.text = savedPhone;
            _savePhoneNumber = true;
            _autoLogin = false;
          });
          print('✅ 저장된 전화번호 불러오기 완료');
        }
      }
    } catch (e) {
      print('⚠️ 저장된 로그인 정보 로드 오류: $e');
    }
  }

  // 자동 로그인 시도
  Future<void> _tryAutoLogin() async {
    if (!_autoLogin || _isAutoLoginAttempted) return;
    
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    
    if (phone.isEmpty || password.isEmpty) return;
    
    // 폼 검증
    if (!_formKey.currentState!.validate()) return;
    
    // 자동 로그인 시도 플래그 설정
    _isAutoLoginAttempted = true;
    
    // 자동 로그인 실행
    await _login();
  }

  // 로그인 정보 저장
  Future<void> _saveLoginInfo(String phone, String password) async {
    try {
      if (_autoLogin) {
        // 자동 로그인 선택 시 전화번호와 비밀번호 모두 저장
        await LoginStorageService.saveAutoLoginInfo(phone, password);
        print('✅ 자동 로그인 정보 저장 완료');
      } else if (_savePhoneNumber) {
        // 전화번호만 저장
        await LoginStorageService.savePhone(phone);
        await LoginStorageService.removePassword(); // 비밀번호는 삭제
        await LoginStorageService.setAutoLoginEnabled(false);
        print('✅ 전화번호 저장 완료');
      } else {
        // 저장하지 않음 - 모든 정보 삭제
        await LoginStorageService.clearAutoLoginInfo();
        print('✅ 저장된 로그인 정보 삭제 완료');
      }
    } catch (e) {
      print('⚠️ 로그인 정보 저장 오류: $e');
    }
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  // 실제 데이터베이스에서 브랜드 설정 로드
  Future<void> _loadBranchConfig() async {
    try {
      setState(() {
        _isLoadingBranch = true;
      });

      // URL에서 브랜치 ID 추출 시도
      String currentUrl = Uri.base.toString();
      String? detectedBranchId;
      
      if (currentUrl.contains('famd') || currentUrl.contains('friends')) {
        detectedBranchId = 'famd';
      } else if (currentUrl.contains('test') || currentUrl.contains('demo')) {
        detectedBranchId = 'test';
      }

      print('현재 URL: $currentUrl');
      print('감지된 브랜치 ID: $detectedBranchId');

      // 감지된 브랜치가 있으면 해당 브랜치 정보 조회
      if (detectedBranchId != null) {
        try {
          final branches = await ApiService.getBranchInfo(branchIds: [detectedBranchId]);
          if (branches.isNotEmpty) {
            final branch = branches.first;
            _currentBranchConfig = _createBranchConfig(branch);
            print('데이터베이스에서 로드된 브랜치 설정: $_currentBranchConfig');
          }
        } catch (e) {
          print('브랜치 정보 조회 실패: $e');
        }
      }

      // 브랜치 설정이 없으면 기본값 사용
      if (_currentBranchConfig == null) {
        _currentBranchConfig = _getDefaultBranchConfig();
        print('기본 브랜치 설정 사용: $_currentBranchConfig');
      }

    } catch (e) {
      print('브랜치 설정 로드 오류: $e');
      _currentBranchConfig = _getDefaultBranchConfig();
    } finally {
      setState(() {
        _isLoadingBranch = false;
      });
    }
  }

  // 데이터베이스 브랜치 정보를 UI 설정으로 변환
  Map<String, dynamic> _createBranchConfig(Map<String, dynamic> branch) {
    final branchId = branch['branch_id']?.toString() ?? '';
    final branchName = branch['branch_name']?.toString() ?? '';
    
    // 스타벅스 스타일 색상 테마
    Color primaryColor;
    Color accentColor;
    
    switch (branchId) {
      case 'famd':
        primaryColor = Color(0xFF00704A); // 스타벅스 그린
        accentColor = Color(0xFF4CAF50);
        break;
      case 'test':
        primaryColor = Color(0xFF1565C0); // 딥 블루
        accentColor = Color(0xFF42A5F5);
        break;
      default:
        primaryColor = Color(0xFF00704A); // 기본 스타벅스 그린
        accentColor = Color(0xFF4CAF50);
    }

    return {
      'primaryColor': primaryColor,
      'accentColor': accentColor,
      'title': branchName.isNotEmpty ? branchName : 'My Golf Planner',
      'subtitle': '', // 서브타이틀 제거
      'branchId': branchId,
      'branchData': branch,
    };
  }

  // 기본 브랜치 설정
  Map<String, dynamic> _getDefaultBranchConfig() {
    return {
      'primaryColor': Color(0xFF00704A),
      'accentColor': Color(0xFF4CAF50),
      'title': 'My Golf Planner',
      'subtitle': '', // 빈 문자열로 변경
      'branchId': 'default',
      'branchData': null,
    };
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // 전화번호 포맷팅 함수
  String _formatPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleaned.length == 11 && cleaned.startsWith('010')) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}';
    }
    
    return phoneNumber;
  }

  void _onPhoneChanged(String value) {
    String formatted = _formatPhoneNumber(value);
    if (formatted != value) {
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final formattedPhone = _formatPhoneNumber(_phoneController.text);
      final password = _passwordController.text;

      print('로그인 시도 - 전화번호: $formattedPhone, 비밀번호: $password');

      final loginResult = await ApiService.login(
        phone: formattedPhone,
        password: password,
      );

      // 로그인 성공 시 저장 설정에 따라 정보 저장
      await _saveLoginInfo(formattedPhone, password);

      final branchIds = List<String>.from(loginResult['branchIds']);
      final memberData = loginResult['memberData'];
      final allMembers = List<Map<String, dynamic>>.from(loginResult['members']); // 전체 회원 목록
      
      print('로그인 성공 - 조회된 지점 수: ${branchIds.length}');

      if (branchIds.length == 1) {
        final branchId = branchIds.first;
        
        // 단일 지점인 경우 해당 지점에 맞는 회원 정보 찾기
        final matchingMember = allMembers.firstWhere(
          (member) => member['branch_id']?.toString() == branchId,
          orElse: () => memberData,
        );
        
        print('단일 지점 로그인 - Branch ID: $branchId');
        print('사용할 회원 정보: $matchingMember');
        
        // 지점 정보 조회
        Map<String, dynamic> branchData = {'branch_id': branchId};
        try {
          final branches = await ApiService.getData(
            table: 'v2_branch',
            where: [{'field': 'branch_id', 'operator': '=', 'value': branchId}],
            fields: ['branch_id', 'branch_name', 'branch_address', 'branch_phone'],
          );
          
          if (branches.isNotEmpty) {
            branchData = branches.first;
            print('✅ 지점 정보 조회 완료: ${branchData['branch_name']}');
          }
        } catch (e) {
          print('❌ 지점 정보 조회 오류: $e');
        }
        
        ApiService.setCurrentUser(matchingMember);
        ApiService.setCurrentBranch(branchId, branchData);
        
        // FCM 토큰 저장 (지점 정보가 설정된 후)
        if (!kIsWeb) {
          print('🔔 FCM 토큰 저장 시작...');
          await FCMService.updateTokenAfterLogin();
        }
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainPage(
              isAdminMode: false,
              selectedMember: matchingMember,
              branchId: branchId,
            ),
          ),
        );
      } else {
        print('다중 지점 로그인 - Branch IDs: $branchIds');
        
        // 전체 회원 목록을 memberData에 포함
        final memberDataWithAll = Map<String, dynamic>.from(memberData);
        memberDataWithAll['allMembers'] = allMembers;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginBranchSelectPage(
              memberData: memberDataWithAll,
              memberBranches: branchIds,
            ),
          ),
        );
      }

    } catch (e) {
      print('로그인 오류: $e');
      
      // 사용자 친화적인 에러 메시지
      String userFriendlyMessage = '아이디(전화번호)와 비밀번호를 확인해주세요.';
      
      // 특정 에러에 대한 메시지 처리
      String errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('network') || errorMessage.contains('connection')) {
        userFriendlyMessage = '네트워크 연결을 확인해주세요.';
      } else if (errorMessage.contains('timeout')) {
        userFriendlyMessage = '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.';
      } else if (errorMessage.contains('server') || errorMessage.contains('500')) {
        userFriendlyMessage = '서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text(userFriendlyMessage, style: TextStyle(fontSize: 16))),
            ],
          ),
          backgroundColor: Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
          elevation: 8,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 개발환경 체크 (PC에서만)
  bool _isDevelopment() {
    // URL 기반 개발 환경 체크 (localhost에서만)
    try {
      String currentUrl = Uri.base.toString();
      // localhost 또는 127.0.0.1에서만 관리자 버튼 표시
      return currentUrl.contains('localhost') ||
             currentUrl.contains('127.0.0.1');
    } catch (e) {
      // URL을 가져올 수 없는 경우 (네이티브 앱)
      // Debug 모드이고 네이티브 환경에서만 표시
      return kDebugMode;
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final config = _currentBranchConfig ?? _getDefaultBranchConfig();
    final primaryColor = config['primaryColor'] as Color;
    final accentColor = config['accentColor'] as Color;

    return Scaffold(
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Container(
                  height: screenHeight - MediaQuery.of(context).padding.top,
                  child: Column(
                    children: [
                      // 상단 로고 영역 - 더 컴팩트하게
                      Expanded(
                        flex: 2,
                        child: _buildHeader(primaryColor, accentColor),
                      ),
                      
                      // 로그인 카드 영역
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
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
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(24),
                            child: _buildLoginForm(primaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor, Color accentColor) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 로고
          Container(
            width: isSmallScreen ? 80 : 100,
            height: isSmallScreen ? 80 : 100,
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
            child: Image.asset(
              'assets/images/applogo.png',
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: 16),
          
          // 타이틀
          Text(
            _currentBranchConfig?['title'] ?? 'My Golf Planner',
            style: TextStyle(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(Color primaryColor) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 인사말
          Text(
            '나를 위한 골프예약! 👋',
            style: TextStyle(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 24),
          
          // 전화번호 입력
          _buildTextField(
            controller: _phoneController,
            label: '전화번호',
            hint: '010-0000-0000',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            onChanged: _onPhoneChanged,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '전화번호를 입력해주세요';
              }
              if (value.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
                return '올바른 전화번호를 입력해주세요';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          
          // 비밀번호 입력
          _buildTextField(
            controller: _passwordController,
            label: '비밀번호',
            hint: '비밀번호를 입력하세요',
            icon: Icons.lock,
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '비밀번호를 입력해주세요';
              }
              if (value.length < 4) {
                return '비밀번호는 4자 이상이어야 합니다';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          
          // 체크박스 영역
          _buildCheckboxes(),
          SizedBox(height: 24),
          
          // 로그인 버튼
          _buildLoginButton(primaryColor),

          // 관리자 로그인 버튼 (개발 모드에서만 표시)
          if (_isDevelopment()) ...[
            SizedBox(height: 16),
            _buildAdminLoginButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        SizedBox(height: 8),
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
            controller: controller,
            obscureText: isPassword && !_isPasswordVisible,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF2D3748),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
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
                child: Icon(
                  icon,
                  color: Color(0xFF4A5568),
                  size: 18,
                ),
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _isPasswordVisible 
                            ? Icons.visibility_off_outlined 
                            : Icons.visibility_outlined,
                        color: Color(0xFF718096),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxes() {
    return Row(
      children: [
        // 전화번호 저장 체크박스
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _savePhoneNumber = !_savePhoneNumber;
                // 전화번호 저장을 해제하면 자동 로그인도 해제
                if (!_savePhoneNumber) {
                  _autoLogin = false;
                }
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _savePhoneNumber 
                          ? Color(0xFF00704A) 
                          : Color(0xFFCBD5E0),
                      width: 2,
                    ),
                    color: _savePhoneNumber 
                        ? Color(0xFF00704A) 
                        : Colors.transparent,
                  ),
                  child: _savePhoneNumber
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '전화번호 저장',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 24),
        // 자동 로그인 체크박스
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _autoLogin = !_autoLogin;
                // 자동 로그인 선택 시 전화번호 저장도 자동으로 체크
                if (_autoLogin) {
                  _savePhoneNumber = true;
                }
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _autoLogin 
                          ? Color(0xFF00704A) 
                          : Color(0xFFCBD5E0),
                      width: 2,
                    ),
                    color: _autoLogin 
                        ? Color(0xFF00704A) 
                        : Colors.transparent,
                  ),
                  child: _autoLogin
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '자동 로그인',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(Color primaryColor) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: _isLoading 
              ? [Color(0xFFE2E8F0), Color(0xFFCBD5E0)]
              : [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: _isLoading ? [] : [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    '로그인 중...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Text(
                '로그인',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildAdminLoginButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.orange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminBranchSelectPage(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              '관리자 로그인',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterLink('비밀번호 찾기', () {
              _showComingSoonSnackBar('비밀번호 찾기');
            }),
            Container(
              width: 1,
              height: 16,
              color: Color(0xFFE2E8F0),
              margin: EdgeInsets.symmetric(horizontal: 16),
            ),
            _buildFooterLink('회원가입', () {
              _showComingSoonSnackBar('회원가입');
            }),
          ],
        ),
        
        SizedBox(height: 20),
        
        _buildFooterLink('게스트로 둘러보기', () {
          Navigator.pushReplacementNamed(context, '/main');
        }, isGuest: true),
      ],
    );
  }

  Widget _buildFooterLink(String text, VoidCallback onTap, {bool isGuest = false}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: isGuest ? Color(0xFF718096) : Color(0xFF4A5568),
          fontWeight: FontWeight.w500,
          decoration: isGuest ? TextDecoration.underline : null,
        ),
      ),
    );
  }

  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              '$feature 기능은 준비중입니다.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Color(0xFF00704A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        elevation: 8,
        duration: Duration(seconds: 3),
      ),
    );
  }
} 