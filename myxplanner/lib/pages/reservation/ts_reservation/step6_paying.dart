import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../services/tile_design_service.dart';
import '../../../../services/api_service.dart';

class Step6Paying extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final DateTime? selectedDate;
  final String? selectedTime;
  final int? selectedDuration;
  final String? selectedTs;
  final int? totalPrice;
  final Map<String, int>? pricingAnalysis;
  final List<Map<String, dynamic>>? selectedCoupons; // 여러 할인권 지원

  const Step6Paying({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.selectedDate,
    this.selectedTime,
    this.selectedDuration,
    this.selectedTs,
    this.totalPrice,
    this.pricingAnalysis,
    this.selectedCoupons,
  }) : super(key: key);

  @override
  Step6PayingState createState() => Step6PayingState();
}

class Step6PayingState extends State<Step6Paying> {
  List<Map<String, dynamic>> _selectedPaymentMethods = [];
  bool _isLoadingBalance = false; // 잔액 조회 중 상태
  // List<Map<String, dynamic>> _periodPassInfo = []; // 기간권 정보 (더 이상 사용하지 않음)
  List<Map<String, dynamic>> _periodPassContracts = []; // 계약별 기간권 정보 추가
  List<Map<String, dynamic>> _prepaidCreditContracts = []; // 계약별 선불크레딧 정보
  List<Map<String, dynamic>> _timePassContracts = []; // 계약별 시간권 정보
  Map<String, Map<String, dynamic>> _contractDetailsMap = {}; // 계약 상세 정보 맵
  
  // 결제 방법별 잔액 (가상 데이터)
  Map<String, dynamic> _balances = {
    'period_pass': 0, // 분 - 초기값을 0으로 설정 (API 오류 시 잘못된 잔액 방지)
  };

  // 기본 결제 방법 목록 (선불크레딧, 시간권, 기간권 제외)
  // 비회원가 구매 제거됨
  final List<Map<String, dynamic>> _basePaymentMethods = [];

  // 동적으로 생성되는 전체 결제 방법 목록
  List<Map<String, dynamic>> get _paymentMethods {
    List<Map<String, dynamic>> methods = [];
    
    // 할인권이 선택된 경우 coupon_use_available 확인
    final bool hasCouponsSelected = widget.selectedCoupons != null && widget.selectedCoupons!.isNotEmpty;
    
    // 계약별 선불크레딧 추가
    for (int i = 0; i < _prepaidCreditContracts.length; i++) {
      final contract = _prepaidCreditContracts[i];
      
      // 할인권이 선택된 경우 coupon_use_available 확인
      if (hasCouponsSelected) {
        final couponUseAvailable = contract['coupon_use_available']?.toString() ?? '';
        if (couponUseAvailable == '불가능') {
          print('🚫 선불크레딧 계약 ${contract['contract_history_id']} 제외: 할인권 사용 불가능');
          continue; // 이 계약은 결제수단에서 제외
        }
      }
      
      final contractName = contract['contract_name']?.toString() ?? '선불크레딧';
      methods.add({
        'type': 'prepaid_credit_${contract['contract_history_id']}',
        'title': contractName,
        'icon': Icons.account_balance_wallet,
        'unit': '원',
        'contract_data': contract,
      });
    }
    
    // 계약별 시간권 추가
    for (int i = 0; i < _timePassContracts.length; i++) {
      final contract = _timePassContracts[i];
      
      // 할인권이 선택된 경우 coupon_use_available 확인
      if (hasCouponsSelected) {
        final couponUseAvailable = contract['coupon_use_available']?.toString() ?? '';
        if (couponUseAvailable == '불가능') {
          print('🚫 시간권 계약 ${contract['contract_history_id']} 제외: 할인권 사용 불가능');
          continue; // 이 계약은 결제수단에서 제외
        }
      }
      
      final contractName = contract['contract_name']?.toString() ?? '시간권';
      methods.add({
        'type': 'time_pass_${contract['contract_history_id']}',
        'title': contractName,
        'icon': Icons.access_time,
        'unit': '분',
        'contract_data': contract,
      });
    }
    
    // 계약별 기간권 추가
    for (int i = 0; i < _periodPassContracts.length; i++) {
      final contract = _periodPassContracts[i];
      
      // 할인권이 선택된 경우 coupon_use_available 확인
      if (hasCouponsSelected) {
        final couponUseAvailable = contract['coupon_use_available']?.toString() ?? '';
        if (couponUseAvailable == '불가능') {
          print('🚫 기간권 계약 ${contract['contract_history_id']} 제외: 할인권 사용 불가능');
          continue; // 이 계약은 결제수단에서 제외
        }
      }
      
      final contractName = contract['contract_name']?.toString() ?? '기간권';
      methods.add({
        'type': 'period_pass_${contract['contract_history_id']}',
        'title': contractName,
        'icon': Icons.card_membership,
        'unit': '분',
        'contract_data': contract,
      });
    }
    
    // 기본 결제 방법들 추가
    methods.addAll(_basePaymentMethods);

    if (hasCouponsSelected) {
      print('🎫 할인권 선택됨: 할인권 사용 가능한 계약만 표시 (총 ${methods.length}개 결제수단)');
    }

    return methods;
  }

  // 실제 요금 계산 (Step5에서 전달받은 데이터 사용)
  int get _totalMinutes => widget.selectedDuration ?? 0;
  int get _totalPrice => widget.totalPrice ?? 0;
  double get _pricePerMinute => _totalMinutes > 0 ? _totalPrice / _totalMinutes : 0;


  @override
  void initState() {
    super.initState();
    _loadMemberBalance();
  }
  
  @override
  void didUpdateWidget(Step6Paying oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 회원이 변경된 경우 잔액 다시 조회
    if (oldWidget.selectedMember?['member_id'] != widget.selectedMember?['member_id']) {
      _loadMemberBalance();
    }
  }
  
