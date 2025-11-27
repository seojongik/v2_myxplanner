import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';

class SmsAuthService extends ChangeNotifier {
  String? _currentPhoneNumber;
  String? _currentMemberId;
  String? _currentCode; // 메모리에 인증번호 저장
  DateTime? _codeExpiry; // 만료 시간
  bool _isCodeSent = false;
  bool _isLoading = false;
  
  bool get isCodeSent => _isCodeSent;
  bool get isLoading => _isLoading;
  String? get currentPhoneNumber => _currentPhoneNumber;
  
  // 관리자 권한 확인
  bool _isAdminUser(Map<String, dynamic> user) {
    final memberType = user['member_type']?.toString().toLowerCase();
    // 관리자 타입들 (실제 DB 데이터에 맞게 조정)
    return memberType == 'admin' || 
           memberType == '관리자' || 
           memberType == 'administrator' ||
           memberType == 'staff' ||
           memberType == '스태프';
  }
  
  // 전화번호 포맷 정리 (010-1234-5678 형태로 통일)
  String _formatPhoneNumber(String phoneNumber) {
    // 숫자만 추출
    String digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // 010으로 시작하는 11자리 번호로 변환
    if (digits.startsWith('82') && digits.length == 13) {
      // +82 10 1234 5678 -> 010-1234-5678
      digits = '0${digits.substring(2)}';
    } else if (digits.startsWith('10') && digits.length == 11) {
      // 10 1234 5678 -> 010-1234-5678
      digits = '0$digits';
    }
    
    // 010-1234-5678 형태로 포맷
    if (digits.length == 11 && digits.startsWith('010')) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    
    throw Exception('올바른 전화번호 형식이 아닙니다.');
  }
  
  // 1단계: 전화번호 유효성 검사 및 SMS 발송
  Future<bool> sendSMSVerification(String phoneNumber) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // 관리자 권한 확인 - 관리자는 SMS 인증 스킵
      final currentUser = ApiService.getCurrentUser();
      if (currentUser != null && _isAdminUser(currentUser)) {
        print('🔑 관리자 계정 감지 - SMS 인증 스킵');
        _isCodeSent = true;
        // 관리자용 더미 코드 설정 (즉시 인증 가능)
        _currentCode = '000000';
        _codeExpiry = DateTime.now().add(Duration(minutes: 60));
        _currentPhoneNumber = _formatPhoneNumber(phoneNumber);
        _currentMemberId = currentUser['member_id'].toString();
        notifyListeners();
        return true;
      }
      
      // 전화번호 포맷 정리
      final formattedPhone = _formatPhoneNumber(phoneNumber);
      print('포맷된 전화번호: $formattedPhone');
      
      // v3_members 테이블에서 전화번호 존재 확인 (지점 무관)
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
      
      print('등록된 회원 확인: ${members.first}');
      _currentMemberId = members.first['member_id'].toString();
      
      // 6자리 랜덤 인증번호 생성
      final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
      
      // 메모리에 저장 (5분 만료)
      _currentCode = code;
      _codeExpiry = DateTime.now().add(Duration(minutes: 5));
      _currentPhoneNumber = formattedPhone;
      
      // 서버를 통해 실제 SMS 발송
      final message = '[MyGolfPlanner] 인증번호: $code (5분간 유효)';
      try {
        await ApiService.sendSMS(
          phoneNumber: formattedPhone,
          message: message,
        );
        print('✅ SMS 발송 성공: $formattedPhone');
      } catch (e) {
        print('❌ SMS 발송 실패: $e');
        // 백업용 콘솔 출력
        print('📱 [개발용 백업] SMS 발송: [$formattedPhone] 인증번호: $code');
      }
      
