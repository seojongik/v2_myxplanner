import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';

/// 타석 예약 취소 서비스
class TsReservationCancelService {
  /// 타석 예약 취소 메인 함수
  static Future<bool> cancelTsReservation({
    required String reservationId,
    required BuildContext context,
    required DateTime reservationStartTime, // 예약 시작 시간 추가
    int? programPenaltyPercent, // 프로그램 페널티 (프로그램 예약인 경우)
  }) async {
    try {
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('타석 예약 취소 시작');
      print('═══════════════════════════════════════════════════════════');
      print('reservation_id: $reservationId');
      
      // 1. v2_priced_TS에서 예약 정보 조회 및 상태 업데이트
      final pricedTsResult = await _updatePricedTsStatus(reservationId);
      if (!pricedTsResult['success']) {
        print('❌ v2_priced_TS 업데이트 실패');
        return false;
      }
      
      // v2_priced_ts.bill_id는 실제로 contract_history_id(회원권ID)를 저장
      // v2_priced_ts.bill_min_id는 실제로 contract_history_id(시간권 회원권ID)를 저장
      final contractHistoryId = pricedTsResult['billId'];  // 선불크레딧 회원권 ID
      final timeContractHistoryId = pricedTsResult['billMinId'];  // 시간권 회원권 ID
      
      print('조회된 contract_history_id (선불크레딧): $contractHistoryId');
      print('조회된 contract_history_id (시간권): $timeContractHistoryId');
      
      bool billSuccess = true;
      bool billTimesSuccess = true;
      
      // 2. 선불크레딧 결제인 경우 v2_bills 취소 처리
      if (contractHistoryId != null && contractHistoryId.toString().isNotEmpty && contractHistoryId.toString() != 'null') {
        billSuccess = await _cancelBillsRecord(
          contractHistoryId.toString(), 
          reservationStartTime, 
          programPenaltyPercent: programPenaltyPercent,
          reservationId: reservationId,
        );
      }
      
      // 3. 시간권 결제인 경우 v2_bill_times 취소 처리
      if (timeContractHistoryId != null && timeContractHistoryId.toString().isNotEmpty && timeContractHistoryId.toString() != 'null') {
        billTimesSuccess = await _cancelBillTimesRecord(timeContractHistoryId.toString(), reservationStartTime, programPenaltyPercent: programPenaltyPercent);
      }
      
      final allSuccess = billSuccess && billTimesSuccess;
      
      // 4. 결제 취소가 성공한 경우에만 할인 쿠폰 처리
      bool couponSuccess = true;
      bool revokeSuccess = true;
      int penaltyAmount = 0;
      String? warningMessage;
      
      if (allSuccess) {
        // 4-1. 사용된 쿠폰 복구
        final restoreSuccess = await _restoreDiscountCoupons(reservationId);
        
        // 4-2. 환불 정보 조회 (쿠폰 차감 계산용)
        int refundAmount = 0;
        String refundUnit = 'credit';
        
        try {
          // v2_priced_TS에서 예약 정보 조회
          final pricedTsData = await ApiService.getData(
            table: 'v2_priced_TS',
            where: [
              {'field': 'reservation_id', 'operator': '=', 'value': reservationId},
            ],
            limit: 1,
          );
          
          if (pricedTsData.isNotEmpty) {
            final reservation = pricedTsData.first;
            final billIdCheck = reservation['bill_id']?.toString() ?? '';
            final billMinIdCheck = reservation['bill_min_id']?.toString() ?? '';
            
            if (billIdCheck.isNotEmpty && billIdCheck != 'null') {
              // 금액 결제 - ts_paid_price 또는 금액 계산
              refundAmount = (reservation['ts_paid_price'] ?? 0).abs();
              refundUnit = 'credit';
              print('💰 금액 결제 환불 정보: ${refundAmount}원');
            } else if (billMinIdCheck.isNotEmpty && billMinIdCheck != 'null') {
              // 시간 결제 - ts_min 사용
              refundAmount = reservation['ts_min'] ?? 0;
              refundUnit = 'time';
              print('⏰ 시간 결제 환불 정보: ${refundAmount}분');
            }
          }
        } catch (e) {
          print('⚠️ 환불 정보 조회 실패: $e');
        }
        
        // 4-3. 발급된 쿠폰 취소 (실패해도 예약 취소는 계속 진행)
        final revokeResult = await _revokeIssuedCouponsWithPenalty(
          reservationId,
          refundAmount: refundAmount,
          refundUnit: refundUnit,
        );
        revokeSuccess = revokeResult['success'] == true;
        penaltyAmount = revokeResult['penalty_amount'] ?? 0;
        warningMessage = revokeResult['warning_message'];
        
        // 사용된 쿠폰 복구만 필수, 발급 쿠폰 취소는 선택적
        couponSuccess = restoreSuccess;
        if (!revokeSuccess) {
          print('⚠️ 발급 쿠폰 취소 실패 (예약 취소는 계속 진행)');
        }
        
        if (penaltyAmount > 0) {
          print('💰 발급 쿠폰 사용 패널티: ${penaltyAmount}원');
        }
        
        if (warningMessage != null) {
          print('⚠️ 경고 메시지: $warningMessage');
        }
      }
      
      final finalSuccess = allSuccess && couponSuccess;
      
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('타석 예약 취소 완료: ${finalSuccess ? "성공" : "실패"}');
      print('  - v2_priced_TS: 성공');
      print('  - v2_bills: ${billSuccess ? "성공" : "실패"}');
      print('  - v2_bill_times: ${billTimesSuccess ? "성공" : "실패"}');
      print('  - 쿠폰 처리: ${couponSuccess ? "성공" : "실패"}');
      print('    └─ 사용된 쿠폰 복구: ${couponSuccess ? "성공" : "실패"}');
      print('    └─ 발급된 쿠폰 취소: ${revokeSuccess ? "성공" : "실패"} (선택적)');
      if (penaltyAmount > 0) {
        print('    └─ 발급 쿠폰 사용 패널티: ${penaltyAmount}원');
      }
      print('═══════════════════════════════════════════════════════════');
      print('');
      
      return finalSuccess;
      
    } catch (e) {
      print('❌ 타석 예약 취소 오류: $e');
      return false;
    }
  }
  
