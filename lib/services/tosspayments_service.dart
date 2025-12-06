import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// 토스페이먼츠 결제 서비스 (직접 연동)
/// 
/// 포트원을 거치지 않고 토스페이먼츠와 직접 연동
/// API 문서: https://docs.tosspayments.com/
class TosspaymentsService {
  // ============================================================
  // 토스페이먼츠 API 키 설정
  // ============================================================
  
  // 상점 아이디 (MID)
  static const String mid = 'im_ineibl8beo';
  
  // 클라이언트 키 (라이브) - API 개별 연동 키
  static const String liveClientKey = 'live_ck_EP59LybZ8BzO7g1OeZlG86GYo7pR';
  
  // 시크릿 키 (라이브) - API 개별 연동 키
  // ⚠️ 중요: 이 키는 절대 외부에 노출되면 안 됩니다!
  static const String liveSecretKey = 'live_sk_ex6BJGQOVDKoG0N0ee4q3W4w2zNb';
  
  // 테스트 클라이언트 키
  static const String testClientKey = 'test_ck_EP59LybZ8BzO7g1OeZlG86GYo7pR';
  
  // 테스트 시크릿 키
  static const String testSecretKey = 'test_sk_XXXXXXXXXXXXXXXX'; // TODO: 실제 키로 교체
  
  // 현재 사용할 키 (라이브 환경)
  static const String clientKey = liveClientKey;
  static const String secretKey = liveSecretKey;
  
  // ============================================================
  // 토스페이먼츠 API 엔드포인트
  // ============================================================
  
  static const String apiBaseUrl = 'https://api.tosspayments.com';
  
  // ============================================================
  // 인증 헤더 생성
  // ============================================================
  
  /// Basic 인증 헤더 생성
  /// 시크릿 키 뒤에 콜론(:)을 붙이고 Base64 인코딩
  static String _getAuthHeader() {
    final credentials = '$secretKey:';
    final encoded = base64Encode(utf8.encode(credentials));
    return 'Basic $encoded';
  }
  
  // ============================================================
  // 결제 ID 생성
  // ============================================================
  
