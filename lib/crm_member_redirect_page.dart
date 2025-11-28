import 'package:flutter/material.dart';
import '../stubs/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'services/api_service.dart';
import 'services/supabase_adapter.dart';
import 'main_page.dart';

/// CRM에서 회원 페이지 예약앱 버튼 클릭 시 리다이렉트 처리
class CrmMemberRedirectPage extends StatefulWidget {
  final String? branchId;
  final String? memberId;
  final bool? isAdminMode;

  const CrmMemberRedirectPage({
    Key? key,
    this.branchId,
    this.memberId,
    this.isAdminMode,
  }) : super(key: key);

  @override
  _CrmMemberRedirectPageState createState() => _CrmMemberRedirectPageState();
}

class _CrmMemberRedirectPageState extends State<CrmMemberRedirectPage> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMemberAndRedirect();
  }

  Future<void> _loadMemberAndRedirect() async {
    try {
      print('🔄 CRM 회원 리다이렉트 시작');

      // Supabase 초기화 확인 및 수행
      if (ApiService.useSupabase) {
        try {
          print('🔄 Supabase 초기화 확인 중...');
          await SupabaseAdapter.initialize();
          print('✅ Supabase 초기화 완료');
        } catch (e) {
          print('❌ Supabase 초기화 실패: $e');
          setState(() {
            _errorMessage = 'Supabase 초기화 실패: $e';
            _isLoading = false;
          });
          return;
        }
      }

      // URL에서 파라미터 추출
      final uri = Uri.parse(html.window.location.href);
      final queryParams = uri.queryParameters;

      String? branchId = widget.branchId ?? queryParams['branchId'];
      String? memberId = widget.memberId ?? queryParams['memberId'];
      bool isAdminMode = widget.isAdminMode ?? (queryParams['isAdminMode'] == 'true');

      print('🔄 URL 파라미터: $queryParams');
      print('🔄 지점 ID: $branchId');
      print('🔄 회원 ID: $memberId');
      print('🔄 관리자 모드: $isAdminMode');

      if (branchId == null || memberId == null) {
        setState(() {
          _errorMessage = '필수 파라미터가 누락되었습니다.';
          _isLoading = false;
        });
        return;
      }

      // 1. 지점 정보 로드
      final branchData = await ApiService.getData(
        table: 'v2_branches',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId}
        ],
      );

      if (branchData.isEmpty) {
        setState(() {
          _errorMessage = '지점 정보를 찾을 수 없습니다.';
          _isLoading = false;
        });
        return;
      }

      // 2. 회원 정보 로드
      final memberData = await ApiService.getMemberById(memberId);

      if (memberData == null) {
        setState(() {
          _errorMessage = '회원 정보를 찾을 수 없습니다.';
          _isLoading = false;
        });
        return;
      }

      // 3. ApiService에 현재 사용자 및 지점 설정
      ApiService.setCurrentUser(memberData, isAdminLogin: isAdminMode);
      ApiService.setCurrentBranch(branchId, branchData[0]);

      print('✅ 회원 및 지점 정보 설정 완료');
      print('✅ 회원: ${memberData['member_name']}');
      print('✅ 지점: ${branchData[0]['branch_name']}');

      // 4. MainPage로 이동
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainPage(
              isAdminMode: isAdminMode,
              selectedMember: memberData,
              branchId: branchId,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ 리다이렉트 오류: $e');
      setState(() {
        _errorMessage = '회원 정보를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '회원 정보를 불러오는 중...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              )
            : Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    SizedBox(height: 24),
                    Text(
                      '오류가 발생했습니다',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      _errorMessage ?? '알 수 없는 오류',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text('돌아가기'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
