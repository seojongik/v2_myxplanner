import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api_service.dart';

class NotificationSettingsAccountContent extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const NotificationSettingsAccountContent({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _NotificationSettingsAccountContentState createState() => _NotificationSettingsAccountContentState();
}

class _NotificationSettingsAccountContentState extends State<NotificationSettingsAccountContent> {
  final ApiService _apiService = ApiService();
  
  // 시스템 알림 관련
  bool _isLoadingDevice = true;
  String _deviceMode = '확인 중...';
  
  // 메시지 수신동의 관련
  bool _isLoadingAgreements = true;
  List<Map<String, dynamic>> _agreements = [];
  String? _currentMemberId;
  String? _currentBranchId;
  String? _memberName;

  // 메시지 타입별 설정
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
    _checkDeviceMode();
    _loadAgreements();
  }
  
  // ========== 시스템 알림 관련 메서드 ==========
  
  Future<void> _checkDeviceMode() async {
    try {
      const platform = MethodChannel('app.mygolfplanner/notification');
      final mode = await platform.invokeMethod<String>('getRingerMode');
      setState(() {
        _deviceMode = mode ?? '알 수 없음';
        _isLoadingDevice = false;
      });
    } catch (e) {
      print('❌ 기기 모드 확인 실패: $e');
      setState(() {
        _deviceMode = '확인 불가';
        _isLoadingDevice = false;
      });
    }
  }
  
  Future<void> _openNotificationSettings() async {
    try {
      const platform = MethodChannel('app.mygolfplanner/notification');
      await platform.invokeMethod('openNotificationSettings');
    } catch (e) {
      print('❌ 알림 설정 열기 실패: $e');
      try {
        final uri = Uri.parse('package:mygolfplanner.app');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } catch (e2) {
        print('❌ 앱 정보 페이지 열기 실패: $e2');
      }
    }
  }

  // ========== 푸쉬알림 수신동의 관련 메서드 ==========

  Future<void> _loadAgreements() async {
    setState(() {
      _isLoadingAgreements = true;
    });

    try {
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

      print('📱 푸쉬알림 수신동의 로드 - member_id: $_currentMemberId, branch_id: $_currentBranchId');

      if (_currentMemberId != null && _currentBranchId != null) {
        final response = await _apiService.getMessageAgreements(
          branchId: _currentBranchId!,
          memberId: _currentMemberId!,
        );

        if (response['success']) {
          _agreements = List<Map<String, dynamic>>.from(response['data'] ?? []);
          print('📱 기존 푸쉬알림 수신동의 데이터: ${_agreements.length}개');
          await _initializeMissingAgreements();
        }
      }
    } catch (e) {
      print('❌ 푸쉬알림 수신동의 로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 로드 중 오류가 발생했습니다.')),
      );
    } finally {
      setState(() {
        _isLoadingAgreements = false;
      });
    }
  }

  Future<void> _initializeMissingAgreements() async {
    if (_currentBranchId == null || _currentMemberId == null) {
      return;
    }
    
    final existingTypes = _agreements.map((a) => a['msg_type']).toSet();
    final memberName = _memberName ?? '회원';
    
    // 누락된 메시지 타입 확인
    final missingTypes = _messageTypes
        .where((m) => !existingTypes.contains(m['key']))
        .map((m) => m['key'])
        .toList();
    
    if (missingTypes.isNotEmpty) {
      print('📱 누락된 푸쉬알림 타입 ${missingTypes.length}개 생성: $missingTypes');
      
      for (final msgType in _messageTypes) {
        if (!existingTypes.contains(msgType['key'])) {
          // 처음 진입 시 기본값은 '수신'으로 설정
          await _apiService.createMessageAgreement(
            branchId: _currentBranchId!,
            memberId: _currentMemberId!,
            memberName: memberName,
            msgType: msgType['key']!,
            msgAgreement: '수신',
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
        print('📱 푸쉬알림 수신동의 초기화 완료: ${_agreements.length}개');
      }
    } else {
      print('📱 모든 푸쉬알림 타입 데이터 존재 - 초기화 불필요');
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
      print('푸쉬알림 수신동의 업데이트 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('설정 저장 중 오류가 발생했습니다.')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== 시스템 알림 설정 섹션 ==========
            _buildSectionHeader(
              icon: Icons.notifications,
              title: '시스템 알림 설정',
            ),
            SizedBox(height: 12),
            
            // 시스템 설정으로 이동 버튼
            _buildCard(
              child: ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF6B73FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.settings,
                    color: Color(0xFF6B73FF),
                    size: 20,
                  ),
                ),
                title: Text(
                  '알림 설정 열기',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                  ),
                ),
                subtitle: Text(
                  '시스템 설정에서 알림 소리, 진동 등을 관리하세요',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
                onTap: _openNotificationSettings,
              ),
            ),
            SizedBox(height: 12),
            
            // 현재 기기 모드 표시
            _buildCard(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFF6B73FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.phone_android,
                        color: Color(0xFF6B73FF),
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '현재 기기 모드',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _isLoadingDevice ? '확인 중...' : _deviceMode,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            
            // 안내 문구
            _buildInfoBox(
              title: '알림 설정 안내',
              content: '알림 소리, 진동 등은 Android 시스템 설정에서 관리됩니다.\n위의 "알림 설정 열기" 버튼을 눌러 시스템 설정으로 이동하세요.\n\n• 무음 모드: 알림이 재생되지 않습니다\n• 진동 모드: 진동만 재생됩니다\n• 벨소리 모드: 소리와 진동이 재생됩니다',
            ),
            SizedBox(height: 24),
            
            // ========== 푸쉬알림 수신동의 섹션 ==========
            _buildSectionHeader(
              icon: Icons.notifications_active,
              title: '푸쉬알림 수신 동의',
            ),
            SizedBox(height: 12),
            
            // 메시지 타입별 설정 리스트
            _buildCard(
              child: _isLoadingAgreements
                  ? Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6B73FF),
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Column(
                      children: _messageTypes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final msgType = entry.value;
                        final agreement = _agreements.firstWhere(
                          (a) => a['msg_type'] == msgType['key'],
                          orElse: () => {'push_agreement': '수신거부'},
                        );
                        final isReceiving = agreement['push_agreement'] == '수신';
                        
                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      msgType['label']!,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    isReceiving ? '수신' : '수신거부',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isReceiving ? Color(0xFF4CAF50) : Color(0xFF9E9E9E),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Transform.scale(
                                    scale: 0.85,
                                    child: Switch(
                                      value: isReceiving,
                                      onChanged: (value) => _updateAgreement(msgType['key']!, value),
                                      activeColor: Color(0xFF4CAF50),
                                      inactiveThumbColor: Color(0xFFBDBDBD),
                                      inactiveTrackColor: Color(0xFFE0E0E0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (index < _messageTypes.length - 1)
                              Divider(
                                height: 1,
                                color: Color(0xFFF0F0F0),
                                indent: 16,
                                endIndent: 16,
                              ),
                          ],
                        );
                      }).toList(),
                    ),
            ),
            SizedBox(height: 12),
            
            // 푸쉬알림 수신 안내
            _buildInfoBox(
              title: '푸쉬알림 수신 안내',
              content: '각 항목별로 푸쉬알림 수신 여부를 설정할 수 있습니다.\n수신거부로 설정하면 해당 유형의 알림을 받지 않습니다.',
            ),
            SizedBox(height: 100),  // 하단 네비게이션 바 여백
          ],
        ),
      ),
    );
  }

  // ========== UI 컴포넌트 빌더 ==========

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Color(0xFF6B73FF),
            size: 22,
          ),
          SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoBox({required String title, required String content}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF6B73FF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Color(0xFF6B73FF),
            size: 18,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B73FF),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