  /// v2_priced_TS 상태 업데이트 및 회원권 ID 조회
  /// 반환: billId = 선불크레딧 contract_history_id, billMinId = 시간권 contract_history_id
  static Future<Map<String, dynamic>> _updatePricedTsStatus(String reservationId) async {
    try {
      print('');
      print('🔄 v2_priced_TS 상태 업데이트 시작');
      
      // 1. 현재 예약 정보 조회
      final currentData = await ApiService.getData(
        table: 'v2_priced_TS',
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': reservationId}
        ],
        limit: 1,
      );
      
      if (currentData.isEmpty) {
        print('❌ 예약 정보를 찾을 수 없습니다: $reservationId');
        return {'success': false};
      }
      
      final reservation = currentData.first;
      // v2_priced_ts.bill_id = 선불크레딧 회원권 ID (contract_history_id)
      // v2_priced_ts.bill_min_id = 시간권 회원권 ID (contract_history_id)
      final creditContractHistoryId = reservation['bill_id'];
      final timeContractHistoryId = reservation['bill_min_id'];
      
      print('현재 예약 상태: ${reservation['ts_status']}');
      print('선불크레딧 회원권 ID (bill_id): $creditContractHistoryId');
      print('시간권 회원권 ID (bill_min_id): $timeContractHistoryId');
      
      // 이미 취소된 예약인지 확인
      if (reservation['ts_status'] == '예약취소') {
        print('⚠️ 이미 취소된 예약입니다');
        return {'success': true, 'billId': creditContractHistoryId, 'billMinId': timeContractHistoryId};
      }
      
      // 2. 상태를 '예약취소'로 업데이트
      final updateResult = await ApiService.updateData(
        table: 'v2_priced_TS',
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': reservationId}
        ],
        data: {
          'ts_status': '예약취소',
          'time_stamp': DateTime.now().toIso8601String(),
        },
      );
      
      final updateSuccess = updateResult['success'] == true;
      
