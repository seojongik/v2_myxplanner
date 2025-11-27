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
      
      final billId = pricedTsResult['billId'];
      final billMinId = pricedTsResult['billMinId'];
      
      print('조회된 bill_id: $billId');
      print('조회된 bill_min_id: $billMinId');
      
      bool billSuccess = true;
      bool billTimesSuccess = true;
      
      // 2. bill_id가 있으면 v2_bills 취소 처리
      if (billId != null && billId.toString().isNotEmpty && billId.toString() != 'null') {
        billSuccess = await _cancelBillsRecord(billId.toString(), reservationStartTime, programPenaltyPercent: programPenaltyPercent);
      }
      
      // 3. bill_min_id가 있으면 v2_bill_times 취소 처리
      if (billMinId != null && billMinId.toString().isNotEmpty && billMinId.toString() != 'null') {
        billTimesSuccess = await _cancelBillTimesRecord(billMinId.toString(), reservationStartTime, programPenaltyPercent: programPenaltyPercent);
      }
      
      final allSuccess = billSuccess && billTimesSuccess;
      
      // 4. 결제 취소가 성공한 경우에만 할인 쿠폰 처리
      bool couponSuccess = true;
      bool revokeSuccess = true;
      int penaltyAmount = 0;
      if (allSuccess) {
        // 4-1. 사용된 쿠폰 복구
        final restoreSuccess = await _restoreDiscountCoupons(reservationId);
        // 4-2. 발급된 쿠폰 취소 (실패해도 예약 취소는 계속 진행)
        final revokeResult = await _revokeIssuedCouponsWithPenalty(reservationId);
        revokeSuccess = revokeResult['success'] == true;
        penaltyAmount = revokeResult['penalty_amount'] ?? 0;
        
        // 사용된 쿠폰 복구만 필수, 발급 쿠폰 취소는 선택적
        couponSuccess = restoreSuccess;
        if (!revokeSuccess) {
          print('⚠️ 발급 쿠폰 취소 실패 (예약 취소는 계속 진행)');
        }
        
        if (penaltyAmount > 0) {
          print('💰 발급 쿠폰 사용 패널티: ${penaltyAmount}원');
          // TODO: 패널티 금액을 취소 처리에 반영 필요
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
  
  /// v2_priced_TS 상태 업데이트 및 bill_id, bill_min_id 조회
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
      final billId = reservation['bill_id'];
      final billMinId = reservation['bill_min_id'];
      
      print('현재 예약 상태: ${reservation['ts_status']}');
      print('bill_id: $billId');
      print('bill_min_id: $billMinId');
      
      // 이미 취소된 예약인지 확인
      if (reservation['ts_status'] == '예약취소') {
        print('⚠️ 이미 취소된 예약입니다');
        return {'success': true, 'billId': billId, 'billMinId': billMinId};
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
          'billId': billId,
          'billMinId': billMinId,
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

  /// v2_bills 취소 처리
  static Future<bool> _cancelBillsRecord(String billId, DateTime reservationStartTime, {int? programPenaltyPercent}) async {
    try {
      print('');
      print('🔄 v2_bills 취소 처리 시작 (bill_id: $billId)');
      
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
      
      // 1. 취소 대상 bill_id 정보 조회
      final targetBillData = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'bill_id', 'operator': '=', 'value': int.parse(billId)}
        ],
        limit: 1,
      );
      
      if (targetBillData.isEmpty) {
        print('❌ 취소 대상 bill_id를 찾을 수 없습니다: $billId');
        return false;
      }
      
      final targetBill = targetBillData.first;
      final contractHistoryId = targetBill['contract_history_id'];
      
      print('취소 대상 계약: $contractHistoryId');
      
      // 2. 동일 contract_history_id에서 해당 bill_id 이상인 모든 레코드 조회
      final affectedBills = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_id', 'operator': '>=', 'value': int.parse(billId)},
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
  static Future<Map<String, dynamic>> previewIssuedCoupons(String reservationId) async {
    try {
      print('');
      print('🔍 발급된 쿠폰 취소 미리보기 시작 (reservation_id: $reservationId)');
      
      final branchId = ApiService.getCurrentBranchId() ?? '';
      if (branchId.isEmpty) {
        print('❌ branch_id를 찾을 수 없습니다');
        return {'success': false, 'coupons': [], 'message': 'branch_id를 찾을 수 없습니다'};
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
      for (final coupon in issuedCoupons) {
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
          'status': coupon['coupon_status'],
        });
      }
      
      print('✅ 발급된 쿠폰 취소 미리보기 완료');
      return {
        'success': true,
        'coupons': couponInfo,
        'message': issuedCoupons.isEmpty ? '취소할 발급 쿠폰이 없습니다' : '${issuedCoupons.length}개의 발급 쿠폰이 취소됩니다'
      };
      
    } catch (e) {
      print('❌ 발급된 쿠폰 취소 미리보기 오류: $e');
      return {'success': false, 'coupons': [], 'message': '발급 쿠폰 정보를 조회할 수 없습니다'};
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

  /// 발급된 쿠폰 취소 처리 및 사용된 쿠폰 패널티 계산
  static Future<Map<String, dynamic>> _revokeIssuedCouponsWithPenalty(String reservationId) async {
    try {
      print('');
      print('🔄 발급된 쿠폰 취소 처리 시작 (reservation_id: $reservationId)');
      
      final branchId = ApiService.getCurrentBranchId() ?? '';
      if (branchId.isEmpty) {
        print('❌ branch_id를 찾을 수 없습니다');
        return {'success': false, 'penalty_amount': 0};
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
        // API 오류 시에도 빈 리스트로 처리하여 계속 진행
        issuedCoupons = [];
      }
      
      print('취소 대상 발급 쿠폰 수: ${issuedCoupons.length}개');
      
      if (issuedCoupons.isEmpty) {
        print('✅ 취소할 발급 쿠폰이 없습니다');
        return {'success': true, 'penalty_amount': 0};
      }
      
      // 2. 각 발급 쿠폰 분석 및 패널티 계산
      int totalPenaltyAmount = 0;
      
      for (final coupon in issuedCoupons) {
        final couponId = coupon['coupon_id'];
        final couponStatus = coupon['coupon_status'];
        final couponType = coupon['coupon_type'] ?? '';
        
        print('발급 쿠폰 처리 중: coupon_id $couponId (상태: $couponStatus)');
        
        // 사용된 쿠폰인 경우 패널티 계산
        if (couponStatus == '사용') {
          int penaltyAmount = 0;
          
          if (couponType == '정률권') {
            final discountRatio = coupon['discount_ratio'] ?? 0;
            print('  ⚠️ 정률권 쿠폰은 패널티 계산 복잡 (${discountRatio}%)');
            // 정률권은 원본 금액을 알아야 계산 가능하므로 일단 0
            penaltyAmount = 0;
          } else if (couponType == '정액권') {
            final discountAmt = coupon['discount_amt'] ?? 0;
            penaltyAmount = discountAmt;
            print('  💰 정액권 패널티 추가: ${penaltyAmount}원');
          } else if (couponType == '시간권') {
            final discountMin = coupon['discount_min'] ?? 0;
            print('  ⏰ 시간권 쿠폰은 금액 패널티 불가 (${discountMin}분)');
            // 시간권은 금액으로 환산하기 어려우므로 일단 0
            penaltyAmount = 0;
          } else if (couponType == '레슨권') {
            final discountMin = coupon['discount_min'] ?? 0;
            print('  🎓 레슨권 쿠폰은 금액 패널티 불가 (${discountMin}분)');
            // 레슨권은 금액으로 환산하기 어려우므로 일단 0
            penaltyAmount = 0;
          }
          
          totalPenaltyAmount += penaltyAmount;
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
          return {'success': false, 'penalty_amount': 0};
        }
        
        print('✅ 발급 쿠폰 취소 성공: coupon_id $couponId');
      }
      
      print('✅ 모든 발급 쿠폰 취소 완료');
      print('💰 총 패널티 금액: ${totalPenaltyAmount}원');
      return {'success': true, 'penalty_amount': totalPenaltyAmount};
      
    } catch (e) {
      print('❌ 발급 쿠폰 취소 오류: $e');
      return {'success': false, 'penalty_amount': 0};
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