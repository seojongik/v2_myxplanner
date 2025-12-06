import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';

/// 알리고 SMS 인증 서비스 (카페24 프록시 경유)
class AligoSmsService extends ChangeNotifier {
  String? _currentPhoneNumber;
  String? _currentMemberId;
  bool _isCodeSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  bool get isCodeSent => _isCodeSent;
  bool get isLoading => _isLoading;
  String? get currentPhoneNumber => _currentPhoneNumber;
  String? get errorMessage => _errorMessage;
  
  // 카페24 프록시 URL
  static const String _cafe24BaseUrl = 'https://golfcrm.mycafe24.com/sms';
  static const String _proxySecret = 'golfcrm_aligo_2024!';
  
  String get _sendCodeUrl => '$_cafe24BaseUrl/send_code.php';
  String get _verifyCodeUrl => '$_cafe24BaseUrl/verify_code.php';
  
  // 관리자 권한 확인
  bool _isAdminUser(Map<String, dynamic> user) {
    final memberType = user['member_type']?.toString().toLowerCase();
    return memberType == 'admin' || 
           memberType == '관리자' || 
           memberType == 'administrator' ||
           memberType == 'staff' ||
           memberType == '스태프';
  }
  
  // 전화번호 포맷 정리 (010-1234-5678 형태로 통일)
  String _formatPhoneNumber(String phoneNumber) {
    String digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digits.startsWith('82') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    } else if (digits.startsWith('10') && digits.length == 10) {
      digits = '0$digits';
    }
    
    if (digits.length == 11 && digits.startsWith('010')) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    
    throw Exception('올바른 전화번호 형식이 아닙니다.');
  }
  
  /// 1단계: 전화번호 유효성 검사 및 SMS 발송
  Future<bool> sendSMSVerification(String phoneNumber) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      // 관리자 권한 확인 - 관리자는 SMS 인증 스킵
      final currentUser = ApiService.getCurrentUser();
      if (currentUser != null && _isAdminUser(currentUser)) {
        print('🔑 관리자 계정 감지 - SMS 인증 스킵');
        _isCodeSent = true;
        _currentPhoneNumber = _formatPhoneNumber(phoneNumber);
        _currentMemberId = currentUser['member_id'].toString();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      // 전화번호 포맷 정리
      final formattedPhone = _formatPhoneNumber(phoneNumber);
      print('📱 포맷된 전화번호: $formattedPhone');
      
      // v3_members 테이블에서 전화번호 존재 확인
      final members = await ApiService.getData(
        table: 'v3_members',
        where: [
          {'field': 'member_phone', 'operator': '=', 'value': formattedPhone}
        ],
        fields: ['member_id', 'member_name', 'member_phone', 'branch_id'],
        limit: 1,
      );
      
      if (members.isEmpty) {
        throw Exception('등록되지 않은 전화번호입니다.\n관리자에게 문의하세요.');
      }
      
      print('✅ 등록된 회원 확인: ${members.first}');
      _currentMemberId = members.first['member_id'].toString();
      _currentPhoneNumber = formattedPhone;
      
      // 카페24 프록시로 SMS 발송 요청
      print('📤 카페24 프록시로 SMS 발송 요청...');
      
      final response = await http.post(
        Uri.parse(_sendCodeUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Proxy-Secret': _proxySecret,
        },
        body: jsonEncode({
          'phone': formattedPhone,
        }),
      );
      
      final result = jsonDecode(response.body);
      print('📥 카페24 응답: $result');
      
      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'SMS 발송에 실패했습니다.');
      }
      
      _isCodeSent = true;
      _isLoading = false;
      notifyListeners();
      
      return true;
      
    } catch (e) {
      print('❌ SMS 발송 오류: $e');
      _isCodeSent = false;
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }
  
  /// 2단계: SMS 코드 검증
  Future<bool> verifySMSCode(String smsCode) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      if (_currentPhoneNumber == null || _currentMemberId == null) {
        throw Exception('인증 정보가 없습니다. 다시 시도해주세요.');
      }
      
      // 관리자 바이패스
      final currentUser = ApiService.getCurrentUser();
      if (currentUser != null && _isAdminUser(currentUser)) {
        if (smsCode.trim() == '000000') {
          print('🔑 관리자 권한으로 인증 성공');
          await _updatePhoneAuthStatus(_currentPhoneNumber!);
          _reset();
          return true;
        }
        throw Exception('관리자 인증번호(000000)를 입력하세요.');
      }
      
      print('🔐 인증번호 검증 시작: $smsCode');
      
      // 카페24 프록시로 코드 검증 요청
      final response = await http.post(
        Uri.parse(_verifyCodeUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Proxy-Secret': _proxySecret,
        },
        body: jsonEncode({
          'phone': _currentPhoneNumber,
          'code': smsCode.trim(),
        }),
      );
      
      final result = jsonDecode(response.body);
      print('📥 검증 응답: $result');
      
      if (result['success'] != true) {
        throw Exception(result['error'] ?? '인증에 실패했습니다.');
      }
      
      print('✅ SMS 인증 성공! Supabase 업데이트 중...');
      
      // 인증 성공 시 Supabase v3_members 업데이트
      await _updatePhoneAuthStatus(_currentPhoneNumber!);
      
      _reset();
      return true;
      
    } catch (e) {
      print('❌ SMS 코드 검증 오류: $e');
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }
  
  /// v3_members 테이블에 인증 상태 업데이트
  Future<void> _updatePhoneAuthStatus(String phoneNumber) async {
    try {
      print('🔄 Supabase 인증 상태 업데이트 시작 - phone: $phoneNumber');
      
      final result = await ApiService.updateData(
        table: 'v3_members',
        data: {
          'member_phone_auth': 'success',
          'member_phone_auth_timestamp': DateTime.now().toIso8601String(),
        },
        where: [
          {'field': 'member_phone', 'operator': '=', 'value': phoneNumber}
        ],
      );
      
      if (result['success'] == true) {
        print('✅ Supabase 인증 상태 업데이트 성공');
      } else {
        print('❌ Supabase 인증 상태 업데이트 실패: ${result['error']}');
      }
    } catch (e) {
      print('💥 Supabase 인증 상태 업데이트 오류: $e');
    }
  }
  
  /// 상태 초기화
  void _reset() {
    _currentPhoneNumber = null;
    _currentMemberId = null;
    _isCodeSent = false;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
  
  /// 다시 시도
  void resetForRetry() {
    _reset();
  }
  
  /// 회원의 인증 상태 확인 (전화번호 기준)
  static Future<bool> isPhoneVerified(String phoneNumber) async {
    try {
      String formattedPhone = phoneNumber;
      if (!phoneNumber.contains('-')) {
        formattedPhone = '${phoneNumber.substring(0, 3)}-${phoneNumber.substring(3, 7)}-${phoneNumber.substring(7)}';
      }
      
      final members = await ApiService.getData(
        table: 'v3_members',
        where: [
          {'field': 'member_phone', 'operator': '=', 'value': formattedPhone}
        ],
        fields: ['member_phone_auth'],
        limit: 1,
      );
      
      if (members.isNotEmpty) {
        return members.first['member_phone_auth']?.toString() == 'success';
      }
      return false;
    } catch (e) {
      print('인증 상태 확인 오류: $e');
      return false;
    }
  }
}
