import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// 로그인 정보를 로컬 저장소에 저장하고 불러오는 서비스
/// - 전화번호 저장 (체크박스 선택 시)
/// - 자동 로그인 (체크박스 선택 시 전화번호 + 비밀번호 저장)
class LoginStorageService {
  static const String _keySavedPhone = 'mgp_saved_phone';
  static const String _keyAutoLoginEnabled = 'mgp_auto_login_enabled';
  static const String _keySavedPassword = 'mgp_saved_password'; // base64 인코딩하여 저장

  /// 저장된 전화번호 가져오기
  static Future<String?> getSavedPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keySavedPhone);
    } catch (e) {
      print('⚠️ 저장된 전화번호 로드 오류: $e');
      return null;
    }
  }

  /// 전화번호 저장
  static Future<bool> savePhone(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_keySavedPhone, phone);
    } catch (e) {
      print('⚠️ 전화번호 저장 오류: $e');
      return false;
    }
  }

  /// 전화번호 삭제
  static Future<bool> removePhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_keySavedPhone);
    } catch (e) {
      print('⚠️ 전화번호 삭제 오류: $e');
      return false;
    }
  }

  /// 자동 로그인 활성화 여부 확인
  static Future<bool> isAutoLoginEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAutoLoginEnabled) ?? false;
    } catch (e) {
      print('⚠️ 자동 로그인 설정 확인 오류: $e');
      return false;
    }
  }

  /// 자동 로그인 설정
  static Future<bool> setAutoLoginEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_keyAutoLoginEnabled, enabled);
    } catch (e) {
      print('⚠️ 자동 로그인 설정 저장 오류: $e');
      return false;
    }
  }

  /// 저장된 비밀번호 가져오기 (base64 디코딩)
  /// 주의: 완전한 암호화는 아니므로 보안에 주의
  static Future<String?> getSavedPassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedPassword = prefs.getString(_keySavedPassword);
      if (encodedPassword == null) return null;
      
      // base64 디코딩
      final bytes = base64Decode(encodedPassword);
      return utf8.decode(bytes);
    } catch (e) {
      print('⚠️ 저장된 비밀번호 로드 오류: $e');
      return null;
    }
  }

  /// 비밀번호 저장 (base64 인코딩)
  /// 주의: 완전한 암호화는 아니므로 보안에 주의
  static Future<bool> savePassword(String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // base64 인코딩하여 저장 (간단한 난독화)
      final encodedPassword = base64Encode(utf8.encode(password));
      return await prefs.setString(_keySavedPassword, encodedPassword);
    } catch (e) {
      print('⚠️ 비밀번호 저장 오류: $e');
      return false;
    }
  }

  /// 비밀번호 삭제
  static Future<bool> removePassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_keySavedPassword);
    } catch (e) {
      print('⚠️ 비밀번호 삭제 오류: $e');
      return false;
    }
  }

  /// 자동 로그인 정보 저장 (전화번호 + 비밀번호)
  static Future<bool> saveAutoLoginInfo(String phone, String password) async {
    try {
      final phoneSaved = await savePhone(phone);
      final passwordSaved = await savePassword(password);
      final autoLoginEnabled = await setAutoLoginEnabled(true);
      
      return phoneSaved && passwordSaved && autoLoginEnabled;
    } catch (e) {
      print('⚠️ 자동 로그인 정보 저장 오류: $e');
      return false;
    }
  }

  /// 자동 로그인 정보 삭제 (전화번호 포함 전체 삭제)
  static Future<bool> clearAutoLoginInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySavedPhone);
      await prefs.remove(_keySavedPassword);
      await prefs.remove(_keyAutoLoginEnabled);
      return true;
    } catch (e) {
      print('⚠️ 자동 로그인 정보 삭제 오류: $e');
      return false;
    }
  }

  /// 로그아웃 시 자동 로그인만 해제 (전화번호는 유지)
  static Future<bool> disableAutoLoginOnLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 비밀번호와 자동로그인 설정만 삭제, 전화번호는 유지
      await prefs.remove(_keySavedPassword);
      await prefs.remove(_keyAutoLoginEnabled);
      return true;
    } catch (e) {
      print('⚠️ 자동 로그인 해제 오류: $e');
      return false;
    }
  }

  /// 저장된 로그인 정보 가져오기 (자동 로그인용)
  static Future<Map<String, String>?> getAutoLoginInfo() async {
    try {
      final isEnabled = await isAutoLoginEnabled();
      if (!isEnabled) return null;

      final phone = await getSavedPhone();
      final password = await getSavedPassword();

      if (phone != null && password != null) {
        return {
          'phone': phone,
          'password': password,
        };
      }
      return null;
    } catch (e) {
      print('⚠️ 자동 로그인 정보 로드 오류: $e');
      return null;
    }
  }
}

