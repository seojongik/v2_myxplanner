import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// 포트원 결제 서비스
class PortonePaymentService {
  // 포트원 상점 ID
  static const String storeId = 'store-58c8f5b8-6bc6-4efb-8dd0-8a98475a4246';
  
  // ============================================================
  // 채널 키 설정 (토스페이먼츠)
  // ============================================================
  
  // 실연동 채널 키 (토스페이먼츠 - 카드사 계약 완료)
  // 발급일: 2024년 (실결제용)
  static const String liveChannelKey = 'channel-key-4ba942b1-404c-4b2b-86b5-143093f9d21f';
  
  // 테스트 채널 키 (토스페이먼츠 - 테스트용)
  static const String testChannelKey = 'channel-key-4103c2a4-ab14-4707-bdb3-6c6254511ba0';
  
  // 기본 채널 키 (실연동 사용)
  static const String defaultChannelKey = liveChannelKey;
  
  // KPN 채널 키 (한국결제네트웍스 - 추후 설정)
  static const String kpnChannelKey = liveChannelKey; // 현재는 토스페이먼츠 사용
  
  // 카카오페이 채널 키 (추후 설정)
  static const String kakaoPayChannelKey = liveChannelKey; // 현재는 토스페이먼츠 사용
  
  // 네이버페이 채널 키 (추후 설정)
  static const String naverPayChannelKey = liveChannelKey; // 현재는 토스페이먼츠 사용
  
  // ============================================================
  
  // 포트원 API 베이스 URL
  static const String portoneApiBaseUrl = 'https://api.portone.io';
  
  // ============================================================
  // 포트원 API 인증 (서버 검증용)
  // ============================================================
  
  // 포트원 API Secret 키 (실결제 검증용)
  // ⚠️ 중요: 이 키는 절대 외부에 노출되면 안 됩니다!
  static const String apiSecret = 'N0ISf8dPoea2d3SH3RjZhS6eMJw0Ggpg7C9iNE7f5YY8YlMce4M8j96FJPdn9zLSOmx9U8p31Lezqmp6';
  
  // ============================================================
  
