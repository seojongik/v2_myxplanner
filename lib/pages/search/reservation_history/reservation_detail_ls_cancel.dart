import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';

/// 레슨 예약 취소 서비스
class LsReservationCancelService {
  /// 레슨 예약 취소 메인 함수
  static Future<bool> cancelLsReservation({
    required String lsId,
    required BuildContext context,
    required DateTime reservationStartTime, // 예약 시작 시간 추가
    int? programPenaltyPercent, // 프로그램 페널티 (프로그램 예약인 경우)
  }) async {
    try {
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('레슨 예약 취소 시작');
      print('═══════════════════════════════════════════════════════════');
      print('LS_id: $lsId');
      
      // 1. v2_LS_orders 상태 업데이트
      final ordersUpdateSuccess = await _updateLsOrdersStatus(lsId);
      if (!ordersUpdateSuccess) {
        print('❌ v2_LS_orders 업데이트 실패');
        return false;
      }
      
      // 2. v3_LS_countings 취소 처리 및 잔액 재계산
      final countingsSuccess = await _cancelLsCountingsRecord(lsId, reservationStartTime, programPenaltyPercent: programPenaltyPercent);
      if (!countingsSuccess) {
        print('❌ v3_LS_countings 취소 처리 실패');
        return false;
      }
      
      // 3. 할인 쿠폰 처리
      // 3-1. 사용된 쿠폰 복구
      final restoreSuccess = await _restoreDiscountCoupons(lsId);
      // 3-2. 발급된 쿠폰 취소 (실패해도 예약 취소는 계속 진행)
      final revokeResult = await _revokeIssuedCouponsWithPenalty(lsId);
      final revokeSuccess = revokeResult['success'] == true;
      final penaltyAmount = revokeResult['penalty_amount'] ?? 0;
      
      // 사용된 쿠폰 복구만 필수, 발급 쿠폰 취소는 선택적
      final couponSuccess = restoreSuccess;
      if (!revokeSuccess) {
        print('⚠️ 발급 쿠폰 취소 실패 (예약 취소는 계속 진행)');
      }
      
      if (penaltyAmount > 0) {
        print('💰 발급 쿠폰 사용 패널티: ${penaltyAmount}원');
        // TODO: 패널티 금액을 취소 처리에 반영 필요
      }
      
      final finalSuccess = countingsSuccess && couponSuccess;
      
      print('');
      print('═══════════════════════════════════════════════════════════');
      print('레슨 예약 취소 완료: ${finalSuccess ? "성공" : "실패"}');
      print('  - v2_LS_orders: 성공');
      print('  - v3_LS_countings: ${countingsSuccess ? "성공" : "실패"}');
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
      print('❌ 레슨 예약 취소 오류: $e');
      return false;
    }
  }
  
