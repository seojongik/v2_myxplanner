import 'package:flutter/foundation.dart';

/// AdMob 광고 설정
class AdMobConfig {
  // ========== Android ==========
  static const String androidAppId = 'ca-app-pub-9967217222063224~8938417671';
  static const String androidBannerAdUnitId = 'ca-app-pub-9967217222063224/1809902541';
  static const String androidInterstitialAdUnitId = 'ca-app-pub-9967217222063224/4868021169';

  // ========== iOS ==========
  static const String iosAppId = 'ca-app-pub-9967217222063224~7022700778';
  static const String iosBannerAdUnitId = 'ca-app-pub-9967217222063224/2632029622';
  static const String iosInterstitialAdUnitId = 'ca-app-pub-9967217222063224/2572319872';

  // ========== 테스트 광고 ID (개발용) ==========
  static const String testAndroidBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testAndroidInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testIosBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';
  static const String testIosInterstitialAdUnitId = 'ca-app-pub-3940256099942544/4411468910';

  // ========== 플랫폼 체크 ==========
  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isMobile => isAndroid || isIOS;

  // ========== 플랫폼별 ID 반환 ==========

  /// 현재 플랫폼의 앱 ID
  static String get appId {
    if (isAndroid) return androidAppId;
    if (isIOS) return iosAppId;
    return '';
  }

  /// 배너 광고 ID (isTest: true면 테스트 광고)
  static String getBannerAdUnitId({bool isTest = false}) {
    if (isAndroid) {
      return isTest ? testAndroidBannerAdUnitId : androidBannerAdUnitId;
    } else if (isIOS) {
      return isTest ? testIosBannerAdUnitId : iosBannerAdUnitId;
    }
    return '';
  }

  /// 전면 광고 ID (isTest: true면 테스트 광고)
  static String getInterstitialAdUnitId({bool isTest = false}) {
    if (isAndroid) {
      return isTest ? testAndroidInterstitialAdUnitId : androidInterstitialAdUnitId;
    } else if (isIOS) {
      return isTest ? testIosInterstitialAdUnitId : iosInterstitialAdUnitId;
    }
    return '';
  }

  // ========== 쿠팡 파트너스 ==========
  static const String coupangPartnersId = 'AF1003246';

  // 골프용품 배너 (320x50)
  static const String coupangGolfBannerLink = 'https://link.coupang.com/a/c8NopB';
  static const String coupangGolfBannerImage = 'https://ads-partners.coupang.com/banners/946522?subId=&traceId=V0-301-efafde73812c2264-I946522&w=320&h=50';
}
