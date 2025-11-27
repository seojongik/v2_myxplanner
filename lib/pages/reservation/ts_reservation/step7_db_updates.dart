import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import '../../../../services/auto_discount_coupon_service.dart';

class Step7DbUpdates {
  // v2_priced_TS 테이블 업데이트
  static Future<bool> updatePricedTsTable({
    required String branchId,
    required Map<String, dynamic> selectedMember,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required int totalPrice,
    required Map<String, int>? pricingAnalysis,
    required List<Map<String, dynamic>> selectedCoupons, // 여러 할인권 지원
    required List<Map<String, dynamic>> selectedPaymentMethods,
    required Map<String, dynamic> usedAmounts,
    required int termDiscountAmount,
    required int couponDiscountAmount,
    required int finalPaymentAmount,
    String? dayOfWeek, // 요금 계산에 사용된 day_of_week 값 (검증용)
  }) async {
    try {
      // reservation_id 생성 (yymmdd_ts_id_hhmm)
      final dateStr = '${selectedDate.year.toString().substring(2)}${selectedDate.month.toString().padLeft(2, '0')}${selectedDate.day.toString().padLeft(2, '0')}';
      final timeStr = selectedTime.replaceAll(':', '');
      final reservationId = '${dateStr}_${selectedTs}_$timeStr';
      
      // 종료 시간 계산
      final startTimeParts = selectedTime.split(':');
      final startHour = int.parse(startTimeParts[0]);
      final startMinute = int.parse(startTimeParts[1]);
      final endDateTime = DateTime(2000, 1, 1, startHour, startMinute).add(Duration(minutes: selectedDuration));
      final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}:00';
      
      // 결제수단 타입 결정
      String paymentMethodType = '기타';
      if (selectedPaymentMethods.isNotEmpty) {
        final firstMethod = selectedPaymentMethods.first['type'];
        if (firstMethod.startsWith('prepaid_credit_')) {
          paymentMethodType = '선불크레딧';
        } else if (firstMethod.startsWith('time_pass_')) {
          paymentMethodType = '시간권';
        } else if (firstMethod == 'period_pass') {
          paymentMethodType = '기간권';
        } else if (firstMethod == 'card_payment') {
          paymentMethodType = '카드결제';
        }
      }
      
      // 시간권으로 사용된 분수 계산
      int billMin = 0;
      for (final method in selectedPaymentMethods) {
        final methodType = method['type'];
        if (methodType.startsWith('time_pass_') || methodType == 'period_pass') {
          final usedAmount = usedAmounts[methodType];
          if (usedAmount != null) {
            billMin += (usedAmount is int) ? usedAmount : (usedAmount as num).toInt();
          }
        }
      }
      
      // 시간대 분류 정보
      final normalMin = pricingAnalysis?['base_price'] ?? 0;
      final discountMin = pricingAnalysis?['discount_price'] ?? 0;
      final extrachargeMin = pricingAnalysis?['extracharge_price'] ?? 0;
      
      // 총 할인 금액
      final totalDiscount = termDiscountAmount + couponDiscountAmount;
      
      // v2_priced_TS 테이블 업데이트 데이터
      final pricedTsData = {
        'reservation_id': reservationId,
        'ts_id': selectedTs,
        'ts_date': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
        'ts_start': '$selectedTime:00',
        'ts_end': endTime,
        'ts_payment_method': paymentMethodType,
        'ts_status': '결제완료',
        'member_id': selectedMember['member_id'],
        'member_type': selectedMember['member_type'] ?? '일반',
        'member_name': selectedMember['member_name'] ?? '',
        'member_phone': selectedMember['member_phone'] ?? '',
        'total_amt': totalPrice,
        'term_discount': termDiscountAmount,
        'coupon_discount': couponDiscountAmount,
        'total_discount': totalDiscount,
        'net_amt': finalPaymentAmount,
        'discount_min': discountMin,
        'normal_min': normalMin,
        'extracharge_min': extrachargeMin,
        'ts_min': selectedDuration,
        'bill_min': billMin > 0 ? billMin : null,
        'time_stamp': DateTime.now().toIso8601String(),
        'branch_id': branchId,
        'day_of_week': dayOfWeek, // 요금 계산에 사용된 day_of_week 값 저장
      };
      
      print('=== v2_priced_TS 테이블 업데이트 시작 ===');
      print('reservation_id: $reservationId');
      print('🗓️ 요금 계산에 사용된 day_of_week: $dayOfWeek');
      print('업데이트 데이터: $pricedTsData');
      
      // API 호출하여 테이블 업데이트
      final success = await ApiService.updatePricedTsTable(pricedTsData);
      
      if (success) {
        print('✅ v2_priced_TS 테이블 업데이트 성공');
        
        return true;
      } else {
        print('❌ v2_priced_TS 테이블 업데이트 실패');
        return false;
      }
      
    } catch (e) {
      print('❌ v2_priced_TS 테이블 업데이트 오류: $e');
      return false;
    }
  }
  
  // 중복 예약 체크
  static Future<bool> checkDuplicateReservation({
    required String branchId,
    required String selectedTs,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
  }) async {
    try {
      // 예약 시간 범위 계산
      final startTimeParts = selectedTime.split(':');
      final startHour = int.parse(startTimeParts[0]);
      final startMinute = int.parse(startTimeParts[1]);
      final startDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        startHour,
        startMinute,
      );
      final endDateTime = startDateTime.add(Duration(minutes: selectedDuration));
      
      // 중복 예약 체크 API 호출
      final isDuplicate = await ApiService.checkTsReservationDuplicate(
        branchId: branchId,
        tsId: selectedTs,
        date: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
        startTime: selectedTime,
        endTime: '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}',
      );
      
      return isDuplicate;
      
    } catch (e) {
      print('중복 예약 체크 오류: $e');
      return false; // 오류 발생 시 중복이 아닌 것으로 처리
    }
  }
  
  // 예약 완료 처리 (메인 함수)
  static Future<Map<String, dynamic>> processReservationCompletion({
    required String branchId,
    required Map<String, dynamic>? selectedMember,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required int totalPrice,
    required int originalPrice,
    required int? finalPaymentMinutes, // Step5에서 계산된 할인 후 시간
    required Map<String, int> pricingAnalysis,
    required Map<String, dynamic> usedAmounts,
    required List<String> selectedPaymentMethods,
    required List<Map<String, dynamic>> selectedCoupons, // 여러 할인권 지원
    Map<String, Map<String, dynamic>>? contractInfo,
    String? dayOfWeek, // 요금 계산에 사용된 day_of_week 값 (검증용)
  }) async {
    try {
      print('=== 예약 완료 처리 시작 ===');
      print('브랜치 ID: $branchId');
      print('선택된 회원: $selectedMember');
      print('날짜: $selectedDate');
      print('시간: $selectedTime');
      print('지속시간: $selectedDuration');
      print('타석: $selectedTs');
      print('할인후 가격: $totalPrice');
      print('원가: $originalPrice');
      print('할인후 시간: $finalPaymentMinutes');
      print('할인권 (총 ${selectedCoupons.length}개): $selectedCoupons');
      
      // reservation_id 생성 (yymmdd_ts_id_hhmm)
      final dateStr = '${selectedDate.year.toString().substring(2)}${selectedDate.month.toString().padLeft(2, '0')}${selectedDate.day.toString().padLeft(2, '0')}';
      final timeStr = selectedTime.replaceAll(':', '');
      final reservationId = '${dateStr}_${selectedTs}_$timeStr';
      
      // 종료 시간 계산
      final startTimeParts = selectedTime.split(':');
      final startHour = int.parse(startTimeParts[0]);
      final startMinute = int.parse(startTimeParts[1]);
      final endDateTime = DateTime(2000, 1, 1, startHour, startMinute).add(Duration(minutes: selectedDuration));
      final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}:00';
      
      // 결제수단 타입 결정
      String paymentMethodType = '기타';
      if (selectedPaymentMethods.isNotEmpty) {
        final firstMethod = selectedPaymentMethods.first;
        if (firstMethod.startsWith('prepaid_credit_')) {
          paymentMethodType = '선불크레딧';
        } else if (firstMethod.startsWith('time_pass_')) {
          paymentMethodType = '시간권';
        } else if (firstMethod == 'period_pass') {
          paymentMethodType = '기간권';
        } else if (firstMethod == 'card_payment') {
          paymentMethodType = '카드결제';
        }
      }
      
      // 시간권으로 사용된 분수 계산
      int billMin = 0;
      for (final methodType in selectedPaymentMethods) {
        if (methodType.startsWith('time_pass_') || methodType == 'period_pass') {
          final usedAmount = usedAmounts[methodType];
          if (usedAmount != null) {
            billMin += (usedAmount is int) ? usedAmount : (usedAmount as num).toInt();
          }
        }
      }
      
      // 시간대 분류 정보
      final normalMin = pricingAnalysis['base_price'] ?? 0;
      final discountMin = pricingAnalysis['discount_price'] ?? 0;
      final extrachargeMin = pricingAnalysis['extracharge_price'] ?? 0;
      
      // 할인 금액 계산
      final couponDiscountAmount = originalPrice - totalPrice;
      
      // 중복 예약 확인
      final endTimeForCheck = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';
      bool isDuplicate = await ApiService.checkTsReservationDuplicate(
        branchId: branchId,
        tsId: selectedTs,
        date: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
        startTime: selectedTime,
        endTime: endTimeForCheck,
      );

      if (isDuplicate) {
        print('중복 예약이 감지되어 처리를 중단합니다.');
        return {
          'success': false,
          'usedCoupons': [],
          'issuedCoupons': [],
        };
      }

      // v2_priced_TS 테이블 업데이트 데이터 (원래 구조대로)
      final pricedTsData = {
        'reservation_id': reservationId,
        'ts_id': selectedTs,
        'ts_date': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
        'ts_start': '$selectedTime:00',
        'ts_end': endTime,
        'ts_payment_method': paymentMethodType,
        'ts_status': '결제완료',
        'member_id': selectedMember?['member_id']?.toString() ?? '',
        'member_type': selectedMember?['member_type']?.toString() ?? '일반',
        'member_name': selectedMember?['member_name']?.toString() ?? '',
        'member_phone': selectedMember?['member_phone']?.toString() ?? '',
        'total_amt': originalPrice, // 원가
        'term_discount': 0, // 기간권 할인은 현재 0
        'coupon_discount': couponDiscountAmount, // 쿠폰 할인금액
        'total_discount': couponDiscountAmount, // 총 할인금액
        'net_amt': totalPrice, // 최종 결제금액 (할인 후)
        'discount_min': discountMin,
        'normal_min': normalMin,
        'extracharge_min': extrachargeMin,
        'ts_min': selectedDuration,
        'bill_min': billMin > 0 ? billMin : null,
        'time_stamp': DateTime.now().toIso8601String(), // 현재 시간 추가
        'branch_id': branchId,
        'day_of_week': dayOfWeek, // 요금 계산에 사용된 day_of_week 값 저장
      };
      
      print('=== v2_priced_TS 테이블 업데이트 시작 ===');
      print('reservation_id: $reservationId');
      print('🗓️ 요금 계산에 사용된 day_of_week: $dayOfWeek');
      print('업데이트 데이터: $pricedTsData');

      await ApiService.updatePricedTsTable(pricedTsData);
      
      // 생성된 bill_id와 bill_min_id를 수집하기 위한 리스트
      List<int> billIds = [];
      List<int> billMinIds = [];
      
      // 선불크레딧 결제 시 v2_bills 테이블도 업데이트
      for (final methodType in selectedPaymentMethods) {
        if (methodType.startsWith('prepaid_credit_')) {
          final contractHistoryId = methodType.replaceFirst('prepaid_credit_', '');
          final usedAmount = usedAmounts[methodType];
          
          if (usedAmount != null && usedAmount > 0) {
            // 계약 정보에서 만료일 가져오기
            String? contractExpiryDate;
            if (contractInfo != null && contractInfo.containsKey(methodType)) {
              final contract = contractInfo[methodType]!;
              contractExpiryDate = contract['expiry_date']?.toString();
            }
            
            // bill_text 생성 (예: "3번 타석(09:00 ~ 09:55)")
            final billText = '${selectedTs}번 타석($selectedTime ~ ${endTime.substring(0, 5)})';
            
            // 할인쿠폰 적용금액 계산
            int totalDiscountAmount = 0;
            if (selectedCoupons.isNotEmpty) {
              for (final coupon in selectedCoupons) {
                final couponType = coupon['coupon_type']?.toString();
                if (couponType == '정액권') {
                  totalDiscountAmount += _parseToInt(coupon['discount_amt']);
                } else if (couponType == '정률권') {
                  final discountRatio = _parseToInt(coupon['discount_ratio']);
                  final originalAmount = usedAmount as int;
                  totalDiscountAmount += (originalAmount * discountRatio / 100).round();
                }
              }
            }
            
            // 선불크레딧은 차감이므로 음수로 처리
            final originalAmount = (usedAmount as int) + totalDiscountAmount; // 할인전 원래 금액
            final billTotalAmt = -originalAmount; // 할인전 총금액 (음수)
            final billDeduction = totalDiscountAmount; // 할인금액 (플러스)
            final billNetAmt = -(usedAmount as int); // 실제 차감금액 (음수)
            
            print('=== 선불크레딧 v2_bills 업데이트 준비 ===');
            print('계약 ID: $contractHistoryId');
            print('할인전 원래 금액: ${originalAmount}원');
            print('할인 금액: ${totalDiscountAmount}원');
            print('실제 사용 금액: $usedAmount원');
            print('bill_text: $billText');
            print('계약 만료일: $contractExpiryDate');
            
            final billUpdateResult = await ApiService.updateBillsTable(
              memberId: selectedMember?['member_id']?.toString() ?? '',
              billDate: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
              billText: billText,
              billTotalAmt: billTotalAmt,
              billDeduction: billDeduction,
              billNetAmt: billNetAmt,
              reservationId: reservationId,
              contractHistoryId: contractHistoryId,
              branchId: branchId,
              contractCreditExpiryDate: contractExpiryDate,
            );
            
            if (billUpdateResult != null && billUpdateResult > 0) {
              billIds.add(billUpdateResult);
              print('✅ 선불크레딧 v2_bills 테이블 업데이트 성공 (계약 ID: $contractHistoryId, bill_id: $billUpdateResult)');
            } else {
              print('❌ 선불크레딧 v2_bills 테이블 업데이트 실패 (계약 ID: $contractHistoryId)');
            }
          }
        }
      }
      
      // 시간권 결제 시 v2_bill_times 테이블도 업데이트
      for (final methodType in selectedPaymentMethods) {
        if (methodType.startsWith('time_pass_')) {
          final contractHistoryId = methodType.replaceFirst('time_pass_', '');
          final usedMinutes = usedAmounts[methodType];
          
          if (usedMinutes != null && usedMinutes > 0) {
            // 계약 정보에서 만료일 가져오기
            String? contractExpiryDate;
            if (contractInfo != null && contractInfo.containsKey(methodType)) {
              final contract = contractInfo[methodType]!;
              contractExpiryDate = contract['expiry_date']?.toString();
            }
            
            // bill_text 생성 (예: "3번 타석(09:00 ~ 09:55)")
            final billText = '${selectedTs}번 타석($selectedTime ~ ${endTime.substring(0, 5)})';
            
            // 할인쿠폰 적용시간 계산
            int billTotalMin = selectedDuration; // 총 시간
            int billDiscountMin = 0; // 할인시간
            int billMin = usedMinutes as int; // 실제 과금시간 (시간권으로 차감되는 시간)
            
            print('=== Step5 계산 정보 사용 ===');
            print('총 시간: ${billTotalMin}분');
            print('Step5에서 계산된 할인후 시간: ${finalPaymentMinutes}분');
            print('원가: ${originalPrice}원');
            print('할인후 가격: ${totalPrice}원');
            print('할인권 정보 (총 ${selectedCoupons.length}개): $selectedCoupons');
            
            // Step5에서 계산된 할인 후 시간을 이용하여 할인시간 계산
            if (finalPaymentMinutes != null) {
              billDiscountMin = billTotalMin - finalPaymentMinutes;
              print('Step5 기반 할인시간 계산: ${billTotalMin}분 - ${finalPaymentMinutes}분 = ${billDiscountMin}분');
            } else {
              // Step5 정보가 없는 경우 기존 방식으로 계산
              if (selectedCoupons.isNotEmpty) {
                int totalDiscountTime = 0;
                
                for (final coupon in selectedCoupons) {
                  final couponType = coupon['coupon_type']?.toString();
                  int couponDiscountTime = 0;
                  
                  if (couponType == '시간권') {
                    // 시간권 할인: 할인시간을 직접 적용
                    couponDiscountTime = _parseToInt(coupon['discount_min']);
                    print('시간권 할인 적용: ${couponDiscountTime}분');
                  } else if (couponType == '정률권') {
                    // 정률권 할인: 비율 계산
                    final discountRatio = _parseToInt(coupon['discount_ratio']);
                    couponDiscountTime = (billTotalMin * discountRatio / 100).round();
                    print('정률권 할인 계산: ${discountRatio}% = ${couponDiscountTime}분');
                  } else if (couponType == '정액권') {
                    // 정액권 할인: 할인금액을 시간으로 환산
                    final discountAmount = _parseToInt(coupon['discount_amt']);
                    final pricePerMinute = originalPrice > 0 ? originalPrice / billTotalMin : 0;
                    couponDiscountTime = pricePerMinute > 0 ? (discountAmount / pricePerMinute).round() : 0;
                    print('정액권 할인 계산: ${discountAmount}원 = ${couponDiscountTime}분');
                  }
                  
                  totalDiscountTime += couponDiscountTime;
                }
                
                billDiscountMin = totalDiscountTime;
                print('총 할인시간: ${billDiscountMin}분');
                
                // 할인시간이 총 시간을 초과하지 않도록 제한
                if (billDiscountMin > billTotalMin) {
                  print('할인시간이 총 시간을 초과하여 조정: ${billDiscountMin}분 → ${billTotalMin}분');
                  billDiscountMin = billTotalMin;
                }
              } else {
                print('할인권 없음');
              }
            }
            
            // 실제 과금시간은 총시간 - 할인시간으로 계산
            billMin = billTotalMin - billDiscountMin;
            
            print('=== 시간권 과금시간 계산 완료 ===');
            print('총 시간: ${billTotalMin}분');
            print('할인시간: ${billDiscountMin}분');
            print('실제 과금시간: ${billMin}분');
            print('시간권에서 차감될 시간: ${usedMinutes}분');
            
            // 검증: 계산된 과금시간과 실제 사용시간이 일치하는지 확인
            if (billMin != usedMinutes) {
              print('⚠️ 주의: 계산된 과금시간(${billMin}분)과 실제 사용시간(${usedMinutes}분)이 다릅니다.');
              print('   시간권 잔액 차감은 실제 사용시간(${usedMinutes}분)으로 진행됩니다.');
            }
            
            print('=== 시간권 v2_bill_times 업데이트 준비 ===');
            print('계약 ID: $contractHistoryId');
            print('총 시간: ${billTotalMin}분 (플러스)');
            print('할인시간: ${billDiscountMin}분 (마이너스로 저장)');
            print('실제 과금시간(차감시간): ${billMin}분 (플러스)');
            print('bill_text: $billText');
            print('계약 만료일: $contractExpiryDate');
            
            final billTimesUpdateResult = await ApiService.updateBillTimesTable(
              memberId: selectedMember?['member_id']?.toString() ?? '',
              billDate: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
              billText: billText,
              billMin: billMin, // 실제 과금시간 (시간권에서 차감되는 시간)
              billTotalMin: billTotalMin, // 총 시간
              billDiscountMin: -billDiscountMin, // 할인시간 (마이너스로 처리)
              reservationId: reservationId,
              contractHistoryId: contractHistoryId,
              branchId: branchId,
              contractTsMinExpiryDate: contractExpiryDate,
            );
            
            if (billTimesUpdateResult != null && billTimesUpdateResult > 0) {
              billMinIds.add(billTimesUpdateResult);
              print('✅ 시간권 v2_bill_times 테이블 업데이트 성공 (계약 ID: $contractHistoryId, bill_min_id: $billTimesUpdateResult)');
            } else {
              print('❌ 시간권 v2_bill_times 테이블 업데이트 실패 (계약 ID: $contractHistoryId)');
            }
          }
        }
      }
      
      // 할인권 사용 시 v2_discount_coupon 테이블도 업데이트 (여러 할인권 지원)
      if (selectedCoupons.isNotEmpty) {
        print('=== 할인권 v2_discount_coupon 업데이트 준비 (총 ${selectedCoupons.length}개) ===');
        
        for (int i = 0; i < selectedCoupons.length; i++) {
          final coupon = selectedCoupons[i];
          final couponId = coupon['coupon_id'];
          
          if (couponId != null) {
            print('${i + 1}번째 쿠폰 업데이트:');
            print('  쿠폰 ID: $couponId');
            print('  회원 ID: ${selectedMember?['member_id']}');
            print('  예약 ID: $reservationId');
            
            final couponUpdateSuccess = await ApiService.updateDiscountCouponTable(
              branchId: branchId,
              memberId: selectedMember?['member_id']?.toString() ?? '',
              couponId: (couponId is int) ? couponId : int.tryParse(couponId.toString()) ?? 0,
              reservationId: reservationId,
            );
            
            if (couponUpdateSuccess) {
              print('  ✅ 할인권 v2_discount_coupon 테이블 업데이트 성공 (쿠폰 ID: $couponId)');
            } else {
              print('  ❌ 할인권 v2_discount_coupon 테이블 업데이트 실패 (쿠폰 ID: $couponId)');
            }
          }
        }
      }
      
      // 생성된 bill_id, bill_min_id, bill_term_id를 수집하기 위한 리스트
      List<int> billTermIds = [];
      
      // 기간권 결제 시 v2_bill_term 테이블도 업데이트
      for (final methodType in selectedPaymentMethods) {
        if (methodType == 'period_pass') {
          final usedMinutes = usedAmounts[methodType];
          
          if (usedMinutes != null && usedMinutes > 0) {
            // bill_text 생성 (예: "3번 타석(09:00 ~ 09:55)")
            final billText = '${selectedTs}번 타석($selectedTime ~ ${endTime.substring(0, 5)})';
            
            // 기간권 정보에서 contract_history_id와 expiry_date 가져오기
            String? contractHistoryId;
            String? contractExpiryDate;
            String? termStartdate;
            String? termEnddate;
            
            // contractInfo가 있고 period_pass 정보가 있는 경우
            if (contractInfo != null && contractInfo.containsKey('period_pass')) {
              final periodPassInfo = contractInfo['period_pass'];
              if (periodPassInfo != null) {
                contractHistoryId = periodPassInfo['contract_history_id']?.toString();
                contractExpiryDate = periodPassInfo['expiry_date']?.toString();
                termStartdate = periodPassInfo['term_startdate']?.toString();
                termEnddate = periodPassInfo['term_enddate']?.toString();
              }
            }
            
            print('=== 기간권 v2_bill_term 업데이트 준비 ===');
            print('사용한 시간: ${usedMinutes}분');
            print('bill_text: $billText');
            print('contract_history_id: $contractHistoryId');
            print('contract_term_month_expiry_date: $contractExpiryDate');
            print('term_startdate: $termStartdate');
            print('term_enddate: $termEnddate');
            
            final billTermUpdateResult = await ApiService.updateBillTermTable(
              memberId: selectedMember?['member_id']?.toString() ?? '',
              billDate: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
              billText: billText,
              billTermMin: usedMinutes as int, // 기간권 사용 시간
              reservationId: reservationId,
              branchId: branchId,
              contractHistoryId: contractHistoryId,
              contractTermMonthExpiryDate: contractExpiryDate,
              termStartdate: termStartdate,
              termEnddate: termEnddate,
            );
            
            if (billTermUpdateResult != null && billTermUpdateResult > 0) {
              billTermIds.add(billTermUpdateResult);
              print('✅ 기간권 v2_bill_term 테이블 업데이트 성공 (bill_term_id: $billTermUpdateResult)');
            } else {
              print('❌ 기간권 v2_bill_term 테이블 업데이트 실패');
            }
          }
        }
      }
      
      // 수집된 bill_id, bill_min_id, bill_term_id를 v2_priced_TS에 업데이트
      if (billIds.isNotEmpty || billMinIds.isNotEmpty || billTermIds.isNotEmpty) {
        print('=== v2_priced_TS에 bill_id/bill_min_id/bill_term_id 업데이트 시작 ===');
        print('수집된 bill_ids: $billIds');
        print('수집된 bill_min_ids: $billMinIds');
        print('수집된 bill_term_ids: $billTermIds');
        
        // bill_ids를 콤마로 구분된 문자열로 변환 (예: "123,124,125")
        final billIdsString = billIds.isNotEmpty ? billIds.join(',') : null;
        final billMinIdsString = billMinIds.isNotEmpty ? billMinIds.join(',') : null;
        final billTermIdsString = billTermIds.isNotEmpty ? billTermIds.join(',') : null;
        
        final updatePricedTsWithIds = await ApiService.updatePricedTsWithBillIds(
          reservationId: reservationId,
          billIds: billIdsString,
          billMinIds: billMinIdsString,
          billTermIds: billTermIdsString,
        );
        
        if (updatePricedTsWithIds) {
          print('✅ v2_priced_TS에 bill_id/bill_min_id/bill_term_id 업데이트 성공');
          print('   bill_ids 필드: $billIdsString');
          print('   bill_min_ids 필드: $billMinIdsString');
          print('   bill_term_ids 필드: $billTermIdsString');
        } else {
          print('❌ v2_priced_TS에 bill_id/bill_min_id/bill_term_id 업데이트 실패');
        }
      } else {
        print('⚠️ 업데이트할 bill_id/bill_min_id/bill_term_id가 없습니다.');
      }
      
      // 자동 쿠폰 발행 처리
      print('=== 자동 할인쿠폰 발행 시작 ===');
      
      // 선택된 결제수단 중 coupon_issue_available 확인
      bool canIssueCoupons = true;
      List<String> couponIssueBlockedContracts = [];
      
      for (String methodType in selectedPaymentMethods) {
        String? contractHistoryId;
        Map<String, dynamic>? contract;
        
        if (methodType.startsWith('prepaid_credit_')) {
          contractHistoryId = methodType.replaceFirst('prepaid_credit_', '');
          // usedAmounts에서 해당 계약이 실제 사용되었는지 확인
          if (usedAmounts.containsKey(methodType) && (usedAmounts[methodType] ?? 0) > 0) {
            contract = contractInfo?[methodType];
          }
        } else if (methodType.startsWith('time_pass_')) {
          contractHistoryId = methodType.replaceFirst('time_pass_', '');
          // usedAmounts에서 해당 계약이 실제 사용되었는지 확인
          if (usedAmounts.containsKey(methodType) && (usedAmounts[methodType] ?? 0) > 0) {
            contract = contractInfo?[methodType];
          }
        } else if (methodType.startsWith('period_pass_')) {
          contractHistoryId = methodType.replaceFirst('period_pass_', '');
          // usedAmounts에서 해당 계약이 실제 사용되었는지 확인
          if (usedAmounts.containsKey(methodType) && (usedAmounts[methodType] ?? 0) > 0) {
            contract = contractInfo?[methodType];
          }
        }
        
        if (contract != null && contractHistoryId != null) {
          // v2_contracts에서 coupon_issue_available 확인
          try {
            final contractDetails = await ApiService.getData(
              table: 'v2_contracts',
              where: [
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
                {'field': 'contract_id', 'operator': '=', 'value': contract['contract_id']},
              ],
            );
            
            if (contractDetails.isNotEmpty) {
              final couponIssueAvailable = contractDetails[0]['coupon_issue_available']?.toString() ?? '';
              if (couponIssueAvailable == '불가능') {
                canIssueCoupons = false;
                final contractName = contractDetails[0]['contract_name'] ?? 'Unknown';
                couponIssueBlockedContracts.add('계약 $contractHistoryId ($contractName)');
                print('🚫 쿠폰 발행 금지 계약 발견: $contractHistoryId ($contractName)');
              }
            }
          } catch (e) {
            print('⚠️ 계약 $contractHistoryId의 coupon_issue_available 확인 실패: $e');
          }
        }
      }
      
      List<Map<String, dynamic>> issuedCoupons = [];
      
      if (!canIssueCoupons) {
        print('❌ 쿠폰 발행 차단: 쿠폰 발행 금지 계약이 포함됨');
        print('차단된 계약들: ${couponIssueBlockedContracts.join(', ')}');
      } else {
        print('✅ 모든 사용된 계약에서 쿠폰 발행 허용됨');
        issuedCoupons = await AutoDiscountCouponService.processAutoCouponIssuance(
          branchId: branchId,
          reservationData: pricedTsData,
        );
      }
      
      print('예약 완료 처리가 성공적으로 완료되었습니다.');
      
      return {
        'success': true,
        'usedCoupons': selectedCoupons,
        'issuedCoupons': issuedCoupons,
      };
      
    } catch (e) {
      print('예약 완료 처리 중 오류 발생: $e');
      return {
        'success': false,
        'usedCoupons': [],
        'issuedCoupons': [],
      };
    }
  }
  
  // 안전한 int 변환 헬퍼 메서드
  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
  
  // 안전한 double 변환 헬퍼 메서드
  static double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

} 