  /// 고유한 주문 ID 생성 (orderId)
  /// 토스페이먼츠 규칙: 영문 대소문자, 숫자, -, _ 만 허용, 6자 이상 64자 이하
  static String generateOrderId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(999999);
    return 'order_${timestamp}_$randomNum';
  }
  
  // ============================================================
  // 결제창 HTML 생성 (WebView용)
  // ============================================================
  
  /// 토스페이먼츠 결제창 HTML 생성
  /// 
  /// [orderId] 주문번호
  /// [orderName] 주문명 (상품명)
  /// [totalAmount] 결제 금액
  /// [customerName] 구매자 이름
  /// [customerEmail] 구매자 이메일
  /// [customerPhone] 구매자 전화번호
  /// [successUrl] 결제 성공 시 리다이렉트 URL
  /// [failUrl] 결제 실패 시 리다이렉트 URL
  static String generatePaymentHtml({
    required String orderId,
    required String orderName,
    required int totalAmount,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    required String successUrl,
    required String failUrl,
  }) {
    // customerKey 생성 (비회원 결제는 TossPayments.ANONYMOUS 사용)
    final customerKey = 'customer_${DateTime.now().millisecondsSinceEpoch}';
    
    // 전화번호에서 하이픈 및 특수문자 제거 (토스페이먼츠 요구사항)
    final cleanPhone = customerPhone?.replaceAll(RegExp(r'[^0-9]'), '');
    
    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>결제 진행</title>
  <!-- 토스페이먼츠 SDK v2 (API 개별 연동) -->
  <script src="https://js.tosspayments.com/v2/standard"></script>
  <style>
    body {
      margin: 0;
      padding: 20px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #f5f5f5;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
    }
    .container {
      background: white;
      padding: 30px;
      border-radius: 12px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      max-width: 400px;
      width: 100%;
    }
    .loading {
      text-align: center;
      padding: 40px 20px;
    }
    .spinner {
      border: 4px solid #f3f3f3;
      border-top: 4px solid #0064FF;
      border-radius: 50%;
      width: 40px;
      height: 40px;
      animation: spin 1s linear infinite;
      margin: 0 auto 20px;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    .error {
      color: #EF4444;
      text-align: center;
      padding: 20px;
    }
    .info {
      text-align: center;
      color: #666;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div id="loading" class="loading">
      <div class="spinner"></div>
      <p>결제창을 불러오는 중...</p>
      <p class="info">잠시만 기다려주세요</p>
    </div>
    <div id="error" class="error" style="display: none;"></div>
  </div>
  
  <script>
    (async function() {
      try {
        // SDK 로드 대기
        let sdkReady = false;
        let checkCount = 0;
        const maxChecks = 30;
        
        while (!sdkReady && checkCount < maxChecks) {
          if (typeof TossPayments !== 'undefined') {
            sdkReady = true;
            break;
          }
          await new Promise(resolve => setTimeout(resolve, 200));
          checkCount++;
        }
        
        if (!sdkReady) {
          throw new Error('토스페이먼츠 SDK를 불러올 수 없습니다.');
        }
        
        console.log('✅ 토스페이먼츠 SDK 로드 완료');
        
        // SDK 초기화 (API 개별 연동 키 사용)
        const clientKey = "$clientKey";
        const tossPayments = TossPayments(clientKey);
        
        // 비회원 결제 (ANONYMOUS) - payment() 방식
        const payment = tossPayments.payment({
          customerKey: TossPayments.ANONYMOUS
        });
        
        console.log('💳 결제 요청 시작');
        console.log('   - 주문번호:', "$orderId");
        console.log('   - 상품명:', "$orderName");
        console.log('   - 금액:', $totalAmount);
        
        // 결제 요청 (바로 결제창 열림)
        await payment.requestPayment({
          method: "CARD",
          amount: {
            currency: "KRW",
            value: $totalAmount
          },
          orderId: "$orderId",
          orderName: "$orderName",
          successUrl: "$successUrl",
          failUrl: "$failUrl",
          ${customerName != null ? 'customerName: "$customerName",' : ''}
          ${customerEmail != null ? 'customerEmail: "$customerEmail",' : ''}
          ${cleanPhone != null && cleanPhone.isNotEmpty ? 'customerMobilePhone: "$cleanPhone",' : ''}
          card: {
            useEscrow: false,
            flowMode: "DEFAULT",
            useCardPoint: false,
            useAppCardOnly: false
          }
        });
        
      } catch (error) {
        console.error('❌ 결제 오류:', error);
        
        document.getElementById('loading').style.display = 'none';
        document.getElementById('error').style.display = 'block';
        
        // 사용자가 결제를 취소한 경우
        if (error.code === 'PAY_PROCESS_CANCELED' || error.message?.includes('취소')) {
          document.getElementById('error').innerHTML = 
            '<p>결제가 취소되었습니다.</p>' +
            '<p style="font-size: 14px; color: #666;">뒤로가기를 눌러 다시 시도해주세요.</p>';
          
          // Flutter에 취소 메시지 전달
          if (window.FlutterChannel) {
            window.FlutterChannel.postMessage(JSON.stringify({
              type: 'payment_cancelled',
              message: '사용자가 결제를 취소했습니다.'
            }));
          }
        } else {
          document.getElementById('error').innerHTML = 
            '<p>결제 중 오류가 발생했습니다.</p>' +
            '<p style="font-size: 12px; color: #999;">' + (error.message || error.toString()) + '</p>';
          
          // Flutter에 에러 메시지 전달
          if (window.FlutterChannel) {
            window.FlutterChannel.postMessage(JSON.stringify({
              type: 'payment_error',
              code: error.code || 'UNKNOWN',
              message: error.message || error.toString()
            }));
          }
        }
      }
    })();
  </script>
</body>
</html>
''';
  }
  
  // ============================================================
  // 결제 승인 API (필수!)
  // ============================================================
  
  /// 결제 승인 요청
  /// 
  /// 결제창에서 인증 완료 후 반드시 호출해야 실제 결제가 완료됩니다.
  /// 
  /// [paymentKey] 토스페이먼츠가 발급한 결제 고유 키
  /// [orderId] 주문번호
  /// [amount] 결제 금액
  static Future<Map<String, dynamic>> confirmPayment({
    required String paymentKey,
    required String orderId,
    required int amount,
  }) async {
    try {
      print('🔐 토스페이먼츠 결제 승인 요청');
      print('   - paymentKey: $paymentKey');
      print('   - orderId: $orderId');
      print('   - amount: $amount원');
      
      final response = await http.post(
        Uri.parse('$apiBaseUrl/v1/payments/confirm'),
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'paymentKey': paymentKey,
          'orderId': orderId,
          'amount': amount,
        }),
      );
      
      print('📋 승인 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ 결제 승인 성공!');
        print('   - status: ${data['status']}');
        print('   - approvedAt: ${data['approvedAt']}');
        
        return {
          'success': true,
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body);
        print('❌ 결제 승인 실패: ${error['code']} - ${error['message']}');
        
        return {
          'success': false,
          'error': error['message'] ?? '결제 승인 실패',
          'errorCode': error['code'],
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ 결제 승인 오류: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // ============================================================
  // 결제 조회 API
  // ============================================================
  
  /// 결제 정보 조회
  static Future<Map<String, dynamic>> getPayment({
    required String paymentKey,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/v1/payments/$paymentKey'),
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['message'] ?? '결제 조회 실패',
          'errorCode': error['code'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// 주문번호로 결제 정보 조회
  static Future<Map<String, dynamic>> getPaymentByOrderId({
    required String orderId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/v1/payments/orders/$orderId'),
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['message'] ?? '결제 조회 실패',
          'errorCode': error['code'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // ============================================================
  // 결제 취소 API
  // ============================================================
  
  /// 결제 취소 (전액 또는 부분)
  /// 
  /// [paymentKey] 결제 고유 키
  /// [cancelReason] 취소 사유 (필수)
  /// [cancelAmount] 취소 금액 (null이면 전액 취소)
  static Future<Map<String, dynamic>> cancelPayment({
    required String paymentKey,
    required String cancelReason,
    int? cancelAmount,
  }) async {
    try {
      print('💳 토스페이먼츠 결제 취소 요청');
      print('   - paymentKey: $paymentKey');
      print('   - 취소 금액: ${cancelAmount != null ? "${cancelAmount}원" : "전액"}');
      print('   - 취소 사유: $cancelReason');
      
      final body = <String, dynamic>{
        'cancelReason': cancelReason,
      };
      
      if (cancelAmount != null) {
        body['cancelAmount'] = cancelAmount;
      }
      
      final response = await http.post(
        Uri.parse('$apiBaseUrl/v1/payments/$paymentKey/cancel'),
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      
      print('📋 취소 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ 결제 취소 성공');
        
        return {
          'success': true,
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body);
        print('❌ 결제 취소 실패: ${error['code']} - ${error['message']}');
        
        return {
          'success': false,
          'error': error['message'] ?? '결제 취소 실패',
          'errorCode': error['code'],
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ 결제 취소 오류: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // ============================================================
  // 결제 정보 DB 저장
  // ============================================================
  
  /// 결제 정보를 DB에 저장
  /// 
  /// 토스페이먼츠 응답 데이터를 v2_portone_payments 테이블에 저장
  /// (테이블명은 기존 호환성 유지)
  static Future<Map<String, dynamic>> savePaymentToDatabase({
    required String paymentKey,
    required String orderId,
    required int contractHistoryId,
    required int memberId,
    required String? branchId,
    required int paymentAmount,
    required String orderName,
    required String paymentStatus,
    String? paymentMethod,
    String? cardCompany,
    String? cardNumber,
    DateTime? approvedAt,
    Map<String, dynamic>? rawData,
  }) async {
    try {
      final paymentData = {
        // 토스페이먼츠 고유 키 (포트원의 payment_uid 대신 사용)
        'portone_payment_uid': paymentKey, // paymentKey를 저장
        'portone_tx_id': orderId, // orderId를 저장
        'contract_history_id': contractHistoryId,
        'member_id': memberId,
        'branch_id': branchId,
        'portone_store_id': mid, // MID 저장
        'portone_channel_key': clientKey, // 클라이언트 키 저장
        'channel_key_type': clientKey.startsWith('live_') ? '실연동' : '테스트',
        'payment_amount': paymentAmount,
        'payment_currency': 'KRW',
        'payment_method': paymentMethod ?? 'CARD',
        'payment_provider': 'tosspayments', // PG사 명시
        'order_name': orderName,
        'payment_status': paymentStatus,
        'payment_status_message': cardCompany != null ? '$cardCompany $cardNumber' : null,
        'payment_requested_at': DateTime.now().toIso8601String(),
        'payment_paid_at': approvedAt?.toIso8601String(),
        'custom_data': rawData != null ? jsonEncode(rawData) : null,
      };
      
      final response = await ApiService.addData(
        table: 'v2_portone_payments',
        data: paymentData,
      );
      
      if (response['success'] == true) {
        final paymentId = response['insertId'];
        
        // v3_contract_history에 payment_id 업데이트
        await ApiService.updateData(
          table: 'v3_contract_history',
          data: {'portone_payment_id': paymentId},
          where: [
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId}
          ],
        );
        
        return {
          'success': true,
          'payment_id': paymentId,
        };
      } else {
        throw Exception('결제 정보 저장 실패');
      }
    } catch (e) {
      print('결제 정보 저장 오류: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // ============================================================
  // 결제 검증
  // ============================================================
  
  /// 결제 검증 (금액, 상태 확인)
  /// 
  /// 결제 승인 후 또는 기존 결제 검증 시 사용
  static Future<Map<String, dynamic>> verifyPayment({
    required String paymentKey,
    required int expectedAmount,
  }) async {
    try {
      print('🔐 결제 검증 시작: $paymentKey');
      
      final result = await getPayment(paymentKey: paymentKey);
      
      if (result['success'] != true) {
        return {
          'success': false,
          'verified': false,
          'error': result['error'],
        };
      }
      
      final data = result['data'] as Map<String, dynamic>;
      
      // 상태 확인 (DONE이어야 결제 완료)
      final status = data['status'] as String?;
      if (status != 'DONE') {
        return {
          'success': true,
          'verified': false,
          'error': '결제가 완료되지 않았습니다. 상태: $status',
          'status': status,
        };
      }
      
      // 금액 확인
      final totalAmount = data['totalAmount'] as int?;
      if (totalAmount != expectedAmount) {
        return {
          'success': true,
          'verified': false,
          'error': '결제 금액이 일치하지 않습니다. 예상: $expectedAmount원, 실제: $totalAmount원',
        };
      }
      
      print('✅ 결제 검증 성공');
      
      return {
        'success': true,
        'verified': true,
        'status': status,
        'amount': totalAmount,
        'approvedAt': data['approvedAt'],
        'data': data,
      };
    } catch (e) {
      return {
        'success': false,
        'verified': false,
        'error': e.toString(),
      };
    }
  }
}