      if (updateSuccess) {
        print('✅ v2_priced_TS 상태 업데이트 성공');
        return {
          'success': true,
          'billId': creditContractHistoryId,  // 선불크레딧 회원권 ID
          'billMinId': timeContractHistoryId,  // 시간권 회원권 ID
        };
      } else {
        print('❌ v2_priced_TS 상태 업데이트 실패');
        return {'success': false};
      }
      
    } catch (e) {
      print('❌ v2_priced_TS 업데이트 오류: $e');
      return {'success': false};
    }
  }
  
  /// 취소 정책 조회 및 적용
  static Future<Map<String, dynamic>> _getCancellationPolicy(String table, DateTime reservationStartTime) async {
    try {
      print('');
      print('🔍 취소 정책 조회 시작 ($table)');
      
      // 1. 해당 테이블의 취소 정책 조회 (apply_sequence 순으로 정렬)
      final policies = await ApiService.getData(
        table: 'v2_cancellation_policy',
        where: [
          {'field': 'db_table', 'operator': '=', 'value': table}
        ],
        orderBy: [
          {'field': 'apply_sequence', 'direction': 'ASC'}
        ],
      );
      
      if (policies.isEmpty) {
        print('❌ 취소 정책을 찾을 수 없습니다: $table');
        return {'canCancel': true, 'penaltyPercent': 0}; // 정책이 없으면 무료 취소
      }
      
      // 2. 현재 시간과 예약 시작 시간의 차이를 분 단위로 계산
      final now = DateTime.now();
      final timeDifferenceInMinutes = reservationStartTime.difference(now).inMinutes;
      
      print('현재 시간: $now');
      print('예약 시작 시간: $reservationStartTime');
      print('시간 차이: ${timeDifferenceInMinutes}분');
      
      // 3. 현재 시간이 예약 시작 시간을 지났다면 apply_sequence 1번 적용
      if (timeDifferenceInMinutes < 0) {
        print('⚠️ 예약 시작 시간이 지났습니다. apply_sequence 1번 적용');
        final firstPolicy = policies.firstWhere(
          (policy) => int.parse(policy['apply_sequence'].toString()) == 1,
          orElse: () => policies.first,
        );
        final penaltyPercent = int.parse(firstPolicy['penalty_percent'].toString());
        print('✅ 적용할 정책: apply_sequence 1번, ${penaltyPercent}% 페널티');
        return {
          'canCancel': true,
          'penaltyPercent': penaltyPercent,
          'policyFound': true,
        };
      }
      
      // 4. apply_sequence 순으로 정책 적용
      for (final policy in policies) {
        final minBeforeUse = int.parse(policy['_min_before_use'].toString());
        final penaltyPercent = int.parse(policy['penalty_percent'].toString());
        final sequence = int.parse(policy['apply_sequence'].toString());
        
        print('정책 확인 - sequence: $sequence, min_before_use: $minBeforeUse, penalty: $penaltyPercent%');
        
        if (timeDifferenceInMinutes <= minBeforeUse) {
          print('✅ 적용할 정책 발견: ${penaltyPercent}% 페널티');
          return {
            'canCancel': true,
            'penaltyPercent': penaltyPercent,
            'policyFound': true,
          };
        }
      }
      
      // 5. 어떤 정책에도 해당하지 않으면 무료 취소 가능
      print('✅ 무료 취소 가능 기간');
      return {'canCancel': true, 'penaltyPercent': 0, 'policyFound': false};
      
    } catch (e) {
      print('❌ 취소 정책 조회 오류: $e');
      return {'canCancel': false, 'penaltyPercent': 0};
    }
  }

  /// v2_bills 취소 처리 (선불크레딧 환불)
  /// [contractHistoryId] 회원권 ID (v2_priced_ts.bill_id에 저장된 값)
  /// [reservationId] 취소할 예약의 reservation_id
  /// 
  /// 구조: contract_history_id (회원권) → 여러 bill_id (거래 레코드)
  static Future<bool> _cancelBillsRecord(String contractHistoryId, DateTime reservationStartTime, {int? programPenaltyPercent, String? reservationId}) async {
    try {
      print('');
      print('🔄 v2_bills 취소 처리 시작 (선불크레딧)');
      print('  - contract_history_id (회원권): $contractHistoryId');
      print('  - reservation_id (예약): $reservationId');
      
      // 0. 취소 정책 조회 (프로그램 페널티가 있으면 우선 적용)
      int penaltyPercent;
      if (programPenaltyPercent != null) {
        penaltyPercent = programPenaltyPercent;
        print('프로그램 통합 페널티 적용: ${penaltyPercent}%');
      } else {
        final policy = await _getCancellationPolicy('v2_bills', reservationStartTime);
        if (!policy['canCancel']) {
          print('❌ 취소가 불가능한 상태입니다');
          return false;
        }
        penaltyPercent = policy['penaltyPercent'] as int;
      }
      final isPenaltyApplicable = penaltyPercent > 0;
      
      print('적용 페널티: ${penaltyPercent}%');
      
      // 1. 취소 대상 레코드 조회 - reservation_id로 조회 (v2_priced_ts.bill_id는 실제로 contract_history_id)
      List<Map<String, dynamic>> targetBillData = [];
      
      if (reservationId != null && reservationId.isNotEmpty) {
        // reservation_id로 실제 취소 대상 조회
        targetBillData = await ApiService.getData(
          table: 'v2_bills',
          where: [
            {'field': 'reservation_id', 'operator': '=', 'value': reservationId}
          ],
          limit: 1,
        );
        print('reservation_id로 조회 결과: ${targetBillData.length}개');
      }
      
      if (targetBillData.isEmpty) {
        print('❌ 취소 대상 v2_bills 레코드를 찾을 수 없습니다');
        print('  - reservation_id: $reservationId');
        return false;
      }
      
      final targetBill = targetBillData.first;
      final targetContractHistoryId = targetBill['contract_history_id'];  // 실제 조회된 회원권 ID
      final targetBillId = targetBill['bill_id'];  // 실제 취소 대상 거래 ID
      
      print('취소 대상 bill_id (거래ID): $targetBillId');
      print('취소 대상 contract_history_id (회원권ID): $targetContractHistoryId');
      
      // 2. 동일 contract_history_id에서 해당 bill_id 이상인 모든 레코드 조회
      final affectedBills = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': targetContractHistoryId},
          {'field': 'bill_id', 'operator': '>=', 'value': targetBillId},
        ],
        orderBy: [
          {'field': 'bill_id', 'direction': 'ASC'}
        ],
      );
      
      print('영향받는 레코드 수: ${affectedBills.length}개');
      
      if (affectedBills.isEmpty) {
        print('❌ 영향받는 레코드가 없습니다');
        return false;
      }
      
      // 3. 첫 번째 레코드 (취소 대상) 처리
      final cancelTarget = affectedBills.first;
      final originalBeforeBalance = cancelTarget['bill_balance_before'];
      final originalNetAmt = cancelTarget['bill_netamt'] ?? 0;
      
      print('취소 대상 처리: bill_id ${cancelTarget['bill_id']}');
      print('  원래 before_balance: $originalBeforeBalance');
      print('  원래 net_amt: $originalNetAmt');
      
      Map<String, dynamic> updateData = {
        'bill_status': '예약취소',
      };
      
      if (isPenaltyApplicable) {
        // 페널티 적용: 원래 금액의 페널티 퍼센트만큼 차감
        final penaltyAmount = (originalNetAmt.abs() * penaltyPercent / 100).round();
        final newAfterBalance = originalBeforeBalance - penaltyAmount;
        
        print('  원래 금액: $originalNetAmt');
        print('  페널티 금액: $penaltyAmount');
        print('  새로운 after_balance: $newAfterBalance');
        
        updateData.addAll({
          'bill_totalamt': -penaltyAmount,
          'bill_deduction': 0,
          'bill_netamt': -penaltyAmount,
          'bill_balance_after': newAfterBalance,
        });
      } else {
        // 무료 취소: 원래 로직 적용
        updateData.addAll({
          'bill_totalamt': 0,
          'bill_deduction': 0,
          'bill_netamt': 0,
          'bill_balance_after': originalBeforeBalance,
        });
      }
      
      // 취소 대상 업데이트
      final cancelResult = await ApiService.updateData(
        table: 'v2_bills',
        where: [
          {'field': 'bill_id', 'operator': '=', 'value': cancelTarget['bill_id']}
        ],
        data: updateData,
      );
      
      final cancelSuccess = cancelResult['success'] == true;
      
      if (!cancelSuccess) {
        print('❌ 취소 대상 업데이트 실패');
        return false;
      }
      
      print('✅ 취소 대상 업데이트 완료');
      
      // 4. 나머지 레코드들의 잔액 재계산
      if (affectedBills.length > 1) {
        print('후속 레코드 잔액 재계산 시작');
        
        for (int i = 1; i < affectedBills.length; i++) {
          final currentBill = affectedBills[i];
          final previousBill = affectedBills[i - 1];
          
          // 이전 레코드의 after_balance를 현재 레코드의 before_balance로 설정
          final newBeforeBalance = i == 1 
            ? (isPenaltyApplicable 
                ? originalBeforeBalance - (originalNetAmt.abs() * penaltyPercent / 100).round()
                : originalBeforeBalance)  // 첫 번째 후속 레코드는 취소된 레코드의 after_balance 사용
            : previousBill['bill_balance_after'];
          
          final netAmt = currentBill['bill_netamt'] ?? 0;
          final newAfterBalance = newBeforeBalance + netAmt;
          
          print('  레코드 ${i + 1}: bill_id ${currentBill['bill_id']}');
          print('    before: ${currentBill['bill_balance_before']} → $newBeforeBalance');
          print('    net_amt: $netAmt');
          print('    after: ${currentBill['bill_balance_after']} → $newAfterBalance');
          
          final updateResult = await ApiService.updateData(
            table: 'v2_bills',
            where: [
              {'field': 'bill_id', 'operator': '=', 'value': currentBill['bill_id']}
            ],
            data: {
              'bill_balance_before': newBeforeBalance,
              'bill_balance_after': newAfterBalance,
            },
          );
          
          final updateSuccess = updateResult['success'] == true;
          
          if (!updateSuccess) {
            print('❌ 레코드 ${currentBill['bill_id']} 업데이트 실패');
            return false;
          }
          
          // 다음 반복을 위해 현재 레코드의 after_balance 업데이트
          affectedBills[i]['bill_balance_after'] = newAfterBalance;
        }
        
        print('✅ 모든 후속 레코드 잔액 재계산 완료');
      }
      
      print('✅ v2_bills 취소 처리 완료');
      return true;
      
    } catch (e) {
      print('❌ v2_bills 취소 처리 오류: $e');
      return false;
    }
  }
  
  /// 발급된 쿠폰 취소 미리보기 (실제 취소하지 않고 조회만)
  /// 사용된 쿠폰의 경우 reservation_id_used로 v2_priced_ts에서 할인액 조회
  static Future<Map<String, dynamic>> previewIssuedCoupons(String reservationId) async {
    try {
      print('');
      print('🔍 발급된 쿠폰 취소 미리보기 시작 (reservation_id: $reservationId)');
      
      final branchId = ApiService.getCurrentBranchId() ?? '';
      if (branchId.isEmpty) {
        print('❌ branch_id를 찾을 수 없습니다');
        return {'success': false, 'coupons': [], 'message': 'branch_id를 찾을 수 없습니다', 'total_used_discount_amt': 0, 'total_used_discount_min': 0};
      }
      
      // 해당 예약으로 발급된 쿠폰 조회
      List<Map<String, dynamic>> issuedCoupons = [];
      try {
        print('🔍 발급 쿠폰 조회 조건:');
        print('  - branch_id: $branchId');
        print('  - reservation_id_issued: $reservationId');
        
        issuedCoupons = await ApiService.getData(
          table: 'v2_discount_coupon',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'reservation_id_issued', 'operator': '=', 'value': reservationId},
          ],
        );
        
        print('🔍 전체 조회 결과: ${issuedCoupons.length}개');
        for (final coupon in issuedCoupons) {
          print('  - coupon_id: ${coupon['coupon_id']}, status: ${coupon['coupon_status']}');
        }
        
        // 취소되지 않은 쿠폰만 필터링
        issuedCoupons = issuedCoupons.where((coupon) => coupon['coupon_status'] != '취소').toList();
        print('🔍 필터링 후 결과: ${issuedCoupons.length}개');
        
      } catch (apiError) {
        print('⚠️ 발급 쿠폰 조회 실패 (API 오류): $apiError');
        // API 오류 시에도 빈 리스트로 처리하여 계속 진행
        issuedCoupons = [];
      }
      
      print('취소 예정 발급 쿠폰 수: ${issuedCoupons.length}개');
      
      List<Map<String, dynamic>> couponInfo = [];
      int totalUsedDiscountAmt = 0;  // 사용된 쿠폰의 총 금액 할인
      int totalUsedDiscountMin = 0;  // 사용된 쿠폰의 총 시간 할인
      
      for (final coupon in issuedCoupons) {
        // 쿠폰 타입별 할인 정보 분석
        final couponType = coupon['coupon_type'] ?? '';
        final discountRatio = coupon['discount_ratio'] ?? 0;
        final discountAmt = coupon['discount_amt'] ?? 0;
        final discountMin = coupon['discount_min'] ?? 0;
        final description = coupon['coupon_description'] ?? '';
        final couponStatus = coupon['coupon_status'] ?? '';
        final reservationIdUsed = coupon['reservation_id_used']?.toString() ?? '';
        
        String discountInfo = '';
        if (couponType == '정률권' && discountRatio > 0) {
          discountInfo = '${discountRatio}% 할인';
        } else if (couponType == '정액권' && discountAmt > 0) {
          discountInfo = '${NumberFormat('#,###').format(discountAmt)}원 할인';
        } else if (couponType == '시간권' && discountMin > 0) {
          discountInfo = '${discountMin}분 할인';
        } else if (couponType == '레슨권' && discountMin > 0) {
          discountInfo = '${discountMin}분 할인';
        } else {
          discountInfo = '할인 정보 없음';
        }
        
        // 쿠폰 이름 결정 (description 우선, 없으면 쿠폰 타입)
        String couponName = '';
        if (description.isNotEmpty) {
          couponName = description;
        } else if (couponType.isNotEmpty) {
          couponName = couponType;
        } else {
          couponName = '할인쿠폰';
        }
        
        // 사용된 쿠폰인 경우 v2_discount_coupon.applied_discount_amt/min에서 조회
        int usedCouponDiscount = 0;  // 금액 할인
        int usedDiscountMinConverted = 0;  // 환산된 분
        
        if (couponStatus == '사용' && reservationIdUsed.isNotEmpty) {
          print('🔍 사용된 쿠폰 할인액 조회: coupon_id ${coupon['coupon_id']}');
          
          final appliedAmt = coupon['applied_discount_amt'];
          final appliedMin = coupon['applied_discount_min'];
          
          usedCouponDiscount = appliedAmt is int ? appliedAmt : int.tryParse(appliedAmt?.toString() ?? '0') ?? 0;
          usedDiscountMinConverted = appliedMin is int ? appliedMin : int.tryParse(appliedMin?.toString() ?? '0') ?? 0;
          
          print('  - 할인 금액: ${usedCouponDiscount}원');
          print('  - 환산 분수: ${usedDiscountMinConverted}분');
          
          totalUsedDiscountAmt += usedCouponDiscount;
          totalUsedDiscountMin += usedDiscountMinConverted;
        }
        
        // 상태 표시 (사용 상태인 경우 reservation_id 포함)
        String statusDisplay = couponStatus;
        if (couponStatus == '사용' && reservationIdUsed.isNotEmpty) {
          statusDisplay = '사용($reservationIdUsed)';
        }
        
        couponInfo.add({
          'coupon_id': coupon['coupon_id'],
          'coupon_code': coupon['coupon_code'],
          'coupon_name': couponName,
          'coupon_type': couponType,
          'discount_info': discountInfo,
          'discount_ratio': discountRatio,
          'discount_amt': discountAmt,
          'discount_min': discountMin,
          'expiry_date': coupon['coupon_expiry_date'],
          'description': description,
          'status': statusDisplay,  // 사용(251211_1_1800) 형식
          'reservation_id_used': reservationIdUsed,
          'used_coupon_discount': usedCouponDiscount,      // 실제 사용된 금액 할인
          'used_discount_min_converted': usedDiscountMinConverted,  // 금액을 분으로 환산한 값
        });
      }
      
      print('✅ 발급된 쿠폰 취소 미리보기 완료');
      print('💰 사용된 쿠폰 총 금액 할인: ${totalUsedDiscountAmt}원');
      print('⏰ 사용된 쿠폰 총 시간 할인: ${totalUsedDiscountMin}분');
      
      return {
        'success': true,
        'coupons': couponInfo,
        'message': issuedCoupons.isEmpty ? '취소할 발급 쿠폰이 없습니다' : '${issuedCoupons.length}개의 발급 쿠폰이 취소됩니다',
        'total_used_discount_amt': totalUsedDiscountAmt,  // 환불금액에서 차감할 금액
        'total_used_discount_min': totalUsedDiscountMin,  // 환불시간에서 차감할 시간
      };
      
    } catch (e) {
      print('❌ 발급된 쿠폰 취소 미리보기 오류: $e');
      return {'success': false, 'coupons': [], 'message': '발급 쿠폰 정보를 조회할 수 없습니다', 'total_used_discount_amt': 0, 'total_used_discount_min': 0};
    }
  }

  /// 할인 쿠폰 복구 미리보기 (실제 복구하지 않고 조회만)
  static Future<Map<String, dynamic>> previewDiscountCoupons(String reservationId) async {
    try {
      print('');
      print('🔍 할인 쿠폰 복구 미리보기 시작 (reservation_id: $reservationId)');
      
      final branchId = ApiService.getCurrentBranchId() ?? '';
      if (branchId.isEmpty) {
        print('❌ branch_id를 찾을 수 없습니다');
        return {'success': false, 'coupons': [], 'message': 'branch_id를 찾을 수 없습니다'};
      }
      
      // 해당 예약에 사용된 쿠폰 조회
      final usedCoupons = await ApiService.getData(
        table: 'v2_discount_coupon',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'reservation_id_used', 'operator': '=', 'value': reservationId},
          {'field': 'coupon_status', 'operator': '=', 'value': '사용'},
        ],
      );
      
      print('복구 예정 쿠폰 수: ${usedCoupons.length}개');
      
      List<Map<String, dynamic>> couponInfo = [];
      for (final coupon in usedCoupons) {
        // 쿠폰 타입별 할인 정보 분석
        final couponType = coupon['coupon_type'] ?? '';
        final discountRatio = coupon['discount_ratio'] ?? 0;
        final discountAmt = coupon['discount_amt'] ?? 0;
        final discountMin = coupon['discount_min'] ?? 0;
        final description = coupon['coupon_description'] ?? '';
        
        String discountInfo = '';
        if (couponType == '정률권' && discountRatio > 0) {
          discountInfo = '${discountRatio}% 할인';
        } else if (couponType == '정액권' && discountAmt > 0) {
          discountInfo = '${NumberFormat('#,###').format(discountAmt)}원 할인';
        } else if (couponType == '시간권' && discountMin > 0) {
          discountInfo = '${discountMin}분 할인';
        } else if (couponType == '레슨권' && discountMin > 0) {
          discountInfo = '${discountMin}분 할인';
        } else {
          discountInfo = '할인 정보 없음';
        }
        
        // 쿠폰 이름 결정 (description 우선, 없으면 쿠폰 타입)
        String couponName = '';
        if (description.isNotEmpty) {
          couponName = description;
        } else if (couponType.isNotEmpty) {
          couponName = couponType;
        } else {
          couponName = '할인쿠폰';
        }
        
        couponInfo.add({
          'coupon_id': coupon['coupon_id'],
          'coupon_name': couponName,
          'coupon_type': couponType,
          'discount_info': discountInfo,
          'discount_ratio': discountRatio,
          'discount_amt': discountAmt,
          'discount_min': discountMin,
          'expiry_date': coupon['coupon_expiry_date'],
          'description': description,
        });
      }
      
      print('✅ 할인 쿠폰 복구 미리보기 완료');
      return {
        'success': true,
        'coupons': couponInfo,
        'message': usedCoupons.isEmpty ? '복구할 쿠폰이 없습니다' : '${usedCoupons.length}개의 쿠폰이 미사용 상태로 복구됩니다'
      };
      
    } catch (e) {
      print('❌ 할인 쿠폰 복구 미리보기 오류: $e');
      return {'success': false, 'coupons': [], 'message': '쿠폰 정보를 조회할 수 없습니다'};
    }
  }

  /// 발급된 쿠폰 취소 처리 및 v2_discount_coupon_misuse 테이블에 기록
  /// [refundAmount] 환불 예정 금액/시간 (쿠폰 차감 전)
  /// [refundUnit] 'credit' 또는 'time'
  static Future<Map<String, dynamic>> _revokeIssuedCouponsWithPenalty(
    String reservationId, {
    int refundAmount = 0,
    String refundUnit = 'credit',
  }) async {
    try {
      print('');
      print('🔄 발급된 쿠폰 취소 처리 시작 (reservation_id: $reservationId)');
      print('  환불 예정: $refundAmount${refundUnit == 'credit' ? '원' : '분'}');
      
      final branchId = ApiService.getCurrentBranchId() ?? '';
      if (branchId.isEmpty) {
        print('❌ branch_id를 찾을 수 없습니다');
        return {'success': false, 'penalty_amount': 0, 'warning_message': null};
      }
      
      // 1. 해당 예약으로 발급된 쿠폰 조회
      List<Map<String, dynamic>> issuedCoupons = [];
      try {
        print('🔍 발급 쿠폰 취소 조회 조건:');
        print('  - branch_id: $branchId');
        print('  - reservation_id_issued: $reservationId');
        
        issuedCoupons = await ApiService.getData(
          table: 'v2_discount_coupon',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'reservation_id_issued', 'operator': '=', 'value': reservationId},
          ],
        );
        
        print('🔍 전체 조회 결과: ${issuedCoupons.length}개');
        for (final coupon in issuedCoupons) {
          print('  - coupon_id: ${coupon['coupon_id']}, status: ${coupon['coupon_status']}');
        }
        
        // 취소되지 않은 쿠폰만 필터링
        issuedCoupons = issuedCoupons.where((coupon) => coupon['coupon_status'] != '취소').toList();
        print('🔍 필터링 후 결과: ${issuedCoupons.length}개');
        
      } catch (apiError) {
        print('⚠️ 발급 쿠폰 조회 실패 (API 오류): $apiError');
        issuedCoupons = [];
      }
      
      print('취소 대상 발급 쿠폰 수: ${issuedCoupons.length}개');
      
      if (issuedCoupons.isEmpty) {
        print('✅ 취소할 발급 쿠폰이 없습니다');
        return {'success': true, 'penalty_amount': 0, 'warning_message': null};
      }
      
      // 2. 총 사용된 쿠폰 할인액 계산
      int totalUsedDiscountAmt = 0;
      int totalUsedDiscountMin = 0;
      int remainingRefund = refundAmount;  // 차감 가능한 남은 환불액
      String? warningMessage;
      
      // 3. 각 발급 쿠폰 처리 및 misuse 테이블 기록
      for (final coupon in issuedCoupons) {
        final couponId = coupon['coupon_id'];
        final couponStatus = coupon['coupon_status'] ?? '';
        final couponType = coupon['coupon_type'] ?? '';
        final memberId = coupon['member_id'];
        final memberName = coupon['member_name'] ?? '';
        final couponCode = coupon['coupon_code'] ?? '';
        final discountRatio = coupon['discount_ratio'] ?? 0;
        final discountAmt = coupon['discount_amt'] ?? 0;
        final discountMin = coupon['discount_min'] ?? 0;
        final reservationIdUsed = coupon['reservation_id_used']?.toString() ?? '';
        
        print('발급 쿠폰 처리 중: coupon_id $couponId (상태: $couponStatus)');
        
        // 사용된 쿠폰의 경우 v2_discount_coupon.applied_discount_amt/min에서 조회
        int usedCouponDiscount = 0;
        int usedDiscountMinConverted = 0;
        int recoveredAmt = 0;
        int recoveredMin = 0;
        int unrecoveredAmt = 0;
        int unrecoveredMin = 0;
        String recoveryStatus = '미사용쿠폰';
        
        if (couponStatus == '사용' && reservationIdUsed.isNotEmpty) {
          final appliedAmt = coupon['applied_discount_amt'];
          final appliedMin = coupon['applied_discount_min'];
          
          usedCouponDiscount = appliedAmt is int ? appliedAmt : int.tryParse(appliedAmt?.toString() ?? '0') ?? 0;
          usedDiscountMinConverted = appliedMin is int ? appliedMin : int.tryParse(appliedMin?.toString() ?? '0') ?? 0;
          
          print('  - 할인 금액: ${usedCouponDiscount}원');
          print('  - 환산 분수: ${usedDiscountMinConverted}분');
          
          totalUsedDiscountAmt += usedCouponDiscount;
          totalUsedDiscountMin += usedDiscountMinConverted;
          
          // 회수 계산 (환불 유형에 따라)
          if (refundUnit == 'credit' && usedCouponDiscount > 0) {
            // 금액 결제 취소 → 금액으로 회수
            if (remainingRefund >= usedCouponDiscount) {
              recoveredAmt = usedCouponDiscount;
              remainingRefund -= usedCouponDiscount;
              recoveryStatus = '완전회수';
              print('    ✅ 완전 회수: ${recoveredAmt}원');
            } else {
              recoveredAmt = remainingRefund;
              unrecoveredAmt = usedCouponDiscount - remainingRefund;
              remainingRefund = 0;
              recoveryStatus = recoveredAmt > 0 ? '부분회수' : '미회수';
              print('    ⚠️ ${recoveryStatus}: 회수 ${recoveredAmt}원, 미회수 ${unrecoveredAmt}원');
            }
          } else if (refundUnit == 'time' && usedDiscountMinConverted > 0) {
            // 시간권 결제 취소 → 환산된 분으로 회수
            if (remainingRefund >= usedDiscountMinConverted) {
              recoveredMin = usedDiscountMinConverted;
              remainingRefund -= usedDiscountMinConverted;
              recoveryStatus = '완전회수';
              print('    ✅ 완전 회수: ${recoveredMin}분');
            } else {
              recoveredMin = remainingRefund;
              unrecoveredMin = usedDiscountMinConverted - remainingRefund;
              remainingRefund = 0;
              recoveryStatus = recoveredMin > 0 ? '부분회수' : '미회수';
              print('    ⚠️ ${recoveryStatus}: 회수 ${recoveredMin}분, 미회수 ${unrecoveredMin}분');
            }
          }
        }
        
        // v2_discount_coupon_misuse 테이블에 기록
        try {
          final misuseData = {
            'branch_id': branchId,
            'member_id': memberId,
            'member_name': memberName,
            'coupon_id': couponId,
            'coupon_code': couponCode,
            'coupon_type': couponType,
            'discount_ratio': discountRatio,
            'discount_amt': discountAmt,
            'discount_min': discountMin,
            'reservation_id_issued': reservationId,
            'reservation_id_used': reservationIdUsed.isEmpty ? null : reservationIdUsed,
            'coupon_status_before': couponStatus,
            'used_coupon_discount': usedCouponDiscount,
            'used_discount_min': usedDiscountMinConverted,  // 금액을 분으로 환산한 값
            'recovered_amt': recoveredAmt,
            'recovered_min': recoveredMin,
            'unrecovered_amt': unrecoveredAmt,
            'unrecovered_min': unrecoveredMin,
            'recovery_status': recoveryStatus,
            'description': '예약 취소로 인한 쿠폰 처리',
            'created_at': DateTime.now().toIso8601String(),
          };
          
          await ApiService.addData(
            table: 'v2_discount_coupon_misuse',
            data: misuseData,
          );
          
          print('  📝 misuse 테이블 기록 완료: $recoveryStatus');
        } catch (e) {
          print('  ⚠️ misuse 테이블 기록 실패: $e');
          // 실패해도 쿠폰 취소는 계속 진행
        }
        
        // 쿠폰 상태를 취소로 변경
        final updateResult = await ApiService.updateData(
          table: 'v2_discount_coupon',
          where: [
            {'field': 'coupon_id', 'operator': '=', 'value': couponId}
          ],
          data: {
            'coupon_status': '취소',
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
        
        final updateSuccess = updateResult['success'] == true;
        
        if (!updateSuccess) {
          print('❌ 발급 쿠폰 취소 실패: coupon_id $couponId');
          return {'success': false, 'penalty_amount': 0, 'warning_message': null};
        }
        
        print('✅ 발급 쿠폰 취소 성공: coupon_id $couponId');
        
        // 미회수분이 있으면 경고 메시지 설정
        if (unrecoveredAmt > 0 || unrecoveredMin > 0) {
          warningMessage = '예약취소 할인쿠폰 미반환분 발생하였습니다.\n추후 할인쿠폰 발행이 제한될 수 있습니다.';
        }
      }
      
      print('✅ 모든 발급 쿠폰 취소 완료');
      print('💰 총 사용된 쿠폰 금액 할인: ${totalUsedDiscountAmt}원');
      print('⏰ 총 사용된 쿠폰 시간 할인: ${totalUsedDiscountMin}분');
      
      return {
        'success': true, 
        'penalty_amount': totalUsedDiscountAmt,
        'penalty_time': totalUsedDiscountMin,
        'warning_message': warningMessage,
      };
      
    } catch (e) {
      print('❌ 발급 쿠폰 취소 오류: $e');
      return {'success': false, 'penalty_amount': 0, 'warning_message': null};
    }
  }

  /// 할인 쿠폰 복구 처리
  static Future<bool> _restoreDiscountCoupons(String reservationId) async {
    try {
      print('');
      print('🔄 할인 쿠폰 복구 처리 시작 (reservation_id: $reservationId)');
      
      final branchId = ApiService.getCurrentBranchId() ?? '';
      if (branchId.isEmpty) {
        print('❌ branch_id를 찾을 수 없습니다');
        return false;
      }
      
      // 1. 해당 예약에 사용된 쿠폰 조회
      final usedCoupons = await ApiService.getData(
        table: 'v2_discount_coupon',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'reservation_id_used', 'operator': '=', 'value': reservationId},
          {'field': 'coupon_status', 'operator': '=', 'value': '사용'},
        ],
      );
      
      print('복구 대상 쿠폰 수: ${usedCoupons.length}개');
      
      if (usedCoupons.isEmpty) {
        print('✅ 복구할 쿠폰이 없습니다');
        return true;
      }
      
      // 2. 각 쿠폰을 미사용 상태로 복구
      for (final coupon in usedCoupons) {
        final couponId = coupon['coupon_id'];
        
        print('쿠폰 복구 중: coupon_id $couponId');
        
        final updateResult = await ApiService.updateData(
          table: 'v2_discount_coupon',
          where: [
            {'field': 'coupon_id', 'operator': '=', 'value': couponId}
          ],
          data: {
            'coupon_status': '미사용',
            'coupon_use_timestamp': null,
            'LS_id_used': null,
            'reservation_id_used': null,
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
        
        final updateSuccess = updateResult['success'] == true;
        
        if (!updateSuccess) {
          print('❌ 쿠폰 복구 실패: coupon_id $couponId');
          return false;
        }
        
        print('✅ 쿠폰 복구 성공: coupon_id $couponId');
      }
      
      print('✅ 모든 할인 쿠폰 복구 완료');
      return true;
      
    } catch (e) {
      print('❌ 할인 쿠폰 복구 오류: $e');
      return false;
    }
  }

  /// v2_bill_times 취소 처리
  static Future<bool> _cancelBillTimesRecord(String billMinId, DateTime reservationStartTime, {int? programPenaltyPercent}) async {
    try {
      print('');
      print('🔄 v2_bill_times 취소 처리 시작 (bill_min_id: $billMinId)');
      
      // 0. 취소 정책 조회 (프로그램 페널티가 있으면 우선 적용)
      int penaltyPercent;
      if (programPenaltyPercent != null) {
        penaltyPercent = programPenaltyPercent;
        print('프로그램 통합 페널티 적용: ${penaltyPercent}%');
      } else {
        final policy = await _getCancellationPolicy('v2_bill_times', reservationStartTime);
        if (!policy['canCancel']) {
          print('❌ 취소가 불가능한 상태입니다');
          return false;
        }
        penaltyPercent = policy['penaltyPercent'] as int;
      }
      final isPenaltyApplicable = penaltyPercent > 0;
      
      print('적용 페널티: ${penaltyPercent}%');
      
      // 1. 취소 대상 bill_min_id 정보 조회
      final targetBillData = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'bill_min_id', 'operator': '=', 'value': int.parse(billMinId)}
        ],
        limit: 1,
      );
      
      if (targetBillData.isEmpty) {
        print('❌ 취소 대상 bill_min_id를 찾을 수 없습니다: $billMinId');
        return false;
      }
      
      final targetBill = targetBillData.first;
      final contractHistoryId = targetBill['contract_history_id'];
      
      print('취소 대상 계약: $contractHistoryId');
      
      // 2. 동일 contract_history_id에서 해당 bill_min_id 이상인 모든 레코드 조회
      final affectedBills = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_min_id', 'operator': '>=', 'value': int.parse(billMinId)},
        ],
        orderBy: [
          {'field': 'bill_min_id', 'direction': 'ASC'}
        ],
      );
      
      print('영향받는 레코드 수: ${affectedBills.length}개');
      
      if (affectedBills.isEmpty) {
        print('❌ 영향받는 레코드가 없습니다');
        return false;
      }
      
      // 3. 첫 번째 레코드 (취소 대상) 처리
      final cancelTarget = affectedBills.first;
      final originalBeforeBalance = cancelTarget['bill_balance_min_before'] ?? 0;
      final originalBillMin = cancelTarget['bill_min'] ?? 0;
      
      print('취소 대상 처리: bill_min_id ${cancelTarget['bill_min_id']}');
      print('  원래 before_balance: $originalBeforeBalance');
      print('  원래 bill_min: $originalBillMin');
      
      // 빈 슬롯 처리: before_balance나 bill_min이 null이면 취소 처리 스킵
      if (originalBeforeBalance == null || originalBeforeBalance == 0) {
        print('⚠️ 빈 슬롯 또는 잔액이 0인 레코드 - 단순 상태 변경만 수행');
        
        final updateResult = await ApiService.updateData(
          table: 'v2_bill_times',
          where: [
            {'field': 'bill_min_id', 'operator': '=', 'value': cancelTarget['bill_min_id']}
          ],
          data: {
            'bill_status': '예약취소',
          },
        );
        
        final updateSuccess = updateResult['success'] == true;
        if (updateSuccess) {
          print('✅ 빈 슬롯 상태 업데이트 완료');
        } else {
          print('❌ 빈 슬롯 상태 업데이트 실패');
          return false;
        }
        
        print('✅ v2_bill_times 취소 처리 완료 (빈 슬롯)');
        return true;
      }
      
      Map<String, dynamic> updateData = {
        'bill_status': '예약취소',
      };
      
      if (isPenaltyApplicable) {
        // 페널티 적용: 원래 시간의 페널티 퍼센트만큼 차감
        final penaltyTime = (originalBillMin * penaltyPercent / 100).round();
        final newAfterBalance = originalBeforeBalance - penaltyTime;
        
        print('  페널티 시간: $penaltyTime분');
        print('  새로운 after_balance: $newAfterBalance');
        
        updateData.addAll({
          'bill_total_min': penaltyTime,
          'bill_discount_min': 0,
          'bill_min': penaltyTime,
          'bill_balance_min_after': newAfterBalance,
        });
      } else {
        // 무료 취소: 원래 로직 적용
        updateData.addAll({
          'bill_total_min': 0,
          'bill_discount_min': 0,
          'bill_min': 0,
          'bill_balance_min_after': originalBeforeBalance,
        });
      }
      
      // 취소 대상 업데이트
      final cancelResult = await ApiService.updateData(
        table: 'v2_bill_times',
        where: [
          {'field': 'bill_min_id', 'operator': '=', 'value': cancelTarget['bill_min_id']}
        ],
        data: updateData,
      );
      
      final cancelSuccess = cancelResult['success'] == true;
      
      if (!cancelSuccess) {
        print('❌ 취소 대상 업데이트 실패');
        return false;
      }
      
      print('✅ 취소 대상 업데이트 완료');
      
      // 4. 나머지 레코드들의 잔액 재계산
      if (affectedBills.length > 1) {
        print('후속 레코드 잔액 재계산 시작');
        
        for (int i = 1; i < affectedBills.length; i++) {
          final currentBill = affectedBills[i];
          final previousBill = affectedBills[i - 1];
          
          // 이전 레코드의 after_balance를 현재 레코드의 before_balance로 설정
          final newBeforeBalance = i == 1 
            ? (isPenaltyApplicable 
                ? originalBeforeBalance - (originalBillMin * penaltyPercent / 100).round()
                : originalBeforeBalance)  // 첫 번째 후속 레코드는 취소된 레코드의 after_balance 사용
            : previousBill['bill_balance_min_after'];
          
          final billMin = currentBill['bill_min'] ?? 0;
          final newAfterBalance = newBeforeBalance - billMin; // 시간권은 차감이므로 빼기
          
          print('  레코드 ${i + 1}: bill_min_id ${currentBill['bill_min_id']}');
          print('    before: ${currentBill['bill_balance_min_before']} → $newBeforeBalance');
          print('    bill_min: $billMin');
          print('    after: ${currentBill['bill_balance_min_after']} → $newAfterBalance');
          
          final updateResult = await ApiService.updateData(
            table: 'v2_bill_times',
            where: [
              {'field': 'bill_min_id', 'operator': '=', 'value': currentBill['bill_min_id']}
            ],
            data: {
              'bill_balance_min_before': newBeforeBalance,
              'bill_balance_min_after': newAfterBalance,
            },
          );
          
          final updateSuccess = updateResult['success'] == true;
          
          if (!updateSuccess) {
            print('❌ 레코드 ${currentBill['bill_min_id']} 업데이트 실패');
            return false;
          }
          
          // 다음 반복을 위해 현재 레코드의 after_balance 업데이트
          affectedBills[i]['bill_balance_min_after'] = newAfterBalance;
        }
        
        print('✅ 모든 후속 레코드 잔액 재계산 완료');
      }
      
      print('✅ v2_bill_times 취소 처리 완료');
      return true;
      
    } catch (e) {
      print('❌ v2_bill_times 취소 처리 오류: $e');
      return false;
    }
  }
}