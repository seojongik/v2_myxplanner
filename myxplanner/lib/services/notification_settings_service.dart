import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsService {
  static const String _keySoundEnabled = 'notification_sound_enabled';
  static const String _keyVibrationEnabled = 'notification_vibration_enabled';
  
  // 기본값: 모두 켜짐
  static const bool _defaultSoundEnabled = true;
  static const bool _defaultVibrationEnabled = true;
  
  // 알림 소리 켜기/끄기
  static Future<bool> isSoundEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keySoundEnabled) ?? _defaultSoundEnabled;
    } catch (e) {
      print('❌ [NotificationSettings] 소리 설정 읽기 실패: $e');
      return _defaultSoundEnabled;
    }
  }
  
  static Future<void> setSoundEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySoundEnabled, enabled);
      print('✅ [NotificationSettings] 소리 설정 저장: $enabled');
    } catch (e) {
      print('❌ [NotificationSettings] 소리 설정 저장 실패: $e');
    }
  }
  
  // 진동 켜기/끄기
  static Future<bool> isVibrationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyVibrationEnabled) ?? _defaultVibrationEnabled;
    } catch (e) {
      print('❌ [NotificationSettings] 진동 설정 읽기 실패: $e');
      return _defaultVibrationEnabled;
    }
  }
  
  static Future<void> setVibrationEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyVibrationEnabled, enabled);
      print('✅ [NotificationSettings] 진동 설정 저장: $enabled');
    } catch (e) {
      print('❌ [NotificationSettings] 진동 설정 저장 실패: $e');
    }
  }
  
  // 모든 설정 초기화 (기본값으로)
  static Future<void> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySoundEnabled, _defaultSoundEnabled);
      await prefs.setBool(_keyVibrationEnabled, _defaultVibrationEnabled);
      print('✅ [NotificationSettings] 설정 초기화 완료');
    } catch (e) {
      print('❌ [NotificationSettings] 설정 초기화 실패: $e');
    }
  }
}