      _isCodeSent = true;
      notifyListeners();
      return true;
      
    } catch (e) {
      print('SMS 발송 오류: $e');
      _isCodeSent = false;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 2단계: SMS 코드 검증
  Future<bool> verifySMSCode(String smsCode) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      if (_currentPhoneNumber == null || _currentMemberId == null || _currentCode == null || _codeExpiry == null) {
        throw Exception('인증 정보가 없습니다. 다시 시도해주세요.');
      }
      
      // 관리자 권한 확인 - 관리자는 000000으로 즉시 인증
      final currentUser = ApiService.getCurrentUser();
      if (currentUser != null && _isAdminUser(currentUser)) {
        if (smsCode.trim() == '000000') {
          print('🔑 관리자 권한으로 인증 성공');
          await _updatePhoneAuthStatus(_currentMemberId!);
          _reset();
          return true;
        }
      }
      
      // 만료 시간 확인
      if (DateTime.now().isAfter(_codeExpiry!)) {
        throw Exception('인증번호가 만료되었습니다. 다시 시도해주세요.');
      }
      
      // 인증번호 비교
      if (smsCode.trim() != _currentCode) {
        throw Exception('인증번호가 올바르지 않습니다.');
      }
      
      print('SMS 인증 성공');
      
      // v3_members 테이블에 인증 상태 업데이트
      await _updatePhoneAuthStatus(_currentMemberId!);
      
      _reset();
      return true;
      
    } catch (e) {
      print('SMS 코드 검증 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // v3_members 테이블에 인증 상태 업데이트 (전체 지점)
  Future<void> _updatePhoneAuthStatus(String memberId) async {
    try {
      print('🔄 전체 지점 인증 상태 업데이트 시작 - memberId: $memberId');
      
      // 현재 사용자의 전화번호로 전체 지점의 계정 조회
      final currentUser = ApiService.getCurrentUser();
      final phoneNumber = currentUser?['member_phone'];
      
      if (phoneNumber == null) {
        throw Exception('전화번호 정보가 없습니다.');
      }
      
      print('📞 전화번호: $phoneNumber로 전체 계정 업데이트');
      
      // 전화번호가 동일한 모든 계정의 인증 상태 업데이트 (지점 무관)
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
      
      print('📊 API 업데이트 결과: $result');
      
      if (result['success'] == true) {
        print('✅ 전체 지점 전화번호 인증 상태 업데이트 성공');
        print('영향받은 행 수: ${result['affectedRows']}');
        
        // 실제로 업데이트되었는지 다시 조회해서 확인 (전체 지점)
        final updatedMembers = await ApiService.getData(
          table: 'v3_members',
          where: [
            {'field': 'member_phone', 'operator': '=', 'value': phoneNumber}
          ],
          fields: ['member_id', 'branch_id', 'member_phone_auth', 'member_phone_auth_timestamp'],
        );
        print('🔍 업데이트 후 전체 계정 확인: $updatedMembers');
      } else {
        print('❌ 전화번호 인증 상태 업데이트 실패: ${result['error']}');
        throw Exception('인증 상태 저장에 실패했습니다: ${result['error']}');
      }
    } catch (e) {
      print('💥 인증 상태 업데이트 오류: $e');
      throw Exception('인증 상태 저장에 실패했습니다: $e');
    }
  }
  
  // 상태 초기화
  void _reset() {
    _currentPhoneNumber = null;
    _currentMemberId = null;
    _currentCode = null;
    _codeExpiry = null;
    _isCodeSent = false;
    _isLoading = false;
    notifyListeners();
  }
  
  // 다시 시도
  void resetForRetry() {
    _reset();
  }
  
  // 알리고 SMS 발송
  Future<bool> _sendAligoSMS(String phone, String code) async {
    try {
      // 알리고 API 설정
      const String aligoUrl = 'https://apis.aligo.in/send/';
      const String userId = 'enables';
      const String apiKey = 'djcg4vyirxyswndxi1xjobnoa93h76jr';
      const String sender = '010-2364-3612'; // 알리고 등록된 발신번호
      
      // 전화번호 포맷 (010-1234-5678 → 01012345678)
      final cleanPhone = phone.replaceAll('-', '');
      
      // SMS 내용
      final message = '[MyGolfPlanner] 인증번호: $code (5분간 유효)';
      
      // API 요청
      final response = await http.post(
        Uri.parse(aligoUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'key': apiKey,
          'userid': userId,
          'sender': sender,
          'receiver': cleanPhone,
          'msg': message,
          'msg_type': 'SMS',
          'title': 'MyGolfPlanner 인증',
        },
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['result_code'] == '1') {
          print('✅ 알리고 SMS 발송 성공: $phone');
          return true;
        } else {
          print('❌ 알리고 SMS 발송 실패: ${result['message']}');
          return false;
        }
      } else {
        print('❌ 알리고 API 호출 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 알리고 SMS 발송 오류: $e');
      return false;
    }
  }
  
  // 회원의 인증 상태 확인 (전화번호 기준)
  static Future<bool> isPhoneVerified(String phoneNumber) async {
    try {
      final members = await ApiService.getData(
        table: 'v3_members',
        where: [
          {'field': 'member_phone', 'operator': '=', 'value': phoneNumber}
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