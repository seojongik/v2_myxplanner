import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/admob_config.dart';

/// 재사용 가능한 AdMob 배너 광고 위젯
class AdBannerWidget extends StatefulWidget {
  /// 광고 로드 완료 시 호출되는 콜백
  final VoidCallback? onAdLoaded;

  const AdBannerWidget({Key? key, this.onAdLoaded}) : super(key: key);

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBannerAd();
    });
  }

  void _loadBannerAd() async {
    // 화면 너비에 맞는 적응형 배너 사이즈
    final width = MediaQuery.of(context).size.width.truncate();
    final adSize = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      width,
    );

    if (adSize == null) {
      print('적응형 배너 사이즈를 가져올 수 없습니다');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdMobConfig.getBannerAdUnitId(isTest: true), // TODO: 배포 시 false로 변경
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isAdLoaded = true);
            widget.onAdLoaded?.call();
          }
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
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      color: Colors.white,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
