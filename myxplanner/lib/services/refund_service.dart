import 'package:supabase_flutter/supabase_flutter.dart';
import 'portone_payment_service.dart';

/// 회원권 환불 서비스
/// 포트원 결제 취소 및 Supabase DB 업데이트를 처리합니다.
class RefundService {
  static final _supabase = Supabase.instance.client;

  /// 환불 가능 여부 확인
  /// 
  /// [branchId] 지점 ID
  /// [memberId] 회원 ID
  /// [contractHistoryId] 계약 이력 ID
  /// 
  /// Returns: 환불 가능 여부 및 결제 정보
  static Future<Map<String, dynamic>> checkRefundEligibility({
    required String branchId,
    required dynamic memberId,
    required dynamic contractHistoryId,
  }) async {
    // 타입 안전하게 int로 변환
    final int memberIdInt = memberId is int ? memberId : int.tryParse(memberId.toString()) ?? 0;
    final int contractHistoryIdInt = contractHistoryId is int ? contractHistoryId : int.tryParse(contractHistoryId.toString()) ?? 0;
    
    if (memberIdInt == 0 || contractHistoryIdInt == 0) {
      return {
        'success': false,
        'error': '잘못된 회원 ID 또는 계약 ID',
      };
    }
    try {
      print('🔍 환불 가능 여부 확인: contractHistoryId=$contractHistoryIdInt');
      
      final response = await _supabase.rpc(
        'check_contract_refund_eligibility',
        params: {
          'p_branch_id': branchId,
          'p_member_id': memberIdInt,
          'p_contract_history_id': contractHistoryIdInt,
        },
      );

      if (response == null) {
        return {
          'success': false,
          'error': 'RPC 응답이 없습니다',
        };
      }

      final result = Map<String, dynamic>.from(response);
      print('✅ 환불 가능 여부: ${result['is_refundable']} - ${result['reason']}');
      
      return result;
    } catch (e) {
      print('❌ 환불 가능 여부 확인 오류: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 환불 처리 실행
  /// 
  /// 1. 포트원 결제 취소 API 호출
  /// 2. Supabase DB 업데이트 (잔액 0원 + 상태 변경)
  /// 
  /// [branchId] 지점 ID
  /// [memberId] 회원 ID
  /// [contractHistoryId] 계약 이력 ID
  /// [paymentId] 포트원 결제 ID
  /// [cancelReason] 취소 사유
  static Future<Map<String, dynamic>> processRefund({
    required String branchId,
    required dynamic memberId,
    required dynamic contractHistoryId,
    required String paymentId,
    String cancelReason = '고객 요청에 의한 환불',
  }) async {
    // 타입 안전하게 int로 변환
    final int memberIdInt = memberId is int ? memberId : int.tryParse(memberId.toString()) ?? 0;
    final int contractHistoryIdInt = contractHistoryId is int ? contractHistoryId : int.tryParse(contractHistoryId.toString()) ?? 0;
    
    if (memberIdInt == 0 || contractHistoryIdInt == 0) {
      return {
        'success': false,
        'error': '잘못된 회원 ID 또는 계약 ID',
      };
    }
    
    try {
      print('💳 환불 처리 시작: contractHistoryId=$contractHistoryIdInt');
      
      // 1. 환불 가능 여부 재확인
      final eligibility = await checkRefundEligibility(
        branchId: branchId,
        memberId: memberIdInt,
        contractHistoryId: contractHistoryIdInt,
      );

      if (eligibility['success'] != true) {
        return {
          'success': false,
          'error': eligibility['error'] ?? '환불 가능 여부 확인 실패',
        };
      }

      if (eligibility['is_refundable'] != true) {
        return {
          'success': false,
          'error': eligibility['reason'] ?? '환불이 불가능합니다',
        };
      }

      final portonePaymentId = eligibility['portone_payment_uid']?.toString() ?? paymentId;
      final paymentAmount = eligibility['payment_amount'] as int?;

      if (paymentAmount == null || paymentAmount <= 0) {
        return {
          'success': false,
          'error': '결제 금액 정보가 없습니다',
        };
      }

      // 2. 포트원 결제 취소 API 호출
      print('💳 포트원 결제 취소 요청: $portonePaymentId, 금액: $paymentAmount원');
      
      final cancelResult = await PortonePaymentService.cancelPayment(
        paymentId: portonePaymentId,
        cancelAmount: paymentAmount,
        cancelReason: cancelReason,
      );

      if (cancelResult['success'] != true) {
        return {
          'success': false,
          'error': '포트원 결제 취소 실패: ${cancelResult['error']}',
          'portone_error': cancelResult['error'],
        };
      }

      print('✅ 포트원 결제 취소 성공');

      // 3. Supabase DB 업데이트
      print('📝 Supabase DB 업데이트 시작');
      
      final dbResult = await _supabase.rpc(
        'process_contract_refund',
        params: {
          'p_branch_id': branchId,
          'p_member_id': memberIdInt,
          'p_contract_history_id': contractHistoryIdInt,
          'p_cancel_reason': cancelReason,
        },
      );

      if (dbResult == null) {
        // 포트원 취소는 성공했지만 DB 업데이트 실패
        // 이 경우 수동 처리 필요
        return {
          'success': false,
          'error': 'DB 업데이트 실패 (포트원 취소는 완료됨 - 수동 처리 필요)',
          'portone_cancelled': true,
        };
      }

      final result = Map<String, dynamic>.from(dbResult);
      
      if (result['success'] != true) {
        return {
          'success': false,
          'error': result['error'] ?? 'DB 업데이트 실패',
          'portone_cancelled': true,
        };
      }

      print('✅ 환불 처리 완료: ${result['refunded_amount']}원');

      return {
        'success': true,
        'message': '환불이 완료되었습니다',
        'refunded_amount': result['refunded_amount'],
        'contract_name': result['contract_name'],
      };
    } catch (e) {
      print('❌ 환불 처리 오류: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 환불 금액 포맷팅
  static String formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}


