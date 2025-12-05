import 'package:flutter/foundation.dart';
import 'supabase_adapter.dart';

/// 광고 정책 모델
class AdPolicy {
  final int policyId;
  final String? branchId;
  final String placementId;
  final String providerId;
  final String adTypeId;
  final int? optionId;
  final int priority;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool isTestMode;
  
  // 관련 옵션 정보 (조인 후 채워짐)
  AdOption? option;

  AdPolicy({
    required this.policyId,
    this.branchId,
    required this.placementId,
    required this.providerId,
    required this.adTypeId,
    this.optionId,
    this.priority = 0,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.isTestMode = false,
    this.option,
  });

  factory AdPolicy.fromMap(Map<String, dynamic> map) {
    return AdPolicy(
      policyId: map['policy_id'] ?? 0,
      branchId: map['branch_id'],
      placementId: map['placement_id'] ?? '',
      providerId: map['provider_id'] ?? '',
      adTypeId: map['ad_type_id'] ?? '',
      optionId: map['option_id'],
      priority: map['priority'] ?? 0,
      startDate: map['start_date'] != null ? DateTime.tryParse(map['start_date'].toString()) : null,
      endDate: map['end_date'] != null ? DateTime.tryParse(map['end_date'].toString()) : null,
      isActive: map['is_active'] == true || map['is_active'] == 1,
      isTestMode: map['is_test_mode'] == true || map['is_test_mode'] == 1,
    );
  }
}

/// 광고 옵션 모델
class AdOption {
  final int optionId;
  final String providerId;
  final String adTypeId;
  final String platform; // android, ios, web, all
  final String appId; // crm_lite_pro, myxplanner, all
  final String? adUnitId;
  final String? testAdUnitId;
  final String? imageUrl;
  final String? linkUrl;
  final int? width;
  final int? height;
  final Map<String, dynamic> config;
  final bool isActive;

  AdOption({
    required this.optionId,
    required this.providerId,
    required this.adTypeId,
    required this.platform,
    this.appId = 'all',
    this.adUnitId,
    this.testAdUnitId,
    this.imageUrl,
    this.linkUrl,
    this.width,
    this.height,
    this.config = const {},
    this.isActive = true,
  });

  factory AdOption.fromMap(Map<String, dynamic> map) {
    return AdOption(
      optionId: map['option_id'] ?? 0,
      providerId: map['provider_id'] ?? '',
      adTypeId: map['ad_type_id'] ?? '',
      platform: map['platform'] ?? 'all',
      appId: map['app_id'] ?? 'all',
      adUnitId: map['ad_unit_id'],
      testAdUnitId: map['test_ad_unit_id'],
      imageUrl: map['image_url'],
      linkUrl: map['link_url'],
      width: map['width'],
      height: map['height'],
      config: map['config'] is Map ? Map<String, dynamic>.from(map['config']) : {},
      isActive: map['is_active'] == true || map['is_active'] == 1,
    );
  }
  
  /// 현재 플랫폼에서 사용할 광고 단위 ID
  String? getAdUnitId({bool isTest = false}) {
    if (isTest && testAdUnitId != null) {
      return testAdUnitId;
    }
    return adUnitId;
  }
}

/// 광고 제공자 모델
class AdProvider {
  final String providerId;
  final String providerName;
  final String providerType;
  final bool isActive;
  final Map<String, dynamic> config;

  AdProvider({
    required this.providerId,
    required this.providerName,
    required this.providerType,
    this.isActive = true,
    this.config = const {},
  });

  factory AdProvider.fromMap(Map<String, dynamic> map) {
    return AdProvider(
      providerId: map['provider_id'] ?? '',
      providerName: map['provider_name'] ?? '',
      providerType: map['provider_type'] ?? '',
      isActive: map['is_active'] == true || map['is_active'] == 1,
      config: map['config'] is Map ? Map<String, dynamic>.from(map['config']) : {},
    );
  }
}

