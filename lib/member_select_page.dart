import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'main_page.dart';

/// 골프 플래너 앱 회원 선택 화면
class MemberSelectPage extends StatefulWidget {
  final String branchId;
  final Map<String, dynamic> branchData;

  const MemberSelectPage({
    Key? key,
    required this.branchId,
    required this.branchData,
  }) : super(key: key);

  @override
  _MemberSelectPageState createState() => _MemberSelectPageState();
}

class _MemberSelectPageState extends State<MemberSelectPage> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    print('🔍 [DEBUG] 검색어 입력: "$query"');
    print('🔍 [DEBUG] TextField 컨트롤러 텍스트: "${_searchController.text}"');
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_members);
      } else {
        _filteredMembers = _members.where((member) {
          final name = member['member_name']?.toString().toLowerCase() ?? '';
          final phone = member['member_phone']?.toString() ?? '';
          return name.contains(query) || phone.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);

    try {
      print('👥 회원 목록 로딩 중... branchId: ${widget.branchId}');
      final response = await ApiService.getData(
        table: 'v3_members',
        where: [
          {
            'field': 'branch_id',
            'operator': '=',
            'value': widget.branchId,
          }
        ],
        orderBy: [
          {'field': 'member_name', 'direction': 'ASC'}
        ],
      );

      print('👥 회원 목록 로딩 완료: ${response.length}명');

      setState(() {
        _members = response;
        _filteredMembers = response;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 회원 목록 로딩 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onMemberSelected(Map<String, dynamic> member) {
    print('👤 회원 선택: ${member['member_name']} (${member['member_id']})');

    // ApiService에 현재 사용자 및 지점 설정 (관리자 로그인으로 표시)
    ApiService.setCurrentUser(member, isAdminLogin: true);
    ApiService.setCurrentBranch(widget.branchId, widget.branchData);

    // MainPage로 이동
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => MainPage(
          isAdminMode: true,
          selectedMember: member,
          branchId: widget.branchId,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          '회원 선택',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Color(0xFF3B82F6), // 파란색 배경
        elevation: 0,
      ),
      body: Column(
        children: [
          // 검색 바
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xFF3B82F6),
            child: Theme(
              data: ThemeData(
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: Colors.black,
                ),
              ),
              child: Builder(
                builder: (context) {
                  print('🎨 [DEBUG] TextField 빌드 중');
                  return TextField(
                    controller: _searchController,
                    cursorColor: Colors.black,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF000000),
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                      decorationColor: Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: '이름 또는 전화번호로 검색',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, color: Color(0xFF3B82F6)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) {
                      print('🎨 [DEBUG] 입력된 텍스트: "$value"');
                      print('🎨 [DEBUG] 텍스트 길이: ${value.length}');
                    },
                  );
                },
              ),
            ),
          ),

          // 회원 목록
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              '회원이 없습니다',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredMembers.length,
                        separatorBuilder: (context, index) => SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildMemberCard(_filteredMembers[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final name = member['member_name']?.toString() ?? '이름 없음';
    final phone = member['member_phone']?.toString() ?? '';
    final memberType = member['member_type']?.toString() ?? '일반';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _onMemberSelected(member),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF3B82F6).withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            memberType,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (phone.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
