import '../../../../services/api_service.dart';
import 'package:intl/intl.dart';

/// 단일 결제 처리 결과 모델
class PaymentResult {
  final String methodType;
  final int usedAmount;
  final int beforeBalance;
  final int afterBalance;
  final String? contractHistoryId;
  final String? contractId;
  final String? expiryDate;
  final String unit; // '원' 또는 '분'
  final bool success;
  final String? errorMessage;
  
  PaymentResult({
    required this.methodType,
    required this.usedAmount,
    required this.beforeBalance,
    required this.afterBalance,
    this.contractHistoryId,
    this.contractId,
    this.expiryDate,
    required this.unit,
    required this.success,
    this.errorMessage,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      methodType: json['methodType'] ?? '',
      usedAmount: json['usedAmount'] ?? 0,
      beforeBalance: json['beforeBalance'] ?? 0,
      afterBalance: json['afterBalance'] ?? 0,
      contractHistoryId: json['contractHistoryId'],
      contractId: json['contractId'],
      expiryDate: json['expiryDate'],
      unit: json['unit'] ?? '원',
      success: json['success'] ?? false,
      errorMessage: json['error'],
    );
  }

  factory PaymentResult.error(String message) {
    return PaymentResult(
      methodType: '',
      usedAmount: 0,
      beforeBalance: 0,
      afterBalance: 0,
      unit: '원',
      success: false,
      errorMessage: message,
    );
  }
}

/// 예약 데이터베이스 업데이트 서비스 (단일 결제 처리)
class TsDbUpdateService {
  
  /// 단일 결제수단으로 예약 처리
  /// 
  /// [branchId] 지점 ID
  /// [memberId] 회원 ID
  /// [selectedDate] 예약 날짜
  /// [selectedTime] 예약 시간
  /// [selectedDuration] 연습 시간 (분)
  /// [selectedTs] 타석 번호
  /// [paymentMethod] 결제수단 정보
  /// [usageAmount] 사용량 (원 또는 분)
  /// [originalPrice] 원가
  /// [finalPrice] 최종 가격
  /// [couponDiscountAmount] 쿠폰 할인 금액
  /// [pricingAnalysis] 가격 분석 정보
  /// [reservationId] 예약 ID (선택사항 - 없으면 자동 생성)
  /// 
  /// 반환값: 단일 결제 처리 결과
  static Future<PaymentResult> processSinglePayment({
    required String branchId,
    required String memberId,
    required String selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required String paymentMethod,
    required int usageAmount,
    required int originalPrice,
    required int finalPrice,
    required int couponDiscountAmount,
    required Map<String, dynamic> pricingAnalysis,
    String? reservationId,
  }) async {
    try {
      // 종료 시간 계산
      final startTime = DateTime.parse('$selectedDate $selectedTime:00');
      final endTime = startTime.add(Duration(minutes: selectedDuration));
      
      // 중복 예약 체크
      final isDuplicate = await checkDuplicateReservation(
        branchId: branchId,
        tsId: selectedTs,
        date: selectedDate,
        startTime: selectedTime,
        endTime: endTime.toString().split(' ')[1].substring(0, 5),
      );
      
      if (isDuplicate) {
        return PaymentResult.error('중복 예약이 존재합니다.');
      }
      
      // 예약 ID 생성
      final String actualReservationId = reservationId ?? generateReservationId(
        selectedDate, selectedTs, selectedTime, isDuplicate
      );
      
      if (actualReservationId.isEmpty) {
        return PaymentResult.error('예약 ID 생성에 실패했습니다.');
      }
      
      // 결제 처리
      final result = await calculatePaymentDeductions(
        branchId: branchId,
        selectedMember: {'member_id': memberId},
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        selectedDuration: selectedDuration,
        selectedTs: selectedTs,
        selectedPaymentMethods: [{'type': paymentMethod, 'amount': usageAmount}],
        prepaidCreditContracts: [],
        timePassContracts: [],
        balances: {},
        originalPrice: originalPrice,
        finalPrice: finalPrice,
        totalPrice: finalPrice,
        totalMinutes: selectedDuration,
        pricePerMinute: finalPrice / selectedDuration,
        pricingAnalysis: pricingAnalysis,
        reservationId: actualReservationId,
      );
      
      if (result['success'] == true) {
        return PaymentResult.fromJson({
          'success': true,
          'reservation_id': actualReservationId,
          'message': '결제가 완료되었습니다.',
        });
      } else {
        return PaymentResult.error(result['error'] ?? '결제 처리에 실패했습니다.');
      }
    } catch (e) {
      print('❌ 결제 처리 오류: $e');
      return PaymentResult.error('결제 처리 중 오류가 발생했습니다: $e');
    }
  }
  
  /// 실시간 잔액 조회
  /// 
  /// [paymentMethod] 결제수단 정보
  /// [branchId] 지점 ID
  /// [memberId] 회원 ID
  /// 
  /// 반환값: 잔액 조회 결과
  static Future<Map<String, dynamic>> _getCurrentBalance({
    required Map<String, dynamic> paymentMethod,
    required String branchId,
    required String memberId,
  }) async {
    try {
      final methodType = paymentMethod['type'] as String;
      
      if (methodType.startsWith('prepaid_credit_')) {
        return await _getPrepaidCreditBalance(
          contractHistoryId: methodType.replaceFirst('prepaid_credit_', ''),
          branchId: branchId,
          memberId: memberId,
        );
      } else if (methodType.startsWith('time_pass_')) {
        return await _getTimePassBalance(
          contractHistoryId: methodType.replaceFirst('time_pass_', ''),
          branchId: branchId,
          memberId: memberId,
        );
      } else {
        return {
          'success': false,
          'error': '지원하지 않는 결제수단입니다',
        };
      }
    } catch (e) {
      print('❌ 실시간 잔액 조회 오류: $e');
      return {
        'success': false,
        'error': '잔액 조회 중 오류 발생: $e',
      };
    }
  }
  
