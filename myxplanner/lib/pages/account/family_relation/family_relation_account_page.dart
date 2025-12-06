import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class FamilyRelationAccountPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const FamilyRelationAccountPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _FamilyRelationAccountPageState createState() => _FamilyRelationAccountPageState();
}

class _FamilyRelationAccountPageState extends State<FamilyRelationAccountPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('관계 관리'),
        backgroundColor: Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: FamilyRelationAccountContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

// 임베드 가능한 관계관리 콘텐츠 위젯
class FamilyRelationAccountContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const FamilyRelationAccountContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _FamilyRelationAccountContentState createState() => _FamilyRelationAccountContentState();
}

class _FamilyRelationAccountContentState extends State<FamilyRelationAccountContent> {
  bool _isLoading = false;
  bool _hasLoadedData = false;
  
  // 내가 마스터인 그룹 (내가 예약권한을 가진 회원들)
  List<Map<String, dynamic>> _myGroupMembers = [];
  
  // 나를 관리하는 마스터들 (나의 예약권한을 가진 회원들)
  List<Map<String, dynamic>> _myMasters = [];
  
  // 현재 회원 정보
  Map<String, dynamic>? _currentMember;
  String? _currentMemberId;
  String? _branchId;

  // 테마 컬러
  static const Color _primaryColor = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedData) {
      _hasLoadedData = true;
      _loadRelationData();
    }
  }

  Future<void> _loadRelationData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 회원 정보 가져오기
      _currentMember = widget.selectedMember ?? ApiService.getCurrentUser();
      _currentMemberId = _currentMember?['member_id']?.toString();
      _branchId = widget.branchId ?? ApiService.getCurrentBranchId();

      if (_currentMemberId == null || _branchId == null) {
        throw Exception('회원 정보가 없습니다');
      }

      print('📍 관계 정보 조회 - member_id: $_currentMemberId, branch_id: $_branchId');

      // 1. 내가 마스터인 그룹 조회 (내가 예약권한을 가진 회원들)
      final myGroupResponse = await ApiService.getData(
        table: 'v2_group',
        where: [
          {'field': '_is_master', 'operator': '=', 'value': _currentMemberId},
          {'field': 'branch_id', 'operator': '=', 'value': _branchId},
        ],
      );

      print('내가 마스터인 그룹: $myGroupResponse');

      // 중복 제거하고 나 자신은 제외
      Set<String> addedIds = {};
      List<Map<String, dynamic>> myGroupMembers = [];
      
      for (var group in myGroupResponse) {
        final relatedMemberId = group['related_member_id']?.toString();
        if (relatedMemberId != null && 
            relatedMemberId != _currentMemberId && 
            !addedIds.contains(relatedMemberId)) {
          myGroupMembers.add({
            'member_id': relatedMemberId,
            'member_name': group['related_member_name']?.toString() ?? '이름 없음',
            'member_phone': group['related_member_phone']?.toString() ?? '',
            'relation': group['relation']?.toString() ?? '관련',
            'member_type': group['member_type']?.toString() ?? '일반',
          });
          addedIds.add(relatedMemberId);
        }
      }

      // 2. 나를 관리하는 마스터 조회 (나의 예약권한을 가진 회원들)
      final myMastersResponse = await ApiService.getData(
        table: 'v2_group',
        where: [
          {'field': 'related_member_id', 'operator': '=', 'value': _currentMemberId},
          {'field': 'branch_id', 'operator': '=', 'value': _branchId},
        ],
      );

      print('나를 관리하는 마스터들: $myMastersResponse');

      Set<String> addedMasterIds = {};
      List<Map<String, dynamic>> myMasters = [];
      
      for (var group in myMastersResponse) {
        final masterId = group['_is_master']?.toString();
        final memberId = group['member_id']?.toString();
        
        if (masterId != null && 
            masterId != _currentMemberId && 
            memberId != null &&
            memberId == masterId &&
            !addedMasterIds.contains(masterId)) {
          myMasters.add({
            'member_id': masterId,
            'member_name': group['member_name']?.toString() ?? '이름 없음',
            'member_phone': group['member_phone']?.toString() ?? '',
            'relation': _getInverseRelation(group['relation']?.toString() ?? '관련'),
            'member_type': group['member_type']?.toString() ?? '일반',
          });
          addedMasterIds.add(masterId);
        }
      }

      if (!mounted) return;

      setState(() {
        _myGroupMembers = myGroupMembers;
        _myMasters = myMasters;
        _isLoading = false;
      });

    } catch (e) {
      print('관계 정보 조회 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('관계 정보를 불러오는 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 관계 역전환
  String _getInverseRelation(String relation) {
    switch (relation) {
      case '부':
      case '모':
        return '부모';
      case '자녀':
        return '자녀';
      case '가족':
        return '가족';
      default:
        return relation;
    }
  }

  // 관계에 따른 색상
  Color _getRelationColor(String relation) {
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
  IconData _getRelationIcon(String relation) {
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
        return Icons.person;
    }
  }

  // 회원 상세 정보 다이얼로그
  void _showMemberDetailDialog(Map<String, dynamic> member, {bool isMaster = false}) {
    final memberName = member['member_name']?.toString() ?? '이름 없음';
    final memberPhone = member['member_phone']?.toString() ?? '전화번호 없음';
    final memberType = member['member_type']?.toString() ?? '일반';
    final relation = member['relation']?.toString() ?? '관련';
    final relationColor = _getRelationColor(relation);
    final relationIcon = _getRelationIcon(relation);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: relationColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(relationIcon, color: relationColor, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memberName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: relationColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: relationColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      relation,
                      style: TextStyle(
                        fontSize: 11,
                        color: relationColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow(Icons.phone, '전화번호', memberPhone),
            SizedBox(height: 12),
            _buildDetailRow(Icons.badge, '회원 유형', memberType),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMaster 
                    ? Colors.orange.withOpacity(0.1) 
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMaster 
                      ? Colors.orange.withOpacity(0.3) 
                      : Colors.green.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isMaster ? Icons.key : Icons.verified_user,
                    color: isMaster ? Colors.orange[700] : Colors.green[700],
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMaster 
                          ? '이 회원이 나의 예약을 대신할 수 있습니다'
                          : '내가 이 회원의 예약을 대신할 수 있습니다',
                      style: TextStyle(
                        color: isMaster ? Colors.orange[700] : Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.grey[600]),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
            Text(
              value.isNotEmpty ? value : '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, {bool isMaster = false}) {
    final memberName = member['member_name']?.toString() ?? '이름 없음';
    final memberPhone = member['member_phone']?.toString() ?? '';
    final memberType = member['member_type']?.toString() ?? '일반';
    final relation = member['relation']?.toString() ?? '관련';
    final relationColor = _getRelationColor(relation);
    final relationIcon = _getRelationIcon(relation);

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
          onTap: () => _showMemberDetailDialog(member, isMaster: isMaster),
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
                      const SizedBox(height: 6),
                      // 전화번호 + 권한 표시
                      Row(
                        children: [
                          if (memberPhone.isNotEmpty) ...[
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
                            const SizedBox(width: 12),
                          ],
                          // 권한 표시
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isMaster 
                                  ? Colors.orange[50] 
                                  : Colors.green[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isMaster ? '대리예약 가능' : '내가 대리',
                              style: TextStyle(
                                fontSize: 10,
                                color: isMaster 
                                    ? Colors.orange[700] 
                                    : Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildEmptyState(String title, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.grey[50],
      child: RefreshIndicator(
        onRefresh: () async {
          _hasLoadedData = false;
          await _loadRelationData();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 나의 예약권한을 가진 회원 섹션
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                '나의 예약을 대신할 수 있는 회원',
                Colors.orange,
                _myMasters.length,
              ),
            ),
            
            if (_myMasters.isEmpty)
              SliverToBoxAdapter(
                child: _buildEmptyState(
                  '대리 예약 가능한 회원이 없습니다',
                  '다른 회원이 나 대신 예약할 수 없습니다',
                  Icons.key_off,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildMemberCard(_myMasters[index], isMaster: true),
                    childCount: _myMasters.length,
                  ),
                ),
              ),

            // 내가 예약권한을 가진 회원 섹션
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                '내가 대리 예약할 수 있는 회원',
                Colors.green,
                _myGroupMembers.length,
              ),
            ),
            
            if (_myGroupMembers.isEmpty)
              SliverToBoxAdapter(
                child: _buildEmptyState(
                  '대리 예약 대상 회원이 없습니다',
                  '다른 회원의 예약을 대신할 수 없습니다',
                  Icons.person_off,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildMemberCard(_myGroupMembers[index], isMaster: false),
                    childCount: _myGroupMembers.length,
                  ),
                ),
              ),

            // 안내 메시지
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primaryColor.withOpacity(0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: _primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '관계 관리 안내',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _primaryColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '관계 추가/삭제는 관리자에게 문의해주세요.',
                            style: TextStyle(
                              color: _primaryColor.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 하단 여백
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }
}