  // 회원 잔액 및 기간권 정보 조회
  Future<void> _loadMemberBalance() async {
    if (widget.selectedMember != null) {
      final memberId = widget.selectedMember!['member_id']?.toString();
      if (memberId != null && memberId.isNotEmpty) {
        try {
          setState(() {
            _isLoadingBalance = true;
          });
          
          print('=== _loadMemberBalance 시작 ===');
          print('회원 ID: $memberId');
          print('선택된 날짜: ${widget.selectedDate}');

          // 당일 사용량 조회 (max_use_per_day 제한 적용용)
          Map<String, int> dailyUsage = {};
          if (widget.selectedDate != null) {
            final billDateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
            dailyUsage = await ApiService.getDailyUsageByContract(
              memberId: memberId,
              billDate: billDateStr,
            );
            print('\n=== 당일 사용량 조회 결과 ===');
            dailyUsage.forEach((contractHistoryId, usedMinutes) {
              print('계약 $contractHistoryId: ${usedMinutes}분 이미 사용');
            });
          }
          
          // 계약별 선불크레딧 조회
          final prepaidCreditContracts = await ApiService.getMemberPrepaidCreditsByContract(memberId: memberId);
          print('API에서 반환된 선불크레딧 계약 수: ${prepaidCreditContracts.length}');
          
          for (int i = 0; i < prepaidCreditContracts.length; i++) {
            final contract = prepaidCreditContracts[i];
            print('계약 $i: $contract');
          }
          
          // 예약 날짜와 유효기간 비교하여 유효한 크레딧만 필터링
          List<Map<String, dynamic>> validPrepaidCredits = [];
          if (widget.selectedDate != null) {
            final selectedDateStr = '${widget.selectedDate!.year}-${widget.selectedDate!.month.toString().padLeft(2, '0')}-${widget.selectedDate!.day.toString().padLeft(2, '0')}';
            print('예약 날짜 문자열: $selectedDateStr');
            
            for (final contract in prepaidCreditContracts) {
              final expiryDateStr = contract['expiry_date']?.toString();
              
              if (expiryDateStr == null || expiryDateStr.isEmpty || expiryDateStr == 'null') {
                // 만료일이 없는 경우 유효한 것으로 처리
                validPrepaidCredits.add(contract);
                print('선불크레딧 계약 ${contract['contract_id']}: 만료일 없음 - 유효');
              } else {
                // 만료일이 예약 날짜보다 이후인 경우만 유효
                if (expiryDateStr.compareTo(selectedDateStr) >= 0) {
                  validPrepaidCredits.add(contract);
                  print('선불크레딧 계약 ${contract['contract_id']}: 유효 (만료일: $expiryDateStr)');
                } else {
                  print('선불크레딧 계약 ${contract['contract_id']}: 만료됨 (만료일: $expiryDateStr)');
                }
              }
            }
          } else {
            // 예약 날짜가 없는 경우 모든 크레딧을 유효한 것으로 처리
            validPrepaidCredits = prepaidCreditContracts;
            print('예약 날짜가 없어서 모든 크레딧을 유효한 것으로 처리');
          }
          
          print('필터링 후 유효한 선불크레딧 계약 수: ${validPrepaidCredits.length}');
          
          // 유효기간 순으로 정렬 (유효기간이 빠른 것부터)
          validPrepaidCredits.sort((a, b) {
            final aExpiryStr = a['expiry_date']?.toString();
            final bExpiryStr = b['expiry_date']?.toString();
            
            // 유효기간이 없는 경우는 맨 뒤로
            if (aExpiryStr == null || aExpiryStr.isEmpty || aExpiryStr == 'null') {
              if (bExpiryStr == null || bExpiryStr.isEmpty || bExpiryStr == 'null') {
                return 0; // 둘 다 유효기간이 없으면 동일
              }
              return 1; // a가 유효기간이 없으면 뒤로
            }
            if (bExpiryStr == null || bExpiryStr.isEmpty || bExpiryStr == 'null') {
              return -1; // b가 유효기간이 없으면 a가 앞으로
            }
            
            // 유효기간 비교 (빠른 날짜가 앞으로)
            return aExpiryStr.compareTo(bExpiryStr);
          });
          
          print('유효기간 순 정렬 완료');
          for (int i = 0; i < validPrepaidCredits.length; i++) {
            final contract = validPrepaidCredits[i];
            print('정렬된 계약 $i: ${contract['contract_id']} (만료일: ${contract['expiry_date']})');
          }
          
          // 계약별 시간권 조회
          final timePassContracts = await ApiService.getMemberTimePassesByContract(memberId: memberId);
          print('API에서 반환된 시간권 계약 수: ${timePassContracts.length}');
          
          for (int i = 0; i < timePassContracts.length; i++) {
            final contract = timePassContracts[i];
            print('시간권 계약 $i: $contract');
          }
          
          // 예약 날짜와 유효기간 비교하여 유효한 시간권만 필터링
          List<Map<String, dynamic>> validTimePassContracts = [];
          if (widget.selectedDate != null) {
            final selectedDateStr = '${widget.selectedDate!.year}-${widget.selectedDate!.month.toString().padLeft(2, '0')}-${widget.selectedDate!.day.toString().padLeft(2, '0')}';
            print('시간권 예약 날짜 문자열: $selectedDateStr');
            
            for (final contract in timePassContracts) {
              final expiryDateStr = contract['expiry_date']?.toString();
              
              if (expiryDateStr == null || expiryDateStr.isEmpty || expiryDateStr == 'null') {
                // 만료일이 없는 경우 유효한 것으로 처리
                validTimePassContracts.add(contract);
                print('시간권 계약 ${contract['contract_id']}: 만료일 없음 - 유효');
              } else {
                // 만료일이 예약 날짜보다 이후인 경우만 유효
                if (expiryDateStr.compareTo(selectedDateStr) >= 0) {
                  validTimePassContracts.add(contract);
                  print('시간권 계약 ${contract['contract_id']}: 유효 (만료일: $expiryDateStr)');
                } else {
                  print('시간권 계약 ${contract['contract_id']}: 만료됨 (만료일: $expiryDateStr)');
                }
              }
            }
          } else {
            // 예약 날짜가 없는 경우 모든 시간권을 유효한 것으로 처리
            validTimePassContracts = timePassContracts;
            print('예약 날짜가 없어서 모든 시간권을 유효한 것으로 처리');
          }
          
          print('필터링 후 유효한 시간권 계약 수: ${validTimePassContracts.length}');
          
          // 유효기간 순으로 정렬 (유효기간이 빠른 것부터)
          validTimePassContracts.sort((a, b) {
            final aExpiryStr = a['expiry_date']?.toString();
            final bExpiryStr = b['expiry_date']?.toString();
            
            // 유효기간이 없는 경우는 맨 뒤로
            if (aExpiryStr == null || aExpiryStr.isEmpty || aExpiryStr == 'null') {
              if (bExpiryStr == null || bExpiryStr.isEmpty || bExpiryStr == 'null') {
                return 0; // 둘 다 유효기간이 없으면 동일
              }
              return 1; // a가 유효기간이 없으면 뒤로
            }
            if (bExpiryStr == null || bExpiryStr.isEmpty || bExpiryStr == 'null') {
              return -1; // b가 유효기간이 없으면 a가 앞으로
            }
            
            // 유효기간 비교 (빠른 날짜가 앞으로)
            return aExpiryStr.compareTo(bExpiryStr);
          });
          
          print('시간권 유효기간 순 정렬 완료');
          for (int i = 0; i < validTimePassContracts.length; i++) {
            final contract = validTimePassContracts[i];
            print('정렬된 시간권 계약 $i: ${contract['contract_id']} (만료일: ${contract['expiry_date']})');
          }
          
          // 시간권 잔액 조회 (기존 방식 - 호환성 유지)
          final timePassBalance = await ApiService.getMemberTimePassBalance(memberId: memberId);
          
          
          // 기간권 정보 조회 (터미널 출력용, 홀드 체크 포함)
          final selectedDateStr = widget.selectedDate != null 
              ? DateFormat('yyyy-MM-dd').format(widget.selectedDate!)
              : null;
          final periodPassInfo = await ApiService.getMemberPeriodPass(
            memberId: memberId,
            reservationDate: selectedDateStr,
          );
          
          // 먼저 기간권의 contract_history_id들을 수집
          final periodPassHistoryIds = <String>[];
          for (final passInfo in periodPassInfo) {
            final historyId = passInfo['contract_history_id']?.toString();
            if (historyId != null && historyId.isNotEmpty) {
              periodPassHistoryIds.add(historyId);
            }
          }
          
          // 기간권 계약 상세 정보를 미리 조회
          Map<String, Map<String, dynamic>> periodPassContractDetails = {};
          if (periodPassHistoryIds.isNotEmpty) {
            periodPassContractDetails = await ApiService.getContractDetails(
              contractHistoryIds: periodPassHistoryIds,
            );
            
            // 조회된 상세 정보를 각 기간권 정보에 병합
            for (final passInfo in periodPassInfo) {
              final historyId = passInfo['contract_history_id']?.toString();
              if (historyId != null && periodPassContractDetails.containsKey(historyId)) {
                passInfo.addAll(periodPassContractDetails[historyId]!);
                print('기간권 ${historyId} 상세 정보 병합: max_ts_use_min=${passInfo['max_ts_use_min']}, max_use_per_day=${passInfo['max_use_per_day']}');
              }
            }
          }
          
          // 기간권 계약별 처리
          List<Map<String, dynamic>> validPeriodPassContracts = [];
          
          // 각 기간권 계약에 대해 개별 사용 가능 분수 계산
          for (final passInfo in periodPassInfo) {
            int usableMinutes = 0;
            
            // 예약 정보가 모두 있는 경우에만 계산
            if (widget.selectedDate != null && 
                widget.selectedTime != null && 
                widget.selectedDuration != null && 
                widget.selectedTs != null) {
              
              // 각 계약의 고유 조건을 반영하여 사용 가능 분수 계산
              usableMinutes = await _calculateContractUsableMinutes(
                contract: passInfo,
                selectedDate: widget.selectedDate!,
                selectedTime: widget.selectedTime!,
                duration: widget.selectedDuration!,
                selectedTs: widget.selectedTs!,
                dailyUsage: dailyUsage,
              );
            }
            
            // 사용 가능 분수가 0보다 큰 경우만 추가
            if (usableMinutes > 0) {
              final contractWithBalance = Map<String, dynamic>.from(passInfo);
              contractWithBalance['usable_minutes'] = usableMinutes;
              validPeriodPassContracts.add(contractWithBalance);
              
              print('기간권 계약 ${passInfo['contract_history_id']}: 사용 가능 ${usableMinutes}분 (계약별 개별 계산)');
            } else {
              print('기간권 계약 ${passInfo['contract_history_id']}: 사용 불가(${usableMinutes}분) - 결제수단에서 제외');
            }
          }
          
          // 유효기간 순으로 정렬 (유효기간이 빠른 것부터)
          validPeriodPassContracts.sort((a, b) {
            final aExpiryStr = a['expiry_date']?.toString();
            final bExpiryStr = b['expiry_date']?.toString();
            
            // 유효기간이 없는 경우는 맨 뒤로
            if (aExpiryStr == null || aExpiryStr.isEmpty || aExpiryStr == 'null') {
              if (bExpiryStr == null || bExpiryStr.isEmpty || bExpiryStr == 'null') {
                return 0; // 둘 다 유효기간이 없으면 동일
              }
              return 1; // a가 유효기간이 없으면 뒤로
            }
            if (bExpiryStr == null || bExpiryStr.isEmpty || bExpiryStr == 'null') {
              return -1; // b가 유효기간이 없으면 a가 앞으로
            }
            
            // 유효기간 비교 (빠른 날짜가 앞으로)
            return aExpiryStr.compareTo(bExpiryStr);
          });
          
          print('유효한 기간권 계약 수: ${validPeriodPassContracts.length}');
          
          // 예약 시간 제약을 통과한 계약들을 저장할 변수
          List<Map<String, dynamic>> finalValidPrepaidCredits = validPrepaidCredits;
          List<Map<String, dynamic>> finalValidTimePassContracts = validTimePassContracts;
          List<Map<String, dynamic>> finalValidPeriodPassContracts = validPeriodPassContracts;
          
          // 모든 계약의 contract_history_id 수집
          final List<String> allContractHistoryIds = [];
          
          // 선불크레디트 contract_history_id 추가 및 max_ts_use_min 적용
          for (final contract in validPrepaidCredits) {
            final historyId = contract['contract_history_id']?.toString();
            if (historyId != null && historyId.isNotEmpty) {
              allContractHistoryIds.add(historyId);
            }
          }
          
          // 시간권 contract_history_id 추가
          for (final contract in validTimePassContracts) {
            final historyId = contract['contract_history_id']?.toString();
            if (historyId != null && historyId.isNotEmpty) {
              allContractHistoryIds.add(historyId);
            }
          }
          
          // 기간권 contract_history_id 추가
          for (final contract in validPeriodPassContracts) {
            final historyId = contract['contract_history_id']?.toString();
            if (historyId != null && historyId.isNotEmpty) {
              allContractHistoryIds.add(historyId);
            }
          }
          
          print('\n=== 계약 상세 정보 조회 시작 ===');
          print('조회할 총 contract_history_id 수: ${allContractHistoryIds.length}');
          
          // 계약 상세 정보 조회
          Map<String, Map<String, dynamic>> contractDetails = {};
          if (allContractHistoryIds.isNotEmpty) {
            contractDetails = await ApiService.getContractDetails(
              contractHistoryIds: allContractHistoryIds,
            );
            
            print('\n=== 계약 상세 정보 조회 결과 ===');
            print('조회된 계약 상세 정보 수: ${contractDetails.length}');
            
            // 각 계약에 상세 정보 병합 (예약 시간 제약을 만족하는 계약만)
            finalValidPrepaidCredits = <Map<String, dynamic>>[];
            for (final contract in validPrepaidCredits) {
              final historyId = contract['contract_history_id']?.toString();
              if (historyId != null && contractDetails.containsKey(historyId)) {
                contract.addAll(contractDetails[historyId]!);
                
                // max_min_reservation_ahead 예약 시간 제약 체크
                bool isTimeConstraintValid = true;
                final maxMinReservationAhead = contract['max_min_reservation_ahead'];
                print('💳 선불크레딧 계약 ${historyId}: max_min_reservation_ahead = ${maxMinReservationAhead}');
                
                if (maxMinReservationAhead != null && maxMinReservationAhead != 'null' && maxMinReservationAhead != '') {
                  try {
                    final minReservationMinutes = int.tryParse(maxMinReservationAhead.toString());
                    print('💳 선불크레딧 계약 ${historyId}: 파싱된 최소 예약 시간 = ${minReservationMinutes}분');
                    
                    if (minReservationMinutes != null && minReservationMinutes > 0 && 
                        widget.selectedDate != null && widget.selectedTime != null) {
                      
                      final selectedTimeParts = widget.selectedTime!.split(':');
                      final selectedHour = int.parse(selectedTimeParts[0]);
                      final selectedMinute = int.parse(selectedTimeParts[1]);
                      
                      final reservationDateTime = DateTime(
                        widget.selectedDate!.year,
                        widget.selectedDate!.month,
                        widget.selectedDate!.day,
                        selectedHour,
                        selectedMinute,
                      );
                      
                      final now = DateTime.now();
                      final timeDifferenceMinutes = reservationDateTime.difference(now).inMinutes;
                      
                      print('💳 선불크레딧 계약 ${historyId}: 현재 시간 = ${now}');
                      print('💳 선불크레딧 계약 ${historyId}: 예약 시간 = ${reservationDateTime}');
                      print('💳 선불크레딧 계약 ${historyId}: 시간 차이 = ${timeDifferenceMinutes}분');
                      print('💳 선불크레딧 계약 ${historyId}: 최소 필요 시간 = ${minReservationMinutes}분');
                      
                      if (timeDifferenceMinutes > minReservationMinutes) {
                        print('❌ 선불크레딧 계약 ${historyId}: 예약 시간 제약 불일치 (${timeDifferenceMinutes}분 > ${minReservationMinutes}분) - 제외 (임박한 예약만 허용)');
                        isTimeConstraintValid = false;
                      } else {
                        print('✅ 선불크레딧 계약 ${historyId}: 예약 시간 제약 통과 (${timeDifferenceMinutes}분 <= ${minReservationMinutes}분) - 임박한 예약');
                      }
                    }
                  } catch (e) {
                    print('❌ 선불크레딧 계약 ${historyId}: 예약 시간 제약 파싱 오류 - $e');
                  }
                } else {
                  print('💳 선불크레딧 계약 ${historyId}: max_min_reservation_ahead 제약 없음');
                }
                
                if (isTimeConstraintValid) {
                  // max_ts_use_min과 max_use_per_day 제한 적용
                  int effectiveMaxMinutes = _totalMinutes; // 기본값은 전체 예약 시간

                  // 1. max_ts_use_min 제한 확인
                  final maxTsUseMin = contract['max_ts_use_min'];
                  if (maxTsUseMin != null && maxTsUseMin != 'null' && maxTsUseMin != '') {
                    try {
                      final maxMinutes = int.tryParse(maxTsUseMin.toString());
                      if (maxMinutes != null && maxMinutes > 0) {
                        effectiveMaxMinutes = effectiveMaxMinutes > maxMinutes ? maxMinutes : effectiveMaxMinutes;
                        print('  - max_ts_use_min 제한: ${maxMinutes}분');
                      }
                    } catch (e) {
                      print('  - max_ts_use_min 파싱 오류: $e');
                    }
                  }

                  // 2. max_use_per_day 제한 확인
                  final maxUsePerDay = contract['max_use_per_day'];
                  if (maxUsePerDay != null && maxUsePerDay != 'null' && maxUsePerDay != '') {
                    try {
                      final maxDailyMinutes = int.tryParse(maxUsePerDay.toString());
                      if (maxDailyMinutes != null && maxDailyMinutes > 0) {
                        // 당일 이미 사용한 분수 확인
                        final usedToday = dailyUsage[historyId] ?? 0;
                        final remainingToday = maxDailyMinutes - usedToday;

                        if (remainingToday <= 0) {
                          print('  - max_use_per_day 초과: 오늘 ${usedToday}분/${maxDailyMinutes}분 이미 사용 - 사용 불가');
                          isTimeConstraintValid = false;
                        } else {
                          effectiveMaxMinutes = effectiveMaxMinutes > remainingToday ? remainingToday : effectiveMaxMinutes;
                          print('  - max_use_per_day 제한: ${maxDailyMinutes}분 (오늘 ${usedToday}분 사용, ${remainingToday}분 남음)');
                        }
                      }
                    } catch (e) {
                      print('  - max_use_per_day 파싱 오류: $e');
                    }
                  }

                  if (isTimeConstraintValid && effectiveMaxMinutes > 0) {
                    // 실제 예약의 분당 가격으로 최대 사용 가능 금액 계산
                    final actualPricePerMinute = _totalPrice / _totalMinutes;
                    final maxUsableAmount = (effectiveMaxMinutes * actualPricePerMinute).round();
                    contract['max_usable_amount'] = maxUsableAmount;
                    print('  - 최종 최대 사용 가능 금액: ${maxUsableAmount}원 (${effectiveMaxMinutes}분 × ${actualPricePerMinute.toStringAsFixed(1)}원/분)');

                    print('\n선불크레디트 계약 ${historyId} 상세 정보 병합 완료');
                    print('  - max_min_reservation_ahead: ${contract['max_min_reservation_ahead']}');
                    print('  - coupon_issue_available: ${contract['coupon_issue_available']}');
                    print('  - coupon_use_available: ${contract['coupon_use_available']}');
                    print('  - max_ts_use_min: ${contract['max_ts_use_min']}');
                    print('  - max_use_per_day: ${contract['max_use_per_day']}');
                    print('  - 당일 사용량: ${dailyUsage[historyId] ?? 0}분');

                    finalValidPrepaidCredits.add(contract);
                  } else {
                    print('\n선불크레디트 계약 ${historyId}: 사용 불가 - 결제수단에서 제외');
                    print('  - 당일 사용량: ${dailyUsage[historyId] ?? 0}분');
                  }
                }
              }
            }
            
            finalValidTimePassContracts = <Map<String, dynamic>>[];
            for (final contract in validTimePassContracts) {
              final historyId = contract['contract_history_id']?.toString();
              if (historyId != null && contractDetails.containsKey(historyId)) {
                contract.addAll(contractDetails[historyId]!);
                
                // max_min_reservation_ahead 예약 시간 제약 체크
                bool isTimeConstraintValid = true;
                final maxMinReservationAhead = contract['max_min_reservation_ahead'];
                print('🕒 시간권 계약 ${historyId}: max_min_reservation_ahead = ${maxMinReservationAhead}');
                
                if (maxMinReservationAhead != null && maxMinReservationAhead != 'null' && maxMinReservationAhead != '') {
                  try {
                    final minReservationMinutes = int.tryParse(maxMinReservationAhead.toString());
                    print('🕒 시간권 계약 ${historyId}: 파싱된 최소 예약 시간 = ${minReservationMinutes}분');
                    
                    if (minReservationMinutes != null && minReservationMinutes > 0 && 
                        widget.selectedDate != null && widget.selectedTime != null) {
                      
                      final selectedTimeParts = widget.selectedTime!.split(':');
                      final selectedHour = int.parse(selectedTimeParts[0]);
                      final selectedMinute = int.parse(selectedTimeParts[1]);
                      
                      final reservationDateTime = DateTime(
                        widget.selectedDate!.year,
                        widget.selectedDate!.month,
                        widget.selectedDate!.day,
                        selectedHour,
                        selectedMinute,
                      );
                      
                      final now = DateTime.now();
                      final timeDifferenceMinutes = reservationDateTime.difference(now).inMinutes;
                      
                      print('🕒 시간권 계약 ${historyId}: 현재 시간 = ${now}');
                      print('🕒 시간권 계약 ${historyId}: 예약 시간 = ${reservationDateTime}');
                      print('🕒 시간권 계약 ${historyId}: 시간 차이 = ${timeDifferenceMinutes}분');
                      print('🕒 시간권 계약 ${historyId}: 최소 필요 시간 = ${minReservationMinutes}분');
                      
                      if (timeDifferenceMinutes > minReservationMinutes) {
                        print('❌ 시간권 계약 ${historyId}: 예약 시간 제약 불일치 (${timeDifferenceMinutes}분 > ${minReservationMinutes}분) - 제외 (임박한 예약만 허용)');
                        isTimeConstraintValid = false;
                      } else {
                        print('✅ 시간권 계약 ${historyId}: 예약 시간 제약 통과 (${timeDifferenceMinutes}분 <= ${minReservationMinutes}분) - 임박한 예약');
                      }
                    }
                  } catch (e) {
                    print('❌ 시간권 계약 ${historyId}: 예약 시간 제약 파싱 오류 - $e');
                  }
                } else {
                  print('🕒 시간권 계약 ${historyId}: max_min_reservation_ahead 제약 없음');
                }
                
                if (isTimeConstraintValid) {
                  final currentBalance = contract['balance'] as int? ?? 0;
                  int effectiveMaxMinutes = currentBalance; // 기본값은 현재 잔액

                  // 1. max_ts_use_min 제한 확인
                  final maxTsUseMin = contract['max_ts_use_min'];
                  if (maxTsUseMin != null && maxTsUseMin != 'null' && maxTsUseMin != '') {
                    try {
                      final maxMinutes = int.tryParse(maxTsUseMin.toString());
                      if (maxMinutes != null && maxMinutes > 0) {
                        effectiveMaxMinutes = effectiveMaxMinutes > maxMinutes ? maxMinutes : effectiveMaxMinutes;
                        print('  - max_ts_use_min 제한: ${maxMinutes}분');
                      }
                    } catch (e) {
                      print('  - max_ts_use_min 파싱 오류: $e');
                    }
                  }

                  // 2. max_use_per_day 제한 확인
                  final maxUsePerDay = contract['max_use_per_day'];
                  if (maxUsePerDay != null && maxUsePerDay != 'null' && maxUsePerDay != '') {
                    try {
                      final maxDailyMinutes = int.tryParse(maxUsePerDay.toString());
                      if (maxDailyMinutes != null && maxDailyMinutes > 0) {
                        // 당일 이미 사용한 분수 확인
                        final usedToday = dailyUsage[historyId] ?? 0;
                        final remainingToday = maxDailyMinutes - usedToday;

                        if (remainingToday <= 0) {
                          print('  - max_use_per_day 초과: 오늘 ${usedToday}분/${maxDailyMinutes}분 이미 사용 - 사용 불가');
                          isTimeConstraintValid = false;
                        } else {
                          effectiveMaxMinutes = effectiveMaxMinutes > remainingToday ? remainingToday : effectiveMaxMinutes;
                          print('  - max_use_per_day 제한: ${maxDailyMinutes}분 (오늘 ${usedToday}분 사용, ${remainingToday}분 남음)');
                        }
                      }
                    } catch (e) {
                      print('  - max_use_per_day 파싱 오류: $e');
                    }
                  }

                  if (isTimeConstraintValid && effectiveMaxMinutes > 0) {
                    contract['usable_balance'] = effectiveMaxMinutes;
                    print('  - 최종 사용 가능 시간: ${effectiveMaxMinutes}분 (잔액: ${currentBalance}분)');

                    print('\n시간권 계약 ${historyId} 상세 정보 병합 완료');
                    print('  - max_min_reservation_ahead: ${contract['max_min_reservation_ahead']}');
                    print('  - coupon_issue_available: ${contract['coupon_issue_available']}');
                    print('  - coupon_use_available: ${contract['coupon_use_available']}');
                    print('  - max_ts_use_min: ${contract['max_ts_use_min']}');
                    print('  - max_use_per_day: ${contract['max_use_per_day']}');
                    print('  - 당일 사용량: ${dailyUsage[historyId] ?? 0}분');

                    finalValidTimePassContracts.add(contract);
                  } else {
                    print('\n시간권 계약 ${historyId}: 사용 불가 - 결제수단에서 제외');
                    print('  - 당일 사용량: ${dailyUsage[historyId] ?? 0}분');
                  }
                }
              }
            }
            
            finalValidPeriodPassContracts = <Map<String, dynamic>>[];
            for (final contract in validPeriodPassContracts) {
              final historyId = contract['contract_history_id']?.toString();
              if (historyId != null && contractDetails.containsKey(historyId)) {
                contract.addAll(contractDetails[historyId]!);
                
                // max_min_reservation_ahead 예약 시간 제약 체크
                bool isTimeConstraintValid = true;
                final maxMinReservationAhead = contract['max_min_reservation_ahead'];
                print('📅 기간권 계약 ${historyId}: max_min_reservation_ahead = ${maxMinReservationAhead}');
                
                if (maxMinReservationAhead != null && maxMinReservationAhead != 'null' && maxMinReservationAhead != '') {
                  try {
                    final minReservationMinutes = int.tryParse(maxMinReservationAhead.toString());
                    print('📅 기간권 계약 ${historyId}: 파싱된 최소 예약 시간 = ${minReservationMinutes}분');
                    
                    if (minReservationMinutes != null && minReservationMinutes > 0 && 
                        widget.selectedDate != null && widget.selectedTime != null) {
                      
                      final selectedTimeParts = widget.selectedTime!.split(':');
                      final selectedHour = int.parse(selectedTimeParts[0]);
                      final selectedMinute = int.parse(selectedTimeParts[1]);
                      
                      final reservationDateTime = DateTime(
                        widget.selectedDate!.year,
                        widget.selectedDate!.month,
                        widget.selectedDate!.day,
                        selectedHour,
                        selectedMinute,
                      );
                      
                      final now = DateTime.now();
                      final timeDifferenceMinutes = reservationDateTime.difference(now).inMinutes;
                      
                      print('📅 기간권 계약 ${historyId}: 현재 시간 = ${now}');
                      print('📅 기간권 계약 ${historyId}: 예약 시간 = ${reservationDateTime}');
                      print('📅 기간권 계약 ${historyId}: 시간 차이 = ${timeDifferenceMinutes}분');
                      print('📅 기간권 계약 ${historyId}: 최소 필요 시간 = ${minReservationMinutes}분');
                      
                      if (timeDifferenceMinutes > minReservationMinutes) {
                        print('❌ 기간권 계약 ${historyId}: 예약 시간 제약 불일치 (${timeDifferenceMinutes}분 > ${minReservationMinutes}분) - 제외 (임박한 예약만 허용)');
                        isTimeConstraintValid = false;
                      } else {
                        print('✅ 기간권 계약 ${historyId}: 예약 시간 제약 통과 (${timeDifferenceMinutes}분 <= ${minReservationMinutes}분) - 임박한 예약');
                      }
                    }
                  } catch (e) {
                    print('❌ 기간권 계약 ${historyId}: 예약 시간 제약 파싱 오류 - $e');
                  }
                } else {
                  print('📅 기간권 계약 ${historyId}: max_min_reservation_ahead 제약 없음');
                }
                
                if (isTimeConstraintValid) {
                  print('\n기간권 계약 ${historyId} 상세 정보 병합 완료');
                  print('  - max_min_reservation_ahead: ${contract['max_min_reservation_ahead']}');
                  print('  - coupon_issue_available: ${contract['coupon_issue_available']}');
                  print('  - coupon_use_available: ${contract['coupon_use_available']}');
                  print('  - max_ts_use_min: ${contract['max_ts_use_min']}');
                  print('  - max_use_per_day: ${contract['max_use_per_day']}');
                  print('  - 당일 사용량: ${dailyUsage[historyId] ?? 0}분');
                  
                  finalValidPeriodPassContracts.add(contract);
                }
              }
            }
            
            _contractDetailsMap = contractDetails;
          }
          
          if (mounted) {
            setState(() {
              _prepaidCreditContracts = finalValidPrepaidCredits;
              _balances['time_pass'] = timePassBalance;
              // _periodPassInfo = periodPassInfo; // 더 이상 사용하지 않음
              _periodPassContracts = finalValidPeriodPassContracts; // 계약별 기간권 정보 저장
              _timePassContracts = finalValidTimePassContracts;
              _isLoadingBalance = false;
            });
            
            print('=== 상태 업데이트 완료 ===');
            print('_prepaidCreditContracts 길이: ${_prepaidCreditContracts.length}');
            print('_timePassContracts 길이: ${_timePassContracts.length}');
            print('_periodPassContracts 길이: ${_periodPassContracts.length}');
            print('_paymentMethods 길이: ${_paymentMethods.length}');
          }
        } catch (e) {
          print('회원 정보 조회 실패: $e');
          if (mounted) {
            setState(() {
              _isLoadingBalance = false;
              // 실패 시 기본값 유지
            });
          }
        }
      }
    }
  }