  /// 선불크레딧 실시간 잔액 조회
  static Future<Map<String, dynamic>> _getPrepaidCreditBalance({
    required String contractHistoryId,
    required String branchId,
    required String memberId,
  }) async {
    try {
      print('💰 선불크레딧 실시간 잔액 조회: $contractHistoryId');
      
      // v2_bills 테이블에서 최신 잔액 조회
      final response = await ApiService.getBillsBalance(
        branchId: branchId,
        memberId: memberId,
        contractHistoryId: contractHistoryId,
      );
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as List<dynamic>;
        if (data.isNotEmpty) {
          final latestBill = data.first as Map<String, dynamic>;
          final balance = int.tryParse(latestBill['bill_balance_after']?.toString() ?? '0') ?? 0;
          final contractId = latestBill['contract_id']?.toString();
          final expiryDate = latestBill['contract_credit_expiry_date']?.toString();
          
          print('✅ 선불크레딧 잔액 조회 성공: ${balance}원');
          
          return {
            'success': true,
            'balance': balance,
            'unit': '원',
            'contractHistoryId': contractHistoryId,
            'contractId': contractId,
            'expiryDate': expiryDate,
          };
        }
      }
      
      print('❌ 선불크레딧 잔액 조회 실패');
      return {
        'success': false,
        'error': '선불크레딧 잔액 조회 실패',
      };
      
    } catch (e) {
      print('❌ 선불크레딧 잔액 조회 오류: $e');
      return {
        'success': false,
        'error': '선불크레딧 잔액 조회 오류: $e',
      };
    }
  }
  
  /// 시간권 실시간 잔액 조회
  static Future<Map<String, dynamic>> _getTimePassBalance({
    required String contractHistoryId,
    required String branchId,
    required String memberId,
  }) async {
    try {
      print('⏰ 시간권 실시간 잔액 조회: $contractHistoryId');
      
      // v2_bill_times 테이블에서 최신 잔액 조회
      final response = await ApiService.getBillTimesBalance(
        branchId: branchId,
        memberId: memberId,
        contractHistoryId: contractHistoryId,
      );
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as List<dynamic>;
        if (data.isNotEmpty) {
          final latestBill = data.first as Map<String, dynamic>;
          final balance = int.tryParse(latestBill['bill_balance_min_after']?.toString() ?? '0') ?? 0;
          final contractId = latestBill['contract_id']?.toString();
          final expiryDate = latestBill['contract_TS_min_expiry_date']?.toString();
          
          print('✅ 시간권 잔액 조회 성공: ${balance}분');
          
          return {
            'success': true,
            'balance': balance,
            'unit': '분',
            'contractHistoryId': contractHistoryId,
            'contractId': contractId,
            'expiryDate': expiryDate,
          };
        }
      }
      
      print('❌ 시간권 잔액 조회 실패');
      return {
        'success': false,
        'error': '시간권 잔액 조회 실패',
      };
      
    } catch (e) {
      print('❌ 시간권 잔액 조회 오류: $e');
      return {
        'success': false,
        'error': '시간권 잔액 조회 오류: $e',
      };
    }
  }
  
  /// 선불크레딧 처리
  static Future<PaymentResult> _processPrepaidCredit({
    required String branchId,
    required Map<String, dynamic> selectedMember,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required Map<String, dynamic> paymentMethod,
    required int usageAmount,
    required int originalPrice,
    required int finalPrice,
    required int couponDiscountAmount,
    required Map<String, dynamic> pricingAnalysis,
    required String reservationId,
  }) async {
    try {
      final methodType = paymentMethod['type'] as String;
      final contractHistoryId = methodType.replaceFirst('prepaid_credit_', '');
      final contractData = paymentMethod['contract_data'] as Map<String, dynamic>?;
      
      if (contractData == null) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: 0,
          afterBalance: 0,
          unit: '원',
          success: false,
          errorMessage: '계약 정보를 찾을 수 없습니다',
        );
      }
      
      final beforeBalance = contractData['balance'] as int;
      final contractId = contractData['contract_id']?.toString();
      final expiryDate = contractData['expiry_date']?.toString();
      
      // 잔액 확인
      if (beforeBalance < usageAmount) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: beforeBalance,
          afterBalance: beforeBalance,
          contractHistoryId: contractHistoryId,
          contractId: contractId,
          expiryDate: expiryDate,
          unit: '원',
          success: false,
          errorMessage: '잔액이 부족합니다',
        );
      }
      
      final afterBalance = beforeBalance - usageAmount;
      
      // v2_priced_TS 테이블 업데이트
      final pricedTsSuccess = await updatePricedTsTable(
        branchId: branchId,
        selectedMember: selectedMember,
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        selectedDuration: selectedDuration,
        selectedTs: selectedTs,
        finalPrice: finalPrice,
        originalPrice: originalPrice,
        couponDiscountAmount: couponDiscountAmount,
        paymentMethodType: '선불크레딧',
        pricingAnalysis: pricingAnalysis,
        reservationId: reservationId,
      );
      
      if (!pricedTsSuccess) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: beforeBalance,
          afterBalance: beforeBalance,
          contractHistoryId: contractHistoryId,
          contractId: contractId,
          expiryDate: expiryDate,
          unit: '원',
          success: false,
          errorMessage: 'v2_priced_TS 테이블 업데이트 실패',
        );
      }
      
      // 선불크레딧 v2_bills 테이블 업데이트
      final billsSuccess = await updatePrepaidCreditBills(
        branchId: branchId,
        memberId: selectedMember['member_id']?.toString() ?? '',
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        selectedDuration: selectedDuration,
        selectedTs: selectedTs,
        contractHistoryId: contractHistoryId,
        contractId: contractId,
        expiryDate: expiryDate,
        usageAmount: usageAmount,
        beforeBalance: beforeBalance,
        afterBalance: afterBalance,
        reservationId: reservationId,
      );
      
      if (!billsSuccess) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: beforeBalance,
          afterBalance: beforeBalance,
          contractHistoryId: contractHistoryId,
          contractId: contractId,
          expiryDate: expiryDate,
          unit: '원',
          success: false,
          errorMessage: 'v2_bills 테이블 업데이트 실패',
        );
      }
      
      print('✅ 선불크레딧 처리 성공');
      return PaymentResult(
        methodType: methodType,
        usedAmount: usageAmount,
        beforeBalance: beforeBalance,
        afterBalance: afterBalance,
        contractHistoryId: contractHistoryId,
        contractId: contractId,
        expiryDate: expiryDate,
        unit: '원',
        success: true,
      );
      
    } catch (e) {
      print('❌ 선불크레딧 처리 오류: $e');
      return PaymentResult(
        methodType: paymentMethod['type'] as String,
        usedAmount: 0,
        beforeBalance: 0,
        afterBalance: 0,
        unit: '원',
        success: false,
        errorMessage: '선불크레딧 처리 오류: $e',
      );
    }
  }
  
  /// 시간권 처리
  static Future<PaymentResult> _processTimePass({
    required String branchId,
    required Map<String, dynamic> selectedMember,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required Map<String, dynamic> paymentMethod,
    required int usageAmount,
    required int originalPrice,
    required int finalPrice,
    required int couponDiscountAmount,
    required Map<String, dynamic> pricingAnalysis,
    required String reservationId,
  }) async {
    try {
      final methodType = paymentMethod['type'] as String;
      final contractHistoryId = methodType.replaceFirst('time_pass_', '');
      final contractData = paymentMethod['contract_data'] as Map<String, dynamic>?;
      
      if (contractData == null) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: 0,
          afterBalance: 0,
          unit: '분',
          success: false,
          errorMessage: '계약 정보를 찾을 수 없습니다',
        );
      }
      
      final beforeBalance = contractData['balance'] as int;
      final contractId = contractData['contract_id']?.toString();
      final expiryDate = contractData['expiry_date']?.toString();
      
      // 잔액 확인
      if (beforeBalance < usageAmount) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: beforeBalance,
          afterBalance: beforeBalance,
          contractHistoryId: contractHistoryId,
          contractId: contractId,
          expiryDate: expiryDate,
          unit: '분',
          success: false,
          errorMessage: '잔액이 부족합니다',
        );
      }
      
      final afterBalance = beforeBalance - usageAmount;
      
      // v2_priced_TS 테이블 업데이트
      final pricedTsSuccess = await updatePricedTsTable(
        branchId: branchId,
        selectedMember: selectedMember,
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        selectedDuration: selectedDuration,
        selectedTs: selectedTs,
        finalPrice: finalPrice,
        originalPrice: originalPrice,
        couponDiscountAmount: couponDiscountAmount,
        paymentMethodType: '시간권',
        pricingAnalysis: pricingAnalysis,
        reservationId: reservationId,
      );
      
      if (!pricedTsSuccess) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: beforeBalance,
          afterBalance: beforeBalance,
          contractHistoryId: contractHistoryId,
          contractId: contractId,
          expiryDate: expiryDate,
          unit: '분',
          success: false,
          errorMessage: 'v2_priced_TS 테이블 업데이트 실패',
        );
      }
      
      // 시간권 v2_bill_times 테이블 업데이트
      final billTimesSuccess = await updateTimePassBillTimes(
        branchId: branchId,
        memberId: selectedMember['member_id']?.toString() ?? '',
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        selectedDuration: selectedDuration,
        selectedTs: selectedTs,
        originalPrice: originalPrice,
        finalPrice: finalPrice,
        contractHistoryId: contractHistoryId,
        contractId: contractId,
        expiryDate: expiryDate,
        usageAmount: usageAmount,
        beforeBalance: beforeBalance,
        afterBalance: afterBalance,
        reservationId: reservationId,
        finalPaymentMinutes: selectedDuration,
      );
      
      if (!billTimesSuccess) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: beforeBalance,
          afterBalance: beforeBalance,
          contractHistoryId: contractHistoryId,
          contractId: contractId,
          expiryDate: expiryDate,
          unit: '분',
          success: false,
          errorMessage: 'v2_bill_times 테이블 업데이트 실패',
        );
      }
      
      print('✅ 시간권 처리 성공');
      return PaymentResult(
        methodType: methodType,
        usedAmount: usageAmount,
        beforeBalance: beforeBalance,
        afterBalance: afterBalance,
        contractHistoryId: contractHistoryId,
        contractId: contractId,
        expiryDate: expiryDate,
        unit: '분',
        success: true,
      );
      
    } catch (e) {
      print('❌ 시간권 처리 오류: $e');
      return PaymentResult(
        methodType: paymentMethod['type'] as String,
        usedAmount: 0,
        beforeBalance: 0,
        afterBalance: 0,
        unit: '분',
        success: false,
        errorMessage: '시간권 처리 오류: $e',
      );
    }
  }
  
  /// 기간권 처리
  static Future<PaymentResult> _processPeriodPass({
    required String branchId,
    required Map<String, dynamic> selectedMember,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required Map<String, dynamic> paymentMethod,
    required int usageAmount,
    required int originalPrice,
    required int finalPrice,
    required int couponDiscountAmount,
    required Map<String, dynamic> pricingAnalysis,
    required String reservationId,
  }) async {
    try {
      final String methodType = paymentMethod['type'] as String;
      final beforeBalance = paymentMethod['balance'] as int;
      
      // 잔액 확인
      if (beforeBalance < usageAmount) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: beforeBalance,
          afterBalance: beforeBalance,
          unit: '분',
          success: false,
          errorMessage: '잔액이 부족합니다',
        );
      }
      
      final afterBalance = beforeBalance - usageAmount;
      
      // v2_priced_TS 테이블 업데이트
      final pricedTsSuccess = await updatePricedTsTable(
        branchId: branchId,
        selectedMember: selectedMember,
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        selectedDuration: selectedDuration,
        selectedTs: selectedTs,
        finalPrice: finalPrice,
        originalPrice: originalPrice,
        couponDiscountAmount: couponDiscountAmount,
        paymentMethodType: '기간권',
        pricingAnalysis: pricingAnalysis,
        reservationId: reservationId,
      );
      
      if (!pricedTsSuccess) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: beforeBalance,
          afterBalance: beforeBalance,
          unit: '분',
          success: false,
          errorMessage: 'v2_priced_TS 테이블 업데이트 실패',
        );
      }
      
      print('✅ 기간권 처리 성공');
      return PaymentResult(
        methodType: methodType,
        usedAmount: usageAmount,
        beforeBalance: beforeBalance,
        afterBalance: afterBalance,
        unit: '분',
        success: true,
      );
      
    } catch (e) {
      final String methodType = paymentMethod['type'] as String;
      print('❌ 기간권 처리 오류: $e');
      return PaymentResult(
        methodType: methodType,
        usedAmount: 0,
        beforeBalance: 0,
        afterBalance: 0,
        unit: '분',
        success: false,
        errorMessage: '기간권 처리 오류: $e',
      );
    }
  }
  
  /// 기업복지 처리
  static Future<PaymentResult> _processCorporateWelfare({
    required String branchId,
    required Map<String, dynamic> selectedMember,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required Map<String, dynamic> paymentMethod,
    required int usageAmount,
    required int originalPrice,
    required int finalPrice,
    required int couponDiscountAmount,
    required Map<String, dynamic> pricingAnalysis,
    required String reservationId,
  }) async {
    try {
      final String methodType = paymentMethod['type'] as String;
      
      // 기업복지는 최대 60분까지만 사용 가능
      final maxCorporateWelfareMinutes = 60;
      if (usageAmount > maxCorporateWelfareMinutes) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: -1,
          afterBalance: -1,
          unit: '분',
          success: false,
          errorMessage: '기업복지는 최대 60분까지만 사용 가능합니다',
        );
      }
      
      // v2_priced_TS 테이블 업데이트
      final pricedTsSuccess = await updatePricedTsTable(
        branchId: branchId,
        selectedMember: selectedMember,
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        selectedDuration: selectedDuration,
        selectedTs: selectedTs,
        finalPrice: finalPrice,
        originalPrice: originalPrice,
        couponDiscountAmount: couponDiscountAmount,
        paymentMethodType: '기업복지',
        pricingAnalysis: pricingAnalysis,
        reservationId: reservationId,
      );
      
      if (!pricedTsSuccess) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: -1,
          afterBalance: -1,
          unit: '분',
          success: false,
          errorMessage: 'v2_priced_TS 테이블 업데이트 실패',
        );
      }
      
      print('✅ 기업복지 처리 성공');
      return PaymentResult(
        methodType: methodType,
        usedAmount: usageAmount,
        beforeBalance: -1, // 무제한을 표시하기 위해 -1 사용
        afterBalance: -1, // 무제한을 표시하기 위해 -1 사용
        unit: '분',
        success: true,
      );
      
    } catch (e) {
      final String methodType = paymentMethod['type'] as String;
      print('❌ 기업복지 처리 오류: $e');
      return PaymentResult(
        methodType: methodType,
        usedAmount: 0,
        beforeBalance: -1,
        afterBalance: -1,
        unit: '분',
        success: false,
        errorMessage: '기업복지 처리 오류: $e',
      );
    }
  }
  
  /// 카드결제 처리
  static Future<PaymentResult> _processCardPayment({
    required String branchId,
    required Map<String, dynamic> selectedMember,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required Map<String, dynamic> paymentMethod,
    required int usageAmount,
    required int originalPrice,
    required int finalPrice,
    required int couponDiscountAmount,
    required Map<String, dynamic> pricingAnalysis,
    required String reservationId,
  }) async {
    try {
      final String methodType = paymentMethod['type'] as String;
      
      // v2_priced_TS 테이블 업데이트
      final pricedTsSuccess = await updatePricedTsTable(
        branchId: branchId,
        selectedMember: selectedMember,
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        selectedDuration: selectedDuration,
        selectedTs: selectedTs,
        finalPrice: finalPrice,
        originalPrice: originalPrice,
        couponDiscountAmount: couponDiscountAmount,
        paymentMethodType: '카드결제',
        pricingAnalysis: pricingAnalysis,
        reservationId: reservationId,
      );
      
      if (!pricedTsSuccess) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: -1,
          afterBalance: -1,
          unit: '원',
          success: false,
          errorMessage: 'v2_priced_TS 테이블 업데이트 실패',
        );
      }
      
      // 카드결제 v2_bills 테이블 업데이트
      final directPaymentSuccess = await updateDirectPaymentBills(
        branchId: branchId,
        memberId: selectedMember['member_id']?.toString() ?? '',
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        selectedDuration: selectedDuration,
        selectedTs: selectedTs,
        finalPrice: finalPrice,
        paymentMethodType: 'card_payment',
        reservationId: reservationId,
      );
      
      if (!directPaymentSuccess) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: -1,
          afterBalance: -1,
          unit: '원',
          success: false,
          errorMessage: 'v2_bills 테이블 업데이트 실패',
        );
      }
      
      print('✅ 카드결제 처리 성공');
      return PaymentResult(
        methodType: methodType,
        usedAmount: usageAmount,
        beforeBalance: -1, // 무제한을 표시하기 위해 -1 사용
        afterBalance: -1, // 무제한을 표시하기 위해 -1 사용
        unit: '원',
        success: true,
      );
      
    } catch (e) {
      final String methodType = paymentMethod['type'] as String;
      print('❌ 카드결제 처리 오류: $e');
      return PaymentResult(
        methodType: methodType,
        usedAmount: 0,
        beforeBalance: -1,
        afterBalance: -1,
        unit: '원',
        success: false,
        errorMessage: '카드결제 처리 오류: $e',
      );
    }
  }
  
  /// 현금결제 처리
  static Future<PaymentResult> _processCashPayment({
    required String branchId,
    required Map<String, dynamic> selectedMember,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required Map<String, dynamic> paymentMethod,
    required int usageAmount,
    required int originalPrice,
    required int finalPrice,
    required int couponDiscountAmount,
    required Map<String, dynamic> pricingAnalysis,
    required String reservationId,
  }) async {
    try {
      final String methodType = paymentMethod['type'] as String;
      
      // v2_priced_TS 테이블 업데이트
      final pricedTsSuccess = await updatePricedTsTable(
        branchId: branchId,
        selectedMember: selectedMember,
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        selectedDuration: selectedDuration,
        selectedTs: selectedTs,
        finalPrice: finalPrice,
        originalPrice: originalPrice,
        couponDiscountAmount: couponDiscountAmount,
        paymentMethodType: '현금결제',
        pricingAnalysis: pricingAnalysis,
        reservationId: reservationId,
      );
      
      if (!pricedTsSuccess) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: -1,
          afterBalance: -1,
          unit: '원',
          success: false,
          errorMessage: 'v2_priced_TS 테이블 업데이트 실패',
        );
      }
      
      // 현금결제 v2_bills 테이블 업데이트
      final directPaymentSuccess = await updateDirectPaymentBills(
        branchId: branchId,
        memberId: selectedMember['member_id']?.toString() ?? '',
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        selectedDuration: selectedDuration,
        selectedTs: selectedTs,
        finalPrice: finalPrice,
        paymentMethodType: 'cash_payment',
        reservationId: reservationId,
      );
      
      if (!directPaymentSuccess) {
        return PaymentResult(
          methodType: methodType,
          usedAmount: 0,
          beforeBalance: -1,
          afterBalance: -1,
          unit: '원',
          success: false,
          errorMessage: 'v2_bills 테이블 업데이트 실패',
        );
      }
      
      print('✅ 현금결제 처리 성공');
      return PaymentResult(
        methodType: methodType,
        usedAmount: usageAmount,
        beforeBalance: -1, // 무제한을 표시하기 위해 -1 사용
        afterBalance: -1, // 무제한을 표시하기 위해 -1 사용
        unit: '원',
        success: true,
      );
      
    } catch (e) {
      final String methodType = paymentMethod['type'] as String;
      print('❌ 현금결제 처리 오류: $e');
      return PaymentResult(
        methodType: methodType,
        usedAmount: 0,
        beforeBalance: -1,
        afterBalance: -1,
        unit: '원',
        success: false,
        errorMessage: '현금결제 처리 오류: $e',
      );
    }
  }
  
  /// 결제수단별 단위 반환
  static String _getPaymentUnit(String methodType) {
    if (methodType.startsWith('prepaid_credit_') || 
        methodType == 'card_payment' || 
        methodType == 'cash_payment') {
      return '원';
    } else {
      return '분';
    }
  }

  /// v2_priced_TS 테이블 업데이트
  static Future<bool> updatePricedTsTable({
    required String branchId,
    required Map<String, dynamic> selectedMember,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required int finalPrice,
    required int originalPrice,
    required int couponDiscountAmount,
    required String paymentMethodType,
    required Map<String, dynamic> pricingAnalysis,
    required String reservationId,
  }) async {
    try {
      // 종료 시간 계산
      final startTimeParts = selectedTime.split(':');
      final startHour = int.parse(startTimeParts[0]);
      final startMinute = int.parse(startTimeParts[1]);
      final endDateTime = DateTime(2000, 1, 1, startHour, startMinute).add(Duration(minutes: selectedDuration));
      final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}:00';
      
      // bill_text 생성 (예: "3번 타석(09:00 ~ 10:00)")
      final billText = '${selectedTs}번 타석($selectedTime ~ ${endTime.substring(0, 5)})';
      
      print('📝 Bill Text 생성: $billText');
      
      // v2_priced_TS의 bill_min은 전체 연습 시간
      final billMin = selectedDuration;
      
      // 시간대 분류 정보
      final normalMin = pricingAnalysis['base_price'] ?? 0;
      final discountMin = pricingAnalysis['discount_price'] ?? 0;
      final extrachargeMin = pricingAnalysis['extracharge_price'] ?? 0;
      
      print('⏰ v2_priced_TS bill_min: ${billMin}분 (전체 연습 시간)');
      
      // v2_priced_TS 테이블 업데이트 데이터
      final pricedTsData = {
        'reservation_id': reservationId,
        'branch_id': branchId,
        'member_id': selectedMember['id'],
        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'time': selectedTime,
        'duration': selectedDuration,
        'ts': selectedTs,
        'bill_text': billText,
        'payment_method_type': paymentMethodType,
        'bill_min': billMin,
        'original_price': originalPrice,
        'coupon_discount_amount': couponDiscountAmount,
        'final_price': finalPrice,
        'end_time': endTime,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      print('=== v2_priced_TS 테이블 업데이트 시작 ===');
      print('reservation_id: $reservationId');
      print('bill_text: $billText');
      print('payment_method_type: $paymentMethodType (외부에서 전달받음)');
      print('업데이트 데이터: $pricedTsData');
      
      await ApiService.updatePricedTsTable(pricedTsData);
      print('✅ v2_priced_TS 테이블 업데이트 성공');
      
      return true;
      
    } catch (e) {
      print('❌ v2_priced_TS 테이블 업데이트 오류: $e');
      return false;
    }
  }
  
  /// 선불크레딧 v2_bills 테이블 업데이트
  static Future<bool> updatePrepaidCreditBills({
    required String branchId,
    required String memberId,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required String contractHistoryId,
    String? contractId,
    String? expiryDate,
    required int usageAmount,
    required int beforeBalance,
    required int afterBalance,
    required String reservationId,
  }) async {
    try {
      // bill_text 생성 (예: "3번 타석(09:00 ~ 09:55)")
      final billText = '${selectedTs}번 타석($selectedTime ~ ${selectedTime.substring(0, 5)})';
      
      // 선불크레딧은 차감이므로 음수로 처리
      final billTotalAmt = -usageAmount; // 총 사용금액 (음수)
      final billDeduction = 0; // 할인금액 (선불크레딧 자체가 할인개념이므로 0)
      final billNetAmt = billTotalAmt; // 실제 차감금액 (음수)
      
      print('=== 선불크레딧 v2_bills 업데이트 준비 ===');
      print('계약 ID: $contractHistoryId');
      print('사용 금액: $usageAmount');
      print('bill_text: $billText');
      print('계약 만료일: $expiryDate');
      
      final billUpdateSuccess = await ApiService.updateBillsTable(
        memberId: memberId,
        billDate: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
        billText: billText,
        billTotalAmt: billTotalAmt,
        billDeduction: billDeduction,
        billNetAmt: billNetAmt,
        reservationId: reservationId,
        contractHistoryId: contractHistoryId,
        branchId: branchId,
        contractCreditExpiryDate: expiryDate,
      );
      
      if (billUpdateSuccess) {
        print('✅ 선불크레딧 v2_bills 테이블 업데이트 성공 (계약 ID: $contractHistoryId)');
        return true;
      } else {
        print('❌ 선불크레딧 v2_bills 테이블 업데이트 실패 (계약 ID: $contractHistoryId)');
        return false;
      }
      
    } catch (e) {
      print('❌ 선불크레딧 v2_bills 테이블 업데이트 오류: $e');
      return false;
    }
  }
  
  /// 시간권 v2_bill_times 테이블 업데이트
  static Future<bool> updateTimePassBillTimes({
    required String branchId,
    required String memberId,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required int originalPrice,
    required int finalPrice,
    required String contractHistoryId,
    String? contractId,
    String? expiryDate,
    required int usageAmount,
    required int beforeBalance,
    required int afterBalance,
    required String reservationId,
    required int finalPaymentMinutes,
  }) async {
    try {
      // 종료 시간 계산
      final startTimeParts = selectedTime.split(':');
      final startHour = int.parse(startTimeParts[0]);
      final startMinute = int.parse(startTimeParts[1]);
      final endDateTime = DateTime(2000, 1, 1, startHour, startMinute).add(Duration(minutes: selectedDuration));
      final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';
      
      // bill_text 생성 (예: "3번 타석(09:00 ~ 09:55)")
      final billText = '${selectedTs}번 타석($selectedTime ~ $endTime)';
      
      // Step5에서 계산된 할인 정보 사용
      int billTotalMin = selectedDuration; // 총 시간
      int billDiscountMin = billTotalMin - finalPaymentMinutes; // 할인시간
      int billMin = usageAmount; // 실제 과금시간 (시간권으로 차감되는 시간)
      
      print('=== Step5 계산 정보 사용 ===');
      print('총 시간: ${billTotalMin}분');
      print('Step5에서 계산된 할인후 시간: ${finalPaymentMinutes}분');
      print('할인시간: ${billDiscountMin}분');
      print('원가: ${originalPrice}원');
      print('할인후 가격: ${finalPrice}원');
      
      // 할인시간이 총 시간을 초과하지 않도록 제한
      if (billDiscountMin > billTotalMin) {
        print('할인시간이 총 시간을 초과하여 조정: ${billDiscountMin}분 → ${billTotalMin}분');
        billDiscountMin = billTotalMin;
      }
      
      // 할인시간이 음수가 되지 않도록 제한
      if (billDiscountMin < 0) {
        print('할인시간이 음수가 되어 조정: ${billDiscountMin}분 → 0분');
        billDiscountMin = 0;
      }
      
      // 실제 과금시간은 총시간 - 할인시간으로 계산
      billMin = billTotalMin - billDiscountMin;
      
      print('=== 시간권 과금시간 계산 완료 ===');
      print('총 시간: ${billTotalMin}분');
      print('할인시간: ${billDiscountMin}분');
      print('실제 과금시간: ${billMin}분');
      print('시간권에서 차감될 시간: ${usageAmount}분');
      
      // 검증: 계산된 과금시간과 실제 사용시간이 일치하는지 확인
      if (billMin != usageAmount) {
        print('⚠️ 주의: 계산된 과금시간(${billMin}분)과 실제 사용시간(${usageAmount}분)이 다릅니다.');
        print('   시간권 잔액 차감은 실제 사용시간(${usageAmount}분)으로 진행됩니다.');
      }
      
      print('=== 시간권 v2_bill_times 업데이트 준비 ===');
      print('계약 ID: $contractHistoryId');
      print('총 시간: ${billTotalMin}분');
      print('할인시간: ${billDiscountMin}분');
      print('실제 과금시간(차감시간): ${billMin}분');
      print('bill_text: $billText');
      print('계약 만료일: $expiryDate');
      
      final billTimesUpdateSuccess = await ApiService.updateBillTimesTable(
        memberId: memberId,
        billDate: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
        billText: billText,
        billMin: billMin, // 실제 과금시간 (시간권에서 차감되는 시간)
        billTotalMin: billTotalMin, // 총 시간
        billDiscountMin: billDiscountMin, // 할인시간
        reservationId: reservationId,
        contractHistoryId: contractHistoryId,
        branchId: branchId,
        contractTsMinExpiryDate: expiryDate,
      );
      
      if (billTimesUpdateSuccess) {
        print('✅ 시간권 v2_bill_times 테이블 업데이트 성공 (계약 ID: $contractHistoryId)');
        return true;
      } else {
        print('❌ 시간권 v2_bill_times 테이블 업데이트 실패 (계약 ID: $contractHistoryId)');
        return false;
      }
      
    } catch (e) {
      print('❌ 시간권 v2_bill_times 테이블 업데이트 오류: $e');
      return false;
    }
  }
  
  /// 카드결제/현금결제 v2_bills 테이블 업데이트
  static Future<bool> updateDirectPaymentBills({
    required String branchId,
    required String memberId,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required int finalPrice,
    required String paymentMethodType, // 'card_payment' 또는 'cash_payment'
    required String reservationId,
  }) async {
    try {
      // 직접결제는 수입이므로 양수로 처리
      final billTotalAmt = finalPrice; // 총 결제금액 (양수)
      final billDeduction = 0; // 할인금액 (별도 할인 없음)
      final billNetAmt = billTotalAmt; // 실제 결제금액 (양수)
      
      print('=== ${paymentMethodType == 'card_payment' ? '카드결제' : '현금결제'} v2_bills 업데이트 준비 ===');
      print('결제 방법: $paymentMethodType');
      print('결제 금액: $finalPrice원');
      print('bill_text: $selectedTime');
      
      final billUpdateSuccess = await ApiService.updateBillsTable(
        memberId: memberId,
        billDate: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
        billText: selectedTime,
        billTotalAmt: billTotalAmt,
        billDeduction: billDeduction,
        billNetAmt: billNetAmt,
        reservationId: reservationId,
        contractHistoryId: null, // 직접결제는 계약 없음
        branchId: branchId,
        contractCreditExpiryDate: null, // 직접결제는 만료일 없음
        paymentMethodType: paymentMethodType, // 결제 방법 타입 전달
      );
      
      if (billUpdateSuccess) {
        print('✅ ${paymentMethodType == 'card_payment' ? '카드결제' : '현금결제'} v2_bills 테이블 업데이트 성공');
        return true;
      } else {
        print('❌ ${paymentMethodType == 'card_payment' ? '카드결제' : '현금결제'} v2_bills 테이블 업데이트 실패');
        return false;
      }
      
    } catch (e) {
      print('❌ ${paymentMethodType == 'card_payment' ? '카드결제' : '현금결제'} v2_bills 테이블 업데이트 오류: $e');
      return false;
    }
  }
  
  /// 결제 공제 계산
  static Future<Map<String, dynamic>> calculatePaymentDeductions({
    required String branchId,
    required Map<String, dynamic> selectedMember,
    required String selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required List<Map<String, dynamic>> selectedPaymentMethods,
    required List<Map<String, dynamic>> prepaidCreditContracts,
    required List<Map<String, dynamic>> timePassContracts,
    required Map<String, dynamic> balances,
    required int originalPrice,
    required int finalPrice,
    required int totalPrice,
    required int totalMinutes,
    required double pricePerMinute,
    required Map<String, dynamic> pricingAnalysis,
    String? reservationId,
  }) async {
    try {
      final results = <Map<String, dynamic>>[];
      var remainingAmount = finalPrice;
      
      for (final method in selectedPaymentMethods) {
        if (remainingAmount <= 0) break;
        
        final methodType = method['type'] as String;
        final usageAmount = method['amount'] as int;
        if (usageAmount <= 0) continue;
        
        // 잔액 정보 추가
        if (balances.containsKey(methodType)) {
          method['balance'] = balances[methodType];
        }
        
        // 선불크레딧 계약 정보 추가
        if (methodType.startsWith('prepaid_credit_')) {
          final contractId = methodType.replaceFirst('prepaid_credit_', '');
          final contract = prepaidCreditContracts.firstWhere(
            (c) => c['contract_history_id'].toString() == contractId,
            orElse: () => <String, dynamic>{},
          );
          if (contract.isNotEmpty) {
            method['contract_data'] = contract;
          }
        }
        
        // 시간권 계약 정보 추가
        if (methodType.startsWith('time_pass_')) {
          final contractId = methodType.replaceFirst('time_pass_', '');
          final contract = timePassContracts.firstWhere(
            (c) => c['contract_history_id'].toString() == contractId,
            orElse: () => <String, dynamic>{},
          );
          if (contract.isNotEmpty) {
            method['contract_data'] = contract;
          }
        }
        
        final result = await processSinglePayment(
          branchId: branchId,
          memberId: selectedMember['member_id']?.toString() ?? '',
          selectedDate: selectedDate,
          selectedTime: selectedTime,
          selectedDuration: selectedDuration,
          selectedTs: selectedTs,
          paymentMethod: methodType,
          usageAmount: usageAmount,
          originalPrice: originalPrice,
          finalPrice: finalPrice,
          couponDiscountAmount: 0,
          pricingAnalysis: pricingAnalysis,
          reservationId: reservationId,
        );
        
        results.add({
          'method': method,
          'result': result,
        });
        
        if (result.success) {
          remainingAmount -= usageAmount;
        }
      }
      
      return {
        'success': remainingAmount <= 0,
        'results': results,
        'remainingAmount': remainingAmount,
        'totalMinutes': totalMinutes,
        'totalPrice': totalPrice,
      };
    } catch (e) {
      print('❌ 결제 공제 계산 오류: $e');
      return {
        'success': false,
        'error': '결제 공제 계산 중 오류 발생: $e',
      };
    }
  }

  /// 예약 완료 처리
  static Future<bool> processReservationCompletion({
    required String branchId,
    required Map<String, dynamic> selectedMember,
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required List<Map<String, dynamic>> paymentResults,
    required List<Map<String, dynamic>> selectedPaymentMethods,
    required List<Map<String, dynamic>> prepaidCreditContracts,
    required List<Map<String, dynamic>> timePassContracts,
    required Map<String, dynamic> balances,
    required int originalPrice,
    required int finalPrice,
    required Map<String, dynamic> pricingAnalysis,
    required int couponDiscountAmount,
    required String paymentMethodType,
    required int finalPaymentMinutes,
    String? reservationId,
  }) async {
    try {
      // 예약 ID 생성 또는 사용
      final String actualReservationId = reservationId ?? generateReservationId(
        selectedDate.toString().split(' ')[0],
        selectedTs,
        selectedTime,
        false
      );
      
      // 결제 처리 결과 검증
      var totalPaid = 0;
      for (final result in paymentResults) {
        if (result['success'] == true) {
          totalPaid += result['amount'] as int;
        }
      }
      
      if (totalPaid != finalPrice) {
        print('❌ 결제 금액 불일치: 지불됨 $totalPaid, 필요 $finalPrice');
        return false;
      }
      
      // v2_priced_TS 테이블 업데이트
      final success = await updatePricedTsTable(
        branchId: branchId,
        selectedMember: selectedMember,
        selectedDate: selectedDate,
        selectedTime: selectedTime,
        selectedDuration: selectedDuration,
        selectedTs: selectedTs,
        finalPrice: finalPrice,
        originalPrice: originalPrice,
        couponDiscountAmount: couponDiscountAmount,
        paymentMethodType: paymentMethodType,
        pricingAnalysis: pricingAnalysis,
        reservationId: actualReservationId,
      );
      
      return success;
      
    } catch (e) {
      print('❌ 예약 완료 처리 오류: $e');
      return false;
    }
  }

  /// 중복 예약 체크
  static Future<bool> checkDuplicateReservation({
    required String branchId,
    required String tsId,
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final response = await ApiClient.call_api(
        'get',
        'v2_priced_TS',
        fields: ['reservation_id', 'ts_start', 'ts_end'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'ts_id', 'operator': '=', 'value': tsId},
          {'field': 'ts_date', 'operator': '=', 'value': date},
          {'field': 'ts_status', 'operator': '<>', 'value': '예약취소'},
        ],
      );
      
      if (response['success'] == true && response['data'] != null) {
        final reservations = response['data'] as List;
        for (final reservation in reservations) {
          final existingStart = reservation['ts_start'].toString().substring(0, 5);
          final existingEnd = reservation['ts_end'].toString().substring(0, 5);
          
          if (isTimeOverlap(startTime, endTime, existingStart, existingEnd)) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('❌ 중복 예약 체크 오류: $e');
      return false;
    }
  }

  static bool isTimeOverlap(String requestStart, String requestEnd, String existingStart, String existingEnd) {
    int timeToMinutes(String time) {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    final reqStart = timeToMinutes(requestStart);
    final reqEnd = timeToMinutes(requestEnd);
    final existStart = timeToMinutes(existingStart);
    final existEnd = timeToMinutes(existingEnd);

    return reqStart < existEnd && reqEnd > existStart;
  }

  static String generateReservationId(
    String date, String tsId, String startTime, bool isDuplicate
  ) {
    try {
      // 날짜를 yymmdd 형식으로 변환
      final dateObj = DateTime.parse(date);
      final datePart = DateFormat('yyMMdd').format(dateObj);
      
      // 시간을 hhmm 형식으로 변환
      final timePart = startTime.replaceAll(':', '');
      
      // 기본 reservation_id 생성
      final baseReservationId = '${datePart}_${tsId}_$timePart';
      
      // 중복이 있으면 타임스탬프 추가
      if (isDuplicate) {
        final timestamp = DateFormat('HHmmss').format(DateTime.now());
        return '${baseReservationId}_$timestamp';
      } else {
        return baseReservationId;
      }
    } catch (e) {
      print('❌ 예약 ID 생성 오류: $e');
      return '';
    }
  }

  static String calculateEndTime(String startTime, int durationMinutes) {
    try {
      final parts = startTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      final totalMinutes = hour * 60 + minute + durationMinutes;
      final endHour = (totalMinutes ~/ 60) % 24;
      final endMinute = totalMinutes % 60;
      
      return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('종료 시간 계산 오류: $e');
      return startTime;
    }
  }

  static Future<Map<String, dynamic>> processReservationWithSelectedContract({
    required String branchId,
    required String memberId,
    required String selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required String contractType,
    required String contractHistoryId,
    required int usageAmount,
  }) async {
    // 계약 기반 예약 처리 로직
    try {
      final endTime = calculateEndTime(selectedTime, selectedDuration);
      final isDuplicate = await checkDuplicateReservation(
        branchId: branchId,
        tsId: selectedTs,
        date: selectedDate,
        startTime: selectedTime,
        endTime: endTime,
      );

      if (isDuplicate) {
        return {
          'success': false,
          'error': '중복 예약이 존재합니다'
        };
      }

      // 여기에 계약 기반 예약 처리 로직 구현
      return {
        'success': true,
        'message': '계약 기반 예약 처리 완료'
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  static Future<Map<String, dynamic>> processSimplePaymentReservation({
    required String branchId,
    required String memberId,
    required String selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    required String paymentType,
    required int paymentAmount,
  }) async {
    // 심플 결제 예약 처리 로직
    try {
      final endTime = calculateEndTime(selectedTime, selectedDuration);
      final isDuplicate = await checkDuplicateReservation(
        branchId: branchId,
        tsId: selectedTs,
        date: selectedDate,
        startTime: selectedTime,
        endTime: endTime,
      );

      if (isDuplicate) {
        return {
          'success': false,
          'error': '중복 예약이 존재합니다'
        };
      }

      // 여기에 심플 결제 예약 처리 로직 구현
      return {
        'success': true,
        'message': '심플 결제 예약 처리 완료'
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }
}

class ApiClient {
  static Future<Map<String, dynamic>> call_api(
    String operation,
    String table, {
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, String>>? orderBy,
    int? limit,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 실제 API 호출 로직 구현
      // 현재는 테스트용으로 성공 응답 반환
      return {
        'success': true,
        'data': [],
        'message': 'API 호출 성공',
      };
    } catch (e) {
      print('❌ API 호출 오류: $e');
      return {
        'success': false,
        'error': 'API 호출 실패: $e',
      };
    }
  }
} 