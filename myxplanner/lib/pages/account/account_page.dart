import 'package:flutter/material.dart';
import '../../services/tab_design_service.dart';
import '../../services/api_service.dart';
import 'profile/profile_account_page.dart';
import 'family_relation/family_relation_account_page.dart';
import 'policy/policy_account_page.dart';
import 'notification_settings/notification_settings_account_page.dart';

class AccountPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const AccountPage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final List<Map<String, dynamic>> accountTabs = [
    {
      'title': '개인정보',
      'type': 'profile',
      'icon': Icons.person,
      'color': Color(0xFFFF8C00),
    },
    {
      'title': '관계관리',
      'type': 'family_relation',
      'icon': Icons.family_restroom,
      'color': Color(0xFF2196F3),
    },
    {
      'title': '알림 설정',
      'type': 'notification_settings',
      'icon': Icons.notifications,
      'color': Color(0xFF6B73FF),
    },
    {
      'title': '약관 및 정책',
      'type': 'policy',
      'icon': Icons.article,
      'color': Color(0xFF9C27B0),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: accountTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 각 탭에 해당하는 위젯 생성
  Widget _buildTabContent(Map<String, dynamic> tab) {
    final String type = tab['type'];

    switch (type) {
      case 'profile':
        return ProfileAccountContent(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
        );

      case 'family_relation':
        return FamilyRelationAccountContent(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
        );

      case 'notification_settings':
        return NotificationSettingsAccountContent(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
        );

      case 'policy':
        return PolicyAccountContent(
          isAdminMode: widget.isAdminMode,
          selectedMember: widget.selectedMember,
          branchId: widget.branchId,
        );

      default:
        return Container(
          child: Center(
            child: Text('알 수 없는 탭입니다.'),
          ),
        );
    }
  }

  // 로그아웃 처리
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('로그아웃'),
          content: Text('정말 로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // 로그아웃 - 자동 로그인 정보도 함께 삭제
                await ApiService.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('로그아웃'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabDesignService.backgroundColor,
      appBar: TabDesignService.buildAppBar(
        title: '계정관리',
        showBranchHeader: false,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _handleLogout,
              icon: Icon(Icons.logout, size: 18),
              label: Text('로그아웃'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
        bottom: TabDesignService.buildUnderlineTabBar(
          controller: _tabController,
          tabs: accountTabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: accountTabs.map((tab) => _buildTabContent(tab)).toList(),
      ),
    );
  }
} 