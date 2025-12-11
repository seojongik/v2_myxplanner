import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 생성 콘텐츠(UGC) EULA 동의 관리 서비스
/// Apple App Store 가이드라인 1.2 준수
/// 채팅 및 게시판 모두에 적용
class ChatEulaService {
  static const String _eulaAcceptedKey = 'ugc_eula_accepted';
  static const String _eulaAcceptedDateKey = 'ugc_eula_accepted_date';
  static const String _eulaVersionKey = 'ugc_eula_version';
  
  // 현재 EULA 버전 (약관 변경 시 버전을 올려 재동의 필요)
  static const String currentEulaVersion = '1.1.0';

  /// EULA 동의 여부 확인
  static Future<bool> hasAcceptedEula() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_eulaAcceptedKey) ?? false;
    final acceptedVersion = prefs.getString(_eulaVersionKey) ?? '';
    
    // 버전이 다르면 재동의 필요
    if (acceptedVersion != currentEulaVersion) {
      return false;
    }
    
    return accepted;
  }

  /// EULA 동의 저장
  static Future<void> acceptEula() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eulaAcceptedKey, true);
    await prefs.setString(_eulaAcceptedDateKey, DateTime.now().toIso8601String());
    await prefs.setString(_eulaVersionKey, currentEulaVersion);
  }

  /// EULA 동의 철회
  static Future<void> revokeEula() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eulaAcceptedKey);
    await prefs.remove(_eulaAcceptedDateKey);
    await prefs.remove(_eulaVersionKey);
  }

  /// 커뮤니티 이용약관 내용 (채팅 + 게시판)
  static String getChatTermsContent() {
    return '''
커뮤니티 서비스 이용약관

마이골프플래너(이하 "회사")가 제공하는 커뮤니티 서비스(채팅, 게시판)의 이용과 관련하여 다음 사항에 동의합니다.

제1조 (서비스 개요)
본 커뮤니티 서비스는 회원과 골프연습장 간의 원활한 소통을 위해 제공되는 채팅 및 게시판 서비스입니다.
• 1:1 채팅: 회원과 매장 간 직접 소통
• 게시판: 공지사항, 자유게시판, 라운딩 모집, 중고판매 등

제2조 (이용자의 의무)
회원은 다음 행위를 하여서는 안 됩니다:
• 타인을 비방하거나 모욕하는 행위
• 욕설, 음란한 표현, 혐오 표현 등 부적절한 내용 게시
• 스팸, 광고성 메시지 또는 게시글 작성
• 타인의 개인정보를 무단으로 수집하거나 공유하는 행위
• 허위 정보를 유포하는 행위
• 사기, 사칭 등 불법적인 행위
• 기타 법령 또는 공서양속에 반하는 행위

위 행위 적발 시 사전 경고 없이 서비스 이용이 제한될 수 있습니다.

제3조 (콘텐츠 관리)
• 회사는 부적절한 콘텐츠를 필터링하고 모니터링합니다.
• 신고된 콘텐츠는 24시간 이내에 검토되며, 위반 확인 시 삭제됩니다.
• 반복적으로 부적절한 콘텐츠를 게시하는 회원은 서비스 이용이 영구 제한될 수 있습니다.

제4조 (신고 및 차단)
• 회원은 부적절한 메시지나 게시글을 신고할 수 있습니다.
• 회원은 특정 사용자를 차단할 수 있으며, 차단된 사용자의 콘텐츠는 표시되지 않습니다.
• 회원은 자신이 작성한 메시지나 게시글을 삭제할 수 있습니다.
• 모든 신고 내용은 회사에서 검토 후 적절한 조치를 취합니다.

제5조 (면책 조항)
• 회사는 회원 간 소통 내용에 대해 책임을 지지 않습니다.
• 회원이 커뮤니티를 통해 공유한 개인정보로 인한 피해에 대해 회사는 책임을 지지 않습니다.

제6조 (문의)
커뮤니티 서비스 관련 문의: support@mygolfplanner.com

본 약관에 동의하시면 커뮤니티 서비스를 이용하실 수 있습니다.
부적절한 콘텐츠 게시 시 서비스 이용이 제한될 수 있습니다.
''';
  }
}

