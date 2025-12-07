import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ad_service.dart';

/// 동적 광고 위젯
/// 
/// Supabase의 광고 정책에 따라 자동으로 AdMob 또는 쿠팡 파트너스 광고를 표시합니다.
/// 
/// 사용 예시:
/// ```dart
/// DynamicAdWidget(
///   placementId: 'myxplanner_reservation_history_bottom',
///   branchId: currentBranchId, // 옵션: 지점별 광고 정책 적용
/// )
/// ```
class DynamicAdWidget extends StatefulWidget {
  /// 광고 위치 ID (ad_placements 테이블의 placement_id)
  final String placementId;
  
  /// 지점 ID (옵션 - 지점별 광고 정책 적용 시 사용)
  final String? branchId;
  
  /// 광고 로드 완료 콜백
  final VoidCallback? onAdLoaded;
  
  /// 광고 로드 실패 콜백
  final Function(String error)? onAdFailed;
  
  /// 폴백 위젯 (광고 로드 실패 시 표시)
  final Widget? fallbackWidget;

  const DynamicAdWidget({
    Key? key,
    required this.placementId,
    this.branchId,
    this.onAdLoaded,
    this.onAdFailed,
    this.fallbackWidget,
  }) : super(key: key);

  @override
  State<DynamicAdWidget> createState() => _DynamicAdWidgetState();
}

class _DynamicAdWidgetState extends State<DynamicAdWidget> {
  AdPolicy? _policy;
  AdOption? _option;
  BannerAd? _bannerAd;
  bool _isLoading = true;
  bool _isAdLoaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAdPolicy();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  /// 광고 정책 로드
  Future<void> _loadAdPolicy() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final adService = AdService();
      
      // 광고 정책 가져오기
      final policy = await adService.getAdPolicy(
        widget.placementId,
        branchId: widget.branchId,
      );
      
      if (policy == null) {
        print('⚠️ [DynamicAdWidget] 광고 정책 없음: ${widget.placementId}');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '광고 정책이 설정되지 않았습니다.';
          });
        }
        widget.onAdFailed?.call('광고 정책 없음');
        return;
      }
      
      // 광고 옵션 가져오기
      final option = await adService.getAdOption(
        widget.placementId,
        branchId: widget.branchId,
      );
      
      if (option == null) {
        print('⚠️ [DynamicAdWidget] 광고 옵션 없음: ${widget.placementId}');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '광고 옵션이 설정되지 않았습니다.';
          });
        }
        widget.onAdFailed?.call('광고 옵션 없음');
        return;
      }
      
      if (mounted) {
        setState(() {
          _policy = policy;
          _option = option;
        });
      }
      
      // 광고 유형에 따라 로드
      if (policy.providerId == 'admob') {
        await _loadAdMobAd(policy, option);
      } else if (policy.providerId == 'coupang') {
        // 쿠팡 배너는 이미지이므로 바로 로드 완료 처리
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isAdLoaded = true;
          });
        }
        widget.onAdLoaded?.call();
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '지원하지 않는 광고 유형: ${policy.providerId}';
          });
        }
        widget.onAdFailed?.call('지원하지 않는 광고 유형');
      }
      
    } catch (e) {
      print('❌ [DynamicAdWidget] 광고 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '광고 로드 중 오류가 발생했습니다.';
        });
      }
      widget.onAdFailed?.call(e.toString());
    }
  }

  /// AdMob 광고 로드
  Future<void> _loadAdMobAd(AdPolicy policy, AdOption option) async {
    // 웹에서는 AdMob 지원 안 함
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '웹에서는 AdMob을 지원하지 않습니다.';
        });
      }
      return;
    }
    
    // 배너 광고만 지원 (전면 광고는 별도 처리 필요)
    if (policy.adTypeId != 'banner' && policy.adTypeId != 'large_banner') {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '이 위젯은 배너 광고만 지원합니다.';
        });
      }
      return;
    }
    
    // 광고 단위 ID 가져오기
    final adUnitId = option.getAdUnitId(isTest: policy.isTestMode);
    if (adUnitId == null || adUnitId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '광고 단위 ID가 설정되지 않았습니다.';
        });
      }
      return;
    }
    
    print('📢 [DynamicAdWidget] AdMob 배너 로드: $adUnitId (테스트: ${policy.isTestMode})');
    
    // 적응형 배너 사이즈 계산
    AdSize adSize;
    if (context.mounted) {
      final width = MediaQuery.of(context).size.width.truncate();
      final adaptiveSize = await AdSize.getAnchoredAdaptiveBannerAdSize(
        Orientation.portrait,
        width,
      );
      adSize = adaptiveSize ?? AdSize.banner;
    } else {
      adSize = AdSize.banner;
    }
    
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('✅ [DynamicAdWidget] AdMob 배너 로드 완료');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isAdLoaded = true;
            });
          }
          widget.onAdLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ [DynamicAdWidget] AdMob 배너 로드 실패: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = '광고 로드에 실패했습니다.';
            });
          }
          widget.onAdFailed?.call(error.message);
        },
        onAdOpened: (ad) {
          print('📢 [DynamicAdWidget] AdMob 배너 열림');
        },
        onAdClosed: (ad) {
          print('📢 [DynamicAdWidget] AdMob 배너 닫힘');
        },
      ),
    );
    
    await _bannerAd!.load();
  }

  /// 쿠팡 배너 클릭 처리
  Future<void> _onCoupangBannerTap() async {
    if (_option?.linkUrl == null) return;
    
    final url = Uri.parse(_option!.linkUrl!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중
    if (_isLoading) {
      return const SizedBox.shrink();
    }
    
    // 에러 발생 시 폴백 또는 빈 위젯
    if (_errorMessage != null || !_isAdLoaded) {
      return widget.fallbackWidget ?? const SizedBox.shrink();
    }
    
    // 광고 렌더링
    if (_policy?.providerId == 'admob' && _bannerAd != null) {
      return _buildAdMobBanner();
    } else if (_policy?.providerId == 'coupang' && _option != null) {
      return _buildCoupangBanner();
    }
    
    return widget.fallbackWidget ?? const SizedBox.shrink();
  }

  /// AdMob 배너 위젯 빌드
  Widget _buildAdMobBanner() {
    return Container(
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      color: Colors.white,
      child: AdWidget(ad: _bannerAd!),
    );
  }

  /// 쿠팡 파트너스 배너 위젯 빌드
  Widget _buildCoupangBanner() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 배너 이미지
          GestureDetector(
            onTap: _onCoupangBannerTap,
            child: Image.network(
              _option!.imageUrl!,
              width: _option!.width?.toDouble() ?? 320,
              height: _option!.height?.toDouble() ?? 50,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  width: _option!.width?.toDouble() ?? 320,
                  height: _option!.height?.toDouble() ?? 50,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('❌ [DynamicAdWidget] 쿠팡 배너 이미지 로드 실패: $error');
                return widget.fallbackWidget ?? const SizedBox.shrink();
              },
            ),
          ),
          // 쿠팡 파트너스 필수 문구
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              '이 포스팅은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.',
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// 전면 광고 관리자
/// 
/// 사용 예시:
/// ```dart
/// final interstitialManager = DynamicInterstitialAdManager();
/// await interstitialManager.loadAd('myxplanner_after_booking');
/// // 적절한 시점에
/// await interstitialManager.showAd();
/// ```
class DynamicInterstitialAdManager {
  final String placementId;
  final String? branchId;
  
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  AdPolicy? _policy;
  AdOption? _option;

