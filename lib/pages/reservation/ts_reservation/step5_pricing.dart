import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import '../../../../services/ts_pricing_service.dart';

class Step5Pricing extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final DateTime? selectedDate;
  final String? selectedTime;
  final int? selectedDuration;
  final String? selectedTs;
  final Function(int finalPrice, int originalPrice, int finalPaymentMinutes, Map<String, int> pricingAnalysis)? onPricingCalculated;
  final Function(List<Map<String, dynamic>> coupons)? onCouponsSelected; // 여러 할인권 지원

  const Step5Pricing({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.selectedDate,
    this.selectedTime,
    this.selectedDuration,
    this.selectedTs,
    this.onPricingCalculated,
    this.onCouponsSelected,
  }) : super(key: key);

  @override
  _Step5PricingState createState() => _Step5PricingState();
}

class _Step5PricingState extends State<Step5Pricing> {
  bool _isLoading = true;
  Map<String, int> _pricingAnalysis = {};
  Map<String, dynamic>? _tsInfo; // 타석 정보 추가
  Map<String, int> _finalPricing = {}; // 최종 요금 정보 추가
  int _totalPrice = 0; // 총 요금 추가
  String _endTime = '';
  bool _hasLoadedPricing = false; // 요금 분석 로드 여부 추적
  
  // 할인권 관련 변수
  List<Map<String, dynamic>> _discountCoupons = [];
  List<Map<String, dynamic>> _selectedCoupons = []; // 여러 할인권 선택 가능
  bool _isLoadingCoupons = false;
  
  // 할인 적용 후 최종 계산 결과
  int _finalPaymentPrice = 0;
  int _finalPaymentMinutes = 0;

  @override
  void initState() {
    super.initState();
    print('🔍 [Step5 initState] 시작');
    print('🔍 [Step5 initState] selectedDate: ${widget.selectedDate}');
    print('🔍 [Step5 initState] selectedTime: ${widget.selectedTime}');
    print('🔍 [Step5 initState] selectedDuration: ${widget.selectedDuration}');
    print('🔍 [Step5 initState] selectedTs: ${widget.selectedTs}');
    print('🔍 [Step5 initState] selectedMember: ${widget.selectedMember}');
    print('🔍 [Step5 initState] isAdminMode: ${widget.isAdminMode}');
    
    // selectedMember의 상세 정보 출력
    if (widget.selectedMember != null) {
      print('🔍 [Step5 initState] selectedMember 상세:');
      widget.selectedMember!.forEach((key, value) {
        print('  - $key: $value');
      });
      
      // member_id 특별 확인
      final memberId = widget.selectedMember!['member_id'];
      print('🔍 [Step5 initState] member_id 값: $memberId (타입: ${memberId?.runtimeType})');
    } else {
      print('🔍 [Step5 initState] selectedMember가 null입니다!');
    }
    
    // 요금 분석 로드 시작
    _loadPricingAnalysis();
  }

  @override
  void didUpdateWidget(Step5Pricing oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('🟡 Step5 didUpdateWidget 호출됨');
    print('🟡 didUpdateWidget - selectedDate: ${widget.selectedDate}');
    print('🟡 didUpdateWidget - selectedTime: ${widget.selectedTime}');
    print('🟡 didUpdateWidget - selectedDuration: ${widget.selectedDuration}');
    print('🟡 didUpdateWidget - selectedTs: ${widget.selectedTs}');
    // 위젯이 업데이트될 때마다 데이터 확인 후 로드
    _checkAndLoadPricing();
  }

