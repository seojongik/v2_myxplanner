import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'main_page.dart';

class AdminMemberSelectPage extends StatefulWidget {
  final Map<String, dynamic> branchData;

  const AdminMemberSelectPage({
    Key? key,
    required this.branchData,
  }) : super(key: key);

  @override
  _AdminMemberSelectPageState createState() => _AdminMemberSelectPageState();
}

class _AdminMemberSelectPageState extends State<AdminMemberSelectPage> 
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // 애니메이션 컨트롤러
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late List<Animation<Offset>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    print('👥 [AdminMemberSelectPage] initState 시작');
    print('👥 [AdminMemberSelectPage] branchData: ${widget.branchData}');
    _initAnimations();
    _loadBranchMembers();
    _searchController.addListener(_onSearchChanged);
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
      _filteredMembers.length,
      (index) => Tween<Offset>(
        begin: Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Interval(
          (index * 0.05).clamp(0.0, 1.0), // Clamp start value
          ((index * 0.05) + 0.3).clamp(0.0, 1.0), // Clamp end value
          curve: Curves.easeOutCubic,
        ),
      )),
    );
    _slideController.reset();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterMembers();
    });
  }

  void _filterMembers() {
    if (_searchQuery.isEmpty) {
      _filteredMembers = List.from(_members);
    } else {
      _filteredMembers = _members.where((member) {
        final name = member['member_name']?.toString().toLowerCase() ?? '';
        final phone = member['member_phone']?.toString().toLowerCase() ?? '';
        return name.contains(_searchQuery) || phone.contains(_searchQuery);
      }).toList();
    }
    _initCardAnimations();
  }

  Future<void> _loadBranchMembers() async {
    print('👥 [AdminMemberSelectPage] _loadBranchMembers 시작');
    setState(() {
      _isLoading = true;
    });

    try {
      final branchId = widget.branchData['branch_id'].toString();
      print('👥 지점 회원 조회 중... Branch ID: $branchId');
      
      // v3_members 테이블에서 해당 지점의 회원 정보 조회
      final members = await ApiService.getData(
        table: 'v3_members',
        fields: [
          'member_id', 
          'member_name', 
          'member_phone', 
          'member_type', 
          'member_chn_keyword', 
          'member_register',
          'branch_id'
        ],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId}
        ],
        orderBy: [{'field': 'member_name', 'direction': 'ASC'}],
      );

      print('조회된 회원 수: ${members.length}');
      
      setState(() {
        _members = members;
        _filteredMembers = List.from(_members);
        _isLoading = false;
      });

      // 카드 애니메이션 초기화
      _initCardAnimations();
      
    } catch (e) {
      print('회원 정보 조회 오류: $e');
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('회원 정보를 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  void _selectMember(Map<String, dynamic> member) {
    final memberName = member['member_name']?.toString() ?? '회원명 없음';
    final branchName = widget.branchData['branch_name']?.toString() ?? '지점명 없음';
    
    print('관리자 모드 - 회원 선택: $memberName (${member['member_id']})');

    // 선택 확인 다이얼로그 표시
    _showSelectionDialog(member);
  }

  void _showSelectionDialog(Map<String, dynamic> member) {
    final memberName = member['member_name']?.toString() ?? '회원명 없음';
    final branchName = widget.branchData['branch_name']?.toString() ?? '지점명 없음';
    
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
              child: Icon(Icons.person, color: Colors.orange, size: 24),
            ),
            SizedBox(width: 12),
            Text('회원 선택', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$memberName님으로 로그인하시겠습니까?',
              style: TextStyle(fontSize: 16, color: Color(0xFF4A5568)),
            ),
            SizedBox(height: 8),
            Text(
              '지점: $branchName',
              style: TextStyle(fontSize: 14, color: Color(0xFF718096)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Color(0xFF718096))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loginAsMember(member);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('로그인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _loginAsMember(Map<String, dynamic> member) async {
    try {
      final branchId = widget.branchData['branch_id'].toString();
      
      // branch_name이 없으면 DB에서 조회
      Map<String, dynamic> branchData = Map<String, dynamic>.from(widget.branchData);
      if (branchData['branch_name'] == null || branchData['branch_name'].toString().isEmpty) {
        print('⚠️ branch_name이 없음 - DB에서 조회: $branchId');
        try {
          final branches = await ApiService.getData(
            table: 'v2_branch',
            where: [{'field': 'branch_id', 'operator': '=', 'value': branchId}],
            fields: ['branch_id', 'branch_name', 'branch_address', 'branch_phone'],
          );
          
          if (branches.isNotEmpty) {
            branchData = branches.first;
            print('✅ branch_name 조회 완료: ${branchData['branch_name']}');
          } else {
            print('⚠️ branch_name 조회 실패 - 기존 데이터 사용');
          }
        } catch (e) {
          print('❌ branch_name 조회 오류: $e');
        }
      }
      
      // ApiService에 현재 사용자 및 지점 설정 (관리자 로그인으로 표시)
      print('🔧 setCurrentUser 호출 전');
      ApiService.setCurrentUser(member, isAdminLogin: true);
      print('🔧 setCurrentBranch 호출 전 - branchId: $branchId, branchData: $branchData');
      ApiService.setCurrentBranch(branchId, branchData);
      print('🔧 setCurrentBranch 호출 후 - getCurrentBranch: ${ApiService.getCurrentBranch()}');

      print('관리자 모드 로그인 완료:');
      print('- 회원: ${member['member_name']} (${member['member_id']})');
      print('- 지점: ${branchData['branch_name']} ($branchId)');
      
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.orange),
                SizedBox(height: 16),
                Text('로그인 중...', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      );
      
      // 잠시 대기 후 MainPage로 이동
      await Future.delayed(Duration(milliseconds: 1500));
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => MainPage(
            isAdminMode: true,
            selectedMember: member,
            branchId: branchId,
          ),
        ),
        (route) => false, // 모든 이전 페이지 제거
      );
      
    } catch (e) {
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      print('로그인 처리 오류: $e');
      _showErrorSnackBar('로그인 처리 중 오류가 발생했습니다: $e');
    }
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
                
                // 검색 바
                _buildSearchBar(isMobile),
                
                // 회원 목록
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
                    child: _buildMemberList(screenWidth, isMobile),
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
    final branchName = widget.branchData['branch_name']?.toString() ?? '지점명 없음';
    
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
                  '회원 선택',
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
          
          // 지점 정보 카드
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
                    Icons.business,
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
                        branchName,
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        '로그인할 회원을 선택해주세요',
                        style: TextStyle(
                          fontSize: descSize,
                          color: Colors.white.withOpacity(0.8),
                        ),
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
                    '${_filteredMembers.length}명',
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 12,
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

  Widget _buildSearchBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 32),
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Theme(
          data: ThemeData(
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: Colors.black,
            ),
          ),
          child: TextField(
            controller: _searchController,
            cursorColor: Colors.black,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: Color(0xFF000000),
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
              decorationColor: Colors.black,
            ),
            decoration: InputDecoration(
              hintText: '회원명 또는 전화번호로 검색',
              hintStyle: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: isMobile ? 14 : 16,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Color(0xFF6B7280),
                size: isMobile ? 20 : 24,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Color(0xFF9CA3AF),
                        size: isMobile ? 20 : 24,
                      ),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20,
                vertical: isMobile ? 12 : 16,
              ),
            ),
            onChanged: (value) {
              print('🎨 [DEBUG-ADMIN] 입력된 텍스트: "$value"');
              print('🎨 [DEBUG-ADMIN] 텍스트 길이: ${value.length}');
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMemberList(double screenWidth, bool isMobile) {
    if (_isLoading) {
      return _buildLoadingState(isMobile);
    }

    if (_filteredMembers.isEmpty) {
      return _buildEmptyState(isMobile);
    }

    final listPadding = isMobile ? 16.0 : 24.0;

    return ListView.builder(
      padding: EdgeInsets.all(listPadding),
      physics: BouncingScrollPhysics(),
      itemCount: _filteredMembers.length,
      itemBuilder: (context, index) {
        final member = _filteredMembers[index];
        final memberId = member['member_id']?.toString() ?? 'member_$index';
        
        return SlideTransition(
          key: ValueKey('member_card_$memberId'),
          position: _cardAnimations.isNotEmpty && index < _cardAnimations.length
              ? _cardAnimations[index]
              : AlwaysStoppedAnimation(Offset.zero),
          child: _buildMemberCard(member, index, screenWidth, isMobile),
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
            '회원 목록을 불러오는 중...',
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
    
    String emptyMessage;
    String emptyDesc;
    
    if (_searchQuery.isNotEmpty) {
      emptyMessage = '검색 결과가 없습니다';
      emptyDesc = '다른 키워드로 검색해보세요';
    } else {
      emptyMessage = '등록된 회원이 없습니다';
      emptyDesc = '지점에 등록된 회원이 없습니다';
    }
    
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
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.person_off,
              size: iconSize,
              color: Color(0xFF9CA3AF),
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Text(
            emptyMessage,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5568),
            ),
          ),
          SizedBox(height: 8),
          Text(
            emptyDesc,
            style: TextStyle(
              fontSize: descSize,
              color: Color(0xFF718096),
            ),
          ),
          SizedBox(height: isMobile ? 24 : 32),
          ElevatedButton.icon(
            onPressed: _searchQuery.isNotEmpty 
                ? () => _searchController.clear()
                : _loadBranchMembers,
            icon: Icon(
              _searchQuery.isNotEmpty ? Icons.clear : Icons.refresh, 
              size: isMobile ? 16 : 20
            ),
            label: Text(_searchQuery.isNotEmpty ? '검색 초기화' : '다시 시도'),
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

  Widget _buildMemberCard(Map<String, dynamic> member, int index, double screenWidth, bool isMobile) {
    final memberId = member['member_id']?.toString() ?? '';
    final memberName = member['member_name']?.toString() ?? '이름 없음';
    final memberPhone = member['member_phone']?.toString() ?? '';
    final memberType = member['member_type']?.toString() ?? '';
    final memberKeyword = member['member_chn_keyword']?.toString() ?? '';
    final memberRegister = member['member_register']?.toString() ?? '';

    // 반응형 크기 설정
    final cardPadding = isMobile ? 16.0 : 24.0;
    final iconSize = isMobile ? 40.0 : 48.0;
    final iconRadius = isMobile ? 10.0 : 12.0;
    final titleSize = isMobile ? 16.0 : 18.0;
    final phoneSize = isMobile ? 13.0 : 15.0;
    final infoSize = isMobile ? 11.0 : 13.0;
    final spacing = isMobile ? 12.0 : 16.0;
    final arrowSize = isMobile ? 10.0 : 14.0;
    final arrowPadding = isMobile ? 6.0 : 10.0;

    // 회원 유형에 따른 색상
    Color typeColor;
    String typeLabel;
    
    switch (memberType.toLowerCase()) {
      case 'vip':
        typeColor = Color(0xFFDC2626);
        typeLabel = 'VIP';
        break;
      case 'premium':
        typeColor = Color(0xFF7C2D12);
        typeLabel = '프리미엄';
        break;
      case 'regular':
        typeColor = Color(0xFF059669);
        typeLabel = '일반';
        break;
      default:
        typeColor = Color(0xFF6B7280);
        typeLabel = memberType.isNotEmpty ? memberType : '일반';
    }

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
          onTap: () => _selectMember(member),
          child: Container(
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              children: [
                // 회원 아이콘
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.orange, Colors.orange.shade700],
                    ),
                    borderRadius: BorderRadius.circular(iconRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: isMobile ? 20 : 24,
                  ),
                ),
                
                SizedBox(width: spacing),
                
                // 회원 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 회원명 + 유형
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              memberName,
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D3748),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 6 : 8, 
                              vertical: isMobile ? 2 : 4
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                              border: Border.all(
                                color: typeColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: isMobile ? 9 : 11,
                                color: typeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: isMobile ? 4 : 6),
                      
                      // 전화번호
                      if (memberPhone.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: isMobile ? 12 : 14,
                              color: Color(0xFF6B7280),
                            ),
                            SizedBox(width: isMobile ? 4 : 6),
                            Expanded(
                              child: Text(
                                memberPhone,
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
                        SizedBox(height: isMobile ? 2 : 4),
                      ],
                      
                      // 추가 정보
                      Row(
                        children: [
                          // 회원 ID
                          Icon(
                            Icons.badge,
                            size: isMobile ? 11 : 13,
                            color: Color(0xFF9CA3AF),
                          ),
                          SizedBox(width: isMobile ? 4 : 6),
                          Text(
                            'ID: $memberId',
                            style: TextStyle(
                              fontSize: infoSize,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          
                          // 키워드가 있으면 표시
                          if (memberKeyword.isNotEmpty) ...[
                            SizedBox(width: isMobile ? 8 : 12),
                            Icon(
                              Icons.local_offer,
                              size: isMobile ? 11 : 13,
                              color: Color(0xFF9CA3AF),
                            ),
                            SizedBox(width: isMobile ? 4 : 6),
                            Expanded(
                              child: Text(
                                memberKeyword,
                                style: TextStyle(
                                  fontSize: infoSize,
                                  color: Color(0xFF6B7280),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.orange,
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