  // 미정산 잔액 계산
  Map<String, dynamic> calculateRemainingBalance() {
    int remainingPrice = _totalPrice;
    int remainingMinutes = _totalMinutes;
    
    // 결제수단별 사용액 추적을 위한 맵
    Map<String, int> usedAmounts = {};
    // 계약 정보 추적을 위한 맵
    Map<String, Map<String, dynamic>> contractInfo = {};
    
    for (var selectedMethod in _selectedPaymentMethods) {
      final methodType = selectedMethod['type'];
      
      if (methodType.startsWith('period_pass_')) {
        // 계약별 기간권: 분으로 차감
        final contractHistoryId = methodType.replaceFirst('period_pass_', '');
        final contract = _periodPassContracts.firstWhere(
          (c) => c['contract_history_id'] == contractHistoryId,
          orElse: () => {'usable_minutes': 0},
        );
        final usableMinutes = contract['usable_minutes'] as int? ?? 0;
        final useMinutes = remainingMinutes > usableMinutes ? usableMinutes : remainingMinutes;
        usedAmounts[methodType] = useMinutes;
        // 계약 정보 저장
        contractInfo[methodType] = {
          'contract_history_id': contractHistoryId,
          'expiry_date': contract['expiry_date'],
          'contract_id': contract['contract_id'],
        };
        remainingMinutes -= useMinutes;
        remainingPrice = (remainingMinutes * _pricePerMinute).round();
      } else if (methodType.startsWith('prepaid_credit_')) {
        // 계약별 선불크레딧: 원으로 차감
        final contractHistoryId = methodType.replaceFirst('prepaid_credit_', '');
        final contract = _prepaidCreditContracts.firstWhere(
          (c) => c['contract_history_id'] == contractHistoryId,
          orElse: () => {'balance': 0},
        );
        final balance = contract['balance'] as int;
        
        // max_usable_amount가 설정되어 있으면 해당 금액까지만 사용 가능
        int effectiveBalance = balance;
        final maxUsableAmount = contract['max_usable_amount'] as int?;
        if (maxUsableAmount != null && maxUsableAmount > 0) {
          effectiveBalance = balance > maxUsableAmount ? maxUsableAmount : balance;
        }
        
        final useAmount = remainingPrice > effectiveBalance ? effectiveBalance : remainingPrice;
        usedAmounts[methodType] = useAmount;
        // 계약 정보 저장
        contractInfo[methodType] = {
          'contract_history_id': contractHistoryId,
          'expiry_date': contract['expiry_date'],
          'contract_id': contract['contract_id'],
        };
        remainingPrice -= useAmount;
        remainingMinutes = (remainingPrice / _pricePerMinute).ceil();
      } else if (methodType.startsWith('time_pass_')) {
        // 계약별 시간권: 분으로 차감
        final contractHistoryId = methodType.replaceFirst('time_pass_', '');
        final contract = _timePassContracts.firstWhere(
          (c) => c['contract_history_id'] == contractHistoryId,
          orElse: () => {'balance': 0},
        );
        
        // usable_balance가 설정되어 있으면 해당 분수까지만 사용 가능
        final balance = contract['usable_balance'] as int? ?? contract['balance'] as int;
        final useMinutes = remainingMinutes > balance ? balance : remainingMinutes;
        usedAmounts[methodType] = useMinutes;
        // 계약 정보 저장
        contractInfo[methodType] = {
          'contract_history_id': contractHistoryId,
          'expiry_date': contract['expiry_date'],
          'contract_id': contract['contract_id'],
        };
        remainingMinutes -= useMinutes;
        remainingPrice = (remainingMinutes * _pricePerMinute).round();
      }

      if (remainingPrice <= 0) break;
    }
    
    final isFullyPaid = remainingPrice <= 0;
    
    return {
      'remainingPrice': remainingPrice,
      'remainingMinutes': remainingMinutes,
      'isFullyPaid': isFullyPaid,
      'usedAmounts': usedAmounts, // 사용된 금액 정보도 반환
      'contractInfo': contractInfo, // 계약 정보도 반환
    };
  }