  DynamicInterstitialAdManager({
    required this.placementId,
    this.branchId,
  });

  bool get isAdLoaded => _isAdLoaded;

  /// 전면 광고 로드
  Future<void> loadAd() async {
    if (kIsWeb) {
      print('⚠️ [DynamicInterstitialAdManager] 웹에서는 전면 광고를 지원하지 않습니다.');
      return;
    }
    
    try {
      final adService = AdService();
      
      _policy = await adService.getAdPolicy(placementId, branchId: branchId);
      if (_policy == null) {
        print('⚠️ [DynamicInterstitialAdManager] 광고 정책 없음');
        return;
      }
      
      _option = await adService.getAdOption(placementId, branchId: branchId);
      if (_option == null) {
        print('⚠️ [DynamicInterstitialAdManager] 광고 옵션 없음');
        return;
      }
      
      // AdMob 전면 광고만 지원
      if (_policy!.providerId != 'admob' || _policy!.adTypeId != 'interstitial') {
        print('⚠️ [DynamicInterstitialAdManager] 전면 광고가 아님');
        return;
      }
      
      final adUnitId = _option!.getAdUnitId(isTest: _policy!.isTestMode);
      if (adUnitId == null) {
        print('⚠️ [DynamicInterstitialAdManager] 광고 단위 ID 없음');
        return;
      }
      
      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isAdLoaded = true;
            print('✅ [DynamicInterstitialAdManager] 전면 광고 로드 완료');
            
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _isAdLoaded = false;
                loadAd(); // 다음 광고 미리 로드
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _isAdLoaded = false;
                print('❌ [DynamicInterstitialAdManager] 전면 광고 표시 실패: $error');
              },
            );
          },
          onAdFailedToLoad: (error) {
            print('❌ [DynamicInterstitialAdManager] 전면 광고 로드 실패: $error');
            _isAdLoaded = false;
          },
        ),
      );
    } catch (e) {
      print('❌ [DynamicInterstitialAdManager] 오류: $e');
    }
  }

  /// 전면 광고 표시
  Future<void> showAd() async {
    if (_isAdLoaded && _interstitialAd != null) {
      await _interstitialAd!.show();
    } else {
      print('⚠️ [DynamicInterstitialAdManager] 광고가 아직 로드되지 않았습니다.');
    }
  }

  /// 리소스 해제
  void dispose() {
    _interstitialAd?.dispose();
  }
}