  // 필수 데이터가 있는지 확인하고 요금 분석 로드
  void _checkAndLoadPricing() {
    print('🟢 _checkAndLoadPricing 호출됨');
    print('🟢 _hasLoadedPricing: $_hasLoadedPricing');
    print('🟢 selectedDate null: ${widget.selectedDate == null}');
    print('🟢 selectedTime null: ${widget.selectedTime == null}');
    print('🟢 selectedDuration null: ${widget.selectedDuration == null}');
    
    // 이미 로드했거나 필수 데이터가 없으면 리턴
    if (_hasLoadedPricing || 
        widget.selectedDate == null || 
        widget.selectedTime == null || 
        widget.selectedDuration == null) {
      print('🟢 요금 분석 로드 건너뛰기');
      return;
    }
    
    print('🟢 요금 분석 로드 시작!');
    _loadPricingAnalysis();
  }

  // 할인권 목록 조회
  Future<void> _loadDiscountCoupons() async {
    print('🎫 _loadDiscountCoupons 함수 시작');
    print('🎫 widget.selectedMember: ${widget.selectedMember}');
    
    if (widget.selectedMember == null) {
      print('🎫 회원 정보가 없어 할인권 조회 건너뛰기');
      return;
    }
    
    try {
      print('🎫 할인권 조회 시작 - setState로 로딩 상태 변경');
      setState(() {
        _isLoadingCoupons = true;
      });
      
      final memberId = widget.selectedMember!['member_id'];
      final currentBranchId = ApiService.getCurrentBranchId();
      final memberBranchId = widget.selectedMember!['branch_id']?.toString();
      
      // 예약 날짜를 문자열로 변환 (YYYY-MM-DD 형식)
      final reservationDateStr = widget.selectedDate != null 
          ? '${widget.selectedDate!.year}-${widget.selectedDate!.month.toString().padLeft(2, '0')}-${widget.selectedDate!.day.toString().padLeft(2, '0')}'
          : DateTime.now().toString().substring(0, 10);
      
      print('=== 할인권 조회 시작 ===');
      print('회원 ID: $memberId');
      print('현재 브랜치 ID: $currentBranchId');
      print('회원의 브랜치 ID: $memberBranchId');
      print('예약 날짜: $reservationDateStr');
      
      // 현재 브랜치에서 할인권 조회 (selectedMember의 branch_id와 현재 branch_id가 일치해야 함)
      // 유효기간이 예약 날짜 이후인 할인권만 조회
      print('🔍 현재 브랜치($currentBranchId)에서 유효한 할인권 조회');
      final coupons = await ApiService.getData(
        table: 'v2_discount_coupon',
        fields: ['coupon_id', 'coupon_type', 'discount_ratio', 'discount_amt', 'discount_min', 'coupon_description', 'coupon_expiry_date', 'multiple_coupon_use'],
        where: [
          {'field': 'member_id', 'operator': '=', 'value': memberId.toString()},
          {'field': 'coupon_status', 'operator': '=', 'value': '미사용'},
          {'field': 'coupon_type', 'operator': '<>', 'value': '레슨권'},
          {'field': 'branch_id', 'operator': '=', 'value': currentBranchId},
          {'field': 'coupon_expiry_date', 'operator': '>=', 'value': reservationDateStr}, // 유효기간 확인
        ],
        orderBy: [
          {'field': 'coupon_expiry_date', 'direction': 'ASC'}, // 만료일 빠른 순으로 정렬
          {'field': 'coupon_type', 'direction': 'ASC'}
        ],
      );
      
      print('🎫 API 호출 완료');
      print('조회된 유효한 할인권 수: ${coupons.length}');
      for (int i = 0; i < coupons.length; i++) {
        final coupon = coupons[i];
        final expiryDate = coupon['coupon_expiry_date']?.toString() ?? '';
        print('할인권 $i: ${coupon['coupon_type']} (만료일: $expiryDate) - ${coupon}');
      }
      
      print('🎫 setState로 할인권 데이터 설정');
      setState(() {
        _discountCoupons = coupons;
        _isLoadingCoupons = false;
      });
      print('🎫 할인권 조회 완료');
    } catch (e) {
      print('🎫 할인권 조회 실패: $e');
      print('🎫 에러 스택트레이스: ${e.toString()}');
      setState(() {
        _discountCoupons = [];
        _isLoadingCoupons = false;
      });
    }
  }

