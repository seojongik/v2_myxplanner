# 광고 연동 가이드

## 광고 ID 정리

### Android
| 구분 | ID |
|------|-----|
| 앱 ID | `ca-app-pub-9967217222063224~8938417671` |
| 배너 광고 | `ca-app-pub-9967217222063224/1809902541` |
| 전면 광고 | `ca-app-pub-9967217222063224/4868021169` |

### iOS
| 구분 | ID |
|------|-----|
| 앱 ID | `ca-app-pub-9967217222063224~7022700778` |
| 배너 광고 | `ca-app-pub-9967217222063224/2632029622` |
| 전면 광고 | `ca-app-pub-9967217222063224/2572319872` |

---

## 설정 파일 위치

- **Dart 상수**: `lib/config/admob_config.dart`
- **Android 앱 ID**: `android/app/src/main/AndroidManifest.xml`
- **iOS 앱 ID**: `ios/Runner/Info.plist`

---

## 패키지 설치

```yaml
# pubspec.yaml
dependencies:
  google_mobile_ads: ^5.1.0
```

```bash
flutter pub get
```

---

## 초기화 (main.dart)

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(MyApp());
}
```

---

## 배너 광고 사용법

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:myxplanner/config/admob_config.dart';

class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdMobConfig.getBannerAdUnitId(isTest: false), // 배포 시 false
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('배너 광고 로드 실패: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 콘텐츠
        Expanded(child: YourContent()),

        // 배너 광고
        if (_isBannerLoaded && _bannerAd != null)
          SizedBox(
            height: _bannerAd!.size.height.toDouble(),
            width: _bannerAd!.size.width.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
      ],
    );
  }
}
```

---

## 전면 광고 사용법

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:myxplanner/config/admob_config.dart';

class InterstitialAdManager {
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  /// 전면 광고 로드
  void loadAd() {
    InterstitialAd.load(
      adUnitId: AdMobConfig.getInterstitialAdUnitId(isTest: false), // 배포 시 false
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isAdLoaded = false;
              loadAd(); // 다음 광고 미리 로드
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isAdLoaded = false;
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('전면 광고 로드 실패: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  /// 전면 광고 표시
  void showAd() {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      print('전면 광고가 아직 로드되지 않았습니다.');
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
  }
}

// 사용 예시
final adManager = InterstitialAdManager();
adManager.loadAd(); // 앱 시작 시 미리 로드

// 특정 시점에 광고 표시 (예: 레슨 예약 완료 후)
adManager.showAd();
```

---

## 광고 표시 타이밍 권장

- **배너 광고**: 메인 페이지 하단, 목록 화면 하단
- **전면 광고**:
  - 레슨 예약 완료 후
  - 결제 완료 후
  - 앱 시작 시 (스플래시 이후)
  - 단, 너무 자주 표시하면 사용자 이탈 주의

---

## 테스트 모드

개발 중에는 반드시 테스트 광고를 사용하세요:

```dart
// 개발 시
AdMobConfig.getBannerAdUnitId(isTest: true)
AdMobConfig.getInterstitialAdUnitId(isTest: true)

// 배포 시
AdMobConfig.getBannerAdUnitId(isTest: false)
AdMobConfig.getInterstitialAdUnitId(isTest: false)
```

> **주의**: 실제 광고 ID로 테스트하면 AdMob 정책 위반으로 계정이 정지될 수 있습니다.

---

## 배너 사이즈 옵션

| 사이즈 | 설명 | 크기 |
|--------|------|------|
| `AdSize.banner` | 표준 배너 | 320x50 |
| `AdSize.largeBanner` | 큰 배너 | 320x100 |
| `AdSize.mediumRectangle` | 중간 직사각형 | 300x250 |
| `AdSize.fullBanner` | 전체 배너 | 468x60 |
| `AdSize.leaderboard` | 리더보드 | 728x90 |

---

## 참고 문서

- [Google Mobile Ads Flutter 패키지](https://pub.dev/packages/google_mobile_ads)
- [AdMob 시작 가이드](https://developers.google.com/admob/flutter/quick-start)
- [AdMob 정책](https://support.google.com/admob/answer/6128543)

---

## 쿠팡 파트너스

| 구분 | 값 |
|------|-----|
| 파트너스 ID | `AF1003246` |

### 골프용품 배너 (320x50)

| 구분 | 값 |
|------|-----|
| 링크 | `https://link.coupang.com/a/c8NopB` |
| 이미지 | `https://ads-partners.coupang.com/banners/946522?subId=&traceId=V0-301-efafde73812c2264-I946522&w=320&h=50` |
| 크기 | 320 x 50 |

### 사용법

```dart
import 'package:myxplanner/config/admob_config.dart';
import 'package:url_launcher/url_launcher.dart';

// 쿠팡 골프용품 배너 위젯
GestureDetector(
  onTap: () => launchUrl(Uri.parse(AdMobConfig.coupangGolfBannerLink)),
  child: Image.network(
    AdMobConfig.coupangGolfBannerImage,
    width: 320,
    height: 50,
  ),
)
```

### 주의사항

1. **필수 문구 표시**: "이 포스팅은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다."
2. **스팸 금지**: 사전 동의 없는 메신저/SNS 발송 시 과태료 3천만원 또는 형사처벌 대상

### 참고
- [쿠팡 파트너스](https://partners.coupang.com/)
