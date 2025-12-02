import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tab_design_service.dart';
import '../../services/tile_design_service.dart';
import 'contract_list_page.dart';
import 'contract_setup_page.dart';

// 페이지 상태 열거형
enum MembershipPageState {
  typeSelection,  // 회원권 유형 선택
  contractList,   // 계약 목록
  contractSetup,  // 계약 설정
}

class MembershipPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const MembershipPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _MembershipPageState createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  List<String> membershipTypes = [];
  bool isLoading = true;
  String? errorMessage;
  
  // 페이지 상태 관리
  MembershipPageState _currentPageState = MembershipPageState.typeSelection;
  String? _selectedMembershipType;
  Map<String, dynamic>? _selectedContract;

  @override
  void initState() {
    super.initState();
    _loadMembershipTypes();
  }
  
  // 페이지 뒤로가기
  void _goBack() {
    if (_currentPageState == MembershipPageState.contractSetup) {
      setState(() {
        _currentPageState = MembershipPageState.contractList;
        _selectedContract = null;
      });
    } else if (_currentPageState == MembershipPageState.contractList) {
      setState(() {
        _currentPageState = MembershipPageState.typeSelection;
        _selectedMembershipType = null;
      });
    }
  }
  
  // AppBar 제목 가져오기
  String _getAppBarTitle() {
    switch (_currentPageState) {
      case MembershipPageState.typeSelection:
        return '회원권 선택';
      case MembershipPageState.contractList:
        return _selectedMembershipType ?? '회원권 유형 선택';
      case MembershipPageState.contractSetup:
        return '회원권 설정';
    }
  }
  
  // AppBar 뒤로가기 버튼 표시 여부
  bool _shouldShowBackButton() {
    return _currentPageState != MembershipPageState.typeSelection;
  }

  // 회원권 유형 동적 로드
  Future<void> _loadMembershipTypes() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      print('회원권 유형 로드 시작 - v2_contracts 테이블에서 contract_type 조회');

      // v2_contracts 테이블에서 회원권 카테고리의 유효한 계약 조회 (금액이 0원 이상인 것만)
      final data = await ApiService.getData(
        table: 'v2_contracts',
        where: [
          {'field': 'contract_category', 'operator': '=', 'value': '회원권'},
          {'field': 'contract_status', 'operator': '=', 'value': '유효'},
          {'field': 'price', 'operator': '>', 'value': 0},
        ],
      );

      print('조회된 계약 수: ${data.length}개');

      // contract_type 추출 및 중복 제거
      final Set<String> typeSet = {};
      for (var contract in data) {
        final contractType = contract['contract_type']?.toString().trim();
        if (contractType != null && contractType.isNotEmpty) {
          typeSet.add(contractType);
        }
      }

      // 정렬
      final types = typeSet.toList()..sort();
      print('추출된 회원권 유형 (중복 제거 후): $types');

      setState(() {
        membershipTypes = types;
        isLoading = false;
      });
    } catch (e) {
      print('회원권 유형 로드 오류: $e');
      setState(() {
        errorMessage = '회원권 유형을 불러오는데 실패했습니다.';
        isLoading = false;
      });
    }
  }

  // 회원권 유형 선택 시 계약 목록 페이지로 전환
  void _onMembershipTypeSelected(String type) {
    setState(() {
      _selectedMembershipType = type;
      _currentPageState = MembershipPageState.contractList;
    });
  }
  
  // 계약 선택 시 설정 페이지로 전환
  void _onContractSelected(Map<String, dynamic> contract) {
    setState(() {
      _selectedContract = contract;
      _currentPageState = MembershipPageState.contractSetup;
    });
  }
  
  // 계약 설정 완료 후 초기화
  void _onContractSetupComplete() {
    setState(() {
      _currentPageState = MembershipPageState.typeSelection;
      _selectedMembershipType = null;
      _selectedContract = null;
    });
  }

  // 회원권 유형 타일 빌드
  Widget _buildMembershipTypeTile(String type) {
    // 타입별 아이콘 매핑
    IconData icon = Icons.card_membership;
    Color color = Color(0xFF3B82F6);

    if (type.contains('크레딧') || type.contains('선불')) {
      icon = Icons.account_balance_wallet;
      color = Color(0xFF8B5CF6);
    } else if (type.contains('레슨')) {
      icon = Icons.school;
      color = Color(0xFF10B981);
    } else if (type.contains('게임') || type.contains('스크린')) {
      icon = Icons.sports_esports;
      color = Color(0xFFF59E0B);
    } else if (type.contains('기간') || type.contains('정기')) {
      icon = Icons.calendar_month;
      color = Color(0xFF06B6D4);
    }

    return GestureDetector(
      onTap: () => _onMembershipTypeSelected(type),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: color,
              ),
            ),
            SizedBox(height: 12),
            Text(
              type,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 현재 페이지의 body 위젯 빌드
  Widget _buildCurrentPageBody() {
    switch (_currentPageState) {
      case MembershipPageState.typeSelection:
        if (isLoading) {
          return Center(
            child: TileDesignService.buildLoading(
              title: '회원권 로딩',
              message: '회원권 유형을 불러오는 중...',
            ),
          );
        }
        
        if (errorMessage != null) {
          return Center(
            child: TileDesignService.buildError(
              errorMessage: errorMessage!,
              onRetry: _loadMembershipTypes,
            ),
          );
        }
        
        if (membershipTypes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Color(0xFF9CA3AF),
                ),
                SizedBox(height: 16),
                Text(
                  '판매중인 회원권이 없습니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }
        
        return Padding(
          padding: EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: membershipTypes.length,
            itemBuilder: (context, index) {
              return _buildMembershipTypeTile(membershipTypes[index]);
            },
          ),
        );
        
      case MembershipPageState.contractList:
        return ContractListPageContent(
          membershipType: _selectedMembershipType!,
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          onContractSelected: _onContractSelected,
        );
        
      case MembershipPageState.contractSetup:
        return ContractSetupPageContent(
          contract: _selectedContract!,
          membershipType: _selectedMembershipType!,
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
          onComplete: _onContractSetupComplete,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabDesignService.backgroundColor,
      appBar: TabDesignService.buildAppBar(
        title: _getAppBarTitle(),
        leading: _shouldShowBackButton()
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
      ),
      body: _buildCurrentPageBody(),
      // MainPage의 body 안에 있으므로 네비게이션 바는 MainPage에서 관리
      // bottomNavigationBar는 제거 (MainPage에 이미 있음)
    );
  }
}
