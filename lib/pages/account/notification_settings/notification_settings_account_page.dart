import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isLoading = true;
  String _deviceMode = '확인 중...';
  
  @override
  void initState() {
    super.initState();
    _checkDeviceMode();
  }
  
  Future<void> _checkDeviceMode() async {
    try {
      const platform = MethodChannel('com.enabletech.autogolfcrm/notification');
      final mode = await platform.invokeMethod<String>('getRingerMode');
      setState(() {
        _deviceMode = mode ?? '알 수 없음';
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 기기 모드 확인 실패: $e');
      setState(() {
        _deviceMode = '확인 불가';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _openNotificationSettings() async {
    try {
      // Android 시스템 알림 설정으로 이동
      const platform = MethodChannel('com.enabletech.autogolfcrm/notification');
      await platform.invokeMethod('openNotificationSettings');
    } catch (e) {
      print('❌ 알림 설정 열기 실패: $e');
      // 대체 방법: 앱 정보 페이지로 이동
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
      color: Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // 헤더
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(
                    Icons.notifications,
                    color: Color(0xFF6B73FF),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    '채팅 알림 설정',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            
            // 시스템 설정으로 이동 버튼
            Container(
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
              child: ListTile(
                leading: Icon(
                  Icons.settings,
                  color: Color(0xFF6B73FF),
                  size: 24,
                ),
                title: Text(
                  '알림 설정 열기',
                  style: TextStyle(
                    fontSize: 16,
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
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Icon(
                    Icons.phone_android,
                    color: Color(0xFF6B73FF),
                    size: 20,
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
                          _deviceMode,
                          style: TextStyle(
                            fontSize: 16,
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
            SizedBox(height: 24),
            
            // 안내 문구
            Container(
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
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '알림 설정 안내',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B73FF),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '알림 소리, 진동 등은 Android 시스템 설정에서 관리됩니다.\n'
                          '위의 "알림 설정 열기" 버튼을 눌러 시스템 설정으로 이동하세요.\n\n'
                          '• 무음 모드: 알림이 재생되지 않습니다\n'
                          '• 진동 모드: 진동만 재생됩니다\n'
                          '• 벨소리 모드: 소리와 진동이 재생됩니다',
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
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

