import 'package:flutter/material.dart';
import 'main_page.dart';
import 'services/api_service.dart';

class LoginGroupMasterOptionPage extends StatefulWidget {
  final Map<String, dynamic> memberData;
  final Map<String, dynamic> branchData;
  final String branchId;

  const LoginGroupMasterOptionPage({
    Key? key,
    required this.memberData,
    required this.branchData,
    required this.branchId,
  }) : super(key: key);

  @override
  _LoginGroupMasterOptionPageState createState() => _LoginGroupMasterOptionPageState();
}

class _LoginGroupMasterOptionPageState extends State<LoginGroupMasterOptionPage> 
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _groupMembers = [];
  bool _isLoading = false;
  
  // 테마 컬러
  static const Color _primaryColor = Color(0xFF00704A);

  // 애니메이션 컨트롤러
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadGroupMembers();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
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

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupMembers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentMemberPhone = widget.memberData['member_phone']?.toString();
      if (currentMemberPhone == null) {
        throw Exception('회원 전화번호 정보가 없습니다.');
      }

      print('현재 로그인한 회원 전화번호: $currentMemberPhone');
      
      // v2_group 테이블에서 _is_master 컬럼에 현재 회원 번호가 있는 데이터 조회
      final response = await ApiService.getData(
        table: 'v2_group',
        where: [
          {
            'field': '_is_master',
            'operator': '=', 
            'value': widget.memberData['member_id']?.toString() ?? '',
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': widget.branchId,
          }
        ],
      );

      print('v2_group 조회 결과: $response');
      
      if (response.isNotEmpty) {
        final List<Map<String, dynamic>> groupData = response;
        
        // 본인 계정과 관련 계정들 모두 포함
        List<Map<String, dynamic>> allAccounts = [];
        Set<String> addedMemberIds = {};
        
        // 본인 계정 추가 (제일 위에)
        final currentMemberId = widget.memberData['member_id']?.toString();
        allAccounts.add({
          'member_id': widget.memberData['member_id'],
          'member_name': widget.memberData['member_name'],
          'member_phone': widget.memberData['member_phone'],
          'member_type': widget.memberData['member_type'],
          'relation': '본인',
          'is_master': true,
        });
        addedMemberIds.add(currentMemberId ?? '');
        
        // 관련 계정들 추가
        for (var group in groupData) {
          final groupMemberId = group['member_id']?.toString();
          final relatedMemberId = group['related_member_id']?.toString();
          final relatedMemberName = group['related_member_name']?.toString();
          final relatedMemberPhone = group['related_member_phone']?.toString();
          
          // 현재 마스터가 아닌 계정만 추가 (related_member)
          if (relatedMemberId != null && 
              relatedMemberName != null && 
              relatedMemberId != currentMemberId &&
              !addedMemberIds.contains(relatedMemberId)) {
            
            // 본인(마스터) 입장에서 관련 회원과의 관계 찾기
            // member_id = 본인이고 related_member_id = 관련회원인 레코드의 relation
            String relationForRelated = '관련';
            for (var groupRecord in groupData) {
              if (groupRecord['member_id']?.toString() == currentMemberId &&
                  groupRecord['related_member_id']?.toString() == relatedMemberId) {
                relationForRelated = groupRecord['relation']?.toString() ?? '관련';
                break;
              }
            }
            
            // 관련 회원의 상세 정보 조회 (member_type 등)
            final memberDetailResponse = await ApiService.getData(
              table: 'v3_members',
              where: [
                {
                  'field': 'member_id',
                  'operator': '=',
                  'value': relatedMemberId,
                },
                {
                  'field': 'branch_id',
                  'operator': '=',
                  'value': widget.branchId,
                }
              ],
            );
            
            String memberType = '일반';
            if (memberDetailResponse.isNotEmpty) {
              memberType = memberDetailResponse[0]['member_type']?.toString() ?? '일반';
            }
            
            allAccounts.add({
              'member_id': relatedMemberId,
              'member_name': relatedMemberName,
              'member_phone': relatedMemberPhone,
              'member_type': memberType,
              'relation': relationForRelated,
              'is_master': false,
            });
            
            addedMemberIds.add(relatedMemberId);
          }
        }
        
        setState(() {
          _groupMembers = allAccounts;
          _isLoading = false;
        });
        
      } else {
        // 그룹 멤버가 없으면 본인 계정만 표시하고 바로 로그인 진행
        _proceedWithSingleAccount();
      }
      
    } catch (e) {
      print('그룹 멤버 조회 오류: $e');
      setState(() {
        _isLoading = false;
      });
      
      // 오류 발생 시 본인 계정으로 바로 진행
      _proceedWithSingleAccount();
    }
  }

  void _proceedWithSingleAccount() {
    // 그룹 멤버가 없거나 오류 발생 시 본인 계정으로 바로 로그인 진행
    ApiService.setCurrentUser(widget.memberData);
    ApiService.setCurrentBranch(widget.branchId, widget.branchData);
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MainPage(
          isAdminMode: false,
          selectedMember: widget.memberData,
          branchId: widget.branchId,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: Duration(milliseconds: 300),
      ),
    );
  }

  void _selectAccount(Map<String, dynamic> selectedAccount) {
    final memberName = selectedAccount['member_name']?.toString() ?? '사용자';
    final relation = selectedAccount['relation']?.toString() ?? '';
    
    String message;
    if (selectedAccount['is_master'] == true) {
      message = '본인 계정($memberName)으로 로그인하시겠습니까?';
    } else {
      message = '$relation 계정($memberName)으로 로그인하시겠습니까?';
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person, color: _primaryColor, size: 24),
            ),
            SizedBox(width: 12),
            Text('계정 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 15, color: Color(0xFF4A5568)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Color(0xFF718096))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedWithSelectedAccount(selectedAccount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('로그인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _proceedWithSelectedAccount(Map<String, dynamic> selectedAccount) async {
    try {
      // 선택된 계정의 전체 정보 조회
      Map<String, dynamic> fullMemberData;
      
      if (selectedAccount['is_master'] == true) {
        // 본인 계정인 경우 기존 데이터 사용
        fullMemberData = widget.memberData;
      } else {
        // 관련 계정인 경우 전체 정보 다시 조회
        final memberDetailResponse = await ApiService.getData(
          table: 'v3_members',
          where: [
            {
              'field': 'member_id',
              'operator': '=',
              'value': selectedAccount['member_id']?.toString(),
            },
            {
              'field': 'branch_id',
              'operator': '=',
              'value': widget.branchId,
            }
          ],
        );
        
        if (memberDetailResponse.isNotEmpty) {
          fullMemberData = memberDetailResponse[0];
        } else {
          throw Exception('선택된 계정의 정보를 불러올 수 없습니다.');
        }
      }
      
      // ApiService에 선택된 사용자 및 지점 설정
      ApiService.setCurrentUser(fullMemberData);
      ApiService.setCurrentBranch(widget.branchId, widget.branchData);
      
      print('선택된 계정으로 로그인: ${fullMemberData['member_name']} (${fullMemberData['member_id']})');
      
      // 메인 페이지로 이동
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => MainPage(
            isAdminMode: false,
            selectedMember: fullMemberData,
            branchId: widget.branchId,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: Duration(milliseconds: 300),
        ),
      );
      
    } catch (e) {
      print('계정 로그인 처리 오류: $e');
      _showErrorSnackBar('선택한 계정으로 로그인하는 중 오류가 발생했습니다: $e');
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 4),
      ),
    );
  }

  // 관계에 따른 색상
  Color _getRelationColor(String relation, bool isMaster) {
    if (isMaster) return _primaryColor;
    
    switch (relation) {
      case '부':
      case '모':
      case '부모':
        return Color(0xFF8E24AA);
      case '자녀':
        return Color(0xFFFF7043);
      case '가족':
        return Color(0xFF1565C0);
      default:
        return Color(0xFF546E7A);
    }
  }

  // 관계에 따른 아이콘
  IconData _getRelationIcon(String relation, bool isMaster) {
    if (isMaster) return Icons.person;
    
    switch (relation) {
      case '부':
      case '모':
      case '부모':
        return Icons.elderly;
      case '자녀':
        return Icons.child_care;
      case '가족':
        return Icons.family_restroom;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberName = widget.memberData['member_name']?.toString() ?? '사용자';
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '계정 선택',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _primaryColor))
            : CustomScrollView(
                slivers: [
                  // 안내 메시지
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.all(20),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primaryColor.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: _primaryColor, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '$memberName님, 로그인할 계정을 선택해주세요.',
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 본인 계정 섹션
                  SliverToBoxAdapter(
                    child: _buildSectionHeader('본인 계정', _primaryColor, 1),
                  ),
                  
                  if (_groupMembers.isNotEmpty && _groupMembers[0]['is_master'] == true)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: _buildAccountCard(_groupMembers[0]),
                      ),
                    ),

                  // 대리 예약 가능 계정 섹션
                  if (_groupMembers.length > 1) ...[
                    SliverToBoxAdapter(
                      child: _buildSectionHeader(
                        '대리 예약 가능한 계정', 
                        Colors.orange, 
                        _groupMembers.length - 1,
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildAccountCard(_groupMembers[index + 1]),
                          childCount: _groupMembers.length - 1,
                        ),
                      ),
                    ),
                  ],

                  // 하단 여백
                  SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey[900],
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
    final memberName = account['member_name']?.toString() ?? '사용자';
    final memberPhone = account['member_phone']?.toString() ?? '';
    final memberType = account['member_type']?.toString() ?? '일반';
    final relation = account['relation']?.toString() ?? '';
    final isMaster = account['is_master'] == true;
    
    final relationColor = _getRelationColor(relation, isMaster);
    final relationIcon = _getRelationIcon(relation, isMaster);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectAccount(account),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 아이콘 영역
                Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: relationColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: relationColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        relationIcon,
                        size: 24,
                        color: relationColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        relation,
                        style: TextStyle(
                          fontSize: 10,
                          color: relationColor,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // 정보 영역
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이름 + 회원 유형 (나란히)
                      Row(
                        children: [
                          Text(
                            memberName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 회원 유형 배지
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: relationColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: relationColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              memberType,
                              style: TextStyle(
                                fontSize: 11,
                                color: relationColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (memberPhone.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              memberPhone,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // 화살표
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
