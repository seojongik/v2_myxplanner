import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../services/otp_service.dart';
import '../../../services/api_service.dart';
import '../../../config/admob_config.dart';
import 'reservation_detail_ts_cancel.dart';
import 'reservation_detail_ls_cancel.dart';
import 'reservation_detail_sp_cancel.dart';
import 'satisfaction_rating_widget.dart';
import 'reservation_self_ts_move.dart';

class ReservationDetailDialog extends StatefulWidget {
  final Map<String, dynamic> reservation;

  const ReservationDetailDialog({
    super.key,
    required this.reservation,
  });

  @override
  State<ReservationDetailDialog> createState() => _ReservationDetailDialogState();
}

class _ReservationDetailDialogState extends State<ReservationDetailDialog> with SingleTickerProviderStateMixin {
  String? _currentOTP;
  bool _isLoadingCancel = false;
  TabController? _tabController;
  int _currentTabIndex = 0;
  Map<String, dynamic>? _currentTabPolicyInfo;
  int? _currentTabBalance;
  Map<String, dynamic>? _couponPreview;
  Map<String, dynamic>? _issuedCouponPreview;

  // 배너 광고
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _generateOTPIfNeeded();
    _initializeTabController();
    _loadTabData();
    // 배너 광고는 context가 필요하므로 첫 프레임 이후 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBannerAd();
    });
  }

  void _loadBannerAd() async {
    // 화면 너비에 맞는 적응형 배너 사이즈 가져오기
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
            setState(() => _isBannerAdLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('배너 광고 로드 실패: $error');
        },
      ),
    )..load();
  }
  
  void _initializeTabController() {
    final paymentTabs = _getPaymentTabs();
    
    if (paymentTabs.length > 1) {
      _tabController = TabController(length: paymentTabs.length, vsync: this);
      _tabController!.addListener(() {
        print('🔄 탭 변경 감지: ${_tabController!.index}');
        if (_currentTabIndex != _tabController!.index) {
          setState(() {
            _currentTabIndex = _tabController!.index;
            // 탭 변경 시 이전 데이터 초기화
            _currentTabPolicyInfo = null;
            _currentTabBalance = null;
          });
          print('🔄 탭 변경 완료: $_currentTabIndex');
          _loadTabData();
          
          // 강제로 UI 다시 그리기
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {});
            }
          });
        }
      });
    }
  }
  
  Future<void> _loadTabData() async {
    final tabInfo = _getCurrentTabInfo();
    if (tabInfo.isNotEmpty) {
      print('🔄 탭 데이터 로드 시작: ${tabInfo['key']}');
      try {
        final policyInfo = await _getTabPolicyInfo(tabInfo['key']);
        final balance = await _getTabBalance(tabInfo['key']);
        final couponPreview = await _getCouponPreview();
        final issuedCouponPreview = await _getIssuedCouponPreview();
        
        print('🔄 새로운 정책 정보: ${policyInfo['refundAmount']}${policyInfo['unit']}');
        print('🔄 새로운 잔액 정보: $balance');
        print('🔄 새로운 사용 쿠폰 정보: ${couponPreview['coupons']?.length ?? 0}개');
        print('🔄 새로운 발급 쿠폰 정보: ${issuedCouponPreview['coupons']?.length ?? 0}개');
        
        if (mounted) {
          setState(() {
            _currentTabPolicyInfo = policyInfo;
            _currentTabBalance = balance;
            _couponPreview = couponPreview;
            _issuedCouponPreview = issuedCouponPreview;
          });
          
          // 추가 rebuild 강제 실행
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
        
        print('🔄 상태 업데이트 완료');
        print('🔄 저장된 환불 시간: ${_currentTabPolicyInfo?['refundAmount']}');
        print('🔄 저장된 잔액: $_currentTabBalance');
        print('🔄 저장된 사용 쿠폰 수: ${_couponPreview?['coupons']?.length ?? 0}개');
        print('🔄 저장된 발급 쿠폰 수: ${_issuedCouponPreview?['coupons']?.length ?? 0}개');
      } catch (e) {
        print('❌ 탭 데이터 로드 오류: $e');
      }
    }
  }
  
  @override
  void dispose() {
    _tabController?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _handleStationMoveSuccess(String newReservationId, int newTsId) async {
    print('🔄 타석 이동 성공! 새 예약 조회 중...');
    print('새 reservation_id: $newReservationId');
    print('새 타석: $newTsId');
    
    // context가 mounted인지 먼저 확인
    if (!mounted) {
      print('❌ 위젯이 이미 dispose됨');
      return;
    }
    
    try {
      // 새 예약 데이터 조회
      final newReservationResponse = await ApiService.getData(
        table: 'v2_priced_TS',
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': newReservationId},
          {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
        ],
      );
      
      if (newReservationResponse.isNotEmpty) {
        final newReservationData = newReservationResponse[0];
        
        // 새 예약 객체 생성
        final newReservation = {
          'type': widget.reservation['type'],
          'date': newReservationData['ts_date'],
          'startTime': newReservationData['ts_start'].substring(0, 5), // HH:mm 형식
          'endTime': newReservationData['ts_end'].substring(0, 5),
          'station': newReservationData['ts_id'],
          'status': newReservationData['ts_status'],
          'amount': newReservationData['net_amt'],
          'reservationId': newReservationData['reservation_id'],
          'billId': newReservationData['bill_id'],
          'billMinId': newReservationData['bill_min_id'] ?? '',
          'billGameId': newReservationData['bill_game_id'] ?? '',
          'programId': newReservationData['program_id'] ?? '',
          'programName': newReservationData['program_name'] ?? '',
        };
        
        // 현재 다이얼로그 닫고 새 다이얼로그 열기 (예약 타일 클릭과 동일)
        if (mounted) {
          print('✅ 현재 다이얼로그 닫기');
          Navigator.of(context).pop();
          
          print('✅ 새 예약 다이얼로그 열기');
          showDialog(
            context: context,
            useRootNavigator: false,
            builder: (BuildContext context) {
              return ReservationDetailDialog(reservation: newReservation);
            },
          );
        } else {
          print('❌ 위젯이 dispose됨');
        }
      } else {
        print('❌ 새 예약 데이터를 찾을 수 없습니다.');
      }
    } catch (e) {
      print('❌ 새 예약 조회 오류: $e');
    }
  }
  
  List<Map<String, dynamic>> _getPaymentTabs() {
    final reservation = widget.reservation;
    
    // 프로그램 예약인 경우 별도 처리
    if (reservation['type'] == '프로그램') {
      List<Map<String, dynamic>> tabs = [];
      
      // 프로그램 예약에서 타석 시간이 있으면 시간권 탭 추가
      final programDetails = reservation['programDetails'] ?? {};
      final tsReservations = programDetails['tsReservations'] ?? [];
      final lessonReservations = programDetails['lessonReservations'] ?? [];
      
      if (tsReservations.isNotEmpty) {
        tabs.add({
          'type': '시간권',
          'icon': Icons.timer,
          'color': Colors.orange,
          'key': 'time',
        });
      }
      
      if (lessonReservations.isNotEmpty) {
        tabs.add({
          'type': '레슨권',
          'icon': Icons.school,
          'color': Colors.purple,
          'key': 'lesson',
        });
      }
      
      print('=== 프로그램 예약 탭 디버깅 ===');
      print('타석 예약 수: ${tsReservations.length}');
      print('레슨 예약 수: ${lessonReservations.length}');
      print('생성된 탭 수: ${tabs.length}');
      for (final tab in tabs) {
        print('  - ${tab['type']} (${tab['key']})');
      }
      
      return tabs;
    }
    
    // 일반 예약인 경우 기존 로직
    final hasCreditPayment = reservation['billId'] != null &&
                            reservation['billId'].toString().isNotEmpty &&
                            reservation['billId'].toString() != 'null';
    final hasTimePayment = reservation['billMinId'] != null &&
                          reservation['billMinId'].toString().isNotEmpty &&
                          reservation['billMinId'].toString() != 'null';
    final hasLessonPayment = reservation['lsId'] != null &&
                            reservation['lsId'].toString().isNotEmpty &&
                            reservation['lsId'].toString() != 'null';
    
    List<Map<String, dynamic>> tabs = [];
    
    if (hasCreditPayment) {
      tabs.add({
        'type': '선불크레딧',
        'icon': Icons.attach_money,
        'color': Colors.green,
        'key': 'credit',
      });
    }
    
    if (hasTimePayment) {
      tabs.add({
        'type': '시간권',
        'icon': Icons.timer,
        'color': Colors.orange,
        'key': 'time',
      });
    }
    
    if (hasLessonPayment) {
      tabs.add({
        'type': '레슨권',
        'icon': Icons.school,
        'color': Colors.purple,
        'key': 'lesson',
      });
    }
    
    print('=== 결제 방식 디버깅 ===');
    print('billId: ${reservation['billId']}');
    print('billMinId: ${reservation['billMinId']}');
    print('lsId: ${reservation['lsId']}');
    print('hasCreditPayment: $hasCreditPayment');
    print('hasTimePayment: $hasTimePayment');
    print('hasLessonPayment: $hasLessonPayment');
    print('총 탭 개수: ${tabs.length}');
    
    return tabs;
  }
  
  Map<String, dynamic> _getCurrentTabInfo() {
    final tabs = _getPaymentTabs();
    if (tabs.isEmpty) return {};
    
    if (_tabController != null && _currentTabIndex < tabs.length) {
      final currentTab = tabs[_currentTabIndex];
      print('🔍 현재 탭 정보: ${currentTab['type']} (${currentTab['key']}) - 인덱스: $_currentTabIndex');
      return currentTab;
    }
    
    final firstTab = tabs.first;
    print('🔍 기본 탭 정보: ${firstTab['type']} (${firstTab['key']}) - 기본값');
    return firstTab;
  }
  
  Widget _buildTabContent() {
    final tabInfo = _getCurrentTabInfo();
    if (tabInfo.isEmpty) return const SizedBox.shrink();
    
    final tabColor = tabInfo['color'] as MaterialColor;
    final tabKey = tabInfo['key'];
    
    // 프로그램 예약인 경우 직접 계산
    int refundTime = 0;
    if (widget.reservation['type'] == '프로그램') {
      final programDetails = widget.reservation['programDetails'] ?? {};
      final tsReservations = programDetails['tsReservations'] ?? [];
      final lessonReservations = programDetails['lessonReservations'] ?? [];
      
      if (tabKey == 'time') {
        // 타석 시간 계산
        for (final ts in tsReservations) {
          final start = ts['startTime']?.toString() ?? '';
          final end = ts['endTime']?.toString() ?? '';
          if (start.isNotEmpty && end.isNotEmpty) {
            try {
              final startTime = DateTime.parse('2000-01-01 $start:00');
              final endTime = DateTime.parse('2000-01-01 $end:00');
              refundTime += endTime.difference(startTime).inMinutes;
            } catch (e) {}
          }
        }
      } else if (tabKey == 'lesson') {
        // 레슨 시간 계산
        for (final lesson in lessonReservations) {
          final start = lesson['startTime']?.toString() ?? '';
          final end = lesson['endTime']?.toString() ?? '';
          if (start.isNotEmpty && end.isNotEmpty) {
            try {
              final startTime = DateTime.parse('2000-01-01 $start:00');
              final endTime = DateTime.parse('2000-01-01 $end:00');
              refundTime += endTime.difference(startTime).inMinutes;
            } catch (e) {}
          }
        }
      }
    }
    
    print('🎨 UI 빌드 - 탭: $tabKey, 환불시간: $refundTime분');
        
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 예약 정보
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.event,
                          size: 20,
                          color: Colors.orange[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '취소 예약 정보',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 예약 상세 정보
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '예약 날짜',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('yyyy년 M월 d일 (E)', 'ko').format(DateTime.parse(widget.reservation['date'])),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '예약 시간',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.reservation['startTime']} - ${widget.reservation['endTime']}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 환불 예정 금액/시간
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          tabInfo['icon'], 
                          size: 20, 
                          color: Colors.green[600]
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '환불 예정 ${tabInfo['key'] == 'credit' ? '금액' : '시간'} 안내',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // 환불 예정 금액/시간 크게 표시
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            '${NumberFormat('#,###').format(_currentTabPolicyInfo?['refundAmount'] ?? 0)}${_currentTabPolicyInfo?['unit'] ?? '원'}',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey[900],
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        // 취소 조건 주석과 물음표 버튼
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentTabPolicyInfo?['currentStatus'] ?? '취소 조건을 확인하는 중...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showPolicyInfo(tabInfo),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue[200]!, width: 1),
                                ),
                                child: Icon(
                                  Icons.help_outline,
                                  size: 16,
                                  color: Colors.blue[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 구분선
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: Colors.grey[200],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 잔액 정보
                  Row(
                    children: [
                      // 환불 전 잔액
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '환불 전 ${tabInfo['key'] == 'credit' ? '잔액' : '시간'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${NumberFormat('#,###').format(_currentTabBalance ?? 0)}${tabInfo['key'] == 'credit' ? '원' : '분'}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 그라데이션 화살표
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[400]!, Colors.green[400]!],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      
                      // 환불 후 잔액
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '환불 후 ${tabInfo['key'] == 'credit' ? '잔액' : '시간'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${NumberFormat('#,###').format((_currentTabBalance ?? 0) + (_currentTabPolicyInfo?['refundAmount'] ?? 0))}${tabInfo['key'] == 'credit' ? '원' : '분'}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 쿠폰 발행/사용 취소 안내 (쿠폰이 있을 경우만 표시)
            if ((_couponPreview != null && _couponPreview!['success'] == true && (_couponPreview!['coupons'] as List).isNotEmpty) || 
                (_issuedCouponPreview != null && _issuedCouponPreview!['success'] == true && (_issuedCouponPreview!['coupons'] as List).isNotEmpty)) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.local_offer,
                            size: 20,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '쿠폰 발행/사용 취소',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    
                    // 사용된 쿠폰 복구 섹션
                    if (_couponPreview != null && _couponPreview!['success'] == true && (_couponPreview!['coupons'] as List).isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        _couponPreview!['message'] ?? '쿠폰 정보를 확인할 수 없습니다',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_couponPreview!['coupons'] as List<Map<String, dynamic>>).map((coupon) => 
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green[600],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      coupon['coupon_type'] ?? '쿠폰',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      coupon['coupon_name'] ?? '할인쿠폰',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_offer,
                                    size: 16,
                                    color: Colors.green[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    coupon['discount_info'] ?? '할인 정보 없음',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (coupon['expiry_date'] != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Colors.green[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '유효기간: ${coupon['expiry_date']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ).toList(),
                    ],
                    
                    // 발급된 쿠폰 취소 섹션
                    if (_issuedCouponPreview != null && _issuedCouponPreview!['success'] == true && (_issuedCouponPreview!['coupons'] as List).isNotEmpty) ...[
                      if (_couponPreview != null && _couponPreview!['success'] == true && (_couponPreview!['coupons'] as List).isNotEmpty) 
                        const SizedBox(height: 20),
                      if (_couponPreview == null || _couponPreview!['success'] != true || (_couponPreview!['coupons'] as List).isEmpty)
                        const SizedBox(height: 20),
                      Text(
                        _issuedCouponPreview!['message'] ?? '발급 쿠폰 정보를 확인할 수 없습니다',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_issuedCouponPreview!['coupons'] as List<Map<String, dynamic>>).map((coupon) => 
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[600],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      coupon['coupon_type'] ?? '쿠폰',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      coupon['coupon_name'] ?? '할인쿠폰',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_offer,
                                    size: 16,
                                    color: Colors.orange[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    coupon['discount_info'] ?? '할인 정보 없음',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.orange[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '현재 상태: ${coupon['status'] ?? '알 수 없음'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ).toList(),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
  }
  
  int _getRefundTime(String tabKey) {
    final reservation = widget.reservation;
    if (reservation['type'] != '프로그램') {
      return _currentTabPolicyInfo?['refundAmount'] ?? 0;
    }
    
    final programDetails = reservation['programDetails'] ?? {};
    final tsReservations = programDetails['tsReservations'] ?? [];
    final lessonReservations = programDetails['lessonReservations'] ?? [];
    
    int totalTsTime = 0;
    int totalLessonTime = 0;
    
    // 타석 시간 계산
    for (final tsReservation in tsReservations) {
      final startTime = tsReservation['startTime']?.toString() ?? '';
      final endTime = tsReservation['endTime']?.toString() ?? '';
      
      if (startTime.isNotEmpty && endTime.isNotEmpty) {
        try {
          final start = DateTime.parse('2000-01-01 $startTime:00');
          final end = DateTime.parse('2000-01-01 $endTime:00');
          totalTsTime += end.difference(start).inMinutes;
        } catch (e) {
          print('타석 시간 파싱 오류: $e');
        }
      }
    }
    
    // 레슨 시간 계산
    for (final lessonReservation in lessonReservations) {
      final startTime = lessonReservation['startTime']?.toString() ?? '';
      final endTime = lessonReservation['endTime']?.toString() ?? '';
      
      if (startTime.isNotEmpty && endTime.isNotEmpty) {
        try {
          final start = DateTime.parse('2000-01-01 $startTime:00');
          final end = DateTime.parse('2000-01-01 $endTime:00');
          totalLessonTime += end.difference(start).inMinutes;
        } catch (e) {}
      }
    }
    
    print('🎯 직접 계산 - 탭키: $tabKey, 타석시간: $totalTsTime분, 레슨시간: $totalLessonTime분');
    
    if (tabKey == 'time') {
      return totalTsTime;
    } else if (tabKey == 'lesson') {
      return totalLessonTime;
    }
    
    return 0;
  }
  
  Future<Map<String, dynamic>> _getTabPolicyInfo(String tabKey) async {
    try {
      // 테이블 이름 결정
      String tableName = '';
      if (widget.reservation['type'] == '프로그램') {
        // 프로그램 예약의 경우 모든 탭에서 프로그램 정책 사용
        tableName = 'v2_program_settings';
      } else if (tabKey == 'credit') {
        tableName = 'v2_bills';
      } else if (tabKey == 'time') {
        tableName = 'v2_bill_times';
      } else if (tabKey == 'lesson') {
        tableName = 'v3_LS_countings';
      } else {
        // 알 수 없는 타입
        return {
          'policies': ['취소 정책을 찾을 수 없습니다.'],
          'currentStatus': '취소 정책을 확인할 수 없습니다.',
          'penaltyPercent': 0,
          'penaltyAmount': 0,
          'refundAmount': 0,
        };
      }
      
      // 취소 정책 조회
      final policies = await ApiService.getData(
        table: 'v2_cancellation_policy',
        where: [
          {'field': 'db_table', 'operator': '=', 'value': tableName}
        ],
        orderBy: [
          {'field': 'apply_sequence', 'direction': 'ASC'}
        ],
      );
      
      // 정책 문구 생성 (환불 관점으로)
      List<String> policyTexts = [];
      if (policies.isEmpty) {
        policyTexts.add('별도의 환불 정책이 설정되지 않았습니다.');
      } else {
        for (final policy in policies) {
          final minBefore = int.parse(policy['_min_before_use'].toString());
          final penaltyPercent = int.parse(policy['penalty_percent'].toString());
          final refundPercent = 100 - penaltyPercent;
          
          String timeText = '';
          if (minBefore == 0) {
            timeText = '시작 시간 이후';
          } else if (minBefore < 60) {
            timeText = '${minBefore}분 이내';
          } else if (minBefore < 1440) {
            timeText = '${(minBefore / 60).round()}시간 이내';
          } else {
            timeText = '${(minBefore / 1440).round()}일 이내';
          }
          
          String refundText = '';
          if (penaltyPercent == 100) {
            refundText = '환불 불가';
          } else if (penaltyPercent == 0) {
            refundText = '전액 환불';
          } else {
            refundText = '${refundPercent}% 환불';
          }
          
          policyTexts.add('$timeText : $refundText');
        }
        
        // 마지막 정책 이후의 전액 환불 정보 추가
        if (policies.isNotEmpty) {
          final lastPolicy = policies.last;
          final lastMinBefore = int.parse(lastPolicy['_min_before_use'].toString());
          
          String afterTimeText = '';
          if (lastMinBefore < 60) {
            afterTimeText = '${lastMinBefore}분 이후';
          } else if (lastMinBefore < 1440) {
            afterTimeText = '${(lastMinBefore / 60).round()}시간 이후';
          } else {
            afterTimeText = '${(lastMinBefore / 1440).round()}일 이후';
          }
          
          policyTexts.add('$afterTimeText : 전액 환불');
        }
      }
      
      // 현재 시간과 예약 시간 차이 계산
      final now = DateTime.now();
      final dateStr = widget.reservation['date'];
      final startTimeStr = widget.reservation['startTime'];
      final startDateTime = DateTime.parse('$dateStr $startTimeStr:00');
      final timeDiff = startDateTime.difference(now).inMinutes;
      
      // 적용될 페널티 찾기
      int appliedPenalty = 0;
      String currentStatusText = '';
      
      if (timeDiff < 0) {
        // 이미 시작된 예약
        if (policies.isNotEmpty) {
          final firstPolicy = policies.firstWhere(
            (p) => int.parse(p['apply_sequence'].toString()) == 1,
            orElse: () => policies.first,
          );
          appliedPenalty = int.parse(firstPolicy['penalty_percent'].toString());
        }
        currentStatusText = appliedPenalty == 100 
          ? '예약 시작 시간이 지났습니다. 환불이 불가능합니다.'
          : '예약 시작 시간이 지났습니다. ${100 - appliedPenalty}% 환불됩니다.';
      } else {
        // 아직 시작 전
        bool policyFound = false;
        for (final policy in policies) {
          final minBefore = int.parse(policy['_min_before_use'].toString());
          if (timeDiff <= minBefore) {
            appliedPenalty = int.parse(policy['penalty_percent'].toString());
            policyFound = true;
            break;
          }
        }
        
        if (!policyFound || appliedPenalty == 0) {
          currentStatusText = '전액 환불 가능한 시간입니다.';
        } else if (appliedPenalty == 100) {
          currentStatusText = '환불이 불가능한 시간입니다.';
        } else {
          currentStatusText = '현재 ${100 - appliedPenalty}% 환불됩니다.';
        }
        
        // 남은 시간 안내 추가
        if (timeDiff < 60) {
          currentStatusText += '\n(예약 시작까지 ${timeDiff}분 남음)';
        } else if (timeDiff < 1440) {
          currentStatusText += '\n(예약 시작까지 ${(timeDiff / 60).toStringAsFixed(0)}시간 ${timeDiff % 60}분 남음)';
        } else {
          currentStatusText += '\n(예약 시작까지 ${(timeDiff / 1440).toStringAsFixed(0)}일 남음)';
        }
      }
      
      // 환불 금액/시간 계산
      int amount = 0;
      int penaltyAmount = 0;
      int refundAmount = 0;
      String unit = '원';
      
      print('');
      print('🔍 환불 시간 계산 디버깅 시작');
      print('예약 타입: $tabKey');
      print('적용 페널티: $appliedPenalty%');
      print('예약 원본 타입: ${widget.reservation['type']}');
      print('프로그램 예약 여부: ${widget.reservation['type'] == '프로그램'}');
      print('예약 데이터: ${widget.reservation}');
      
      // 프로그램 예약인 경우 먼저 처리
      if (widget.reservation['type'] == '프로그램') {
        // 프로그램 예약은 별도 처리 (타석+레슨 통합)
        print('프로그램 환불 계산:');
        print('  - 프로그램 예약은 통합 처리');
        
        // 프로그램 예약에서 실제 예약 시간 계산
        final programDetails = widget.reservation['programDetails'] ?? {};
        final tsReservations = programDetails['tsReservations'] ?? [];
        final lessonReservations = programDetails['lessonReservations'] ?? [];
        
        int totalTsTime = 0;
        int totalLessonTime = 0;
        
        // 타석 시간 합산 (시간 차이로 계산)
        print('    타석 예약 상세 분석:');
        for (int i = 0; i < tsReservations.length; i++) {
          final tsReservation = tsReservations[i];
          final startTime = tsReservation['startTime']?.toString() ?? '';
          final endTime = tsReservation['endTime']?.toString() ?? '';
          
          print('      타석 ${i + 1}: $startTime - $endTime');
          
          if (startTime.isNotEmpty && endTime.isNotEmpty) {
            try {
              final start = DateTime.parse('2000-01-01 $startTime:00');
              final end = DateTime.parse('2000-01-01 $endTime:00');
              final minutes = end.difference(start).inMinutes;
              totalTsTime += minutes;
              print('        계산 결과: ${minutes}분');
            } catch (e) {
              print('        타석 시간 파싱 오류: $e');
            }
          } else {
            print('        시간 정보 없음');
          }
        }
        
        // 레슨 시간 합산 (세션별 시간 차이로 계산)
        print('    레슨 예약 상세 분석:');
        for (int i = 0; i < lessonReservations.length; i++) {
          final lessonReservation = lessonReservations[i];
          final startTime = lessonReservation['startTime']?.toString() ?? '';
          final endTime = lessonReservation['endTime']?.toString() ?? '';
          
          print('      레슨 ${i + 1}: $startTime - $endTime');
          
          if (startTime.isNotEmpty && endTime.isNotEmpty) {
            try {
              final start = DateTime.parse('2000-01-01 $startTime:00');
              final end = DateTime.parse('2000-01-01 $endTime:00');
              final minutes = end.difference(start).inMinutes;
              totalLessonTime += minutes;
              print('        계산 결과: ${minutes}분');
            } catch (e) {
              print('        레슨 시간 파싱 오류: $e');
            }
          } else {
            print('        시간 정보 없음');
          }
        }
        
        print('  - 타석 총 시간: ${totalTsTime}분');
        print('  - 레슨 총 시간: ${totalLessonTime}분');
        
        // 프로그램 예약에서 탭에 따라 시간 선택
        if (tabKey == 'time') {
          amount = totalTsTime;
          print('  - 탭 키: $tabKey → 타석 시간 사용');
        } else if (tabKey == 'lesson') {
          amount = totalLessonTime;
          print('  - 탭 키: $tabKey → 레슨 시간 사용');
        } else {
          // 기본적으로 타석 시간 사용
          amount = totalTsTime;
          print('  - 탭 키: $tabKey → 기본 타석 시간 사용');
        }
        
        penaltyAmount = (amount * appliedPenalty / 100).round();
        refundAmount = amount - penaltyAmount;
        unit = '분';
        
        print('  - 선택된 시간: $amount분');
        print('  - 페널티 시간: $penaltyAmount분');
        print('  - 환불 시간: $refundAmount분');
        
      } else if (tabKey == 'credit') {
        // 금액 기반 계산
        amount = widget.reservation['amount'] ?? 0;
        int absAmount = amount.abs();
        penaltyAmount = (absAmount * appliedPenalty / 100).round();
        refundAmount = absAmount - penaltyAmount;
        unit = '원';
        
        print('선불크레딧 환불 계산:');
        print('  - 원본 금액: $amount');
        print('  - 절댓값: $absAmount');
        print('  - 페널티 금액: $penaltyAmount');
        print('  - 환불 금액: $refundAmount');
        
      } else if (tabKey == 'time') {
        // 시간 기반 계산 (시간권)
        amount = widget.reservation['timeAmount'] ?? 0;  // 시간권 시간(분)
        penaltyAmount = (amount * appliedPenalty / 100).round();
        refundAmount = amount - penaltyAmount;
        unit = '분';
        
        print('시간권 환불 계산:');
        print('  - 원본 시간: $amount분');
        print('  - 페널티 시간: $penaltyAmount분');
        print('  - 환불 시간: $refundAmount분');
        
      } else if (tabKey == 'lesson') {
        // 시간 기반 계산 (레슨)
        amount = widget.reservation['lessonDuration'] ?? 0;  // 레슨 시간(분)
        penaltyAmount = (amount * appliedPenalty / 100).round();
        refundAmount = amount - penaltyAmount;
        unit = '분';
        
        print('레슨 환불 계산:');
        print('  - 원본 시간: $amount분');
        print('  - 페널티 시간: $penaltyAmount분');
        print('  - 환불 시간: $refundAmount분');
      }
      
      print('최종 환불 계산 결과:');
      print('  - 환불 예정: $refundAmount$unit');
      print('  - 페널티: $penaltyAmount$unit');
      print('🔍 환불 시간 계산 디버깅 완료');
      print('');
      
      return {
        'policies': policyTexts,
        'currentStatus': currentStatusText,
        'penaltyPercent': appliedPenalty,
        'penaltyAmount': penaltyAmount,
        'refundAmount': refundAmount,
        'unit': unit,
      };
      
    } catch (e) {
      print('취소 정책 조회 오류: $e');
      return {
        'policies': ['취소 정책을 조회할 수 없습니다.'],
        'currentStatus': '취소 정책을 확인할 수 없습니다.',
        'penaltyPercent': 0,
        'penaltyAmount': 0,
        'refundAmount': 0,
        'unit': '원',
      };
    }
  }

  Future<int> _getCurrentBalance() async {
    try {
      final reservation = widget.reservation;
      final billId = reservation['billId'];
      
      if (billId == null) return 0;
      
      // 현재 예약의 bill 정보 조회하여 contract_history_id 가져오기
      final billData = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'bill_id', 'operator': '=', 'value': billId}
        ],
        limit: 1,
      );
      
      if (billData.isEmpty) return 0;
      
      final contractHistoryId = billData.first['contract_history_id'];
      if (contractHistoryId == null) return 0;
      
      // 동일 계약의 최종 레코드(가장 큰 bill_id) 조회
      final latestBillData = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId}
        ],
        orderBy: [
          {'field': 'bill_id', 'direction': 'DESC'}
        ],
        limit: 1,
      );
      
      if (latestBillData.isNotEmpty) {
        return latestBillData.first['bill_balance_after'] ?? 0;
      }
      
      return 0;
    } catch (e) {
      print('잔액 조회 오류: $e');
      return 0;
    }
  }
  
  Future<int> _getCurrentTimeBalance() async {
    try {
      final reservation = widget.reservation;
      String? billMinId;
      
      print('=== 시간권 잔액 조회 시작 ===');
      print('예약 타입: ${reservation['type']}');
      
      // 프로그램 예약인 경우 programDetails에서 billMinId 가져오기
      if (reservation['type'] == '프로그램') {
        final programDetails = reservation['programDetails'] ?? {};
        final tsReservations = programDetails['tsReservations'] ?? [];
        
        print('프로그램 예약 - 타석 예약 수: ${tsReservations.length}');
        
        if (tsReservations.isNotEmpty) {
          // 첫 번째 타석 예약의 billMinId 사용
          billMinId = tsReservations[0]['billMinId']?.toString();
          print('첫 번째 타석 예약 데이터: ${tsReservations[0]}');
        }
      } else {
        // 일반 타석 예약인 경우
        billMinId = reservation['billMinId']?.toString();
        print('일반 타석 예약 billMinId: $billMinId');
      }
      
      if (billMinId == null || billMinId.isEmpty) {
        print('❌ 시간권 잔액 조회: billMinId를 찾을 수 없음');
        return 0;
      }
      
      print('✅ 사용할 billMinId: $billMinId');
      
      // 현재 예약의 bill_times 정보 조회하여 contract_history_id 가져오기
      final billData = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'bill_min_id', 'operator': '=', 'value': billMinId}
        ],
        limit: 1,
      );
      
      print('bill_times 조회 결과: ${billData.length}개');
      if (billData.isNotEmpty) {
        print('bill_times 데이터: ${billData.first}');
      }
      
      if (billData.isEmpty) {
        print('❌ 시간권 잔액 조회: bill_times 데이터 없음');
        return 0;
      }
      
      final contractHistoryId = billData.first['contract_history_id'];
      
      print('contract_history_id: $contractHistoryId');
      
      if (contractHistoryId == null) {
        print('❌ 시간권 잔액 조회: contract_history_id 없음');
        return 0;
      }
      
      // contract_history_id로 최종 레코드 조회
      final latestBillData = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId}
        ],
        orderBy: [
          {'field': 'bill_min_id', 'direction': 'DESC'}
        ],
        limit: 1,
      );
      
      print('최종 레코드 조회 결과: ${latestBillData.length}개');
      if (latestBillData.isNotEmpty) {
        print('최종 레코드 데이터: ${latestBillData.first}');
        final balance = latestBillData.first['bill_balance_min_after'] ?? 0;
        print('✅ 시간권 최종 잔액: $balance분');
        print('=== 시간권 잔액 조회 완료 ===');
        return balance;
      }
      
      print('❌ 시간권 잔액 조회: 최종 레코드 없음');
      print('=== 시간권 잔액 조회 완료 ===');
      return 0;
    } catch (e) {
      print('❌ 시간권 잔액 조회 오류: $e');
      print('=== 시간권 잔액 조회 완료 ===');
      return 0;
    }
  }
  
  Future<int> _getCurrentLessonBalance() async {
    try {
      final reservation = widget.reservation;
      String? lsId;
      
      print('=== 레슨권 잔액 조회 시작 ===');
      print('예약 타입: ${reservation['type']}');
      
      // 프로그램 예약인 경우 programDetails에서 lsId 가져오기
      if (reservation['type'] == '프로그램') {
        final programDetails = reservation['programDetails'] ?? {};
        final lessonReservations = programDetails['lessonReservations'] ?? [];
        
        print('프로그램 예약 - 레슨 예약 수: ${lessonReservations.length}');
        
        if (lessonReservations.isNotEmpty) {
          // 첫 번째 레슨 예약의 lsId 사용
          lsId = lessonReservations[0]['lsId']?.toString();
          print('첫 번째 레슨 예약 데이터: ${lessonReservations[0]}');
        }
      } else {
        // 일반 레슨 예약인 경우
        lsId = reservation['lsId']?.toString();
        print('일반 레슨 예약 lsId: $lsId');
      }
      
      if (lsId == null || lsId.isEmpty) {
        print('❌ 레슨 잔액 조회: lsId를 찾을 수 없음');
        return 0;
      }
      
      print('✅ 사용할 lsId: $lsId');
      
      // 현재 예약의 LS_countings 정보 조회하여 LS_contract_id 가져오기
      final lsData = await ApiService.getData(
        table: 'v3_LS_countings',
        where: [
          {'field': 'LS_id', 'operator': '=', 'value': lsId}
        ],
        limit: 1,
      );
      
      print('LS_countings 조회 결과: ${lsData.length}개');
      if (lsData.isNotEmpty) {
        print('LS_countings 데이터: ${lsData.first}');
      }
      
      if (lsData.isEmpty) {
        print('❌ 레슨 잔액 조회: LS_countings 데이터 없음');
        return 0;
      }
      
      final lsContractId = lsData.first['LS_contract_id'];
      final contractHistoryId = lsData.first['contract_history_id'];
      
      print('LS_contract_id: $lsContractId');
      print('contract_history_id: $contractHistoryId');
      
      if (contractHistoryId == null) {
        print('❌ 레슨 잔액 조회: contract_history_id 없음');
        return 0;
      }
      
      // contract_history_id로 최종 레코드 조회
      final latestLsData = await ApiService.getData(
        table: 'v3_LS_countings',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId}
        ],
        orderBy: [
          {'field': 'LS_counting_id', 'direction': 'DESC'}
        ],
        limit: 1,
      );
      
      print('최종 레코드 조회 결과: ${latestLsData.length}개');
      if (latestLsData.isNotEmpty) {
        print('최종 레코드 데이터: ${latestLsData.first}');
        final balance = latestLsData.first['LS_balance_min_after'] ?? 0;
        print('✅ 레슨권 최종 잔액: $balance분');
        print('=== 레슨권 잔액 조회 완료 ===');
        return balance;
      }
      
      print('❌ 레슨 잔액 조회: 최종 레코드 없음');
      print('=== 레슨권 잔액 조회 완료 ===');
      return 0;
    } catch (e) {
      print('❌ 레슨 잔액 조회 오류: $e');
      print('=== 레슨권 잔액 조회 완료 ===');
      return 0;
    }
  }

  void _generateOTPIfNeeded() {
    print('=== 예약 상세 디버깅 ===');
    print('전체 예약 데이터: ${widget.reservation}');
    
    // 타석 예약이거나 프로그램 예약(타석 포함)인 경우 OTP 생성
    if (widget.reservation['type'] == '타석' || 
        (widget.reservation['type'] == '프로그램' && (widget.reservation['tsCount'] ?? 0) > 0)) {
      print('Bill ID: ${widget.reservation['billId']}');
      print('Bill Min ID: ${widget.reservation['billMinId']}');
      print('Bill Game ID: ${widget.reservation['billGameId']}');
      
      final branchId = ApiService.getCurrentBranchId() ?? '';
      final reservationId = widget.reservation['reservationId'] ?? '';

      if (branchId.isNotEmpty && reservationId.isNotEmpty) {
        setState(() {
          _currentOTP = OTPService.generateStationOTP(
            branchId: branchId,
            reservationId: reservationId,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservation = widget.reservation;
    final isLessonType = reservation['type'] == '레슨';
    final isProgramType = reservation['type'] == '프로그램';
    final isCancelled = reservation['status'] == '취소';
    final date = DateTime.parse(reservation['date']);
    final dateStr = DateFormat('M월 d일 EEEE', 'ko').format(date);
    final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

    // 하단 네비게이션 바를 덮지 않도록 패딩 추가
    return DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Material(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: Column(
              children: [
              // 드래그 핸들
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isProgramType
                                  ? Icons.widgets
                                  : isLessonType ? Icons.school : Icons.sports_golf,
                                color: isCancelled 
                                  ? Colors.grey[600]
                                  : isProgramType
                                    ? Colors.purple[600]
                                    : isLessonType ? Colors.orange[600] : Colors.blue[600],
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isProgramType
                                    ? '프로그램 예약'
                                    : isLessonType 
                                      ? '${reservation['station']} 프로 레슨' 
                                      : '${reservation['station']}번 타석',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[900],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00A86B).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '오늘',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF00A86B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),

            // 내용
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // OTP (타석/프로그램만, 취소되지 않은 경우, 예약이 끝나지 않은 경우)
                    if (!isLessonType && !isCancelled && _currentOTP != null && !_isReservationEnded()) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[500]!, Colors.blue[700]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_open, color: Colors.white, size: 28),
                                const SizedBox(width: 12),
                                Text(
                                  '타석 개방 코드',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _currentOTP!,
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.blue[800],
                                      letterSpacing: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer, color: Colors.white70, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '5분간 유효 • 타석 PC에 입력하세요',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 셀프 타석이동 버튼
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => ReservationSelfTsMove.handleSelfMove(
                            context, 
                            widget.reservation,
                            onMoveSuccess: (String newReservationId, int newTsId) {
                              _handleStationMoveSuccess(newReservationId, newTsId);
                            },
                          ),
                          icon: Icon(Icons.swap_horiz),
                          label: Text(
                            '셀프 타석이동',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else if (!isLessonType && !isCancelled && _isReservationEnded()) ...[
                      // 예약이 끝난 경우 만족도 평가 표시
                      SatisfactionRatingWidget(
                        reservationId: reservation['reservationId'] ?? '',
                        onSubmit: (rating, feedback) async {
                          // TODO: DB 저장 로직 구현
                          print('만족도 평가 - 예약ID: ${reservation['reservationId']}, 평점: $rating, 피드백: $feedback');
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // 시간 정보
                    _buildInfoRow(
                      icon: Icons.access_time,
                      title: '예약 시간',
                      content: '${reservation['startTime']} - ${reservation['endTime']}',
                    ),
                    
                    // 프로그램 구성 정보
                    if (isProgramType) ...[
                      const SizedBox(height: 16),
                      _buildProgramDetails(reservation),
                      const SizedBox(height: 16),
                    ] else ...[
                      const SizedBox(height: 16),
                    ],
                    
                    // 상태
                    _buildInfoRow(
                      icon: Icons.info_outline,
                      title: '상태',
                      content: reservation['status'],
                      contentColor: _getStatusColor(reservation['status']),
                    ),
                    
                    // 그룹 레슨인 경우
                    if (reservation['isGrouped'] == true) ...[
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        icon: Icons.group,
                        title: '그룹 레슨',
                        content: '${reservation['groupCount']}명',
                      ),
                    ],
                    
                    // 금액 (타석만)
                    if (!isLessonType && !isProgramType && (reservation['amount'] ?? 0) > 0) ...[
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        icon: Icons.attach_money,
                        title: '금액',
                        content: '${NumberFormat('#,###').format(reservation['amount'] ?? 0)}원',
                        contentColor: Colors.green[600],
                      ),
                    ],
                  
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // 배너 광고
            if (_isBannerAdLoaded && _bannerAd != null)
              Container(
                width: double.infinity,
                height: _bannerAd!.size.height.toDouble(),
                color: Colors.white,
                child: AdWidget(ad: _bannerAd!),
              ),

            // 하단 버튼 영역
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  // 취소 버튼 (과거가 아니고 취소되지 않은 경우만)
                  if (!isPast && !isCancelled) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoadingCancel ? null : _showCancelConfirmation,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.red[400]!, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoadingCancel
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              '예약 취소',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  
                  // 확인 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A86B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
              ],
            ),
          );
        },
      );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String content,
    Color? contentColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: contentColor ?? Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgramDetails(Map<String, dynamic> reservation) {
    final programDetails = reservation['programDetails'];
    if (programDetails == null) return const SizedBox.shrink();
    
    final tsReservations = List<Map<String, dynamic>>.from(programDetails['tsReservations'] ?? []);
    final lessonReservations = List<Map<String, dynamic>>.from(programDetails['lessonReservations'] ?? []);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.widgets, size: 20, color: Colors.purple[600]),
              const SizedBox(width: 8),
              Text(
                '프로그램 구성',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 타석 정보
          if (tsReservations.isNotEmpty) ...[
            _buildProgramSection(
              title: '타석 예약',
              icon: Icons.sports_golf,
              color: Colors.blue[600]!,
              items: tsReservations,
              itemBuilder: (ts) => '${ts['station']}번 타석 (${ts['startTime']} - ${ts['endTime']})',
            ),
            if (lessonReservations.isNotEmpty) const SizedBox(height: 12),
          ],
          
          // 레슨 정보
          if (lessonReservations.isNotEmpty) ...[
            _buildProgramSection(
              title: '레슨 예약',
              icon: Icons.school,
              color: Colors.orange[600]!,
              items: lessonReservations,
              itemBuilder: (lesson) => '${lesson['station']} 프로 (${lesson['startTime']} - ${lesson['endTime']})',
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildProgramSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) itemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 22, bottom: 4),
          child: Text(
            '• ${itemBuilder(item)}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        )),
      ],
    );
  }

  Future<int> _getTabBalance(String tabKey) async {
    print('');
    print('🔍 탭별 잔액 조회 디버깅');
    print('탭 키: $tabKey');
    
    int balance = 0;
    switch (tabKey) {
      case 'credit':
        balance = await _getCurrentBalance();
        print('선불크레딧 잔액: $balance원');
        break;
      case 'time':
        balance = await _getCurrentTimeBalance();
        print('시간권 잔액: $balance분');
        break;
      case 'lesson':
        balance = await _getCurrentLessonBalance();
        print('레슨권 잔액: $balance분');
        break;
      default:
        balance = 0;
        print('알 수 없는 탭: $tabKey');
    }
    
    print('최종 잔액 반환: $balance');
    print('');
    return balance;
  }

  void _showPolicyInfo(Map<String, dynamic> tabInfo) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(0),
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.policy,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '환불 정책 안내 (${tabInfo['type']})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
        ),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 실제 정책 목록 표시
              if (_currentTabPolicyInfo?['policies'] != null)
                ...(_currentTabPolicyInfo!['policies'] as List<String>).map((policy) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        Expanded(
                          child: Text(
                            policy,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '확인',
              style: TextStyle(
                color: Colors.blue[600],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 발급 쿠폰 취소 미리보기 조회
  Future<Map<String, dynamic>> _getIssuedCouponPreview() async {
    try {
      final reservation = widget.reservation;
      final reservationType = reservation['type'];
      
      if (reservationType == '타석') {
        final reservationId = reservation['reservationId']?.toString() ?? '';
        if (reservationId.isNotEmpty) {
          return await TsReservationCancelService.previewIssuedCoupons(reservationId);
        }
      } else if (reservationType == '레슨') {
        final lsId = reservation['lsId']?.toString() ?? '';
        if (lsId.isNotEmpty) {
          return await LsReservationCancelService.previewIssuedCoupons(lsId);
        }
      } else if (reservationType == '프로그램') {
        // 프로그램 예약은 개별 타석/레슨에서 처리되므로 통합 미리보기 필요
        return await _getProgramIssuedCouponPreview();
      }
      
      return {'success': true, 'coupons': [], 'message': '취소할 발급 쿠폰이 없습니다'};
    } catch (e) {
      print('❌ 발급 쿠폰 미리보기 조회 오류: $e');
      return {'success': false, 'coupons': [], 'message': '발급 쿠폰 정보를 조회할 수 없습니다'};
    }
  }

  /// 프로그램 예약 발급 쿠폰 미리보기 (타석+레슨 통합)
  Future<Map<String, dynamic>> _getProgramIssuedCouponPreview() async {
    try {
      final reservation = widget.reservation;
      final programDetails = reservation['programDetails'] ?? {};
      final tsReservations = programDetails['tsReservations'] ?? [];
      final lessonReservations = programDetails['lessonReservations'] ?? [];
      
      List<Map<String, dynamic>> allCoupons = [];
      
      // 타석 예약 발급 쿠폰 조회
      for (final ts in tsReservations) {
        final reservationId = ts['reservationId']?.toString() ?? '';
        if (reservationId.isNotEmpty) {
          final preview = await TsReservationCancelService.previewIssuedCoupons(reservationId);
          if (preview['success'] == true) {
            allCoupons.addAll(List<Map<String, dynamic>>.from(preview['coupons'] ?? []));
          }
        }
      }
      
      // 레슨 예약 발급 쿠폰 조회
      for (final lesson in lessonReservations) {
        final lsId = lesson['lsId']?.toString() ?? '';
        if (lsId.isNotEmpty) {
          final preview = await LsReservationCancelService.previewIssuedCoupons(lsId);
          if (preview['success'] == true) {
            allCoupons.addAll(List<Map<String, dynamic>>.from(preview['coupons'] ?? []));
          }
        }
      }
      
      // 중복 제거 (coupon_id 기준)
      final uniqueCoupons = <String, Map<String, dynamic>>{};
      for (final coupon in allCoupons) {
        final couponId = coupon['coupon_id']?.toString() ?? '';
        if (couponId.isNotEmpty) {
          uniqueCoupons[couponId] = coupon;
        }
      }
      
      return {
        'success': true,
        'coupons': uniqueCoupons.values.toList(),
        'message': uniqueCoupons.isEmpty ? '취소할 발급 쿠폰이 없습니다' : '${uniqueCoupons.length}개의 발급 쿠폰이 취소됩니다'
      };
    } catch (e) {
      print('❌ 프로그램 발급 쿠폰 미리보기 오류: $e');
      return {'success': false, 'coupons': [], 'message': '발급 쿠폰 정보를 조회할 수 없습니다'};
    }
  }

  /// 쿠폰 복구 미리보기 조회
  Future<Map<String, dynamic>> _getCouponPreview() async {
    try {
      final reservation = widget.reservation;
      final reservationType = reservation['type'];
      
      if (reservationType == '타석') {
        final reservationId = reservation['reservationId']?.toString() ?? '';
        if (reservationId.isNotEmpty) {
          return await TsReservationCancelService.previewDiscountCoupons(reservationId);
        }
      } else if (reservationType == '레슨') {
        final lsId = reservation['lsId']?.toString() ?? '';
        if (lsId.isNotEmpty) {
          return await LsReservationCancelService.previewDiscountCoupons(lsId);
        }
      } else if (reservationType == '프로그램') {
        // 프로그램 예약은 개별 타석/레슨에서 처리되므로 통합 미리보기 필요
        return await _getProgramCouponPreview();
      }
      
      return {'success': true, 'coupons': [], 'message': '복구할 쿠폰이 없습니다'};
    } catch (e) {
      print('❌ 쿠폰 미리보기 조회 오류: $e');
      return {'success': false, 'coupons': [], 'message': '쿠폰 정보를 조회할 수 없습니다'};
    }
  }

  /// 프로그램 예약 쿠폰 미리보기 (타석+레슨 통합)
  Future<Map<String, dynamic>> _getProgramCouponPreview() async {
    try {
      final reservation = widget.reservation;
      final programDetails = reservation['programDetails'] ?? {};
      final tsReservations = programDetails['tsReservations'] ?? [];
      final lessonReservations = programDetails['lessonReservations'] ?? [];
      
      List<Map<String, dynamic>> allCoupons = [];
      
      // 타석 예약 쿠폰 조회
      for (final ts in tsReservations) {
        final reservationId = ts['reservationId']?.toString() ?? '';
        if (reservationId.isNotEmpty) {
          final preview = await TsReservationCancelService.previewDiscountCoupons(reservationId);
          if (preview['success'] == true) {
            allCoupons.addAll(List<Map<String, dynamic>>.from(preview['coupons'] ?? []));
          }
        }
      }
      
      // 레슨 예약 쿠폰 조회
      for (final lesson in lessonReservations) {
        final lsId = lesson['lsId']?.toString() ?? '';
        if (lsId.isNotEmpty) {
          final preview = await LsReservationCancelService.previewDiscountCoupons(lsId);
          if (preview['success'] == true) {
            allCoupons.addAll(List<Map<String, dynamic>>.from(preview['coupons'] ?? []));
          }
        }
      }
      
      // 중복 제거 (coupon_id 기준)
      final uniqueCoupons = <String, Map<String, dynamic>>{};
      for (final coupon in allCoupons) {
        final couponId = coupon['coupon_id']?.toString() ?? '';
        if (couponId.isNotEmpty) {
          uniqueCoupons[couponId] = coupon;
        }
      }
      
      return {
        'success': true,
        'coupons': uniqueCoupons.values.toList(),
        'message': uniqueCoupons.isEmpty ? '복구할 쿠폰이 없습니다' : '${uniqueCoupons.length}개의 쿠폰이 미사용 상태로 복구됩니다'
      };
    } catch (e) {
      print('❌ 프로그램 쿠폰 미리보기 오류: $e');
      return {'success': false, 'coupons': [], 'message': '쿠폰 정보를 조회할 수 없습니다'};
    }
  }

  void _showCancelConfirmation() async {
    if (!mounted) return;
    
    final paymentTabs = _getPaymentTabs();
    final isComplexReservation = paymentTabs.length > 1;

    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          content: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 복합 예약인 경우에만 탭 표시
                  if (isComplexReservation) ...[
                    Container(
                      key: ValueKey('tab_container_$_currentTabIndex'),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          // 탭 바 (수동 구현)
                          Container(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: paymentTabs.asMap().entries.map((entry) {
                                final index = entry.key;
                                final tab = entry.value;
                                final isSelected = index == _currentTabIndex;
                                
                                return Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        print('💥 수동 탭 클릭: $index');
                                        if (_currentTabIndex != index) {
                                          print('💥 탭 변경 시작: $_currentTabIndex → $index');
                                          
                                          // 다이얼로그 상태 업데이트
                                          setDialogState(() {
                                            _currentTabIndex = index;
                                            // 탭 변경 시 이전 데이터 초기화
                                            _currentTabPolicyInfo = null;
                                            _currentTabBalance = null;
                                          });
                                          
                                          // 메인 위젯 상태도 업데이트
                                          setState(() {
                                            _currentTabIndex = index;
                                            _currentTabPolicyInfo = null;
                                            _currentTabBalance = null;
                                          });
                                          
                                          print('💥 탭 변경 완료: $_currentTabIndex');
                                          
                                          // 새로운 탭 데이터 로드
                                          await _loadTabData();
                                          
                                          // 데이터 로드 후 다시 UI 업데이트
                                          if (mounted) {
                                            setDialogState(() {});
                                            setState(() {});
                                          }
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isSelected ? tab['color'][100] : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          border: isSelected ? Border.all(color: tab['color'][300]!) : null,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(tab['icon'], size: 16, color: tab['color'][600]),
                                            const SizedBox(width: 6),
                                            Text(
                                              tab['type'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                color: tab['color'][600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          // 탭 내용
                          Container(
                            key: ValueKey('tab_content_$_currentTabIndex'),
                            padding: const EdgeInsets.all(16),
                            child: _buildTabContent(),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // 단일 예약인 경우 탭 없이 바로 내용 표시
                    _buildTabContent(),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '돌아가기',
                style: TextStyle(
                  color: Colors.grey[700], 
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelReservation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text('예약 취소', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelReservation() async {
    setState(() {
      _isLoadingCancel = true;
    });
    
    try {
      final reservation = widget.reservation;
      final reservationType = reservation['type'];
      final reservationId = reservation['reservationId']?.toString() ?? '';
      
      if (reservationId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('예약 ID를 찾을 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      bool success = false;
      String message = '';
      
      if (reservationType == '타석') {
        // 순수 타석 예약 취소
        final reservationDate = DateTime.parse(reservation['date']);
        final startTimeStr = reservation['startTime'];
        final startDateTime = DateTime.parse('${reservation['date']} $startTimeStr:00');
        
        success = await TsReservationCancelService.cancelTsReservation(
          reservationId: reservationId,
          context: context,
          reservationStartTime: startDateTime,
        );
        message = success ? '타석 예약이 성공적으로 취소되었습니다.' : '타석 예약 취소에 실패했습니다.';
        
      } else if (reservationType == '레슨') {
        // 순수 레슨 예약 취소
        final lsId = reservation['lsId']?.toString() ?? '';
        if (lsId.isEmpty) {
          message = 'LS_ID를 찾을 수 없습니다.';
        } else {
          final reservationDate = DateTime.parse(reservation['date']);
          final startTimeStr = reservation['startTime'];
          final startDateTime = DateTime.parse('${reservation['date']} $startTimeStr:00');
          
          success = await LsReservationCancelService.cancelLsReservation(
            lsId: lsId,
            context: context,
            reservationStartTime: startDateTime,
          );
          message = success ? '레슨 예약이 성공적으로 취소되었습니다.' : '레슨 예약 취소에 실패했습니다.';
        }
        
      } else if (reservationType == '프로그램') {
        // 프로그램 예약 취소
        final programId = reservation['programId'] ?? '';
        if (programId.isNotEmpty) {
          final reservationDate = DateTime.parse(reservation['date']);
          final startTimeStr = reservation['startTime'];
          final startDateTime = DateTime.parse('${reservation['date']} $startTimeStr:00');
          
          success = await SpReservationCancelService.cancelProgramReservation(
            programId: programId,
            context: context,
            reservationStartTime: startDateTime,
          );
          message = success ? '프로그램 예약이 성공적으로 취소되었습니다.' : '프로그램 예약 취소에 실패했습니다.';
        } else {
          message = '프로그램 ID를 찾을 수 없습니다.';
        }
        
      } else {
        message = '알 수 없는 예약 타입입니다.';
      }
      
      // 결과 표시
      if (success) {
        print('✅ 예약 취소 성공: $message');
      } else {
        print('❌ 예약 취소 실패: $message');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        
        if (success) {
          Navigator.of(context).pop(true); // 취소 성공 시 true 반환
        }
      }
    } catch (e) {
      print('❌ 예약 취소 중 예외 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('예약 취소 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCancel = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '예약완료':
        return Colors.blue[600]!;
      case '결제완료':
        return Colors.green[600]!;
      case '취소':
        return Colors.red[600]!;
      case '노쇼':
        return Colors.orange[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  bool _isReservationEnded() {
    try {
      final now = DateTime.now();
      final dateStr = widget.reservation['date'];
      final endTimeStr = widget.reservation['endTime'];
      final endDateTime = DateTime.parse('$dateStr $endTimeStr:00');
      return now.isAfter(endDateTime);
    } catch (e) {
      print('Error checking reservation end time: $e');
      return false;
    }
  }


  void _confirmStationMove(BuildContext context, String newTsId, String newStartTime, String newEndTime, Map<String, dynamic> reservation) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '타석 이동 확인',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '다음과 같이 이동하시겠습니까?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              
              // 변경 전/후 비교
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.arrow_back, color: Colors.red[600], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '현재: ${reservation['station']}번 타석',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.arrow_forward, color: Colors.green[600], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '이동: ${newTsId}번 타석 ($newStartTime - $newEndTime)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleStationMove(context, newTsId, newStartTime, newEndTime, reservation);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '이동하기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleStationMove(BuildContext context, String newTsId, String newStartTime, String newEndTime, Map<String, dynamic> reservation) async {
    // TODO: 실제 타석 이동 API 호출 구현
    print('=== 타석 이동 실행 ===');
    print('예약 ID: ${reservation['reservationId']}');
    print('기존 타석: ${reservation['station']}번');
    print('새 타석: ${newTsId}번');
    print('새 시간: $newStartTime - $newEndTime');
    
    // 시간 비중 계산
    await _calculateTimeRatio(reservation, newStartTime, newEndTime, newTsId);
    
    // 위젯이 여전히 마운트되어 있는지 확인
    if (!context.mounted) return;
    
    // 성공 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${newTsId}번 타석으로 이동이 완료되었습니다.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _calculateTimeRatio(Map<String, dynamic> reservation, String newStartTime, String newEndTime, String newTsId) async {
    try {
      print('\n=== 시간 비중 계산 ===');
      
      // 원래 예약 시간 계산
      final originalStartTime = reservation['startTime'];
      final originalEndTime = reservation['endTime'];
      final originalStart = DateTime.parse('2000-01-01 $originalStartTime:00');
      final originalEnd = DateTime.parse('2000-01-01 $originalEndTime:00');
      final originalDurationMinutes = originalEnd.difference(originalStart).inMinutes;
      
      // 새로운 예약 시간 계산
      final newStart = DateTime.parse('2000-01-01 $newStartTime:00');
      final newEnd = DateTime.parse('2000-01-01 $newEndTime:00');
      final newDurationMinutes = newEnd.difference(newStart).inMinutes;
      
      // 타석별 비중 계산
      final originalTsId = int.parse(reservation['station'].toString());
      final newTsIdInt = int.parse(newTsId);
      
      // 실제 시간 구간별 비중 계산
      final moveTime = DateTime.parse('2000-01-01 $newStartTime:00');
      final originalEndDateTime = DateTime.parse('2000-01-01 $originalEndTime:00');
      final originalStartDateTime = DateTime.parse('2000-01-01 $originalStartTime:00');
      
      int originalTsMinutes;
      int newTsMinutes;
      
      // 완전한 타석 이동인지 확인 (시간이 동일하면 완전한 타석 이동)
      if (originalStartTime == newStartTime && originalEndTime == newEndTime) {
        // 완전한 타석 이동: 전체 시간을 새 타석으로 이동
        originalTsMinutes = 0;
        newTsMinutes = originalDurationMinutes;
      } else {
        // 부분적 타석 이동: 시간 기준으로 분할
        // 기존 타석 사용 시간 (원래 시작 ~ 이동 시작)
        originalTsMinutes = moveTime.difference(originalStartDateTime).inMinutes;
        // 새 타석 사용 시간 (이동 시작 ~ 원래 종료)
        newTsMinutes = originalEndDateTime.difference(moveTime).inMinutes;
      }
      
      // 전체 시간 대비 비중 계산
      double originalTsRatio;
      double newTsRatio;
      
      if (originalDurationMinutes == 0) {
        // 0분인 경우 이미 취소된 예약이므로 처리 불가
        print('⚠️ 기존 예약이 이미 0분 상태입니다. 타석 이동을 할 수 없습니다.');
        return;
      } else {
        originalTsRatio = (originalTsMinutes / originalDurationMinutes * 100);
        newTsRatio = (newTsMinutes / originalDurationMinutes * 100);
      }
      
      print('원래 예약: $originalStartTime - $originalEndTime (${originalDurationMinutes}분)');
      print('새 예약: $newStartTime - $newEndTime (${newDurationMinutes}분)');
      print('');
      print('시간 비중 계산:');
      print('  ts_id($originalTsId): ${originalTsRatio.toStringAsFixed(1)}% (${originalTsMinutes}분)');
      print('  ts_id($newTsIdInt): ${newTsRatio.toStringAsFixed(1)}% (${newTsMinutes}분)');
      print('');
      
      // 새로운 reservation_id 생성
      final originalReservationId = reservation['reservationId'];
      final newReservationId = originalReservationId.replaceFirst('_${originalTsId}_', '_${newTsIdInt}_');
      
      // 시간 비중에 따른 가격 재계산
      await _calculatePriceByTimeRatio(reservation, originalTsRatio, newTsRatio, originalTsMinutes, newTsMinutes, originalTsId, newTsIdInt, originalReservationId, newReservationId, newStartTime, newEndTime);
      print('=== 시간 비중 계산 완료 ===\n');
      
    } catch (e) {
      print('시간 비중 계산 오류: $e');
    }
  }

  Future<void> _calculatePriceByTimeRatio(Map<String, dynamic> reservation, double originalTsRatio, double newTsRatio, int originalTsMinutes, int newTsMinutes, int originalTsId, int newTsIdInt, String originalReservationId, String newReservationId, String newStartTime, String newEndTime) async {
    try {
      print('=== 가격 정보 시간비중별 재계산 ===');
      
      // v2_bills에서 원본 금액 조회 (v2_priced_TS는 이전 이동으로 0이 될 수 있음)
      final billData = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': originalReservationId}
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'DESC'}] // 가장 최신 bill 선택
      );
      
      // 디버깅: bill 조회 결과 확인
      if (billData.isNotEmpty) {
        print('=== v2_bills 조회 결과 ===');
        final bill = billData.first;
        bill.forEach((key, value) {
          print('  $key: $value');
        });
        print('');
      } else {
        print('=== v2_bills 조회 결과: 데이터 없음 (reservation_id: $originalReservationId) ===');
      }
      
      // v2_priced_TS에서 기타 정보 조회
      final pricedTsData = await ApiService.getData(
        table: 'v2_priced_TS',
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': originalReservationId}
        ]
      );
      
      // 디버깅: 조회된 데이터 확인
      if (pricedTsData.isNotEmpty) {
        print('=== v2_priced_TS 조회 결과 ===');
        final priceData = pricedTsData.first;
        priceData.forEach((key, value) {
          print('  $key: $value');
        });
        print('');
      }
      
      int totalAmt = 0;
      int termDiscount = 0;
      int couponDiscount = 0;
      int totalDiscount = 0;
      int netAmt = 0;
      int discountMin = 0;
      int normalMin = 0;
      int extrachargeMin = 0;
      int tsMin = 0;
      dynamic billMin = null;
      dynamic billMinId = null;
      int billDiscountMin = 0;
      int billTotalMin = 0;
      
      // bill에서 실제 금액 정보 가져오기
      String? actualBillId = null;
      if (billData.isNotEmpty) {
        final bill = billData.first;
        actualBillId = bill['bill_id'].toString(); // 실제 사용할 bill_id 저장
        totalAmt = (bill['bill_totalamt'] ?? 0).abs(); // 음수를 양수로 변환
        netAmt = totalAmt;
        
        // v2_priced_TS에서 기타 정보 가져오기
        if (pricedTsData.isNotEmpty) {
          final priceData = pricedTsData.first;
          termDiscount = priceData['term_discount'] ?? 0;
          couponDiscount = priceData['coupon_discount'] ?? 0;
          totalDiscount = priceData['total_discount'] ?? 0;
          discountMin = priceData['discount_min'] ?? 0;
          normalMin = priceData['normal_min'] ?? 0;
          extrachargeMin = priceData['extracharge_min'] ?? 0;
          tsMin = priceData['ts_min'] ?? 0;
          billMin = priceData['bill_min'];
          billMinId = priceData['bill_min_id'];
          billDiscountMin = priceData['bill_discount_min'] != null ? (priceData['bill_discount_min'] as num).toInt() : 0;
          billTotalMin = priceData['bill_total_min'] != null ? (priceData['bill_total_min'] as num).toInt() : 0;
        }
      } else if (pricedTsData.isNotEmpty) {
        // bill이 없으면 v2_priced_TS에서 가져오기
        final priceData = pricedTsData.first;
        totalAmt = priceData['total_amt'] ?? 0;
        termDiscount = priceData['term_discount'] ?? 0;
        couponDiscount = priceData['coupon_discount'] ?? 0;
        totalDiscount = priceData['total_discount'] ?? 0;
        netAmt = priceData['net_amt'] ?? 0;
        discountMin = priceData['discount_min'] ?? 0;
        normalMin = priceData['normal_min'] ?? 0;
        extrachargeMin = priceData['extracharge_min'] ?? 0;
        tsMin = priceData['ts_min'] ?? 0;
        billMin = priceData['bill_min'];
        billMinId = priceData['bill_min_id'];
        billDiscountMin = priceData['bill_discount_min'] != null ? (priceData['bill_discount_min'] as num).toInt() : 0;
        billTotalMin = priceData['bill_total_min'] != null ? (priceData['bill_total_min'] as num).toInt() : 0;
      } else {
        // 조회 실패 시 reservation에서 가져오기
        totalAmt = reservation['amount'] ?? 0;
        netAmt = totalAmt;
        normalMin = originalTsMinutes + newTsMinutes;
        tsMin = normalMin;
      }
      
      print('원본 가격정보:');
      print('  total_amt: $totalAmt');
      print('  term_discount: $termDiscount');
      print('  coupon_discount: $couponDiscount');
      print('  total_discount: $totalDiscount');
      print('  net_amt: $netAmt');
      print('  discount_min: $discountMin | normal_min: $normalMin | extracharge_min: $extrachargeMin | ts_min: $tsMin | bill_min: null');
      print('');
      
      // 할인쿠폰 조회
      await _fetchCouponsForReservation(originalReservationId);
      
      // 기존 타석 비중별 가격 계산
      final originalTsAmt = (totalAmt * originalTsRatio / 100).round();
      final originalTsCouponDiscount = (couponDiscount * originalTsRatio / 100).round();
      final originalTsNetAmt = originalTsAmt - originalTsCouponDiscount;
      
      // 새 타석 비중별 가격 계산 (반올림 오차 방지를 위해 나머지로 계산)
      final newTsAmt = totalAmt - originalTsAmt;
      final newTsCouponDiscount = couponDiscount - originalTsCouponDiscount;
      final newTsNetAmt = newTsAmt - newTsCouponDiscount;
      
      print('기존 타석 예약 ID: $originalReservationId - ${originalTsRatio.toStringAsFixed(1)}% (${originalTsMinutes}분):');
      print('  total_amt: $originalTsAmt');
      print('  term_discount: 0');
      print('  coupon_discount: $originalTsCouponDiscount');
      print('  total_discount: $originalTsCouponDiscount');
      print('  net_amt: $originalTsNetAmt');
      print('  discount_min: 0 | normal_min: $originalTsMinutes | extracharge_min: 0 | ts_min: $originalTsMinutes | bill_min: null');
      print('');
      
      print('새 타석 예약 ID: $newReservationId - ${newTsRatio.toStringAsFixed(1)}% (${newTsMinutes}분):');
      print('  total_amt: $newTsAmt');
      print('  term_discount: 0');
      print('  coupon_discount: $newTsCouponDiscount');
      print('  total_discount: $newTsCouponDiscount');
      print('  net_amt: $newTsNetAmt');
      print('  discount_min: 0 | normal_min: $newTsMinutes | extracharge_min: 0 | ts_min: $newTsMinutes | bill_min: null');
      print('');
      
      // DB 업데이트를 위한 전체 데이터 준비
      if (pricedTsData.isNotEmpty) {
        final originalData = pricedTsData.first;
        
        print('=== DB 업데이트 준비 ===');
        print('[기존 예약 업데이트 - v2_priced_TS]');
        print('  reservation_id: $originalReservationId');
        print('  branch_id: ${originalData['branch_id']}');
        print('  ts_id: ${originalData['ts_id']}');
        print('  ts_date: ${originalData['ts_date']}');
        print('  ts_start: ${originalData['ts_start']}');
        print('  ts_end: $newStartTime:00 (변경됨)'); // 새로운 이용시간의 시작시간
        print('  ts_payment_method: ${originalData['ts_payment_method']}');
        print('  ts_status: ${originalData['ts_status']}');
        print('  member_id: ${originalData['member_id']}');
        print('  member_type: ${originalData['member_type']}');
        print('  member_name: ${originalData['member_name']}');
        print('  member_phone: ${originalData['member_phone']}');
        print('  total_amt: $originalTsAmt (${originalTsRatio.toStringAsFixed(1)}%)');
        print('  term_discount: ${(termDiscount * originalTsRatio / 100).round()}');
        print('  coupon_discount: $originalTsCouponDiscount');
        print('  total_discount: ${(totalDiscount * originalTsRatio / 100).round()}');
        print('  net_amt: $originalTsNetAmt');
        print('  discount_min: ${originalTsRatio == 0 ? 0 : discountMin}'); // 0%면 0, 아니면 원본값
        print('  normal_min: $originalTsMinutes');
        print('  extracharge_min: ${originalTsRatio == 0 ? 0 : extrachargeMin}'); // 0%면 0, 아니면 원본값
        print('  ts_min: $originalTsMinutes');
        print('  bill_min: ${originalData['bill_min']}');
        print('  day_of_week: ${originalData['day_of_week']}');
        print('  bill_id: ${originalData['bill_id'] ?? 'null'}');
        print('  bill_min_id: ${originalData['bill_min_id'] ?? 'null'}');
        print('  bill_game_id: ${originalData['bill_game_id'] ?? 'null'}');
        print('  program_id: ${originalData['program_id']}');
        print('  program_name: ${originalData['program_name']}');
        print('');
        
        print('[새 예약 생성 - v2_priced_TS]');
        print('  reservation_id: $newReservationId');
        print('  branch_id: ${originalData['branch_id']}');
        print('  ts_id: $newTsIdInt');
        print('  ts_date: ${originalData['ts_date']}');
        print('  ts_start: $newStartTime:00');
        print('  ts_end: $newEndTime:00');
        print('  ts_payment_method: ${originalData['ts_payment_method']}');
        print('  ts_status: ${originalData['ts_status']}');
        print('  member_id: ${originalData['member_id']}');
        print('  member_type: ${originalData['member_type']}');
        print('  member_name: ${originalData['member_name']}');
        print('  member_phone: ${originalData['member_phone']}');
        print('  total_amt: $newTsAmt (${newTsRatio.toStringAsFixed(1)}%)');
        print('  term_discount: ${(termDiscount * newTsRatio / 100).round()}');
        print('  coupon_discount: $newTsCouponDiscount');
        print('  total_discount: ${(totalDiscount * newTsRatio / 100).round()}');
        print('  net_amt: $newTsNetAmt');
        print('  discount_min: ${newTsRatio == 100 ? discountMin : 0}'); // 100%면 원본값, 아니면 0
        print('  normal_min: $newTsMinutes');
        print('  extracharge_min: ${newTsRatio == 100 ? extrachargeMin : 0}'); // 100%면 원본값, 아니면 0
        print('  ts_min: $newTsMinutes');
        print('  bill_min: ${originalData['bill_min']}');
        print('  day_of_week: ${originalData['day_of_week']}');
        final billId = originalData['bill_id'];
        final billMinId = originalData['bill_min_id'];
        final billGameId = originalData['bill_game_id'];
        print('  bill_id: ${billId != null ? '${billId}*확인예정' : 'null'}');
        print('  bill_min_id: ${billMinId != null ? '${billMinId}*확인예정' : 'null'}');
        print('  bill_game_id: ${billGameId != null ? '${billGameId}*확인예정' : 'null'}');
        print('  program_id: ${originalData['program_id']}');
        print('  program_name: ${originalData['program_name']}');
        print('');
        
        // v2_discount_coupon 업데이트 계획 출력
        print('[v2_discount_coupon 업데이트 계획]');
        // 해당 예약과 관련된 쿠폰 필터링
        final allCoupons = await ApiService.getData(
          table: 'v2_discount_coupon',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': 'test'}
          ]
        );
        
        final relatedCoupons = allCoupons.where((coupon) => 
          coupon['reservation_id_issued'] == originalReservationId || 
          coupon['reservation_id_used'] == originalReservationId
        ).toList();
        
        if (relatedCoupons.isEmpty) {
          print('  업데이트할 쿠폰 없음');
        } else {
          for (final coupon in relatedCoupons) {
            final couponId = coupon['coupon_id'];
            final oldIssued = coupon['reservation_id_issued'] ?? '';
            final oldUsed = coupon['reservation_id_used'] ?? '';
            final newIssued = oldIssued == originalReservationId ? newReservationId : oldIssued;
            final newUsed = oldUsed == originalReservationId ? newReservationId : oldUsed;
            
            // 변경되는 것만 출력
            bool hasChanges = false;
            print('  쿠폰 ID: $couponId');
            
            if (oldIssued == originalReservationId) {
              print('    reservation_id_issued: "$oldIssued" → "$newIssued"');
              hasChanges = true;
            }
            
            if (oldUsed == originalReservationId) {
              print('    reservation_id_used: "$oldUsed" → "$newUsed"');
              hasChanges = true;
            }
            
            if (!hasChanges) {
              print('    변경사항 없음');
            }
          }
        }
        // v2_bills 업데이트 계획 출력
        if (originalData['bill_id'] != null && originalData['bill_id'].toString().isNotEmpty && originalData['bill_id'] != '') {
          await _prepareBillsUpdate(originalData, originalTsAmt, newTsAmt, (totalDiscount * originalTsRatio / 100).round(), (totalDiscount * newTsRatio / 100).round(), originalReservationId, newReservationId, newTsIdInt, newStartTime, newEndTime);
        }
        
        // v2_bill_times 업데이트 계획 출력
        if (originalData['bill_min_id'] != null && originalData['bill_min_id'].toString().isNotEmpty && originalData['bill_min_id'] != '') {
          await _prepareBillTimesUpdate(originalData, originalTsRatio, newTsRatio, originalReservationId, newReservationId, newTsIdInt, newStartTime, newEndTime);
        }
        
        print('=== DB 업데이트 준비 완료 ===\n');
        
        // actualBillId가 있으면 originalData에 설정
        if (actualBillId != null) {
          originalData['bill_id'] = actualBillId;
        }
        
        // 셀프 타석이동 코드가 ReservationSelfTsMove로 분리되었으므로 주석 처리
        // 실제 DB 업데이트는 ReservationSelfTsMove에서 처리
      }
      
    } catch (e) {
      print('가격 재계산 오류: $e');
    }
  }

  Future<void> _prepareBillsUpdate(Map<String, dynamic> originalData, int originalTsAmt, int newTsAmt, int originalDeduction, int newDeduction, String originalReservationId, String newReservationId, int newTsId, String newStartTime, String newEndTime) async {
    try {
      print('[v2_bills 업데이트 계획]');
      
      final billId = originalData['bill_id'];
      
      // 현재 bill에서 contract_history_id 조회
      final currentBills = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'bill_id', 'operator': '=', 'value': billId}
        ]
      );
      
      if (currentBills.isEmpty) {
        print('  오류: bill_id $billId를 찾을 수 없음');
        return;
      }
      
      final currentBill = currentBills.first;
      final contractHistoryId = currentBill['contract_history_id'];
      print('기존 bill 정보 (bill_id: $billId):');
      print('  contract_history_id: $contractHistoryId');
      print('  bill_totalamt: ${currentBill['bill_totalamt']} → ${-originalTsAmt} (${((originalTsAmt / currentBill['bill_totalamt'] * 100)).toStringAsFixed(1)}%)');
      print('  bill_deduction: ${currentBill['bill_deduction']} → $originalDeduction');
      print('  bill_netamt: ${currentBill['bill_netamt']} → ${-(originalTsAmt - originalDeduction)}');
      print('  reservation_id: ${currentBill['reservation_id']} → $originalReservationId (변경없음)');
      print('');
      
      // 2. contract_history_id 기준으로 기존 bill_id보다 큰 bills 조회
      final subsequentBills = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_id', 'operator': '>', 'value': billId}
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'ASC'}]
      );
      
      // 기존 bill의 새 잔액 계산 및 업데이트
      int newBalanceAfter = (currentBill['bill_balance_before'] as num).toInt() - (originalTsAmt - originalDeduction);
      print('기존 bill(${billId}) 새 잔액: $newBalanceAfter');
      
      // 기존 bill 업데이트
      await ApiService.updateData(
        table: 'v2_bills',
        data: {
          'bill_balance_after': newBalanceAfter,
        },
        where: [
          {'field': 'bill_id', 'operator': '=', 'value': billId}
        ]
      );
      print('기존 bill 업데이트 완료');

      print('잔액 재계산 대상 bills (contract_history_id: $contractHistoryId, bill_id > $billId):');
      if (subsequentBills.isEmpty) {
        print('  재계산 대상 없음');
      } else {
        int runningBalance = newBalanceAfter;
        print('  시작 잔액: ${runningBalance}');
        
        for (final bill in subsequentBills) {
          final currentBillId = bill['bill_id'];
          final oldBalanceBefore = bill['bill_balance_before'];
          final oldBalanceAfter = bill['bill_balance_after'];
          final billNetAmt = (bill['bill_netamt'] as num).toInt();
          
          final newBalanceBefore = runningBalance;
          final newBalanceAfter = runningBalance + billNetAmt;
          
          print('  bill_id: ${currentBillId}');
          print('    bill_balance_before: $oldBalanceBefore → $newBalanceBefore');
          print('    bill_balance_after: $oldBalanceAfter → $newBalanceAfter');
          
          // 후속 bill 업데이트
          await ApiService.updateData(
            table: 'v2_bills',
            data: {
              'bill_balance_before': newBalanceBefore,
              'bill_balance_after': newBalanceAfter,
            },
            where: [
              {'field': 'bill_id', 'operator': '=', 'value': currentBillId}
            ]
          );
          
          runningBalance = newBalanceAfter;
        }
      }
      print('');
      
      // 3. 새 bill 생성 정보 - 마지막 업데이트된 bill의 balance_after 사용
      int newBillBalanceBefore;
      if (subsequentBills.isNotEmpty) {
        // 후속 bills가 있는 경우: 마지막 후속 bill의 balance_after
        int lastRunningBalance = newBalanceAfter;
        for (final bill in subsequentBills) {
          final billNetAmt = (bill['bill_netamt'] as num).toInt();
          lastRunningBalance += billNetAmt;
        }
        newBillBalanceBefore = lastRunningBalance;
      } else {
        // 후속 bills가 없는 경우: 기존 bill의 새 balance_after
        newBillBalanceBefore = newBalanceAfter;
      }
      final newBillBalanceAfter = newBillBalanceBefore - (newTsAmt - newDeduction);
        
      print('새 bill 생성:');
      print('  branch_id: ${currentBill['branch_id']}');
      print('  member_id: ${currentBill['member_id']}');
      print('  bill_date: ${currentBill['bill_date']}');
      print('  bill_type: ${currentBill['bill_type']}');
      // bill_text에서 타석번호와 시간 모두 새로운 값으로 변경
      final newBillText = '${newTsId}번 타석(${newStartTime} ~ ${newEndTime})';
      print('  bill_text: $newBillText');
      print('  bill_totalamt: ${-newTsAmt}');
      print('  bill_deduction: $newDeduction');
      print('  bill_netamt: ${-(newTsAmt - newDeduction)}');
      print('  bill_timestamp: [현재시간]');
      print('  bill_balance_before: $newBillBalanceBefore');
      print('  bill_balance_after: $newBillBalanceAfter');
      print('  reservation_id: $newReservationId');
      print('  bill_status: ${currentBill['bill_status']}');
      print('  contract_history_id: $contractHistoryId');
      print('  bill_id: [자동채번]');
      print('');
      
    } catch (e) {
      print('bills 업데이트 준비 오류: $e');
    }
  }

  Future<void> _prepareBillTimesUpdate(Map<String, dynamic> originalData, double originalTsRatio, double newTsRatio, String originalReservationId, String newReservationId, int newTsId, String newStartTime, String newEndTime) async {
    try {
      print('[v2_bill_times 업데이트 계획]');
      
      final billMinId = originalData['bill_min_id'];
      
      // 현재 bill_times에서 contract_history_id 조회
      final currentBillTimes = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'bill_min_id', 'operator': '=', 'value': billMinId}
        ]
      );
      
      if (currentBillTimes.isEmpty) {
        print('  오류: bill_min_id $billMinId를 찾을 수 없음');
        return;
      }
      
      final currentBillTime = currentBillTimes.first;
      final contractHistoryId = currentBillTime['contract_history_id'];
      
      // 기존 bill_times의 값들
      final billTotalMin = (currentBillTime['bill_total_min'] ?? 0) as num;
      final billDiscountMin = (currentBillTime['bill_discount_min'] ?? 0) as num;
      final billMin = (currentBillTime['bill_min'] ?? 0) as num;
      
      // 비율에 따라 분할
      final originalBillTotalMin = (billTotalMin * originalTsRatio / 100).round();
      final newBillTotalMin = (billTotalMin * newTsRatio / 100).round();
      final originalBillDiscountMin = (billDiscountMin * originalTsRatio / 100).round();
      final newBillDiscountMin = (billDiscountMin * newTsRatio / 100).round();
      final originalBillMin = (billMin * originalTsRatio / 100).round();
      final newBillMin = (billMin * newTsRatio / 100).round();
      
      print('기존 bill_times 정보 (bill_min_id: $billMinId):');
      print('  contract_history_id: $contractHistoryId');
      print('  bill_total_min: $billTotalMin → $originalBillTotalMin (${originalTsRatio.toStringAsFixed(1)}%)');
      print('  bill_discount_min: $billDiscountMin → $originalBillDiscountMin');
      print('  bill_min: $billMin → $originalBillMin');
      print('  reservation_id: ${currentBillTime['reservation_id']} → $originalReservationId (변경없음)');
      print('');
      
      // 2. contract_history_id 기준으로 기존 bill_min_id보다 큰 bill_times 조회
      final subsequentBillTimes = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_min_id', 'operator': '>', 'value': billMinId}
        ],
        orderBy: [{'field': 'bill_min_id', 'direction': 'ASC'}]
      );
      
      print('잔액 재계산 대상 bill_times (contract_history_id: $contractHistoryId, bill_min_id > $billMinId):');
      if (subsequentBillTimes.isEmpty) {
        print('  재계산 대상 없음');
      } else {
        int runningBalance = (currentBillTime['bill_balance_min_before'] as num).toInt() - originalBillMin;
        print('  기존 bill_times 새 잔액: ${runningBalance}');
        
        for (final billTime in subsequentBillTimes) {
          final oldBalanceMinBefore = billTime['bill_balance_min_before'];
          final oldBalanceMinAfter = billTime['bill_balance_min_after'];
          final billMin = (billTime['bill_min'] as num).toInt();
          
          print('  bill_min_id: ${billTime['bill_min_id']}');
          print('    bill_balance_min_before: $oldBalanceMinBefore → $runningBalance');
          print('    bill_balance_min_after: $oldBalanceMinAfter → ${runningBalance - billMin}');
          
          runningBalance -= billMin;
        }
      }
      print('');
      
      // 3. 새 bill_times 생성 정보
      int newBillMinBalanceBefore;
      if (subsequentBillTimes.isNotEmpty) {
        // 마지막 bill_times의 새로운 balance_min_after 계산
        int lastRunningBalance = (currentBillTime['bill_balance_min_before'] as num).toInt() - originalBillMin;
        for (final billTime in subsequentBillTimes) {
          final billMin = (billTime['bill_min'] as num).toInt();
          lastRunningBalance -= billMin;
        }
        newBillMinBalanceBefore = lastRunningBalance;
      } else {
        // 기존 bill_times 다음에 바로 오는 경우
        newBillMinBalanceBefore = (currentBillTime['bill_balance_min_before'] as num).toInt() - originalBillMin;
      }
      final newBillMinBalanceAfter = newBillMinBalanceBefore - newBillMin;
        
      print('새 bill_times 생성:');
      print('  branch_id: ${currentBillTime['branch_id']}');
      print('  bill_min_id: [자동채번]');
      print('  member_id: ${currentBillTime['member_id']}');
      print('  bill_date: ${currentBillTime['bill_date']}');
      print('  bill_type: ${currentBillTime['bill_type']}');
      // bill_text에서 타석번호와 시간 모두 새로운 값으로 변경
      final newBillText = '${newTsId}번 타석(${newStartTime} ~ ${newEndTime})';
      print('  bill_text: $newBillText');
      print('  bill_min: $newBillMin');
      print('  bill_timestamp: [현재시간]');
      print('  bill_balance_min_before: $newBillMinBalanceBefore');
      print('  bill_balance_min_after: $newBillMinBalanceAfter');
      print('  reservation_id: $newReservationId');
      print('  bill_status: ${currentBillTime['bill_status']}');
      print('  contract_history_id: $contractHistoryId');
      print('  routine_id: ${currentBillTime['routine_id']}');
      print('  contract_TS_min_expiry_date: ${currentBillTime['contract_TS_min_expiry_date']}');
      print('  bill_total_min: $newBillTotalMin');
      print('  bill_discount_min: $newBillDiscountMin');
      print('');
      
    } catch (e) {
      print('bill_times 업데이트 준비 오류: $e');
    }
  }

  Future<void> _fetchCouponsForReservation(String reservationId) async {
    try {
      print('=== 할인쿠폰 조회 ===');
      
      final coupons = await ApiService.getData(
        table: 'v2_discount_coupon',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': 'test'},
          {
            'operator': 'AND',
            'conditions': [
              {
                'operator': 'OR',
                'conditions': [
                  {'field': 'reservation_id_issued', 'operator': '=', 'value': reservationId},
                  {'field': 'reservation_id_used', 'operator': '=', 'value': reservationId}
                ]
              }
            ]
          }
        ],
        orderBy: [{'field': 'coupon_id', 'direction': 'ASC'}]
      );
      
      // 해당 예약으로 사용된 쿠폰 필터링
      final usedCoupons = coupons.where((coupon) => 
        coupon['reservation_id_used'] == reservationId
      ).toList();
      
      // 해당 예약으로 발급된 쿠폰 필터링
      final issuedCoupons = coupons.where((coupon) => 
        coupon['reservation_id_issued'] == reservationId
      ).toList();
      
      print('예약 ID: $reservationId 관련 쿠폰:');
      
      // 사용된 쿠폰 출력
      print('  [사용된 쿠폰]');
      if (usedCoupons.isEmpty) {
        print('    없음');
      } else {
        for (final coupon in usedCoupons) {
          print('    쿠폰 ID: ${coupon['coupon_id']} | ${coupon['coupon_type']} | ${coupon['discount_amt']}원 | 상태: ${coupon['coupon_status']}');
          print('      설명: ${coupon['coupon_description'] ?? ""}');
        }
      }
      
      // 발급된 쿠폰 출력
      print('  [발급된 쿠폰]');
      if (issuedCoupons.isEmpty) {
        print('    없음');
      } else {
        for (final coupon in issuedCoupons) {
          print('    쿠폰 ID: ${coupon['coupon_id']} | ${coupon['coupon_type']} | ${coupon['discount_amt']}원 | 상태: ${coupon['coupon_status']}');
          print('      설명: ${coupon['coupon_description'] ?? ""}');
        }
      }
      print('');
      
    } catch (e) {
      print('쿠폰 조회 오류: $e');
      print('');
    }
  }


}