  /// v2_LS_orders 상태 업데이트
  static Future<bool> _updateLsOrdersStatus(String lsId) async {
    try {
      print('');
      print('🔄 v2_LS_orders 상태 업데이트 시작');
      
      // 1. 현재 예약 정보 조회
      final currentData = await ApiService.getData(
        table: 'v2_LS_orders',
        where: [
          {'field': 'LS_id', 'operator': '=', 'value': lsId}
        ],
        limit: 1,
      );
      
      if (currentData.isEmpty) {
        print('❌ 레슨 예약 정보를 찾을 수 없습니다: $lsId');
        return false;
      }
      
      final order = currentData.first;
      print('현재 레슨 상태: ${order['LS_status']}');
      
      // 이미 취소된 예약인지 확인
      if (order['LS_status'] == '예약취소') {
        print('⚠️ 이미 취소된 레슨 예약입니다');
        return true;
      }
      
      // 2. 상태를 '예약취소'로 업데이트
      final updateResult = await ApiService.updateData(
        table: 'v2_LS_orders',
        where: [
          {'field': 'LS_id', 'operator': '=', 'value': lsId}
        ],
        data: {
          'LS_status': '예약취소',
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      
      final updateSuccess = updateResult['success'] == true;
      
      if (updateSuccess) {
        print('✅ v2_LS_orders 상태 업데이트 성공');
        return true;
      } else {
        print('❌ v2_LS_orders 상태 업데이트 실패');
        return false;
      }
      
    } catch (e) {
      print('❌ v2_LS_orders 업데이트 오류: $e');
      return false;
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

  /// 발급된 쿠폰 취소 미리보기 (실제 취소하지 않고 조회만)
  static Future<Map<String, dynamic>> previewIssuedCoupons(String lsId) async {
    try {
      print('');
      print('🔍 발급된 쿠폰 취소 미리보기 시작 (LS_id: $lsId)');
      
      final branchId = ApiService.getCurrentBranchId() ?? '';
      if (branchId.isEmpty) {
        print('❌ branch_id를 찾을 수 없습니다');
        return {'success': false, 'coupons': [], 'message': 'branch_id를 찾을 수 없습니다'};
      }
      
      // 해당 레슨 예약으로 발급된 쿠폰 조회
      List<Map<String, dynamic>> issuedCoupons = [];
      try {
        issuedCoupons = await ApiService.getData(
          table: 'v2_discount_coupon',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'LS_id_issued', 'operator': '=', 'value': lsId},
            {'field': 'coupon_status', 'operator': '!=', 'value': '취소'},
          ],
        );
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
  static Future<Map<String, dynamic>> previewDiscountCoupons(String lsId) async {
    try {
      print('');
      print('🔍 할인 쿠폰 복구 미리보기 시작 (LS_id: $lsId)');
      
      final branchId = ApiService.getCurrentBranchId() ?? '';
      if (branchId.isEmpty) {
        print('❌ branch_id를 찾을 수 없습니다');
        return {'success': false, 'coupons': [], 'message': 'branch_id를 찾을 수 없습니다'};
      }
      
      // 해당 레슨 예약에 사용된 쿠폰 조회
      final usedCoupons = await ApiService.getData(
        table: 'v2_discount_coupon',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'LS_id_used', 'operator': '=', 'value': lsId},
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

  /// 발급된 쿠폰 취소 처리 (패널티 계산 포함)
  static Future<Map<String, dynamic>> _revokeIssuedCouponsWithPenalty(String lsId) async {
    try {
      print('');
      print('🔄 발급된 쿠폰 취소 처리 시작 (LS_id: $lsId)');
      
      final branchId = ApiService.getCurrentBranchId() ?? '';
      if (branchId.isEmpty) {
        print('❌ branch_id를 찾을 수 없습니다');
        return {'success': false, 'penalty_amount': 0};
      }
      
      // 1. 해당 레슨 예약으로 발급된 쿠폰 조회
      List<Map<String, dynamic>> issuedCoupons = [];
      try {
        issuedCoupons = await ApiService.getData(
          table: 'v2_discount_coupon',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'LS_id_issued', 'operator': '=', 'value': lsId},
          ],
        );
      } catch (apiError) {
        print('⚠️ 발급 쿠폰 조회 실패 (API 오류): $apiError');
        // API 오류 시에도 빈 리스트로 처리하여 계속 진행
        issuedCoupons = [];
      }
      
      // 취소되지 않은 쿠폰만 필터링
      final validCoupons = issuedCoupons.where((coupon) => coupon['coupon_status'] != '취소').toList();
      
      print('취소 대상 발급 쿠폰 수: ${validCoupons.length}개');
      
      if (validCoupons.isEmpty) {
        print('✅ 취소할 발급 쿠폰이 없습니다');
        return {'success': true, 'penalty_amount': 0};
      }
      
      int totalPenaltyAmount = 0;
      
      // 2. 각 발급 쿠폰을 취소 상태로 변경 및 패널티 계산
      for (final coupon in validCoupons) {
        final couponId = coupon['coupon_id'];
        final couponStatus = coupon['coupon_status'];
        final couponType = coupon['coupon_type'] ?? '';
        
        print('발급 쿠폰 취소 중: coupon_id $couponId (상태: $couponStatus, 타입: $couponType)');
        
        // 사용된 쿠폰인 경우 패널티 계산
        if (couponStatus == '사용') {
          int penaltyAmount = 0;
          
          if (couponType == '정액권') {
            final discountAmt = coupon['discount_amt'] ?? 0;
            penaltyAmount = discountAmt;
            print('  💰 정액권 패널티 추가: ${penaltyAmount}원');
          } else if (couponType == '정률권') {
            // 정률권은 사용 금액을 알 수 없으므로 패널티 없음
            print('  ⚠️ 정률권은 패널티 계산 불가');
          } else if (couponType == '시간권') {
            // 시간권은 시간 단위이므로 패널티 없음
            print('  ⚠️ 시간권은 패널티 계산 불가');
          } else if (couponType == '레슨권') {
            // 레슨권은 시간 단위이므로 패널티 없음
            print('  ⚠️ 레슨권은 패널티 계산 불가');
          }
          
          totalPenaltyAmount += penaltyAmount;
        }
        
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
      if (totalPenaltyAmount > 0) {
        print('💰 총 패널티 금액: ${totalPenaltyAmount}원');
      }
      
      return {'success': true, 'penalty_amount': totalPenaltyAmount};
      
    } catch (e) {
      print('❌ 발급 쿠폰 취소 오류: $e');
      return {'success': false, 'penalty_amount': 0};
    }
  }

  /// 할인 쿠폰 복구 처리
  static Future<bool> _restoreDiscountCoupons(String lsId) async {
    try {
      print('');
      print('🔄 할인 쿠폰 복구 처리 시작 (LS_id: $lsId)');
      
      final branchId = ApiService.getCurrentBranchId() ?? '';
      if (branchId.isEmpty) {
        print('❌ branch_id를 찾을 수 없습니다');
        return false;
      }
      
      // 1. 해당 레슨 예약에 사용된 쿠폰 조회
      final usedCoupons = await ApiService.getData(
        table: 'v2_discount_coupon',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'LS_id_used', 'operator': '=', 'value': lsId},
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

  /// v3_LS_countings 취소 처리 및 잔액 재계산
  static Future<bool> _cancelLsCountingsRecord(String lsId, DateTime reservationStartTime, {int? programPenaltyPercent}) async {
    try {
      print('');
      print('🔄 v3_LS_countings 취소 처리 시작 (LS_id: $lsId)');
      
      // 0. 취소 정책 조회 (프로그램 페널티가 있으면 우선 적용)
      int penaltyPercent;
      if (programPenaltyPercent != null) {
        penaltyPercent = programPenaltyPercent;
        print('프로그램 통합 페널티 적용: ${penaltyPercent}%');
      } else {
        final policy = await _getCancellationPolicy('v3_LS_countings', reservationStartTime);
        if (!policy['canCancel']) {
          print('❌ 취소가 불가능한 상태입니다');
          return false;
        }
        penaltyPercent = policy['penaltyPercent'] as int;
      }
      final isPenaltyApplicable = penaltyPercent > 0;
      
      print('적용 페널티: ${penaltyPercent}%');
      
      // 1. 취소 대상 LS_counting 정보 조회
      final targetCountingData = await ApiService.getData(
        table: 'v3_LS_countings',
        where: [
          {'field': 'LS_id', 'operator': '=', 'value': lsId}
        ],
        limit: 1,
      );
      
      if (targetCountingData.isEmpty) {
        print('❌ 취소 대상 LS_counting을 찾을 수 없습니다: $lsId');
        return false;
      }
      
      final targetCounting = targetCountingData.first;
      final lsCountingId = targetCounting['LS_counting_id'];
      final lsContractId = targetCounting['LS_contract_id'];
      
      print('취소 대상 LS_counting_id: $lsCountingId');
      print('취소 대상 LS_contract_id: $lsContractId');
      
      // 2. 동일 LS_contract_id에서 해당 LS_counting_id 이상인 모든 레코드 조회
      final affectedCountings = await ApiService.getData(
        table: 'v3_LS_countings',
        where: [
          {'field': 'LS_contract_id', 'operator': '=', 'value': lsContractId},
          {'field': 'LS_counting_id', 'operator': '>=', 'value': lsCountingId},
        ],
        orderBy: [
          {'field': 'LS_counting_id', 'direction': 'ASC'}
        ],
      );
      
      print('영향받는 레코드 수: ${affectedCountings.length}개');
      
      if (affectedCountings.isEmpty) {
        print('❌ 영향받는 레코드가 없습니다');
        return false;
      }
      
      // 3. 첫 번째 레코드 (취소 대상) 처리
      final cancelTarget = affectedCountings.first;
      final originalBeforeBalance = cancelTarget['LS_balance_min_before'] ?? 0;
      final originalNetMin = cancelTarget['LS_net_min'] ?? 0;
      
      print('취소 대상 처리: LS_counting_id ${cancelTarget['LS_counting_id']}');
      print('  원래 before_balance: $originalBeforeBalance');
      print('  원래 LS_net_min: $originalNetMin');
      
      // 빈 슬롯 처리: before_balance나 LS_net_min이 null이면 취소 처리 스킵
      if (originalBeforeBalance == null || originalBeforeBalance == 0) {
        print('⚠️ 빈 슬롯 또는 잔액이 0인 레코드 - 단순 상태 변경만 수행');
        
        final updateResult = await ApiService.updateData(
          table: 'v3_LS_countings',
          where: [
            {'field': 'LS_counting_id', 'operator': '=', 'value': cancelTarget['LS_counting_id']}
          ],
          data: {
            'LS_status': '예약취소',
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
        
        final updateSuccess = updateResult['success'] == true;
        if (updateSuccess) {
          print('✅ 빈 슬롯 상태 업데이트 완료');
        } else {
          print('❌ 빈 슬롯 상태 업데이트 실패');
          return false;
        }
        
        print('✅ v3_LS_countings 취소 처리 완료 (빈 슬롯)');
        return true;
      }
      
      Map<String, dynamic> updateData = {
        'LS_status': '예약취소',
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (isPenaltyApplicable) {
        // 페널티 적용: 원래 레슨 시간의 페널티 퍼센트만큼 차감
        final penaltyNetMin = (originalNetMin * penaltyPercent / 100).round();
        final newAfterBalance = originalBeforeBalance - penaltyNetMin;
        
        print('  페널티 시간: $penaltyNetMin분');
        print('  새로운 after_balance: $newAfterBalance');
        
        updateData.addAll({
          'LS_net_min': penaltyNetMin,
          'LS_balance_min_after': newAfterBalance,
        });
      } else {
        // 무료 취소: 원래 로직 적용
        updateData.addAll({
          'LS_net_min': 0,
          'LS_balance_min_after': originalBeforeBalance,
        });
      }
      
      // 취소 대상 업데이트
      final cancelResult = await ApiService.updateData(
        table: 'v3_LS_countings',
        where: [
          {'field': 'LS_counting_id', 'operator': '=', 'value': cancelTarget['LS_counting_id']}
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
      if (affectedCountings.length > 1) {
        print('후속 레코드 잔액 재계산 시작');
        
        for (int i = 1; i < affectedCountings.length; i++) {
          final currentCounting = affectedCountings[i];
          final previousCounting = affectedCountings[i - 1];
          
          // 이전 레코드의 after_balance를 현재 레코드의 before_balance로 설정
          final newBeforeBalance = i == 1 
            ? (isPenaltyApplicable 
                ? originalBeforeBalance - (originalNetMin * penaltyPercent / 100).round()
                : originalBeforeBalance)  // 첫 번째 후속 레코드는 취소된 레코드의 after_balance 사용
            : previousCounting['LS_balance_min_after'];
          
          final netMin = currentCounting['LS_net_min'] ?? 0;
          final newAfterBalance = newBeforeBalance - netMin; // 레슨은 차감이므로 빼기
          
          print('  레코드 ${i + 1}: LS_counting_id ${currentCounting['LS_counting_id']}');
          print('    before: ${currentCounting['LS_balance_min_before']} → $newBeforeBalance');
          print('    LS_net_min: $netMin');
          print('    after: ${currentCounting['LS_balance_min_after']} → $newAfterBalance');
          
          final updateResult = await ApiService.updateData(
            table: 'v3_LS_countings',
            where: [
              {'field': 'LS_counting_id', 'operator': '=', 'value': currentCounting['LS_counting_id']}
            ],
            data: {
              'LS_balance_min_before': newBeforeBalance,
              'LS_balance_min_after': newAfterBalance,
              'updated_at': DateTime.now().toIso8601String(),
            },
          );
          
          final updateSuccess = updateResult['success'] == true;
          
          if (!updateSuccess) {
            print('❌ 레코드 ${currentCounting['LS_counting_id']} 업데이트 실패');
            return false;
          }
          
          // 다음 반복을 위해 현재 레코드의 after_balance 업데이트
          affectedCountings[i]['LS_balance_min_after'] = newAfterBalance;
        }
        
        print('✅ 모든 후속 레코드 잔액 재계산 완료');
      }
      
      print('✅ v3_LS_countings 취소 처리 완료');
      return true;
      
    } catch (e) {
      print('❌ v3_LS_countings 취소 처리 오류: $e');
      return false;
    }
  }
}