/// 광고 서비스 - Supabase에서 광고 정책을 가져와 관리
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // 캐시된 데이터
  Map<String, AdPolicy> _policiesCache = {};
  Map<int, AdOption> _optionsCache = {};
  Map<String, AdProvider> _providersCache = {};
  
  DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(minutes: 30);

  /// 현재 플랫폼 문자열 반환
  String get _currentPlatform {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'all';
  }

  /// 광고 데이터 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    if (!SupabaseAdapter.isInitialized) {
      print('⚠️ [AdService] Supabase가 초기화되지 않았습니다.');
      return;
    }
    
    try {
      await _fetchAllData();
      print('✅ [AdService] 광고 서비스 초기화 완료');
    } catch (e) {
      print('❌ [AdService] 초기화 실패: $e');
    }
  }

  /// 캐시 새로고침 필요 여부 확인
  bool _needsRefresh() {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > _cacheExpiry;
  }

  /// 모든 광고 데이터 가져오기
  Future<void> _fetchAllData() async {
    try {
      // 병렬로 데이터 가져오기
      final results = await Future.wait([
        _fetchProviders(),
        _fetchOptions(),
        _fetchPolicies(),
      ]);
      
      _lastFetchTime = DateTime.now();
    } catch (e) {
      print('❌ [AdService] 데이터 가져오기 실패: $e');
      rethrow;
    }
  }

  /// 광고 제공자 데이터 가져오기
  Future<void> _fetchProviders() async {
    try {
      final client = SupabaseAdapter.client;
      final response = await client
          .from('ad_providers')
          .select()
          .eq('is_active', true);
      
      _providersCache.clear();
      for (final row in response) {
        final provider = AdProvider.fromMap(row);
        _providersCache[provider.providerId] = provider;
      }
      print('📢 [AdService] 광고 제공자 ${_providersCache.length}개 로드');
    } catch (e) {
      print('❌ [AdService] 광고 제공자 로드 실패: $e');
    }
  }

  /// 광고 옵션 데이터 가져오기
  Future<void> _fetchOptions() async {
    try {
      final client = SupabaseAdapter.client;
      final platform = _currentPlatform;
      
      final response = await client
          .from('ad_options')
          .select()
          .eq('is_active', true)
          .or('platform.eq.$platform,platform.eq.all');
      
      _optionsCache.clear();
      for (final row in response) {
        final option = AdOption.fromMap(row);
        _optionsCache[option.optionId] = option;
      }
      print('📢 [AdService] 광고 옵션 ${_optionsCache.length}개 로드 (플랫폼: $platform)');
    } catch (e) {
      print('❌ [AdService] 광고 옵션 로드 실패: $e');
    }
  }

  /// 광고 정책 데이터 가져오기
  Future<void> _fetchPolicies() async {
    try {
      final client = SupabaseAdapter.client;
      final response = await client
          .from('ad_policies')
          .select()
          .eq('is_active', true)
          .order('priority', ascending: false);
      
      _policiesCache.clear();
      for (final row in response) {
        final policy = AdPolicy.fromMap(row);
        
        // 옵션 연결
        if (policy.optionId != null && _optionsCache.containsKey(policy.optionId)) {
          policy.option = _optionsCache[policy.optionId];
        }
        
        // 캐시 키: placement_id + branch_id (null이면 'all')
        final cacheKey = '${policy.placementId}_${policy.branchId ?? 'all'}';
        
        // 우선순위가 높은 것만 저장 (이미 있으면 스킵 - priority 내림차순이므로)
        if (!_policiesCache.containsKey(cacheKey)) {
          _policiesCache[cacheKey] = policy;
        }
      }
      print('📢 [AdService] 광고 정책 ${_policiesCache.length}개 로드');
    } catch (e) {
      print('❌ [AdService] 광고 정책 로드 실패: $e');
    }
  }

  /// 특정 위치의 광고 정책 가져오기
  /// 
  /// [placementId]: 광고 위치 ID (예: 'myxplanner_reservation_history_bottom')
  /// [branchId]: 지점 ID (null이면 전체 지점용 정책 사용)
  /// 
  /// 반환: 해당 위치에 적용할 광고 정책 (없으면 null)
  Future<AdPolicy?> getAdPolicy(String placementId, {String? branchId}) async {
    // 캐시 만료 확인
    if (_needsRefresh()) {
      await _fetchAllData();
    }
    
    // 1. 특정 지점용 정책 먼저 확인
    if (branchId != null) {
      final branchKey = '${placementId}_$branchId';
      if (_policiesCache.containsKey(branchKey)) {
        final policy = _policiesCache[branchKey]!;
        if (_isPolicyValid(policy)) {
          return policy;
        }
      }
    }
    
    // 2. 전체 지점용 정책 확인
    final allKey = '${placementId}_all';
    if (_policiesCache.containsKey(allKey)) {
      final policy = _policiesCache[allKey]!;
      if (_isPolicyValid(policy)) {
        return policy;
      }
    }
    
    return null;
  }

  /// 정책이 현재 유효한지 확인 (기간 체크)
  bool _isPolicyValid(AdPolicy policy) {
    final now = DateTime.now();
    
    // 시작일 체크
    if (policy.startDate != null && now.isBefore(policy.startDate!)) {
      return false;
    }
    
    // 종료일 체크
    if (policy.endDate != null && now.isAfter(policy.endDate!)) {
      return false;
    }
    
    return policy.isActive;
  }

  /// 현재 앱 ID (crm_lite_pro, myxplanner 등)
  static const String currentAppId = 'myxplanner';

  /// 특정 위치에 대한 광고 옵션 가져오기
  /// 플랫폼과 앱에 맞는 옵션을 자동으로 선택
  Future<AdOption?> getAdOption(String placementId, {String? branchId, String? appId}) async {
    final policy = await getAdPolicy(placementId, branchId: branchId);
    if (policy == null) return null;
    
    // 정책에 연결된 옵션이 있으면 반환
    if (policy.option != null) {
      return policy.option;
    }
    
    // 옵션이 없으면 provider + ad_type + platform + app_id로 찾기
    final platform = _currentPlatform;
    final targetAppId = appId ?? currentAppId;
    
    // 1차: 정확한 app_id 매칭
    for (final option in _optionsCache.values) {
      if (option.providerId == policy.providerId &&
          option.adTypeId == policy.adTypeId &&
          (option.platform == platform || option.platform == 'all') &&
          option.appId == targetAppId) {
        return option;
      }
    }
    
    // 2차: app_id가 'all'인 옵션 (공용)
    for (final option in _optionsCache.values) {
      if (option.providerId == policy.providerId &&
          option.adTypeId == policy.adTypeId &&
          (option.platform == platform || option.platform == 'all') &&
          option.appId == 'all') {
        return option;
      }
    }
    
    return null;
  }

  /// 광고 제공자 정보 가져오기
  AdProvider? getProvider(String providerId) {
    return _providersCache[providerId];
  }

  /// 캐시 강제 새로고침
  Future<void> refreshCache() async {
    _lastFetchTime = null;
    await _fetchAllData();
  }

  /// 캐시 초기화
  void clearCache() {
    _policiesCache.clear();
    _optionsCache.clear();
    _providersCache.clear();
    _lastFetchTime = null;
  }
}


