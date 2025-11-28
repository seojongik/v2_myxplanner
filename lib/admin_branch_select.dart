import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'admin_member_select.dart';

class AdminBranchSelectPage extends StatefulWidget {
  const AdminBranchSelectPage({Key? key}) : super(key: key);

  @override
  _AdminBranchSelectPageState createState() => _AdminBranchSelectPageState();
}

class _AdminBranchSelectPageState extends State<AdminBranchSelectPage> 
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
    _loadAllBranches();
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
    final itemCount = _branches.length;
    if (itemCount == 0) {
      _cardAnimations = [];
      return;
    }
    
    // 각 아이템의 애니메이션 구간 계산 (0.0 ~ 1.0 범위 내로 제한)
    final maxItems = itemCount.clamp(1, 10);
    final intervalStep = 0.6 / maxItems;
    
    _cardAnimations = List.generate(
      itemCount,
      (index) {
        // 인덱스가 클수록 나중에 애니메이션 시작
        final start = (index * intervalStep).clamp(0.0, 0.7);
        final end = (start + 0.3).clamp(start + 0.1, 1.0);
        
        return Tween<Offset>(
          begin: Offset(0, 0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideController,
          curve: Interval(
            start,
            end,
            curve: Curves.easeOutCubic,
          ),
        ));
      },
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadAllBranches() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('전체 지점 정보 조회 중...');
      
      // v2_branch 테이블에서 전체 지점 정보 조회
      final branches = await ApiService.getData(
        table: 'v2_branch',
        fields: ['branch_id', 'branch_name', 'branch_address', 'branch_phone', 'branch_director_name'],
        orderBy: [{'field': 'branch_name', 'direction': 'ASC'}],
      );

      print('조회된 전체 지점 정보: $branches');
      
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

  void _selectBranch(Map<String, dynamic> branch) {
    final branchId = branch['branch_id'].toString();
    final branchName = branch['branch_name']?.toString() ?? '지점명 없음';
    
    print('관리자 모드 - 지점 선택: $branchName ($branchId)');

    // 선택 확인 다이얼로그 표시
    _showSelectionDialog(branch);
  }

  void _showSelectionDialog(Map<String, dynamic> branch) {
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
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.admin_panel_settings, color: Colors.orange, size: 24),
            ),
            SizedBox(width: 12),
            Text('지점 선택', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          '$branchName의 회원을 선택하시겠습니까?',
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
              _navigateToMemberSelect(branch);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('다음', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _navigateToMemberSelect(Map<String, dynamic> branch) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AdminMemberSelectPage(
          branchData: branch,
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
              Colors.orange,
              Colors.orange.withOpacity(0.8),
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
                // 상단 헤더
                _buildHeader(screenWidth, screenHeight, isMobile),
                
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

  Widget _buildHeader(double screenWidth, double screenHeight, bool isMobile) {
    final headerPadding = isMobile ? 20.0 : 32.0;
    final titleSize = isMobile ? 20.0 : 24.0;
    final descSize = isMobile ? 12.0 : 14.0;
    
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
                  '관리자 지점 선택',
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
          
          // 관리자 정보 카드
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
                    Icons.admin_panel_settings,
                    color: Colors.orange,
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '관리자 모드',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        '관리할 지점을 선택해주세요',
                        style: TextStyle(
                          fontSize: descSize,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
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
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: Colors.orange,
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
            '등록된 지점이 없습니다',
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5568),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '시스템 관리자에게 문의해주세요',
            style: TextStyle(
              fontSize: descSize,
              color: Color(0xFF718096),
            ),
          ),
          SizedBox(height: isMobile ? 24 : 32),
          ElevatedButton.icon(
            onPressed: _loadAllBranches,
            icon: Icon(Icons.refresh, size: isMobile ? 16 : 20),
            label: Text('다시 시도'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
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
    final branchDirector = branch['branch_director_name']?.toString() ?? '';

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
        primaryColor = Colors.orange;
        accentColor = Colors.orange.shade700;
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
                      // 지점명
                      Text(
                        branchName,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D3748),
                        ),
                        maxLines: isMobile ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
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
                      
                      // 원장
                      if (branchDirector.isNotEmpty) ...[
                        SizedBox(height: isMobile ? 4 : 6),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isMobile ? 3 : 4),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.person,
                                size: isMobile ? 12 : 14,
                                color: accentColor,
                              ),
                            ),
                            SizedBox(width: isMobile ? 6 : 8),
                            Text(
                              '원장: $branchDirector',
                              style: TextStyle(
                                fontSize: addressSize,
                                color: Color(0xFF4A5568),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
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