  // 할인권 선택 모달 표시
  void _showCouponSelectionModal() {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return _CouponSelectionModal(
          coupons: _discountCoupons,
          selectedCoupons: _selectedCoupons,
          onConfirm: _onCouponsSelected,
        );
      },
    );
  }
  
  // 할인권 선택 처리 (여러 개)
  void _onCouponsSelected(List<Map<String, dynamic>> coupons) {
    setState(() {
      _selectedCoupons = coupons;
      _calculateFinalPayment();
    });
    
    // 상위 위젯으로 할인권 정보 전달
    if (widget.onCouponsSelected != null) {
      widget.onCouponsSelected!(_selectedCoupons);
    }
  }

  // 최종 결제금액 계산 (여러 할인권 적용)
  void _calculateFinalPayment() {
    print('=== 최종 결제금액 계산 시작 ===');
    print('선택된 할인권들: $_selectedCoupons');
    print('원래 총 요금: $_totalPrice원');
    print('원래 총 시간: ${widget.selectedDuration}분');
    
    if (_selectedCoupons.isEmpty) {
      // 할인권이 선택되지 않은 경우
      _finalPaymentPrice = _totalPrice;
      _finalPaymentMinutes = widget.selectedDuration ?? 0;
    } else {
      // 여러 할인권 동시 적용 로직
      double totalDiscountRatio = 0.0; // 정률권들의 총 할인율
      int totalDiscountAmt = 0; // 정액권들의 총 할인액
      int totalDiscountMin = 0; // 시간권들의 총 할인시간
      
      // 각 할인권 유형별로 누적
      for (final coupon in _selectedCoupons) {
        final couponType = coupon['coupon_type']?.toString() ?? '';
        
        if (couponType == '정률권') {
          final discountRatio = int.tryParse(coupon['discount_ratio']?.toString() ?? '0') ?? 0;
          totalDiscountRatio += discountRatio;
        } else if (couponType == '정액권') {
          final discountAmt = int.tryParse(coupon['discount_amt']?.toString() ?? '0') ?? 0;
          totalDiscountAmt += discountAmt;
        } else if (couponType == '시간권') {
          final discountMin = int.tryParse(coupon['discount_min']?.toString() ?? '0') ?? 0;
          totalDiscountMin += discountMin;
        }
      }
      
      // 할인 적용 순서: 정률권 → 정액권 → 시간권
      double currentPrice = _totalPrice.toDouble();
      int currentMinutes = widget.selectedDuration ?? 0;
      
      // 1. 정률권 적용 (가격과 시간 모두 할인)
      if (totalDiscountRatio > 0) {
        totalDiscountRatio = totalDiscountRatio.clamp(0, 100); // 최대 100% 할인
        currentPrice = currentPrice * (100 - totalDiscountRatio) / 100;
        currentMinutes = (currentMinutes * (100 - totalDiscountRatio) / 100).round();
        print('정률권 적용: ${totalDiscountRatio}% 할인');
      }
      
      // 2. 정액권 적용 (가격만 할인, 시간은 비례 조정)
      if (totalDiscountAmt > 0) {
        final priceBeforeAmt = currentPrice;
        currentPrice = (currentPrice - totalDiscountAmt).clamp(0, currentPrice);
        if (priceBeforeAmt > 0) {
          final amtDiscountRatio = (priceBeforeAmt - currentPrice) / priceBeforeAmt;
          currentMinutes = (currentMinutes * (1 - amtDiscountRatio)).round().clamp(0, currentMinutes);
        }
        print('정액권 적용: ${totalDiscountAmt}원 할인');
      }
      
      // 3. 시간권 적용 (시간만 할인, 가격은 비례 조정)
      if (totalDiscountMin > 0) {
        final minutesBeforeTime = currentMinutes;
        currentMinutes = (currentMinutes - totalDiscountMin).clamp(0, currentMinutes);
        if (minutesBeforeTime > 0 && widget.selectedDuration! > 0) {
          final timeDiscountRatio = (minutesBeforeTime - currentMinutes) / widget.selectedDuration!;
          currentPrice = currentPrice * (1 - timeDiscountRatio);
        }
        print('시간권 적용: ${totalDiscountMin}분 할인');
      }
      
      _finalPaymentPrice = currentPrice.round();
      _finalPaymentMinutes = currentMinutes;
      
      print('최종 할인 후 요금: $_finalPaymentPrice원');
      print('최종 할인 후 시간: $_finalPaymentMinutes분');
    }
    
    // 콜백 함수 호출하여 최종 계산된 가격 정보를 상위 위젯에 전달
    if (widget.onPricingCalculated != null) {
      widget.onPricingCalculated!(_finalPaymentPrice, _totalPrice, _finalPaymentMinutes, _pricingAnalysis);
    }
  }

  // 할인권 표시 텍스트 생성
  String _getCouponDisplayText(Map<String, dynamic> coupon) {
    final couponType = coupon['coupon_type']?.toString() ?? '';
    final expiryDate = coupon['coupon_expiry_date']?.toString() ?? '';
    
    String displayText = '';
    
    if (couponType == '정률권') {
      final ratio = coupon['discount_ratio']?.toString() ?? '0';
      displayText = '$couponType (${ratio}%)';
    } else if (couponType == '정액권') {
      final amt = coupon['discount_amt']?.toString() ?? '0';
      displayText = '$couponType (${amt}원)';
    } else if (couponType == '시간권') {
      final min = coupon['discount_min']?.toString() ?? '0';
      displayText = '$couponType (${min}분)';
    } else {
      displayText = couponType;
    }
    
    // 만료일 정보 추가 (YYYY-MM-DD 형식을 MM/DD로 간단히 표시)
    if (expiryDate.isNotEmpty) {
      try {
        final dateParts = expiryDate.split('-');
        if (dateParts.length >= 3) {
          final month = dateParts[1];
          final day = dateParts[2];
          displayText += ' (~$month/$day)';
        }
      } catch (e) {
        // 날짜 파싱 실패 시 원본 날짜 표시
        displayText += ' (~$expiryDate)';
      }
    }
    
    return displayText;
  }

  // 요금 분석 로드
  Future<void> _loadPricingAnalysis() async {
    try {
      print('=== 요금 분석 시작 ===');
      print('selectedDate: ${widget.selectedDate}');
      print('selectedTime: ${widget.selectedTime}');
      print('selectedDuration: ${widget.selectedDuration}');
      print('selectedTs: ${widget.selectedTs}');
      print('selectedMember: ${widget.selectedMember}');
      
      if (widget.selectedDate == null || 
          widget.selectedTime == null || 
          widget.selectedDuration == null ||
          widget.selectedTs == null) {
        print('필수 정보 누락');
        print('- selectedDate null: ${widget.selectedDate == null}');
        print('- selectedTime null: ${widget.selectedTime == null}');
        print('- selectedDuration null: ${widget.selectedDuration == null}');
        print('- selectedTs null: ${widget.selectedTs == null}');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      _hasLoadedPricing = true; // 로드 시작 표시

      // 새로운 TsPricingService 사용
      final memberId = widget.selectedMember?['member_id']?.toString();
      
      final pricingResult = await TsPricingService.calculatePricing(
        selectedDate: widget.selectedDate!,
        selectedTime: widget.selectedTime!,
        selectedDuration: widget.selectedDuration!,
        selectedTs: widget.selectedTs!,
        memberId: memberId,
      );

      if (pricingResult != null) {
        // 기존 변수들에 결과 할당
        _pricingAnalysis = pricingResult.timeAnalysis;
        _finalPricing = pricingResult.priceAnalysis;
        _totalPrice = pricingResult.totalPrice;
        _endTime = pricingResult.endTime;
        _tsInfo = pricingResult.tsInfo;
        
        print('TsPricingService 결과:');
        print('- 시간대별 분석: $_pricingAnalysis');
        print('- 요금 분석: $_finalPricing');
        print('- 총 요금: $_totalPrice원');
        print('- 종료 시간: $_endTime');
        
        // 디버깅용 포맷된 결과 출력
        print(TsPricingService.formatPricingResult(pricingResult));
        
        // 할인권 목록 로드 - 요금 분석과 독립적으로 실행
        if (widget.selectedMember != null) {
          print('🎫 selectedMember 존재 - 할인권 조회 진행');
          _loadDiscountCoupons();
        } else {
          print('🎫 selectedMember가 null이어서 할인권 조회 건너뛰기');
        }
        
        // 최종 결제금액 계산 (할인권 적용)
        _calculateFinalPayment();
      } else {
        print('TsPricingService에서 결과를 받지 못함');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('요금 분석 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 요금 정책 이름 변환
  String _getPolicyDisplayName(String policyKey) {
    switch (policyKey) {
      case 'base_price':
        return '일반';
      case 'discount_price':
        return '할인';
      case 'extracharge_price':
        return '할증';
      case 'out_of_business':
        return '미운영';
      default:
        return policyKey;
    }
  }

  // 요금 정책 색상
  Color _getPolicyColor(String policyKey) {
    switch (policyKey) {
      case 'base_price':
        return Color(0xFF00A86B);
      case 'discount_price':
        return Color(0xFF3498DB);
      case 'extracharge_price':
        return Color(0xFFE74C3C);
      case 'out_of_business':
        return Color(0xFF95A5A6);
      default:
        return Color(0xFF666666);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔴 Step5 build 호출됨');
    print('🔴 build - _isLoading: $_isLoading');
    print('🔴 build - _pricingAnalysis: $_pricingAnalysis');
    print('🔴 build - selectedDate: ${widget.selectedDate}');
    print('🔴 build - selectedTime: ${widget.selectedTime}');
    print('🔴 build - selectedDuration: ${widget.selectedDuration}');
    print('🔴 build - selectedTs: ${widget.selectedTs}');
    print('🔴 build - selectedMember: ${widget.selectedMember}');
    print('🔴 build - _discountCoupons.length: ${_discountCoupons.length}');
    print('🔴 build - _isLoadingCoupons: $_isLoadingCoupons');
    
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A86B)),
              ),
              SizedBox(height: 16),
              Text(
                '요금 정보를 분석 중...',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 결제내역 확인 카드
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 4),
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 시간대별 예약내역 (임팩트 있는 제목)
                if (_pricingAnalysis.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Color(0xFF00A86B),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '시간대별 예약내역',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // 요금 분석 테이블
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFE9ECEF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // 테이블 헤더
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '시간대',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF495057),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '시간(분)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF495057),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  '이용요금',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF495057),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // 테이블 데이터 행들
                        ..._pricingAnalysis.entries
                            .where((entry) => entry.value > 0)
                            .map((entry) => _buildPricingTableRow(entry.key, entry.value))
                            .toList(),
                            
                        // 합계 행
                        if (_totalPrice > 0) ...[
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Color(0xFF00A86B).withOpacity(0.1),
                              border: Border(top: BorderSide(color: Color(0xFF00A86B), width: 2)),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '합계',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00A86B),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${widget.selectedDuration}분',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00A86B),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Text(
                                      '${_totalPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00A86B),
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else if (widget.selectedDate != null && 
                          widget.selectedTime != null && 
                          widget.selectedDuration != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Color(0xFF00A86B),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '시간대별 예약내역',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFE9ECEF)),
                    ),
                    child: Text(
                      '요금 정보를 불러오는 중입니다...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6C757D),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // 할인권 선택 섹션
          if (_totalPrice > 0) ...[
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 4),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_offer,
                        color: Color(0xFF00A86B),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '할인권 선택',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  // 할인권 선택 버튼
                  Container(
                    width: double.infinity,
                    child: _isLoadingCoupons
                        ? Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Color(0xFFE0E0E0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '할인권 조회 중...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: _showCouponSelectionModal,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF00A86B),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_offer,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  _selectedCoupons.isEmpty 
                                    ? '할인권 선택 (사용가능: ${_discountCoupons.length}개)'
                                    : '할인권 선택됨 (${_selectedCoupons.length}개)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  
                  // 할인 적용 결과 표시
                  if (_selectedCoupons.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF00A86B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFF00A86B).withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '할인 전',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              Text(
                                '${widget.selectedDuration}분 (${_totalPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '최종 결제금액',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00A86B),
                                ),
                              ),
                              Text(
                                '${_finalPaymentMinutes}분 (${_finalPaymentPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00A86B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 요금 분석 테이블 행 위젯
  Widget _buildPricingTableRow(String policyKey, int minutes) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _getPolicyDisplayName(policyKey),
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF495057),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$minutes분',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF495057),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                '${_finalPricing[policyKey]?.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF495057),
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 할인권 선택 모달 팝업
class _CouponSelectionModal extends StatefulWidget {
  final List<Map<String, dynamic>> coupons;
  final List<Map<String, dynamic>> selectedCoupons;
  final Function(List<Map<String, dynamic>>) onConfirm;

  const _CouponSelectionModal({
    Key? key,
    required this.coupons,
    required this.selectedCoupons,
    required this.onConfirm,
  }) : super(key: key);

  @override
  _CouponSelectionModalState createState() => _CouponSelectionModalState();
}

class _CouponSelectionModalState extends State<_CouponSelectionModal> {
  late List<Map<String, dynamic>> _tempSelectedCoupons;

  @override
  void initState() {
    super.initState();
    _tempSelectedCoupons = List.from(widget.selectedCoupons);
  }

  // 할인권 선택/해제 처리
  void _toggleCoupon(Map<String, dynamic> coupon) {
    setState(() {
      final multipleUse = coupon['multiple_coupon_use']?.toString() ?? '불가능';
      final isCurrentlySelected = _tempSelectedCoupons.any((c) => c['coupon_id'] == coupon['coupon_id']);
      
      if (isCurrentlySelected) {
        // 선택 해제
        _tempSelectedCoupons.removeWhere((c) => c['coupon_id'] == coupon['coupon_id']);
      } else {
        // 새로 선택
        if (multipleUse == '불가능') {
          // 불가능 쿠폰 선택 시 기존 선택 모두 해제
          _tempSelectedCoupons.clear();
          _tempSelectedCoupons.add(coupon);
        } else {
          // 가능 쿠폰 선택 시
          // 기존에 불가능 쿠폰이 선택되어 있다면 해제
          _tempSelectedCoupons.removeWhere((c) => c['multiple_coupon_use']?.toString() == '불가능');
          _tempSelectedCoupons.add(coupon);
        }
      }
    });
  }

  // 할인권이 선택 가능한지 확인
  bool _isCouponSelectable(Map<String, dynamic> coupon) {
    final multipleUse = coupon['multiple_coupon_use']?.toString() ?? '불가능';
    
    if (_tempSelectedCoupons.isEmpty) {
      return true; // 아무것도 선택되지 않았으면 모든 쿠폰 선택 가능
    }
    
    final hasImpossibleSelected = _tempSelectedCoupons.any((c) => c['multiple_coupon_use']?.toString() == '불가능');
    
    if (hasImpossibleSelected) {
      // 불가능 쿠폰이 선택되어 있으면 해당 쿠폰만 선택/해제 가능
      return _tempSelectedCoupons.any((c) => c['coupon_id'] == coupon['coupon_id']);
    } else {
      // 가능 쿠폰들만 선택되어 있으면
      if (multipleUse == '불가능') {
        return true; // 불가능 쿠폰은 선택 가능 (기존 선택 해제됨)
      } else {
        return true; // 가능 쿠폰도 추가 선택 가능
      }
    }
  }

  // 할인권 표시 텍스트 생성
  String _getCouponDisplayText(Map<String, dynamic> coupon) {
    final couponType = coupon['coupon_type']?.toString() ?? '';
    final expiryDate = coupon['coupon_expiry_date']?.toString() ?? '';
    
    String displayText = '';
    
    if (couponType == '정률권') {
      final ratio = coupon['discount_ratio']?.toString() ?? '0';
      displayText = '$couponType (${ratio}%)';
    } else if (couponType == '정액권') {
      final amt = coupon['discount_amt']?.toString() ?? '0';
      displayText = '$couponType (${amt}원)';
    } else if (couponType == '시간권') {
      final min = coupon['discount_min']?.toString() ?? '0';
      displayText = '$couponType (${min}분)';
    } else {
      displayText = couponType;
    }
    
    // 만료일 정보 추가
    if (expiryDate.isNotEmpty) {
      try {
        final dateParts = expiryDate.split('-');
        if (dateParts.length >= 3) {
          final month = dateParts[1];
          final day = dateParts[2];
          displayText += ' (~$month/$day)';
        }
      } catch (e) {
        displayText += ' (~$expiryDate)';
      }
    }
    
    return displayText;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF00A86B),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_offer,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '할인권 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // 할인권 목록
            Flexible(
              child: widget.coupons.isEmpty
                  ? Container(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox,
                            size: 48,
                            color: Color(0xFF9E9E9E),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '사용 가능한 할인권이 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.coupons.length,
                      itemBuilder: (context, index) {
                        final coupon = widget.coupons[index];
                        final isSelected = _tempSelectedCoupons.any((c) => c['coupon_id'] == coupon['coupon_id']);
                        final isSelectable = _isCouponSelectable(coupon);
                        final multipleUse = coupon['multiple_coupon_use']?.toString() ?? '불가능';
                        
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isSelectable ? () => _toggleCoupon(coupon) : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected 
                                        ? Color(0xFF00A86B) 
                                        : isSelectable 
                                            ? Color(0xFFE0E0E0)
                                            : Color(0xFFF0F0F0),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: isSelected 
                                      ? Color(0xFF00A86B).withOpacity(0.1)
                                      : isSelectable 
                                          ? Colors.white
                                          : Color(0xFFF8F9FA),
                                ),
                                child: Row(
                                  children: [
                                    // 체크박스
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected 
                                              ? Color(0xFF00A86B) 
                                              : isSelectable 
                                                  ? Color(0xFFBDBDBD)
                                                  : Color(0xFFE0E0E0),
                                          width: 2,
                                        ),
                                        color: isSelected ? Color(0xFF00A86B) : Colors.transparent,
                                      ),
                                      child: isSelected
                                          ? Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    SizedBox(width: 12),
                                    
                                    // 할인권 정보
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getCouponDisplayText(coupon),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isSelectable ? Color(0xFF1A1A1A) : Color(0xFF9E9E9E),
                                            ),
                                          ),
                                          if (coupon['coupon_description']?.toString().isNotEmpty == true) ...[
                                            SizedBox(height: 4),
                                            Text(
                                              coupon['coupon_description'].toString(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isSelectable ? Color(0xFF666666) : Color(0xFFBDBDBD),
                                              ),
                                            ),
                                          ],
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: multipleUse == '가능' 
                                                      ? Color(0xFF4CAF50).withOpacity(0.1)
                                                      : Color(0xFFFF9800).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  multipleUse == '가능' ? '중복사용 가능' : '단독사용만',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: multipleUse == '가능' 
                                                        ? Color(0xFF4CAF50)
                                                        : Color(0xFFFF9800),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            
            // 하단 버튼
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: Row(
                children: [
                  // 선택 해제 버튼
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _tempSelectedCoupons.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Color(0xFF00A86B)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '전체 해제',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF00A86B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  
                  // 확인 버튼
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onConfirm(_tempSelectedCoupons);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00A86B),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '확인 (${_tempSelectedCoupons.length}개 선택)',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 