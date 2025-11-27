import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class MessageAgreementAccountPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const MessageAgreementAccountPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _MessageAgreementAccountPageState createState() => _MessageAgreementAccountPageState();
}

class _MessageAgreementAccountPageState extends State<MessageAgreementAccountPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('메시지 수신동의'),
        backgroundColor: Color(0xFF6B73FF),
        foregroundColor: Colors.white,
      ),
      body: MessageAgreementAccountContent(
        isAdminMode: widget.isAdminMode,
        selectedMember: widget.selectedMember,
        branchId: widget.branchId,
      ),
    );
  }
}

// 임베드 가능한 메시지 수신동의 콘텐츠 위젯
class MessageAgreementAccountContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const MessageAgreementAccountContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _MessageAgreementAccountContentState createState() => _MessageAgreementAccountContentState();
}

class _MessageAgreementAccountContentState extends State<MessageAgreementAccountContent> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _agreements = [];
  String? _currentMemberId;
  String? _currentBranchId;
  String? _memberName;

  // 메시지 타입별 기본 설정 (DB 구조에 맞춤)
  final List<Map<String, String>> _messageTypes = [
    {'key': '회원권 등록/취소', 'label': '회원권 등록/취소'},
    {'key': '크레딧 적립/차감', 'label': '크레딧 적립/차감'},
    {'key': '예약 접수/취소', 'label': '예약 접수/취소'},
    {'key': '그룹활동 초대', 'label': '그룹활동 초대'},
    {'key': '1:1메시지', 'label': '1:1메시지'},
    {'key': '할인권 등록/사용', 'label': '할인권 등록/사용'},
    {'key': '공지사항', 'label': '공지사항'},
    {'key': '일반안내', 'label': '일반안내'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAgreements();
  }

  Future<void> _loadAgreements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 사용자 정보 가져오기
      if (widget.isAdminMode && widget.selectedMember != null) {
        _currentMemberId = widget.selectedMember!['member_id']?.toString();
        _currentBranchId = widget.branchId;
        _memberName = widget.selectedMember!['name'];
      } else {
        final userData = ApiService.getCurrentUser();
        if (userData != null) {
          _currentMemberId = userData['member_id']?.toString();
          _currentBranchId = userData['branch_id'] ?? ApiService.getCurrentBranchId();
          _memberName = userData['name'];
        }
      }

      if (_currentMemberId != null && _currentBranchId != null) {
        // 기존 동의 내역 조회
        final response = await _apiService.getMessageAgreements(
          branchId: _currentBranchId!,
          memberId: _currentMemberId!,
        );

        if (response['success']) {
          _agreements = List<Map<String, dynamic>>.from(response['data'] ?? []);
          
          // 없는 메시지 타입은 기본값으로 추가
          await _initializeMissingAgreements();
        }
      }
    } catch (e) {
      print('메시지 수신동의 로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 로드 중 오류가 발생했습니다.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeMissingAgreements() async {
    if (_currentBranchId == null || _currentMemberId == null) {
      return;
    }
    
    final existingTypes = _agreements.map((a) => a['msg_type']).toSet();
    final memberName = _memberName ?? '회원';
    
    for (final msgType in _messageTypes) {
      if (!existingTypes.contains(msgType['key'])) {
        // 기본값으로 '수신거부' 설정
        await _apiService.createMessageAgreement(
          branchId: _currentBranchId!,
          memberId: _currentMemberId!,
          memberName: memberName,
          msgType: msgType['key']!,
          msgAgreement: '수신거부',
        );
      }
    }
    
    // 다시 로드
    final response = await _apiService.getMessageAgreements(
      branchId: _currentBranchId!,
      memberId: _currentMemberId!,
    );
    
    if (response['success']) {
      setState(() {
        _agreements = List<Map<String, dynamic>>.from(response['data'] ?? []);
      });
    }
  }

  Future<void> _updateAgreement(String msgType, bool isReceiving) async {
    try {
      final agreement = isReceiving ? '수신' : '수신거부';
      
      final response = await _apiService.updateMessageAgreement(
        branchId: _currentBranchId!,
        memberId: _currentMemberId!,
        msgType: msgType,
        msgAgreement: agreement,
      );

      if (response['success']) {
        // 로컬 상태 업데이트
        setState(() {
          final index = _agreements.indexWhere((a) => a['msg_type'] == msgType);
          if (index != -1) {
            _agreements[index]['push_agreement'] = agreement;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('설정이 저장되었습니다.'),
            backgroundColor: isReceiving ? Color(0xFF4CAF50) : Color(0xFF757575),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception(response['error'] ?? '업데이트 실패');
      }
    } catch (e) {
      print('메시지 수신동의 업데이트 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('설정 저장 중 오류가 발생했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Color(0xFFF8F9FA),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6B73FF),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: Color(0xFF6B73FF),
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  '활동별 메시지 수신 여부를 설정하세요',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _messageTypes.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Color(0xFFF0F0F0),
                indent: 20,
                endIndent: 20,
              ),
              itemBuilder: (context, index) {
                final msgType = _messageTypes[index];
                final agreement = _agreements.firstWhere(
                  (a) => a['msg_type'] == msgType['key'],
                  orElse: () => {'push_agreement': '수신거부'},
                );
                final isReceiving = agreement['push_agreement'] == '수신';
                
                return Container(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(
                      msgType['label']!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isReceiving ? '수신' : '수신거부',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isReceiving ? Color(0xFF4CAF50) : Color(0xFF9E9E9E),
                          ),
                        ),
                        SizedBox(width: 8),
                        Switch(
                          value: isReceiving,
                          onChanged: (value) => _updateAgreement(msgType['key']!, value),
                          activeColor: Color(0xFF4CAF50),
                          inactiveThumbColor: Color(0xFFBDBDBD),
                          inactiveTrackColor: Color(0xFFE0E0E0),
                        ),
                      ],
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}