  // 결제 완료 시 디버깅 정보 출력
  void printPaymentDebugInfo(Map<String, dynamic> usedAmounts) {
    print('=== 결제 완료 디버깅 정보 시작 ===');
    print('');
    
    // 예약 기본 정보
    print('📅 예약 날짜: ${widget.selectedDate != null ? "${widget.selectedDate!.year}-${widget.selectedDate!.month.toString().padLeft(2, '0')}-${widget.selectedDate!.day.toString().padLeft(2, '0')}" : "미선택"}');
    print('⏰ 시작 시간: ${widget.selectedTime ?? "미선택"}');
    print('⏱️ 연습 시간: ${widget.selectedDuration ?? 0}분');
    
    // 종료 시간 계산
    if (widget.selectedTime != null && widget.selectedDuration != null) {
      try {
        final startTimeParts = widget.selectedTime!.split(':');
        final startHour = int.parse(startTimeParts[0]);
        final startMinute = int.parse(startTimeParts[1]);
        final endDateTime = DateTime(2000, 1, 1, startHour, startMinute).add(Duration(minutes: widget.selectedDuration!));
        final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';
        print('🏁 종료 시간: $endTime');
      } catch (e) {
        print('🏁 종료 시간: 계산 오류');
      }
    } else {
      print('🏁 종료 시간: 계산 불가');
    }
    
    // 시간대 분류 정보 추가
    if (widget.pricingAnalysis != null) {
      print('⏰ 시간대 분류:');
      final normalMin = widget.pricingAnalysis!['base_price'] ?? 0;
      final discountMin = widget.pricingAnalysis!['discount_price'] ?? 0;
      final extrachargeMin = widget.pricingAnalysis!['extracharge_price'] ?? 0;
      print('   - normal_min: ${normalMin}분');
      print('   - discount_min: ${discountMin}분');
      print('   - extracharge_min: ${extrachargeMin}분');
    } else {
      print('⏰ 시간대 분류: 정보 없음');
    }
    
    print('🎯 선택한 타석: ${widget.selectedTs ?? "미선택"}');
    
    // 할인권 사용 가능 여부 검증
    if (widget.selectedCoupons != null && widget.selectedCoupons!.isNotEmpty) {
      print('🔍 할인권 사용 가능 여부 검증 시작');
      
      // 선택된 결제수단 중 할인권 사용 불가능한 계약 확인
      List<String> couponUnavailableContracts = [];
      
      for (var selectedMethod in _selectedPaymentMethods) {
        final methodType = selectedMethod['type'];
        
        if (methodType.startsWith('prepaid_credit_')) {
          final contractHistoryId = methodType.replaceFirst('prepaid_credit_', '');
          final contract = _prepaidCreditContracts.firstWhere(
            (c) => c['contract_history_id'] == contractHistoryId,
            orElse: () => {},
          );
          final couponUseAvailable = contract['coupon_use_available']?.toString() ?? '';
          if (couponUseAvailable == '불가능') {
            couponUnavailableContracts.add('선불크레딧 계약 $contractHistoryId (${contract['contract_name'] ?? 'Unknown'})');
          }
        } else if (methodType.startsWith('time_pass_')) {
          final contractHistoryId = methodType.replaceFirst('time_pass_', '');
          final contract = _timePassContracts.firstWhere(
            (c) => c['contract_history_id'] == contractHistoryId,
            orElse: () => {},
          );
          final couponUseAvailable = contract['coupon_use_available']?.toString() ?? '';
          if (couponUseAvailable == '불가능') {
            couponUnavailableContracts.add('시간권 계약 $contractHistoryId (${contract['contract_name'] ?? 'Unknown'})');
          }
        } else if (methodType.startsWith('period_pass_')) {
          final contractHistoryId = methodType.replaceFirst('period_pass_', '');
          final contract = _periodPassContracts.firstWhere(
            (c) => c['contract_history_id'] == contractHistoryId,
            orElse: () => {},
          );
          final couponUseAvailable = contract['coupon_use_available']?.toString() ?? '';
          if (couponUseAvailable == '불가능') {
            couponUnavailableContracts.add('기간권 계약 $contractHistoryId (${contract['contract_name'] ?? 'Unknown'})');
          }
        }
      }
      
      if (couponUnavailableContracts.isNotEmpty) {
        print('❌ 할인권 사용 불가능한 계약들:');
        for (String contract in couponUnavailableContracts) {
          print('   - $contract');
        }
        
        // 사용자에게 경고 표시
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCouponUnavailableDialog(couponUnavailableContracts);
        });
        
        return; // 할인권 적용 중단
      } else {
        print('✅ 모든 선택된 계약에서 할인권 사용 가능');
      }
    }
    
    // 할인 내역 (여러 할인권 지원)
    if (widget.selectedCoupons != null && widget.selectedCoupons!.isNotEmpty) {
      print('🎫 선택된 할인내역 (총 ${widget.selectedCoupons!.length}개):');
      for (int i = 0; i < widget.selectedCoupons!.length; i++) {
        final coupon = widget.selectedCoupons![i];
        print('   ${i + 1}. 쿠폰 ID: ${coupon['coupon_id'] ?? "없음"} (타입: ${coupon['coupon_type'] ?? "없음"})');
        if (coupon['coupon_type'] == '정률권') {
          print('      할인율: ${coupon['discount_ratio'] ?? 0}%');
        } else if (coupon['coupon_type'] == '정액권') {
          print('      할인액: ${coupon['discount_amt'] ?? 0}원');
        } else if (coupon['coupon_type'] == '시간권') {
          print('      할인시간: ${coupon['discount_min'] ?? 0}분');
        }
      }
      
    } else {
      print('🎫 선택된 할인내역: 없음');
    }
    
    print('');
    print('💳 등록된 결제수단 잔액 변화:');
    
    // 등록된 결제수단들의 잔액 변화
    for (var selectedMethod in _selectedPaymentMethods) {
      final methodType = selectedMethod['type'];
      final usedAmount = usedAmounts[methodType] ?? 0;
      
      if (methodType.startsWith('prepaid_credit_')) {
        final contractHistoryId = methodType.replaceFirst('prepaid_credit_', '');
        final contract = _prepaidCreditContracts.firstWhere(
          (c) => c['contract_history_id'] == contractHistoryId,
          orElse: () => {'balance': 0, 'contract_id': 'Unknown'},
        );
        final originalBalance = contract['balance'] as int;
        final afterBalance = originalBalance - usedAmount;
        final contractId = contract['contract_id'] ?? 'Unknown';
        
        print('   ✅ [테이블: v2_bills] 선불크레딧 (계약번호: $contractId)');
        print('      bill_balance_before: ${originalBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원 → bill_netamt: ${usedAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원 → bill_balance_after: ${afterBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원');
        
      } else if (methodType.startsWith('time_pass_')) {
        final contractHistoryId = methodType.replaceFirst('time_pass_', '');
        final contract = _timePassContracts.firstWhere(
          (c) => c['contract_history_id'] == contractHistoryId,
          orElse: () => {'balance': 0, 'contract_id': 'Unknown'},
        );
        final originalBalance = contract['balance'] as int;
        final afterBalance = originalBalance - usedAmount;
        final contractId = contract['contract_id'] ?? 'Unknown';
        
        print('   ✅ [테이블: v2_bill_times] 시간권 (계약번호: $contractId)');
        print('      bill_balance_min_before: ${originalBalance}분 → bill_min: ${usedAmount}분 → bill_balance_min_after: ${afterBalance}분');
        
      } else {
        final originalBalance = _balances[methodType];
        
        if (methodType == 'period_pass') {
          final afterBalance = (originalBalance as int) - usedAmount;
          print('   ✅ [테이블: v3_contract_history] 기간권');
          print('      사용가능분수: ${originalBalance}분 → 차감액: ${usedAmount}분 → 차감후: ${afterBalance}분');
          
        }
      }
    }
    
    print('');
    print('💰 선택되지 않은 결제수단 잔액:');
    
    // 선택되지 않은 결제수단들의 잔액 (차감액 0)
    final selectedTypes = _selectedPaymentMethods.map((m) => m['type']).toSet();
    
    // 선불크레딧
    for (final contract in _prepaidCreditContracts) {
      final methodType = 'prepaid_credit_${contract['contract_history_id']}';
      if (!selectedTypes.contains(methodType)) {
        final balance = contract['balance'] as int;
        final contractId = contract['contract_id'] ?? 'Unknown';
        print('   ⭕ [테이블: v2_bills] 선불크레딧 (계약번호: $contractId)');
        print('      bill_balance_before: ${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원 → bill_netamt: 0원 → bill_balance_after: ${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원');
      }
    }
    
    // 시간권
    for (final contract in _timePassContracts) {
      final methodType = 'time_pass_${contract['contract_history_id']}';
      if (!selectedTypes.contains(methodType)) {
        final balance = contract['balance'] as int;
        final contractId = contract['contract_id'] ?? 'Unknown';
        print('   ⭕ [테이블: v2_bill_times] 시간권 (계약번호: $contractId)');
        print('      bill_balance_min_before: ${balance}분 → bill_min: 0분 → bill_balance_min_after: ${balance}분');
      }
    }
    
    // 기본 결제수단들
    for (final method in _basePaymentMethods) {
      final methodType = method['type'];
      if (!selectedTypes.contains(methodType)) {
        final balance = _balances[methodType];
        
        if (methodType == 'period_pass') {
          print('   ⭕ [테이블: v3_contract_history] 기간권');
          print('      사용가능분수: ${balance}분 → 차감액: 0분 → 차감후: ${balance}분');
          
        }
      }
    }
    
    print('=== 결제 완료 디버깅 정보 끝 ===\n');
  }

  // 선택된 결제 방법 목록 반환
  List<Map<String, dynamic>> getSelectedPaymentMethods() {
    return _selectedPaymentMethods;
  }

  // 선불크레딧 계약 정보 반환
  List<Map<String, dynamic>> getPrepaidCreditContracts() {
    return _prepaidCreditContracts;
  }

  // 시간권 계약 정보 반환
  List<Map<String, dynamic>> getTimePassContracts() {
    return _timePassContracts;
  }

  // 기간권 계약 정보 반환
  List<Map<String, dynamic>> getPeriodPassContracts() {
    return _periodPassContracts;
  }

  // 각 기간권 계약의 사용 가능 분수 계산
  Future<int> _calculateContractUsableMinutes({
    required Map<String, dynamic> contract,
    required DateTime selectedDate,
    required String selectedTime,
    required int duration,
    required String selectedTs,
    Map<String, int>? dailyUsage,
  }) async {
    // 1. 시간대 체크
    final availableStartTime = contract['available_start_time']?.toString();
    final availableEndTime = contract['available_end_time']?.toString();

    if (availableStartTime != null && availableStartTime.isNotEmpty && availableStartTime != 'null' &&
        availableEndTime != null && availableEndTime.isNotEmpty && availableEndTime != 'null') {

      // "전체"는 모든 시간 허용 (제약 없음)
      if (availableStartTime == '전체' || availableEndTime == '전체') {
        print('기간권 ${contract['contract_history_id']}: 시간 제약 없음 (전체)');
      } else {
        try {
          // 선택한 시간을 분 단위로 변환
          final selectedTimeParts = selectedTime.split(':');
          final selectedHour = int.parse(selectedTimeParts[0]);
          final selectedMinute = int.parse(selectedTimeParts[1]);
          final selectedTimeInMinutes = selectedHour * 60 + selectedMinute;
          final selectedEndTimeInMinutes = selectedTimeInMinutes + duration;

          // 이용 가능 시간을 분 단위로 변환
          final availableStartParts = availableStartTime.split(':');
          final availableStartHour = int.parse(availableStartParts[0]);
          final availableStartMinute = availableStartParts.length > 1 ? int.parse(availableStartParts[1]) : 0;
          final availableStartInMinutes = availableStartHour * 60 + availableStartMinute;

          final availableEndParts = availableEndTime.split(':');
          final availableEndHour = int.parse(availableEndParts[0]);
          final availableEndMinute = availableEndParts.length > 1 ? int.parse(availableEndParts[1]) : 0;
          final availableEndInMinutes = availableEndHour * 60 + availableEndMinute;

          // 예약 시간이 이용 가능 시간 범위를 벗어나는지 체크
          if (selectedTimeInMinutes < availableStartInMinutes ||
              selectedEndTimeInMinutes > availableEndInMinutes) {
            print('기간권 ${contract['contract_history_id']}: 시간대 불일치');
            print('  이용 가능: $availableStartTime ~ $availableEndTime');
            print('  선택 시간: $selectedTime ~ 종료 ${duration}분 후');
            return 0; // 시간대가 맞지 않음
          }
        } catch (e) {
          print('기간권 ${contract['contract_history_id']}: 시간 파싱 오류 - $e');
        }
      }
    }
    
    // 3. 예약 시간 제약 체크 (max_min_reservation_ahead)
    final maxMinReservationAhead = contract['max_min_reservation_ahead'];
    if (maxMinReservationAhead != null && maxMinReservationAhead != 'null' && maxMinReservationAhead != '') {
      try {
        final minReservationMinutes = int.tryParse(maxMinReservationAhead.toString());
        if (minReservationMinutes != null && minReservationMinutes > 0) {
          // 선택된 예약 날짜와 시간을 DateTime으로 변환
          final selectedTimeParts = selectedTime.split(':');
          final selectedHour = int.parse(selectedTimeParts[0]);
          final selectedMinute = int.parse(selectedTimeParts[1]);
          
          final reservationDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedHour,
            selectedMinute,
          );
          
          // 현재 시간과의 차이 계산 (분 단위)
          final now = DateTime.now();
          final timeDifferenceMinutes = reservationDateTime.difference(now).inMinutes;
          
          print('기간권 ${contract['contract_history_id']}: 예약 시간 제약 확인');
          print('  현재 시간: $now');
          print('  예약 시간: $reservationDateTime');
          print('  시간 차이: ${timeDifferenceMinutes}분');
          print('  최소 예약 시간: ${minReservationMinutes}분');
          
          // 예약 시간이 최소 예약 시간보다 가까우면 사용 불가
          if (timeDifferenceMinutes < minReservationMinutes) {
            print('기간권 ${contract['contract_history_id']}: 예약 시간 제약 불일치 (${timeDifferenceMinutes}분 < ${minReservationMinutes}분)');
            return 0;
          }
          
          print('기간권 ${contract['contract_history_id']}: 예약 시간 제약 통과');
        }
      } catch (e) {
        print('기간권 ${contract['contract_history_id']}: 예약 시간 제약 파싱 오류 - $e');
      }
    }
    
    // 4. 타석 체크
    final availableTsId = contract['available_ts_id']?.toString();
    if (availableTsId != null && availableTsId.isNotEmpty && availableTsId != 'null') {
      // "없음" 또는 "전체"는 모든 타석 허용 (제약 없음)
      if (availableTsId == '없음' || availableTsId == '전체') {
        print('기간권 ${contract['contract_history_id']}: 타석 제약 없음 ($availableTsId)');
      } else {
        // 예: "1,2,3" 또는 "1-5" 형식 처리
        bool isTsAvailable = false;

        if (availableTsId.contains('-')) {
          // 범위 형식 (1-5)
          final rangeParts = availableTsId.split('-');
          if (rangeParts.length == 2) {
            try {
              final startTs = int.parse(rangeParts[0].trim());
              final endTs = int.parse(rangeParts[1].trim());
              final selectedTsNum = int.parse(selectedTs);

              if (selectedTsNum >= startTs && selectedTsNum <= endTs) {
                isTsAvailable = true;
              }
            } catch (e) {
              print('기간권 ${contract['contract_history_id']}: 타석 범위 파싱 오류 - $e');
            }
          }
        } else if (availableTsId.contains(',')) {
          // 개별 목록 (1,2,3)
          final tsList = availableTsId.split(',').map((t) => t.trim()).toList();
          if (tsList.contains(selectedTs)) {
            isTsAvailable = true;
          }
        } else {
          // 단일 타석
          if (availableTsId.trim() == selectedTs) {
            isTsAvailable = true;
          }
        }

        if (!isTsAvailable) {
          print('기간권 ${contract['contract_history_id']}: 타석 불일치 (설정: $availableTsId, 선택: $selectedTs)');
          return 0; // 타석이 맞지 않음
        }
      }
    }
    
    // 5. 선택 불가능 타석 체크 (prohibited_ts_id)
    final prohibitedTsId = contract['prohibited_ts_id']?.toString();
    if (prohibitedTsId != null && prohibitedTsId.isNotEmpty && prohibitedTsId != 'null') {
      // 콤마로 구분된 타석 ID 리스트로 변환
      final prohibitedTsList = prohibitedTsId.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      
      // 선택한 타석이 제한된 타석 목록에 포함되어 있는지 확인
      if (prohibitedTsList.contains(selectedTs)) {
        print('기간권 ${contract['contract_history_id']}: 선택 불가능한 타석 (제한된 타석: $prohibitedTsId, 선택: $selectedTs)');
        return 0; // 선택 불가능한 타석
      }
      
      print('기간권 ${contract['contract_history_id']}: 선택 가능한 타석 (제한된 타석: $prohibitedTsId, 선택: $selectedTs)');
    }
    
    // 모든 조건을 통과한 경우 사용 가능 분수 반환
    int maxMinutes = duration; // 기본값은 예약 시간

    // 1. max_ts_use_min 제한 확인
    final maxTsUseMin = contract['max_ts_use_min'];
    if (maxTsUseMin != null && maxTsUseMin != 'null' && maxTsUseMin != '') {
      try {
        final maxLimit = int.tryParse(maxTsUseMin.toString());
        if (maxLimit != null && maxLimit > 0) {
          maxMinutes = duration > maxLimit ? maxLimit : duration;
          print('기간권 ${contract['contract_history_id']}: max_ts_use_min 제한 - 최대 ${maxLimit}분');
        }
      } catch (e) {
        print('기간권 ${contract['contract_history_id']}: max_ts_use_min 파싱 오류 - $e');
        // 파싱 오류 시 기본값 60분 사용
        maxMinutes = duration > 60 ? 60 : duration;
      }
    } else {
      // max_ts_use_min이 없으면 기본값 60분 사용
      maxMinutes = duration > 60 ? 60 : duration;
      print('기간권 ${contract['contract_history_id']}: max_ts_use_min 미설정 - 기본 60분 제한 적용');
    }

    // 2. max_use_per_day 제한 확인
    final maxUsePerDay = contract['max_use_per_day'];
    if (maxUsePerDay != null && maxUsePerDay != 'null' && maxUsePerDay != '' && dailyUsage != null) {
      try {
        final maxDailyMinutes = int.tryParse(maxUsePerDay.toString());
        if (maxDailyMinutes != null && maxDailyMinutes > 0) {
          // 당일 이미 사용한 분수 확인
          final contractHistoryId = contract['contract_history_id']?.toString();
          final usedToday = dailyUsage[contractHistoryId] ?? 0;
          final remainingToday = maxDailyMinutes - usedToday;

          if (remainingToday <= 0) {
            print('기간권 ${contract['contract_history_id']}: max_use_per_day 초과 - 오늘 ${usedToday}분/${maxDailyMinutes}분 이미 사용');
            return 0; // 사용 불가
          } else {
            maxMinutes = maxMinutes > remainingToday ? remainingToday : maxMinutes;
            print('기간권 ${contract['contract_history_id']}: max_use_per_day 제한 - ${maxDailyMinutes}분 (오늘 ${usedToday}분 사용, ${remainingToday}분 남음)');
          }
        }
      } catch (e) {
        print('기간권 ${contract['contract_history_id']}: max_use_per_day 파싱 오류 - $e');
      }
    }

    print('기간권 ${contract['contract_history_id']}: 모든 조건 통과, 최종 사용 가능 ${maxMinutes}분');
    return maxMinutes;
  }

  // 결제수단 등록 상세 계산
  List<Map<String, dynamic>> _calculatePaymentDetails() {
    List<Map<String, dynamic>> details = [];
    int remainingPrice = _totalPrice;
    int remainingMinutes = _totalMinutes;
    
    for (var selectedMethod in _selectedPaymentMethods) {
      final methodType = selectedMethod['type'];
      final method = _paymentMethods.firstWhere((m) => m['type'] == methodType);
      
      Map<String, dynamic> detail = {
        'method': method['title'],
        'type': methodType,
        'icon': method['icon'],
      };
      
      if (methodType.startsWith('period_pass_')) {
        // 계약별 기간권: 분으로 차감
        final contractHistoryId = methodType.replaceFirst('period_pass_', '');
        final contract = _periodPassContracts.firstWhere(
          (c) => c['contract_history_id'] == contractHistoryId,
          orElse: () => {'usable_minutes': 0},
        );
        final usableMinutes = contract['usable_minutes'] as int? ?? 0;
        final useMinutes = remainingMinutes > usableMinutes ? usableMinutes : remainingMinutes;
        detail['amount'] = useMinutes;
        detail['unit'] = '분';
        remainingMinutes -= useMinutes;
        remainingPrice = (remainingMinutes * _pricePerMinute).round();
      } else if (methodType.startsWith('prepaid_credit_')) {
        // 계약별 선불크레딧: 원으로 차감
        final contractHistoryId = methodType.replaceFirst('prepaid_credit_', '');
        final contract = _prepaidCreditContracts.firstWhere(
          (c) => c['contract_history_id'] == contractHistoryId,
          orElse: () => {'balance': 0},
        );
        final balance = contract['balance'] as int;
        final useAmount = remainingPrice > balance ? balance : remainingPrice;
        detail['amount'] = useAmount;
        detail['unit'] = '원';
        remainingPrice -= useAmount;
        remainingMinutes = (remainingPrice / _pricePerMinute).ceil();
      } else if (methodType.startsWith('time_pass_')) {
        // 계약별 시간권: 분으로 차감
        final contractHistoryId = methodType.replaceFirst('time_pass_', '');
        final contract = _timePassContracts.firstWhere(
          (c) => c['contract_history_id'] == contractHistoryId,
          orElse: () => {'balance': 0},
        );
        final balance = contract['balance'] as int;
        final useMinutes = remainingMinutes > balance ? balance : remainingMinutes;
        detail['amount'] = useMinutes;
        detail['unit'] = '분';
        remainingMinutes -= useMinutes;
        remainingPrice = (remainingMinutes * _pricePerMinute).round();
      }

      details.add(detail);
      if (remainingPrice <= 0) break;
    }
    
    return details;
  }

  // 결제 방법 선택/해제 처리
  void _togglePaymentMethod(String paymentType) {
    setState(() {
      final existingIndex = _selectedPaymentMethods.indexWhere((method) => method['type'] == paymentType);
      
      if (existingIndex >= 0) {
        // 이미 선택된 경우 제거
        _selectedPaymentMethods.removeAt(existingIndex);
      } else {
        // 새로 선택하는 경우 추가
        _selectedPaymentMethods.add({'type': paymentType});
      }
    });
  }

  // 잔액 표시 포맷
  String _formatBalance(String type) {
    if (type.startsWith('period_pass_')) {
      if (_isLoadingBalance) {
        return '조회중...';
      }
      
      final contractHistoryId = type.replaceFirst('period_pass_', '');
      final contract = _periodPassContracts.firstWhere(
        (c) => c['contract_history_id'] == contractHistoryId,
        orElse: () => {'usable_minutes': 0, 'expiry_date': null},
      );
      
      final usableMinutes = contract['usable_minutes'] as int? ?? 0;
      final expiryDateStr = contract['expiry_date']?.toString();
      
      String balanceText = '${usableMinutes}분';
      
      // 유효기간 표시 추가 - (유효기간: YY.MM.DD) 형식
      if (expiryDateStr != null && expiryDateStr.isNotEmpty && expiryDateStr != 'null') {
        try {
          final dateParts = expiryDateStr.split('-');
          if (dateParts.length >= 3) {
            final year = dateParts[0].substring(2); // 2025 -> 25
            final month = dateParts[1];
            final day = dateParts[2];
            balanceText += '\n(~$year.$month.$day)';
          }
        } catch (e) {
          balanceText += '\n(~$expiryDateStr)';
        }
      }
      
      return balanceText;
    }
    
    if (type.startsWith('prepaid_credit_')) {
      if (_isLoadingBalance) {
        return '조회중...';
      }
      
      final contractHistoryId = type.replaceFirst('prepaid_credit_', '');
      final contract = _prepaidCreditContracts.firstWhere(
        (c) => c['contract_history_id'] == contractHistoryId,
        orElse: () => {'balance': 0, 'expiry_date': null},
      );
      
      final balance = contract['balance'] as int;
      final expiryDateStr = contract['expiry_date']?.toString();
      
      String balanceText = '${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
      
      // 유효기간 표시 추가 - (유효기간: YY.MM.DD) 형식
      if (expiryDateStr != null && expiryDateStr.isNotEmpty && expiryDateStr != 'null') {
        try {
          final dateParts = expiryDateStr.split('-');
          if (dateParts.length >= 3) {
            final year = dateParts[0].substring(2); // 2025 -> 25
            final month = dateParts[1];
            final day = dateParts[2];
            balanceText += '\n(~$year.$month.$day)';
          }
        } catch (e) {
          balanceText += '\n(~$expiryDateStr)';
        }
      }
      
      return balanceText;
    }
    
    if (type.startsWith('time_pass_')) {
      if (_isLoadingBalance) {
        return '조회중...';
      }
      
      final contractHistoryId = type.replaceFirst('time_pass_', '');
      final contract = _timePassContracts.firstWhere(
        (c) => c['contract_history_id'] == contractHistoryId,
        orElse: () => {'balance': 0, 'expiry_date': null},
      );
      
      final balance = contract['balance'] as int;
      final expiryDateStr = contract['expiry_date']?.toString();
      
      String balanceText = '${balance}분';
      
      // 유효기간 표시 추가 - (유효기간: YY.MM.DD) 형식
      if (expiryDateStr != null && expiryDateStr.isNotEmpty && expiryDateStr != 'null') {
        try {
          final dateParts = expiryDateStr.split('-');
          if (dateParts.length >= 3) {
            final year = dateParts[0].substring(2); // 2025 -> 25
            final month = dateParts[1];
            final day = dateParts[2];
            balanceText += '\n(~$year.$month.$day)';
          }
        } catch (e) {
          balanceText += '\n(~$expiryDateStr)';
        }
      }
      
      return balanceText;
    }

    return '';
  }

  // 선불크레딧 잔액 표시 위젯 (잔액과 유효기간을 다른 폰트 크기로 표시)
  Widget _buildPrepaidCreditBalance(String type, bool isDisabled, bool isSelected, Color color) {
    if (_isLoadingBalance) {
      return Text(
        '조회중...',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDisabled
              ? Colors.grey.shade400
              : isSelected 
                  ? color 
                  : Colors.grey.shade600,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      );
    }
    
    final contractHistoryId = type.replaceFirst('prepaid_credit_', '');
    final contract = _prepaidCreditContracts.firstWhere(
      (c) => c['contract_history_id'] == contractHistoryId,
      orElse: () => {'balance': 0, 'expiry_date': null},
    );
    
    final balance = contract['balance'] as int;
    final expiryDateStr = contract['expiry_date']?.toString();
    final maxUsableAmount = contract['max_usable_amount'] as int?;

    // 1회 최대 금액 또는 전체 잔액을 메인으로 표시
    String balanceText;
    if (maxUsableAmount != null && maxUsableAmount > 0 && maxUsableAmount < balance) {
      balanceText = '${maxUsableAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
    } else {
      balanceText = '${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
    }

    // 잔액과 유효기간 텍스트 생성
    String expiryText = '';
    if (expiryDateStr != null && expiryDateStr.isNotEmpty && expiryDateStr != 'null') {
      try {
        final dateParts = expiryDateStr.split('-');
        if (dateParts.length >= 3) {
          final year = dateParts[0].substring(2); // 2025 -> 25
          final month = dateParts[1];
          final day = dateParts[2];

          // max_ts_use_min 제한이 있으면 잔액도 표시
          if (maxUsableAmount != null && maxUsableAmount > 0 && maxUsableAmount < balance) {
            expiryText = '(잔액 : ${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원/~$year.$month.$day)';
          } else {
            expiryText = '(~$year.$month.$day)';
          }
        }
      } catch (e) {
        expiryText = '(~$expiryDateStr)';
      }
    } else if (maxUsableAmount != null && maxUsableAmount > 0 && maxUsableAmount < balance) {
      // 유효기간이 없지만 제한이 있는 경우
      expiryText = '(잔액 : ${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원)';
    }
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          // 잔액 표시 (큰 폰트)
          TextSpan(
            text: balanceText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDisabled
                  ? Colors.grey.shade400
                  : isSelected 
                      ? color 
                      : Colors.grey.shade600,
              height: 1.2,
            ),
          ),
          // 유효기간 표시 (작은 폰트)
          if (expiryText.isNotEmpty) ...[
            TextSpan(text: '\n'),
            TextSpan(
              text: expiryText,
              style: TextStyle(
                fontSize: 14, // 2포인트 작게
                fontWeight: FontWeight.normal,
                color: isDisabled
                    ? Colors.grey.shade400
                    : isSelected 
                        ? color.withOpacity(0.8)
                        : Colors.grey.shade500,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 기간권 잔액 표시 위젯 (잔액과 유효기간을 다른 폰트 크기로 표시)
  Widget _buildPeriodPassBalance(String type, bool isDisabled, bool isSelected, Color color) {
    if (_isLoadingBalance) {
      return Text(
        '조회중...',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDisabled
              ? Colors.grey.shade400
              : isSelected 
                  ? color 
                  : Colors.grey.shade600,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      );
    }
    
    final contractHistoryId = type.replaceFirst('period_pass_', '');
    final contract = _periodPassContracts.firstWhere(
      (c) => c['contract_history_id'] == contractHistoryId,
      orElse: () => {'usable_minutes': 0, 'expiry_date': null},
    );
    
    final usableMinutes = contract['usable_minutes'] as int? ?? 0;
    final expiryDateStr = contract['expiry_date']?.toString();
    
    String balanceText = '${usableMinutes}분';
    
    // 유효기간 텍스트 생성
    String expiryText = '';
    if (expiryDateStr != null && expiryDateStr.isNotEmpty && expiryDateStr != 'null') {
      try {
        final dateParts = expiryDateStr.split('-');
        if (dateParts.length >= 3) {
          final year = dateParts[0].substring(2); // 2025 -> 25
          final month = dateParts[1];
          final day = dateParts[2];
          expiryText = '(~$year.$month.$day)';
        }
      } catch (e) {
        expiryText = '(~$expiryDateStr)';
      }
    }
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          // 잔액 표시 (큰 폰트)
          TextSpan(
            text: balanceText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDisabled
                  ? Colors.grey.shade400
                  : isSelected 
                      ? color 
                      : Colors.grey.shade600,
              height: 1.2,
            ),
          ),
          // 유효기간 표시 (작은 폰트)
          if (expiryText.isNotEmpty) ...[
            TextSpan(text: '\n'),
            TextSpan(
              text: expiryText,
              style: TextStyle(
                fontSize: 14, // 2포인트 작게
                fontWeight: FontWeight.normal,
                color: isDisabled
                    ? Colors.grey.shade400
                    : isSelected 
                        ? color.withOpacity(0.8)
                        : Colors.grey.shade500,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 시간권 잔액 표시 위젯 (잔액과 유효기간을 다른 폰트 크기로 표시)
  Widget _buildTimePassBalance(String type, bool isDisabled, bool isSelected, Color color) {
    if (_isLoadingBalance) {
      return Text(
        '조회중...',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDisabled
              ? Colors.grey.shade400
              : isSelected 
                  ? color 
                  : Colors.grey.shade600,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      );
    }
    
    final contractHistoryId = type.replaceFirst('time_pass_', '');
    final contract = _timePassContracts.firstWhere(
      (c) => c['contract_history_id'] == contractHistoryId,
      orElse: () => {'balance': 0, 'expiry_date': null},
    );
    
    final balance = contract['balance'] as int;
    final usableBalance = contract['usable_balance'] as int? ?? balance;
    final expiryDateStr = contract['expiry_date']?.toString();

    // 1회 최대 시간 또는 전체 잔액을 메인으로 표시
    String balanceText;
    if (usableBalance < balance) {
      balanceText = '${usableBalance}분';
    } else {
      balanceText = '${balance}분';
    }

    // 잔액과 유효기간 텍스트 생성
    String expiryText = '';
    if (expiryDateStr != null && expiryDateStr.isNotEmpty && expiryDateStr != 'null') {
      try {
        final dateParts = expiryDateStr.split('-');
        if (dateParts.length >= 3) {
          final year = dateParts[0].substring(2); // 2025 -> 25
          final month = dateParts[1];
          final day = dateParts[2];

          // max_ts_use_min 제한이 있으면 잔액도 표시
          if (usableBalance < balance) {
            expiryText = '(잔액 : ${balance}분/~$year.$month.$day)';
          } else {
            expiryText = '(~$year.$month.$day)';
          }
        }
      } catch (e) {
        expiryText = '(~$expiryDateStr)';
      }
    } else if (usableBalance < balance) {
      // 유효기간이 없지만 제한이 있는 경우
      expiryText = '(잔액 : ${balance}분)';
    }
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          // 잔액 표시 (큰 폰트)
          TextSpan(
            text: balanceText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDisabled
                  ? Colors.grey.shade400
                  : isSelected 
                      ? color 
                      : Colors.grey.shade600,
              height: 1.2,
            ),
          ),
          // 유효기간 표시 (작은 폰트)
          if (expiryText.isNotEmpty) ...[
            TextSpan(text: '\n'),
            TextSpan(
              text: expiryText,
              style: TextStyle(
                fontSize: 14, // 2포인트 작게
                fontWeight: FontWeight.normal,
                color: isDisabled
                    ? Colors.grey.shade400
                    : isSelected 
                        ? color.withOpacity(0.8)
                        : Colors.grey.shade500,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 기간권 잔액 텍스트 (리스트용)
  Widget _buildPeriodPassBalanceText(String type, bool isDisabled, bool isSelected, Color color) {
    if (_isLoadingBalance) {
      return Text(
        '조회중...',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDisabled ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
        ),
      );
    }

    final contractHistoryId = type.replaceFirst('period_pass_', '');
    final contract = _periodPassContracts.firstWhere(
      (c) => c['contract_history_id'] == contractHistoryId,
      orElse: () => {'usable_minutes': 0, 'expiry_date': null},
    );

    final usableMinutes = contract['usable_minutes'] as int? ?? 0;
    final expiryDateStr = contract['expiry_date']?.toString();

    String displayText = '사용 가능 ${usableMinutes}분';

    // 유효기간 추가
    if (expiryDateStr != null && expiryDateStr.isNotEmpty && expiryDateStr != 'null') {
      try {
        final dateParts = expiryDateStr.split('-');
        if (dateParts.length >= 3) {
          final year = dateParts[0].substring(2);
          final month = dateParts[1];
          final day = dateParts[2];
          displayText += ' (~$year.$month.$day)';
        }
      } catch (e) {
        displayText += ' (~$expiryDateStr)';
      }
    }

    return Text(
      displayText,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isDisabled ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
      ),
    );
  }

  // 선불크레딧 잔액 텍스트 (리스트용)
  Widget _buildPrepaidCreditBalanceText(String type, bool isDisabled, bool isSelected, Color color) {
    if (_isLoadingBalance) {
      return Text(
        '조회중...',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDisabled ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
        ),
      );
    }

    final contractHistoryId = type.replaceFirst('prepaid_credit_', '');
    final contract = _prepaidCreditContracts.firstWhere(
      (c) => c['contract_history_id'] == contractHistoryId,
      orElse: () => {'balance': 0, 'expiry_date': null},
    );

    final balance = contract['balance'] as int;
    final expiryDateStr = contract['expiry_date']?.toString();
    final maxUsableAmount = contract['max_usable_amount'] as int?;

    String displayText;
    if (maxUsableAmount != null && maxUsableAmount > 0 && maxUsableAmount < balance) {
      displayText = '사용 가능 ${maxUsableAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원 (전체: ${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원)';
    } else {
      displayText = '사용 가능 ${balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
    }

    // 유효기간 추가
    if (expiryDateStr != null && expiryDateStr.isNotEmpty && expiryDateStr != 'null') {
      try {
        final dateParts = expiryDateStr.split('-');
        if (dateParts.length >= 3) {
          final year = dateParts[0].substring(2);
          final month = dateParts[1];
          final day = dateParts[2];
          displayText += ' (~$year.$month.$day)';
        }
      } catch (e) {
        displayText += ' (~$expiryDateStr)';
      }
    }

    return Text(
      displayText,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isDisabled ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
      ),
    );
  }

  // 시간권 잔액 텍스트 (리스트용)
  Widget _buildTimePassBalanceText(String type, bool isDisabled, bool isSelected, Color color) {
    if (_isLoadingBalance) {
      return Text(
        '조회중...',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDisabled ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
        ),
      );
    }

    final contractHistoryId = type.replaceFirst('time_pass_', '');
    final contract = _timePassContracts.firstWhere(
      (c) => c['contract_history_id'] == contractHistoryId,
      orElse: () => {'balance': 0, 'expiry_date': null},
    );

    final balance = contract['balance'] as int;
    final usableBalance = contract['usable_balance'] as int? ?? balance;
    final expiryDateStr = contract['expiry_date']?.toString();

    String displayText;
    if (usableBalance < balance) {
      displayText = '사용 가능 ${usableBalance}분 (전체: ${balance}분)';
    } else {
      displayText = '사용 가능 ${balance}분';
    }

    // 유효기간 추가
    if (expiryDateStr != null && expiryDateStr.isNotEmpty && expiryDateStr != 'null') {
      try {
        final dateParts = expiryDateStr.split('-');
        if (dateParts.length >= 3) {
          final year = dateParts[0].substring(2);
          final month = dateParts[1];
          final day = dateParts[2];
          displayText += ' (~$year.$month.$day)';
        }
      } catch (e) {
        displayText += ' (~$expiryDateStr)';
      }
    }

    return Text(
      displayText,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isDisabled ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
      ),
    );
  }

  // 커스텀 결제 방법 카드 위젯 (리스트 형태)
  Widget _buildPaymentCard(Map<String, dynamic> method, Color color, int index) {
    final isSelected = _selectedPaymentMethods.any((selected) => selected['type'] == method['type']);
    final remainingBalance = calculateRemainingBalance();
    final isFullyPaid = remainingBalance['isFullyPaid'] as bool;
    
    // 미정산 잔액이 없으면 선택되지 않은 결제수단은 비활성화
    bool isDisabled = isFullyPaid && !isSelected;
    
    // 여러 회원권 동시 선택 허용 (동일 타입 제한 제거)
    
    // 계약별 선불크레딧의 경우 추가 유효성 검사
    if (method['type'].startsWith('prepaid_credit_')) {
      final contractData = method['contract_data'] as Map<String, dynamic>?;
      if (contractData != null) {
        final balance = contractData['balance'] as int;
        // 잔액이 0인 경우 비활성화
        if (balance <= 0) {
          isDisabled = true;
        }
      }
    }
    
    // 계약별 시간권의 경우 추가 유효성 검사
    if (method['type'].startsWith('time_pass_')) {
      final contractData = method['contract_data'] as Map<String, dynamic>?;
      if (contractData != null) {
        final balance = contractData['balance'] as int;
        // 잔액이 0인 경우 비활성화
        if (balance <= 0) {
          isDisabled = true;
        }
      }
    }
    

    return GestureDetector(
      onTap: isDisabled ? null : () => _togglePaymentMethod(method['type']),
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.05)
                : (isDisabled ? Color(0xFFF3F4F6) : Colors.white),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDisabled ? Color(0xFFD1D5DB) : Color(0xFFE5E7EB)),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // 왼쪽 색상 바 (동적 높이)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withOpacity(0.3),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // 선택 표시 (체크박스)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected
                          ? color
                          : (isDisabled ? Color(0xFFD1D5DB) : Color(0xFFD1D5DB)),
                      width: 2,
                    ),
                    color: isSelected ? color : Colors.transparent,
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

                // 결제수단 정보
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 결제수단 아이콘 + 제목
                        Row(
                          children: [
                            Icon(
                              method['icon'],
                              size: 18,
                              color: isDisabled ? Color(0xFF9CA3AF) : color,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                method['title'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: (isDisabled ? Color(0xFF9CA3AF) : Color(0xFF1F2937)),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        // 잔액 정보
                        if (method['type'].startsWith('period_pass_')) ...[
                          _buildPeriodPassBalanceText(method['type'], isDisabled, isSelected, color),
                        ] else if (method['type'].startsWith('prepaid_credit_')) ...[
                          _buildPrepaidCreditBalanceText(method['type'], isDisabled, isSelected, color),
                        ] else if (method['type'].startsWith('time_pass_')) ...[
                          _buildTimePassBalanceText(method['type'], isDisabled, isSelected, color),
                        ] else ...[
                          Text(
                            _formatBalance(method['type']),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: (isDisabled ? Color(0xFF9CA3AF) : Color(0xFF6B7280)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 결제 계산 결과 표시 위젯
  Widget _buildPaymentCalculation() {
    final remainingBalance = calculateRemainingBalance();
    final paymentDetails = _calculatePaymentDetails();

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 총 결제금액
          Row(
            children: [
              Icon(
                Icons.calculate,
                color: Color(0xFF666666),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                '총 결제금액',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Spacer(),
              Text(
                '${_totalMinutes}분 (${_totalPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          
          // 할인권 적용 정보 표시 (여러 할인권 지원)
          if (widget.selectedCoupons != null && widget.selectedCoupons!.isNotEmpty) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE9ECEF)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_offer,
                    color: Color(0xFF666666),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '할인권 적용 (총 ${widget.selectedCoupons!.length}개):',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                        ),
                        SizedBox(height: 4),
                        ...widget.selectedCoupons!.map((coupon) => Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 2),
                          child: Text(
                            '• ${_getCouponDisplayText(coupon)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF555555),
                            ),
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          if (paymentDetails.isNotEmpty) ...[
            SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.payment,
                  color: Color(0xFF666666),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  '결제수단 등록',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ...paymentDetails.map((item) {
              // 결제수단 타입별 하이라이트 처리
              final isTimePayment = item['type'] == 'period_pass' || item['type'] == 'time_pass';
              
              // 분으로 환산된 금액 계산
              String displayText;
              if (item['unit'] == '분') {
                // 기간권/시간권: 분 사용
                final minutes = item['amount'] as int;
                final price = (minutes * _pricePerMinute).round();
                displayText = '${minutes}분 (${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원)';
              } else {
                // 선불크레딧/카드결제: 원을 분으로 환산
                final price = item['amount'] as int;
                final minutes = (_pricePerMinute > 0 ? (price / _pricePerMinute).round() : 0);
                displayText = '${minutes}분 (${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원)';
              }
              
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFE3F2FD), // 모든 결제수단을 옅은 하늘색으로
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFE9ECEF)),
                ),
                child: Row(
                  children: [
                    Icon(
                      item['icon'],
                      color: Color(0xFF666666),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['method'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    // 시간 결제권 사용시 시간 하이라이트, 금액 결제시 금액 하이라이트
                    RichText(
                      text: TextSpan(
                        children: [
                          if (item['unit'] == '분') ...[
                            // 시간권 사용시 시간 하이라이트
                            TextSpan(
                              text: '${item['amount'] as int}분',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2196F3), // 파란색 하이라이트
                              ),
                            ),
                            TextSpan(
                              text: ' (${((item['amount'] as int) * _pricePerMinute).round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: item['surcharge'] == true ? Colors.red : Color(0xFF333333),
                              ),
                            ),
                          ] else ...[
                            // 금액 결제시 금액 하이라이트
                            TextSpan(
                              text: '${(_pricePerMinute > 0 ? ((item['amount'] as int) / _pricePerMinute).round() : 0)}분 (',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                            TextSpan(
                              text: '${(item['amount'] as int).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2196F3), // 파란색 하이라이트로 변경
                              ),
                            ),
                            TextSpan(
                              text: ')',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          
          // 미정산 잔액
          SizedBox(height: 16),
          Row(
            children: [
              Icon(
                remainingBalance['isFullyPaid'] 
                    ? Icons.check_circle 
                    : Icons.warning,
                color: remainingBalance['isFullyPaid'] 
                    ? Color(0xFF666666) 
                    : Colors.orange,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                '미정산 잔액',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Spacer(),
              Text(
                remainingBalance['isFullyPaid'] 
                    ? '없음'
                    : '${remainingBalance['remainingMinutes']}분 (${(remainingBalance['remainingPrice'] as int).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: remainingBalance['isFullyPaid'] 
                      ? Color(0xFF666666) 
                      : Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 할인권 표시 텍스트 생성
  String _getCouponDisplayText(Map<String, dynamic> coupon) {
    final couponType = coupon['coupon_type']?.toString() ?? '';
    
    if (couponType == '정률권') {
      final ratio = coupon['discount_ratio']?.toString() ?? '0';
      return '$couponType (${ratio}%)';
    } else if (couponType == '정액권') {
      final amt = coupon['discount_amt']?.toString() ?? '0';
      return '$couponType (${amt}원)';
    } else if (couponType == '시간권') {
      final min = coupon['discount_min']?.toString() ?? '0';
      return '$couponType (${min}분)';
    }
    
    return couponType;
  }

  @override
  Widget build(BuildContext context) {
    // 가격 정보가 없으면 안내 메시지 표시
    if (_totalPrice == 0) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: Color(0xFF666666),
              ),
              SizedBox(height: 16),
              Text(
                '가격 정보를 계산 중입니다...',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
              ),
              SizedBox(height: 8),
              Text(
                '이전 단계에서 예약내역확인을 완료해주세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF999999),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final remainingBalance = calculateRemainingBalance();

    return Container(
      padding: EdgeInsets.all(0), // 전체 패딩 제거
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 결제 계산 결과
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4), // 다른 스텝과 동일한 마진 적용
            child: _buildPaymentCalculation(),
          ),
          SizedBox(height: 16),
          
          // 헤더 (결제 계산 결과 아래로 이동)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16), // 헤더만 패딩 적용
            child: Text(
              '결제 방법을 선택하세요',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          SizedBox(height: 16),
          
          // 결제 방법 리스트
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: List.generate(_paymentMethods.length, (index) {
                final method = _paymentMethods[index];
                final color = TileDesignService.getColorByIndex(index);

                return _buildPaymentCard(method, color, index);
              }),
            ),
          ),
        ],
      ),
    );
  }

  // 할인권 사용 불가능 계약 경고 다이얼로그
  void _showCouponUnavailableDialog(List<String> unavailableContracts) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('할인권 사용 불가'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('선택된 결제수단 중 할인권 사용이 불가능한 계약이 있습니다.'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '할인권 사용 불가능한 계약:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    ...unavailableContracts.map((contract) => Text(
                      '• $contract',
                      style: TextStyle(fontSize: 14),
                    )),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                '할인권을 사용하려면 할인권 사용 가능한 결제수단만 선택해주세요.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }
} 