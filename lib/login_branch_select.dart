import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'main_page.dart';
import 'services/api_service.dart';
import 'services/fcm_service.dart';
import 'login_group_master_option.dart';

class LoginBranchSelectPage extends StatefulWidget {
  final Map<String, dynamic> memberData;
  final List<String> memberBranches;

  const LoginBranchSelectPage({
    Key? key,
    required this.memberData,
    required this.memberBranches,
  }) : super(key: key);

  @override
  _LoginBranchSelectPageState createState() => _LoginBranchSelectPageState();
}

class _LoginBranchSelectPageState extends State<LoginBranchSelectPage> 
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = false;
  
  // 애니메이션 컨트롤러
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late List<Animation<Offset>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadBranches();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
  }

  void _initCardAnimations() {
    _cardAnimations = List.generate(
      _branches.length,
      (index) => Tween<Offset>(
        begin: Offset(0, 0.5),
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
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('사용자가 접근 가능한 지점들: ${widget.memberBranches}');
      
      // ApiService의 getBranchInfo 함수 사용
      final branches = await ApiService.getBranchInfo(
        branchIds: widget.memberBranches,
      );

      print('조회된 지점 정보: $branches');
      
      setState(() {
        _branches = branches;
        _isLoading = false;
      });

      // 카드 애니메이션 초기화
      _initCardAnimations();
      
    } catch (e) {
      print('지점 정보 조회 오류: $e');
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('지점 정보를 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _selectBranch(Map<String, dynamic> branch) async {
    final branchId = branch['branch_id'].toString();
    print('지점 선택 완료: ${branch['branch_name']} ($branchId)');
    print('원래 회원 정보: ${widget.memberData}');

    // 선택된 지점에 맞는 회원 정보 찾기
    Map<String, dynamic> selectedMemberData = widget.memberData;
    
    // 로그인 시 받은 전체 회원 목록에서 선택된 브랜치와 일치하는 회원 정보 찾기
    if (widget.memberData.containsKey('allMembers')) {
      final allMembers = widget.memberData['allMembers'] as List<Map<String, dynamic>>;
      final matchingMember = allMembers.firstWhere(
        (member) => member['branch_id']?.toString() == branchId,
        orElse: () => widget.memberData,
      );
      selectedMemberData = matchingMember;
      print('선택된 지점에 맞는 회원 정보: $selectedMemberData');
    }

    // ApiService에 현재 사용자 및 지점 설정
    ApiService.setCurrentUser(selectedMemberData);
    ApiService.setCurrentBranch(branchId, branch);
    
    // FCM 토큰 저장 (지점 정보가 설정된 후)
    if (!kIsWeb) {
      print('🔔 FCM 토큰 저장 시작...');
      await FCMService.updateTokenAfterLogin();
    }

    // 선택 확인 다이얼로그 표시
    _showSelectionDialog(branch, selectedMemberData);
  }

  void _showSelectionDialog(Map<String, dynamic> branch, Map<String, dynamic> selectedMemberData) {
    final branchName = branch['branch_name']?.toString() ?? '지점명 없음';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF00704A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_circle, color: Color(0xFF00704A), size: 24),
            ),
            SizedBox(width: 12),
            Text('지점 선택 완료', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          '$branchName으로 입장하시겠습니까?',
          style: TextStyle(fontSize: 16, color: Color(0xFF4A5568)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Color(0xFF718096))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkGroupMasterAndProceed(branch, selectedMemberData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00704A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('입장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkGroupMasterAndProceed(Map<String, dynamic> branch, Map<String, dynamic> selectedMemberData) async {
    try {
      final branchId = branch['branch_id'].toString();
      final currentMemberId = selectedMemberData['member_id']?.toString();
      
      if (currentMemberId == null) {
        _navigateToMain(branch, selectedMemberData);
        return;
      }

      print('그룹 마스터 권한 확인 중... member_id: $currentMemberId, branch_id: $branchId');
      
      // v2_group 테이블에서 _is_master 컬럼에 현재 회원 ID가 있는지 확인
      final response = await ApiService.getData(
        table: 'v2_group',
        where: [
          {
            'field': '_is_master',
            'operator': '=',
            'value': currentMemberId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': branchId,
          }
        ],
      );

      print('v2_group 조회 결과: $response');
      
      if (response.isNotEmpty) {
        // 그룹 멤버가 있다면 계정 선택 페이지로 이동
        print('그룹 마스터 권한 확인됨. 계정 선택 페이지로 이동');
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => LoginGroupMasterOptionPage(
              memberData: selectedMemberData,
              branchData: branch,
              branchId: branchId,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: Duration(milliseconds: 300),
          ),
        );
      } else {
        // 그룹 멤버가 없다면 바로 메인으로 이동
        print('그룹 마스터 권한 없음. 바로 메인으로 이동');
        _navigateToMain(branch, selectedMemberData);
      }
      
    } catch (e) {
      print('그룹 마스터 권한 확인 오류: $e');
      // 오류 발생 시 바로 메인으로 이동
      _navigateToMain(branch, selectedMemberData);
    }
  }

  void _navigateToMain(Map<String, dynamic> branch, Map<String, dynamic> selectedMemberData) {
    final branchId = branch['branch_id'].toString();
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MainPage(
          isAdminMode: false,
          selectedMember: selectedMemberData,
          branchId: branchId,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: Duration(milliseconds: 300),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
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
  }

  @override
  Widget build(BuildContext context) {
    final memberName = widget.memberData['member_name']?.toString() ?? '사용자';
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isMobile = screenWidth < 600;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00704A),
              Color(0xFF00704A).withOpacity(0.8),
              Colors.white,
            ],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // 상단 헤더 - 반응형 높이
                _buildHeader(memberName, screenWidth, screenHeight, isMobile),
                
                // 지점 목록
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
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: _buildBranchList(screenWidth, isMobile),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String memberName, double screenWidth, double screenHeight, bool isMobile) {
    final headerPadding = isMobile ? 20.0 : 32.0;
    final titleSize = isMobile ? 20.0 : 24.0;
    final welcomeSize = isMobile ? 16.0 : 18.0;
    final descSize = isMobile ? 12.0 : 14.0;
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
                    size: isMobile ? 16 : 20
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Text(
                  '지점 선택',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 40 : 48), // 균형을 위한 공간
            ],
          ),
          
          SizedBox(height: isMobile ? 16 : 24),
          
          // 사용자 정보 카드
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
                    Icons.person,
                    color: Color(0xFF00704A),
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$memberName님, 환영합니다!',
                          style: TextStyle(
                            fontSize: welcomeSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        '이용하실 지점을 선택해주세요',
                        style: TextStyle(
                          fontSize: descSize,
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
                    vertical: isMobile ? 4 : 6
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                  ),
                  child: Text(
                    '${widget.memberBranches.length}개 지점',
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

  Widget _buildBranchList(double screenWidth, bool isMobile) {
    if (_isLoading) {
      return _buildLoadingState(isMobile);
    }

    if (_branches.isEmpty) {
      return _buildEmptyState(isMobile);
    }

    final listPadding = isMobile ? 16.0 : 24.0;

    return ListView.builder(
      padding: EdgeInsets.all(listPadding),
      physics: BouncingScrollPhysics(),
      itemCount: _branches.length,
      itemBuilder: (context, index) {
        final branch = _branches[index];
        
        return SlideTransition(
          position: _cardAnimations.isNotEmpty && index < _cardAnimations.length
              ? _cardAnimations[index]
              : AlwaysStoppedAnimation(Offset.zero),
          child: _buildBranchCard(branch, index, screenWidth, isMobile),
        );
      },
    );
  }

  Widget _buildLoadingState(bool isMobile) {
    final titleSize = isMobile ? 16.0 : 18.0;
    final descSize = isMobile ? 12.0 : 14.0;
    final iconSize = isMobile ? 20.0 : 24.0;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(iconSize),
            decoration: BoxDecoration(
              color: Color(0xFF00704A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: Color(0xFF00704A),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Text(
            '지점 목록을 불러오는 중...',
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4A5568),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '잠시만 기다려주세요',
            style: TextStyle(
              fontSize: descSize,
              color: Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    final titleSize = isMobile ? 18.0 : 20.0;
    final descSize = isMobile ? 12.0 : 14.0;
    final iconSize = isMobile ? 40.0 : 48.0;
    final buttonPadding = isMobile ? 16.0 : 24.0;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 20 : 24),
            decoration: BoxDecoration(
              color: Color(0xFFF7FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_off_outlined,
              size: iconSize,
              color: Color(0xFF9CA3AF),
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Text(
            '이용 가능한 지점이 없습니다',
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5568),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '관리자에게 문의해주세요',
            style: TextStyle(
              fontSize: descSize,
              color: Color(0xFF718096),
            ),
          ),
          SizedBox(height: isMobile ? 24 : 32),
          ElevatedButton.icon(
            onPressed: _loadBranches,
            icon: Icon(Icons.refresh, size: isMobile ? 16 : 20),
            label: Text('다시 시도'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00704A),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: buttonPadding, 
                vertical: isMobile ? 10 : 12
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(Map<String, dynamic> branch, int index, double screenWidth, bool isMobile) {
    final branchId = branch['branch_id']?.toString() ?? '';
    final branchName = branch['branch_name']?.toString() ?? '지점명 없음';
    final branchAddress = branch['branch_address']?.toString() ?? '주소 정보 없음';
    final branchPhone = branch['branch_phone']?.toString() ?? '';

    // 반응형 크기 설정
    final cardPadding = isMobile ? 16.0 : 24.0;
    final iconSize = isMobile ? 48.0 : 64.0;
    final iconRadius = isMobile ? 12.0 : 16.0;
    final titleSize = isMobile ? 16.0 : 20.0;
    final phoneSize = isMobile ? 13.0 : 15.0;
    final addressSize = isMobile ? 12.0 : 14.0;
    final spacing = isMobile ? 12.0 : 20.0;
    final arrowSize = isMobile ? 12.0 : 16.0;
    final arrowPadding = isMobile ? 8.0 : 12.0;

    // 지점별 색상 테마
    Color primaryColor;
    Color accentColor;
    IconData branchIcon;
    
    switch (branchId) {
      case 'famd':
        primaryColor = Color(0xFF00704A);
        accentColor = Color(0xFF4CAF50);
        branchIcon = Icons.school_outlined;
        break;
      case 'test':
        primaryColor = Color(0xFF1565C0);
        accentColor = Color(0xFF42A5F5);
        branchIcon = Icons.science_outlined;
        break;
      default:
        primaryColor = Color(0xFF00704A);
        accentColor = Color(0xFF4CAF50);
        branchIcon = Icons.business_outlined;
    }

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          onTap: () => _selectBranch(branch),
          child: Container(
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              children: [
                // 지점 아이콘
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryColor, accentColor],
                    ),
                    borderRadius: BorderRadius.circular(iconRadius),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    branchIcon,
                    color: Colors.white,
                    size: isMobile ? 24 : 28,
                  ),
                ),
                
                SizedBox(width: spacing),
                
                // 지점 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 지점명 - 반응형 텍스트
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Text(
                            branchName,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2D3748),
                            ),
                            maxLines: isMobile ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      
                      SizedBox(height: isMobile ? 6 : 8),
                      
                      // 전화번호
                      if (branchPhone.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isMobile ? 3 : 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.phone,
                                size: isMobile ? 12 : 14,
                                color: primaryColor,
                              ),
                            ),
                            SizedBox(width: isMobile ? 6 : 8),
                            Flexible(
                              child: Text(
                                branchPhone,
                                style: TextStyle(
                                  fontSize: phoneSize,
                                  color: Color(0xFF4A5568),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isMobile ? 4 : 6),
                      ],
                      
                      // 주소
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isMobile ? 3 : 4),
                            decoration: BoxDecoration(
                              color: Color(0xFFF7FAFC),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.location_on,
                              size: isMobile ? 12 : 14,
                              color: Color(0xFF718096),
                            ),
                          ),
                          SizedBox(width: isMobile ? 6 : 8),
                          Expanded(
                            child: Text(
                              branchAddress,
                              style: TextStyle(
                                fontSize: addressSize,
                                color: Color(0xFF718096),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(width: isMobile ? 8 : 12),
                
                // 선택 버튼
                Container(
                  padding: EdgeInsets.all(arrowPadding),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: primaryColor,
                    size: arrowSize,
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