  /// 고유한 결제 ID 생성
  /// 포트원 규칙: 대문자, 소문자, 숫자만 허용 (특수문자 불가)
  static String generatePaymentId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(999999);
    // 하이픈 제거하고 영문자와 숫자만 사용
    return 'payment${timestamp}${randomNum}';
  }
  
  /// 포트원 결제 HTML 생성 (WebView에서 사용)
  static String generatePaymentHtml({
    required String paymentId,
    required String channelKey,
    required String orderName,
    required int totalAmount,
    String currency = 'KRW',
    String payMethod = 'CARD',
    String? redirectUrl,
  }) {
    // 웹 환경과 동일하게 currency 변환 (KRW -> CURRENCY_KRW)
    final portoneCurrency = currency == 'KRW' ? 'CURRENCY_KRW' : currency;
    
    final redirectUrlParam = redirectUrl != null 
        ? ', redirectUrl: "$redirectUrl"'
        : '';
    
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>결제 진행</title>
  <script src="https://cdn.portone.io/v2/browser-sdk.js"></script>
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
      border-top: 4px solid #3B82F6;
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
  </style>
</head>
<body>
  <div class="container">
    <div id="loading" class="loading">
      <div class="spinner"></div>
      <p>결제창을 불러오는 중...</p>
    </div>
    <div id="error" class="error" style="display: none;"></div>
  </div>
  
  <script>
    (async function() {
      try {
        // 포트원 SDK가 로드되었는지 확인 (재시도 로직)
        let portoneReady = false;
        let checkCount = 0;
        const maxChecks = 30; // 최대 6초 대기 (200ms * 30)
        
        while (!portoneReady && checkCount < maxChecks) {
          if (typeof PortOne !== 'undefined' && PortOne && typeof PortOne.requestPayment === 'function') {
            portoneReady = true;
            break;
          }
          await new Promise(resolve => setTimeout(resolve, 200));
          checkCount++;
        }
        
        if (!portoneReady) {
          throw new Error('포트원 SDK를 불러올 수 없습니다. 네트워크 연결을 확인해주세요.');
        }
        
        console.log('✅ 포트원 SDK 로드 완료, 결제 요청 시작');
        
        const paymentParams = {
          storeId: "$storeId",
          channelKey: "$channelKey",
          paymentId: "$paymentId",
          orderName: "$orderName",
          totalAmount: $totalAmount,
          currency: "$portoneCurrency",
          payMethod: "$payMethod"$redirectUrlParam
        };
        
        console.log('💳 포트원 결제 파라미터:', paymentParams);
        
        const response = await PortOne.requestPayment(paymentParams);
        
        console.log('💳 포트원 결제 응답:', response);
        
        if (response.code !== undefined) {
          // 결제 실패
          document.getElementById('loading').style.display = 'none';
          document.getElementById('error').style.display = 'block';
          document.getElementById('error').textContent = '결제 실패: ' + (response.message || '알 수 없는 오류');
          
          // Flutter에 실패 메시지 전달
          if (window.FlutterChannel) {
            window.FlutterChannel.postMessage(JSON.stringify({
              type: 'payment_failed',
              code: response.code,
              message: response.message,
              pgCode: response.pgCode,
              pgMessage: response.pgMessage
            }));
          }
        } else {
          // 결제 성공
          if (window.FlutterChannel) {
            window.FlutterChannel.postMessage(JSON.stringify({
              type: 'payment_success',
              paymentId: response.paymentId,
              txId: response.txId
            }));
          }
        }
      } catch (error) {
        console.error('❌ 포트원 결제 오류:', error);
        document.getElementById('loading').style.display = 'none';
        document.getElementById('error').style.display = 'block';
        document.getElementById('error').textContent = '오류 발생: ' + (error.message || error.toString());
        
        if (window.FlutterChannel) {
          window.FlutterChannel.postMessage(JSON.stringify({
            type: 'payment_error',
            error: error.message || error.toString()
          }));
        }
      }
    })();
  </script>
</body>
</html>
''';
  }
  
  /// 포트원 결제 정보를 DB에 저장
  static Future<Map<String, dynamic>> savePaymentToDatabase({
    required String portonePaymentId,
    String? portoneTxId,
    required int contractHistoryId,
    required int memberId,
    required String? branchId,
    required String channelKey,
    required int paymentAmount,
    required String paymentMethod,
    required String paymentProvider,
    required String orderName,
    required String paymentStatus,
    String? paymentStatusMessage,
    DateTime? paymentRequestedAt,
    DateTime? paymentPaidAt,
    Map<String, dynamic>? customData,
  }) async {
    try {
      // 테스트 채널 키 목록
      // 실연동 키: channel-key-4ba942b1-404c-4b2b-86b5-143093f9d21f (토스페이먼츠)
      const testChannelKeys = [
        'channel-key-4103c2a4-ab14-4707-bdb3-6c6254511ba0', // 토스페이먼츠 테스트 키
        'channel-key-bc51c093-a46c-45cc-934a-c805007abe3d',
        'channel-key-601c7153-6a75-45e0-b2df-09b67a45b452',
        'channel-key-77102617-6e37-4f2f-bf37-e6e54b8c6417',
      ];
      
      // 채널 키로 테스트/실연동 판단
      final channelKeyType = testChannelKeys.contains(channelKey) ? '테스트' : '실연동';
      
      final paymentData = {
        'portone_payment_uid': portonePaymentId,
        'portone_tx_id': portoneTxId,
        'contract_history_id': contractHistoryId,
        'member_id': memberId,
        'branch_id': branchId,
        'portone_store_id': storeId,
        'portone_channel_key': channelKey,
        'channel_key_type': channelKeyType, // 테스트 또는 실연동
        'payment_amount': paymentAmount,
        'payment_currency': 'KRW',
        'payment_method': paymentMethod,
        'payment_provider': paymentProvider,
        'order_name': orderName,
        'payment_status': paymentStatus,
        'payment_status_message': paymentStatusMessage,
        'payment_requested_at': paymentRequestedAt?.toIso8601String(),
        'payment_paid_at': paymentPaidAt?.toIso8601String(),
        'custom_data': customData != null ? jsonEncode(customData) : null,
      };
      
      final response = await ApiService.addData(
        table: 'v2_portone_payments',
        data: paymentData,
      );
      
      if (response['success'] == true) {
        final portonePaymentId_db = response['insertId'];
        
        // v3_contract_history에 portone_payment_id 업데이트
        await ApiService.updateData(
          table: 'v3_contract_history',
          data: {'portone_payment_id': portonePaymentId_db},
          where: [
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId}
          ],
        );
        
        return {
          'success': true,
          'portone_payment_id': portonePaymentId_db,
        };
      } else {
        throw Exception('결제 정보 저장 실패');
      }
    } catch (e) {
      print('포트원 결제 정보 저장 오류: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// 포트원 API를 통해 결제 정보 조회 (서버에서 검증용)
  static Future<Map<String, dynamic>> getPaymentFromPortone({
    required String paymentId,
    required String apiSecret,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$portoneApiBaseUrl/payments/$paymentId'),
        headers: {
          'Authorization': 'PortOne $apiSecret',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': '결제 조회 실패: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// 포트원 API를 통해 실제 결제 상태 검증 (회원권 부여 전 필수!)
  /// 결제가 실제로 완료되었는지 확인하고, 결제 금액도 검증
  static Future<Map<String, dynamic>> verifyPaymentFromPortone({
    required String paymentId,
    required int expectedAmount,
  }) async {
    try {
      print('🔐 포트원 API로 결제 검증 시작: $paymentId');
      print('🔐 예상 결제 금액: $expectedAmount원');
      
      // 포트원 API 호출
      final result = await getPaymentFromPortone(
        paymentId: paymentId,
        apiSecret: apiSecret,
      );
      
      if (result['success'] != true) {
        print('❌ 포트원 API 호출 실패: ${result['error']}');
        return {
          'success': false,
          'verified': false,
          'error': '포트원 API 호출 실패: ${result['error']}',
        };
      }
      
      final paymentData = result['data'] as Map<String, dynamic>;
      print('📋 포트원 API 응답: $paymentData');
      
      // 결제 상태 확인 (status가 PAID여야 함)
      final status = paymentData['status'] as String?;
      if (status != 'PAID') {
        print('❌ 결제 상태가 PAID가 아닙니다: $status');
        return {
          'success': true,
          'verified': false,
          'error': '결제가 완료되지 않았습니다. 상태: $status',
          'status': status,
        };
      }
      
      // 결제 금액 확인
      final amount = paymentData['amount'] as Map<String, dynamic>?;
      final totalAmount = amount?['total'] as int?;
      final paidAmount = amount?['paid'] as int?;
      
      // totalAmount 또는 paidAmount 중 하나라도 예상 금액과 일치해야 함
      final actualAmount = paidAmount ?? totalAmount;
      
      if (actualAmount == null) {
        print('❌ 결제 금액 정보가 없습니다');
        return {
          'success': true,
          'verified': false,
          'error': '결제 금액 정보를 확인할 수 없습니다.',
        };
      }
      
      if (actualAmount != expectedAmount) {
        print('❌ 결제 금액 불일치: 예상 $expectedAmount원, 실제 $actualAmount원');
        return {
          'success': true,
          'verified': false,
          'error': '결제 금액이 일치하지 않습니다. 예상: $expectedAmount원, 실제: $actualAmount원',
          'expectedAmount': expectedAmount,
          'actualAmount': actualAmount,
        };
      }
      
      // 결제 시간 확인
      final paidAt = paymentData['paidAt'] as String?;
      if (paidAt == null || paidAt.isEmpty) {
        print('❌ 결제 완료 시간이 없습니다');
        return {
          'success': true,
          'verified': false,
          'error': '결제 완료 시간을 확인할 수 없습니다.',
        };
      }
      
      // 채널 정보에서 테스트 여부 확인
      final channel = paymentData['channel'] as Map<String, dynamic>?;
      final channelType = channel?['type'] as String?;
      final isTest = channelType == 'TEST';
      
      print('✅ 포트원 결제 검증 성공!');
      print('   - 상태: $status');
      print('   - 금액: $actualAmount원');
      print('   - 결제 시간: $paidAt');
      print('   - 채널 타입: $channelType (${isTest ? "테스트" : "실결제"})');
      
      return {
        'success': true,
        'verified': true,
        'status': status,
        'amount': actualAmount,
        'paidAt': paidAt,
        'isTest': isTest,
        'paymentData': paymentData,
      };
    } catch (e) {
      print('❌ 결제 검증 중 오류: $e');
      return {
        'success': false,
        'verified': false,
        'error': '결제 검증 중 오류: $e',
      };
    }
  }
  
  /// 포트원 채널 정보 조회 (테스트/실제 결제 구분용)
  /// 브라우저 SDK를 통해 채널 정보를 확인하거나 결제 응답에서 확인
  /// 서버 API 호출은 불가능하므로 브라우저 SDK 또는 결제 응답에서만 확인 가능
  static Future<Map<String, dynamic>> getChannelInfo({
    required String channelKey,
    String? apiSecret, // 사용하지 않음 (서버 API 호출 불가)
  }) async {
    // 서버 API 호출이 불가능하므로 브라우저 SDK를 통해 확인하거나
    // 결제 응답에서 확인하는 방법만 사용 가능
    // 채널 키 자체로는 테스트/실제 여부를 판별할 수 없음
    
    return {
      'success': false,
      'error': '서버 API 호출이 불가능합니다. 결제 응답에서 채널 정보를 확인하세요.',
      'isTest': null,
    };
  }
  
  /// 포트원 결제 취소 API 호출
  /// 
  /// [paymentId] 결제 ID (portone_payment_uid)
  /// [cancelAmount] 취소 금액 (null이면 전액 취소)
  /// [cancelReason] 취소 사유 (필수)
  /// 
  /// Returns: 취소 결과
  static Future<Map<String, dynamic>> cancelPayment({
    required String paymentId,
    int? cancelAmount,
    required String cancelReason,
  }) async {
    try {
      print('💳 포트원 결제 취소 요청: $paymentId');
      print('   - 취소 금액: ${cancelAmount != null ? "${cancelAmount}원" : "전액"}');
      print('   - 취소 사유: $cancelReason');
      
      final Map<String, dynamic> requestBody = {
        'storeId': storeId,
        'reason': cancelReason,
      };
      
      // 부분 취소인 경우에만 금액 포함
      if (cancelAmount != null) {
        requestBody['amount'] = cancelAmount;
      }
      
      final response = await http.post(
        Uri.parse('$portoneApiBaseUrl/payments/$paymentId/cancel'),
        headers: {
          'Authorization': 'PortOne $apiSecret',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      print('📋 포트원 취소 응답 상태: ${response.statusCode}');
      print('📋 포트원 취소 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ 포트원 결제 취소 성공');
        return {
          'success': true,
          'data': responseData,
        };
      } else {
        final errorData = jsonDecode(response.body);
        final errorType = errorData['type'] ?? 'UnknownError';
        final errorMessage = errorData['message'] ?? '결제 취소 실패';
        
        print('❌ 포트원 결제 취소 실패: $errorType - $errorMessage');
        
        return {
          'success': false,
          'error': errorMessage,
          'errorType': errorType,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ 포트원 결제 취소 오류: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 결제 응답에서 테스트 결제 여부 확인
  /// 포트원 SDK가 API와 통신할 때 채널 정보를 받아옴
  /// 결제 응답에 채널 정보가 포함되어 있음
  static bool? isTestPaymentFromResponse(Map<String, dynamic> paymentResponse) {
    try {
      print('🔍 결제 응답에서 채널 정보 확인 중...');
      print('🔍 응답 키 목록: ${paymentResponse.keys.toList()}');
      
      // 방법 1: channel.type 확인 (가장 확실한 방법)
      if (paymentResponse['channel'] != null) {
        final channel = paymentResponse['channel'];
        print('🔍 channel 필드 발견: $channel');
        
        if (channel is Map<String, dynamic>) {
          final channelType = channel['type'] as String?;
          print('🔍 channel.type: $channelType');
          
          if (channelType != null) {
            final isTest = channelType == 'TEST';
            print('✅ 채널 타입 확인: $channelType -> ${isTest ? "테스트" : "실제"}');
            return isTest;
          }
        } else if (channel is String) {
          // channel이 문자열로 올 수도 있음
          print('🔍 channel이 문자열: $channel');
        }
      }
      
      // 방법 2: channelType 직접 확인
      if (paymentResponse['channelType'] != null) {
        final channelType = paymentResponse['channelType'] as String?;
        print('🔍 channelType 필드: $channelType');
        if (channelType != null) {
          return channelType == 'TEST';
        }
      }
      
      // 방법 3: test 필드 확인
      if (paymentResponse['test'] != null) {
        final test = paymentResponse['test'];
        print('🔍 test 필드: $test');
        return test == true;
      }
      
      // 방법 4: isTest 필드 확인
      if (paymentResponse['isTest'] != null) {
        final isTest = paymentResponse['isTest'];
        print('🔍 isTest 필드: $isTest');
        return isTest == true;
      }
      
      print('⚠️ 결제 응답에 채널 정보가 없습니다.');
      return null; // 확인 불가
    } catch (e) {
      print('❌ 테스트 결제 여부 확인 오류: $e');
      return null;
    }
  }
}

