/// 콘텐츠 필터링 서비스
/// Apple App Store 가이드라인 1.2 준수를 위한 불쾌한 콘텐츠 필터링
class ContentFilterService {
  // 금칙어 목록 (욕설, 비속어, 혐오 표현 등)
  static final List<String> _profanityList = [
    // 한국어 욕설/비속어
    '시발', '씨발', '씨팔', '씹', '지랄', '병신', '븅신', '빙신',
    '개새끼', '개새기', '개색기', '개색끼', '새끼', '썅', '좆', '존나',
    '니미', '니애미', '느금마', '느금', '엠창', '애미', '에미',
    '꺼져', '닥쳐', '뒤져', '뒈져', '죽어', '꺼지', '닥치',
    '멍청이', '바보', '등신', '돼지', '찐따', '찐찌',
    '미친놈', '미친년', '미친새끼', '정신병자',
    '걸레', '창녀', '화냥년', '보지', '자지',
    
    // 영어 욕설
    'fuck', 'shit', 'damn', 'bitch', 'asshole', 'bastard',
    'dick', 'cock', 'pussy', 'cunt', 'whore', 'slut',
    
    // 변형 표현 (발음 유사)
    'ㅅㅂ', 'ㅂㅅ', 'ㅈㄹ', 'ㄱㅅㄲ', 'ㅆㅂ', 'ㅈㄴ',
  ];

  /// 메시지에 금칙어가 포함되어 있는지 확인
  /// 반환값: (필터링 통과 여부, 감지된 금칙어 목록)
  static (bool isClean, List<String> detected) checkMessage(String message) {
    final lowercaseMessage = message.toLowerCase();
    final detectedWords = <String>[];

    for (final word in _profanityList) {
      if (lowercaseMessage.contains(word.toLowerCase())) {
        detectedWords.add(word);
      }
    }

    return (detectedWords.isEmpty, detectedWords);
  }

  /// 메시지에서 금칙어를 마스킹 처리
  static String maskProfanity(String message) {
    String maskedMessage = message;

    for (final word in _profanityList) {
      final regex = RegExp(word, caseSensitive: false);
      maskedMessage = maskedMessage.replaceAllMapped(
        regex,
        (match) => '*' * match.group(0)!.length,
      );
    }

    return maskedMessage;
  }

  /// 메시지 전체 검증
  /// 반환값: (허용 여부, 거부 사유)
  static (bool isAllowed, String? reason) validateMessage(String message) {
    // 1. 금칙어 검사
    final (isClean, detectedWords) = checkMessage(message);
    if (!isClean) {
      return (false, '부적절한 표현이 포함되어 있습니다.');
    }

    // 2. 빈 메시지 검사
    if (message.trim().isEmpty) {
      return (false, '메시지를 입력해주세요.');
    }

    // 3. 길이 제한 (1000자)
    if (message.length > 1000) {
      return (false, '메시지는 1000자 이내로 작성해주세요.');
    }

    return (true, null);
  }
}

