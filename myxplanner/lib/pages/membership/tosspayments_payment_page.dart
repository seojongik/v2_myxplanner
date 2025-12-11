import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/tosspayments_service.dart';
import '../../services/tab_design_service.dart';

// 웹 환경에서 사용할 JavaScript 인터페이스
import '../../stubs/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import '../../stubs/js_stub.dart' if (dart.library.js) 'dart:js' as js;

/// 토스페이먼츠 결제 페이지 (포트원 없이 직접 연동)
/// 
/// 결제 플로우:
/// 1. 결제창 열기 (SDK v2)
/// 2. 사용자 결제 진행
/// 3. successUrl로 리다이렉트 (paymentKey, orderId, amount 포함)
/// 4. **서버에서 결제 승인 API 호출** (필수!)
/// 5. 결제 완료
class TosspaymentsPaymentPage extends StatefulWidget {
  final String orderId;
  final String orderName;
  final int totalAmount;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final Function(Map<String, dynamic>)? onPaymentSuccess;
  final Function(Map<String, dynamic>)? onPaymentFailed;

  const TosspaymentsPaymentPage({
    Key? key,
    required this.orderId,
    required this.orderName,
    required this.totalAmount,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.onPaymentSuccess,
    this.onPaymentFailed,
  }) : super(key: key);

  @override
  _TosspaymentsPaymentPageState createState() => _TosspaymentsPaymentPageState();
}

class _TosspaymentsPaymentPageState extends State<TosspaymentsPaymentPage> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _isProcessing = false; // 결제 승인 처리 중
  bool _isRedirectHandled = false;
  static const MethodChannel _intentChannel = MethodChannel('app.mygolfplanner/intent_launcher');

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeWebPayment();
    } else {
      _initializeWebView();
    }
  }

  // ============================================================
  // 웹 환경 결제 처리
  // ============================================================

  void _initializeWebPayment() {
    _savePaymentInfoToStorage();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final redirectHandled = _checkRedirectResult();
      if (!redirectHandled) {
        _loadTosspaymentsSDKAndRequestPayment();
      }
    });
  }

  // localStorage에 결제 정보 저장 (리디렉션 후 복원용)
  void _savePaymentInfoToStorage() {
    if (!kIsWeb) return;
    try {
      final storage = html.window.localStorage;
      storage['toss_payment_orderId'] = widget.orderId;
      storage['toss_payment_orderName'] = widget.orderName;
      storage['toss_payment_totalAmount'] = widget.totalAmount.toString();
      debugPrint('💾 결제 정보를 localStorage에 저장했습니다.');
    } catch (e) {
      debugPrint('⚠️ localStorage 저장 오류: $e');
    }
  }

  void _clearPaymentInfoFromStorage() {
    if (!kIsWeb) return;
    try {
      final storage = html.window.localStorage;
      storage.remove('toss_payment_orderId');
      storage.remove('toss_payment_orderName');
      storage.remove('toss_payment_totalAmount');
      storage.remove('toss_payment_paymentKey');
    } catch (e) {
      debugPrint('⚠️ localStorage 제거 오류: $e');
    }
  }

  // 리디렉션 URL 생성
  String _getSuccessUrl() {
    try {
      final currentUrl = html.window.location.href;
      final uri = Uri.parse(currentUrl);
      final redirectParams = {
        ...uri.queryParameters,
        'toss_redirect': 'success',
        'expected_orderId': widget.orderId,
      };
      return uri.replace(queryParameters: redirectParams).toString();
    } catch (e) {
      debugPrint('⚠️ successUrl 생성 오류: $e');
      return html.window.location.href;
    }
  }

  String _getFailUrl() {
    try {
      final currentUrl = html.window.location.href;
      final uri = Uri.parse(currentUrl);
      final redirectParams = {
        ...uri.queryParameters,
        'toss_redirect': 'fail',
        'expected_orderId': widget.orderId,
      };
      return uri.replace(queryParameters: redirectParams).toString();
    } catch (e) {
      debugPrint('⚠️ failUrl 생성 오류: $e');
      return html.window.location.href;
    }
  }

  // 리디렉션 결과 확인
  bool _checkRedirectResult() {
    try {
      final uri = Uri.parse(html.window.location.href);
      final redirectType = uri.queryParameters['toss_redirect'];
      
      if (redirectType == null || _isRedirectHandled) {
        return false;
      }
      
      _isRedirectHandled = true;
      debugPrint('🔄 토스페이먼츠 리디렉션 감지: $redirectType');
      
      if (redirectType == 'success') {
        // 결제 성공 - 승인 처리 필요
        final paymentKey = uri.queryParameters['paymentKey'];
        final orderId = uri.queryParameters['orderId'];
        final amount = int.tryParse(uri.queryParameters['amount'] ?? '');
        
        debugPrint('✅ 결제 인증 성공!');
        debugPrint('   - paymentKey: $paymentKey');
        debugPrint('   - orderId: $orderId');
        debugPrint('   - amount: $amount');
        
        if (paymentKey != null && orderId != null && amount != null) {
          // 금액 검증
          if (amount != widget.totalAmount) {
            debugPrint('❌ 금액 불일치! 예상: ${widget.totalAmount}, 실제: $amount');
            _handlePaymentFailure({
              'code': 'AMOUNT_MISMATCH',
              'message': '결제 금액이 일치하지 않습니다.',
            });
            return true;
          }
          
          // 결제 승인 API 호출 (필수!)
          _confirmPayment(paymentKey, orderId, amount);
        } else {
          _handlePaymentFailure({
            'code': 'MISSING_PARAMS',
            'message': '결제 정보가 누락되었습니다.',
          });
        }
        return true;
        
      } else if (redirectType == 'fail') {
        // 결제 실패
        final code = uri.queryParameters['code'];
        final message = uri.queryParameters['message'];
        
        debugPrint('❌ 결제 실패: $code - $message');
        _handlePaymentFailure({
          'code': code ?? 'UNKNOWN',
          'message': message ?? '결제가 실패했습니다.',
        });
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('⚠️ 리디렉션 결과 확인 오류: $e');
      return false;
    }
  }

  // 결제 승인 API 호출 (핵심!)
  Future<void> _confirmPayment(String paymentKey, String orderId, int amount) async {
    setState(() {
      _isProcessing = true;
    });
    
    debugPrint('🔐 결제 승인 API 호출 시작...');
    
    try {
      final result = await TosspaymentsService.confirmPayment(
        paymentKey: paymentKey,
        orderId: orderId,
        amount: amount,
      );
      
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        debugPrint('✅ 결제 승인 성공!');
        debugPrint('   - status: ${data['status']}');
        debugPrint('   - approvedAt: ${data['approvedAt']}');
        
        // 결제 성공 콜백
        _handlePaymentSuccess({
          'paymentKey': paymentKey,
          'orderId': orderId,
          'amount': amount,
          'status': data['status'],
          'approvedAt': data['approvedAt'],
          'method': data['method'],
          'card': data['card'],
          'easyPay': data['easyPay'],
          'rawData': data,
        });
      } else {
        debugPrint('❌ 결제 승인 실패: ${result['error']}');
        _handlePaymentFailure({
          'code': result['errorCode'] ?? 'CONFIRM_FAILED',
          'message': result['error'] ?? '결제 승인에 실패했습니다.',
        });
      }
    } catch (e) {
      debugPrint('❌ 결제 승인 오류: $e');
      _handlePaymentFailure({
        'code': 'ERROR',
        'message': '결제 승인 중 오류가 발생했습니다: $e',
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // 토스페이먼츠 SDK 로드 및 결제 요청 (API 개별 연동 방식)
  Future<void> _loadTosspaymentsSDKAndRequestPayment() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // SDK 로드 대기
      await _ensureTosspaymentsSDKLoaded();

      // SDK 초기화 (API 개별 연동 키 사용)
      final tossPayments = js.context.callMethod('TossPayments', [TosspaymentsService.clientKey]);
      
      // 비회원 결제 (ANONYMOUS) - payment() 방식
      final paymentOptions = js.JsObject.jsify({
        'customerKey': js.context['TossPayments']['ANONYMOUS'],
      });
      final payment = tossPayments.callMethod('payment', [paymentOptions]);

      debugPrint('💳 토스페이먼츠 결제 요청 시작');
      debugPrint('   - orderId: ${widget.orderId}');
      debugPrint('   - orderName: ${widget.orderName}');
      debugPrint('   - amount: ${widget.totalAmount}');

      // 결제 요청 파라미터
      final requestParams = {
        'method': 'CARD',
        'amount': {
          'currency': 'KRW',
          'value': widget.totalAmount,
        },
        'orderId': widget.orderId,
        'orderName': widget.orderName,
        'successUrl': _getSuccessUrl(),
        'failUrl': _getFailUrl(),
        'card': {
          'useEscrow': false,
          'flowMode': 'DEFAULT',
          'useCardPoint': false,
          'useAppCardOnly': false,
        },
      };

      // 고객 정보 추가 (null이 아닐 때만)
      if (widget.customerName != null) {
        requestParams['customerName'] = widget.customerName!;
      }
      if (widget.customerEmail != null) {
        requestParams['customerEmail'] = widget.customerEmail!;
      }
      if (widget.customerPhone != null) {
        // 토스페이먼츠는 전화번호에 하이픈 없이 숫자만 허용
        final cleanPhone = widget.customerPhone!.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanPhone.isNotEmpty) {
          requestParams['customerMobilePhone'] = cleanPhone;
        }
      }

      final jsParams = js.JsObject.jsify(requestParams);

      // 결제 요청 (Promise 반환)
      final paymentPromise = payment.callMethod('requestPayment', [jsParams]);

      // Promise 처리 (에러만 처리, 성공은 리디렉션)
      paymentPromise.callMethod('catch', [
        js.allowInterop((error) {
          debugPrint('❌ 결제 요청 오류: $error');
          setState(() {
            _isLoading = false;
          });
          
          String errorCode = 'ERROR';
          String errorMessage = '결제 요청 중 오류가 발생했습니다.';
          
          try {
            if (error is js.JsObject) {
              final errorMap = _jsObjectToMap(error);
              errorCode = errorMap['code']?.toString() ?? errorCode;
              errorMessage = errorMap['message']?.toString() ?? errorMessage;
            }
          } catch (e) {
            errorMessage = error.toString();
          }
          
          // 사용자 취소인 경우
          if (errorCode == 'PAY_PROCESS_CANCELED' || errorMessage.contains('취소')) {
            _handlePaymentFailure({
              'code': 'USER_CANCELLED',
              'message': '결제가 취소되었습니다.',
            });
          } else {
            _handlePaymentFailure({
              'code': errorCode,
              'message': errorMessage,
            });
          }
        }),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 토스페이먼츠 초기화 오류: $e');
      setState(() {
        _isLoading = false;
      });
      _handlePaymentFailure({
        'code': 'INIT_ERROR',
        'message': '결제 초기화 중 오류가 발생했습니다: $e',
      });
    }
  }

  // 토스페이먼츠 SDK 로드 보장
  Future<void> _ensureTosspaymentsSDKLoaded({int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // 이미 로드되어 있는지 확인
        if (js.context.hasProperty('TossPayments')) {
          debugPrint('✅ 토스페이먼츠 SDK가 이미 로드되어 있습니다.');
          return;
        }

        // 기존 스크립트 제거 (재시도 시)
        if (attempt > 0) {
          final existingScripts = html.document.querySelectorAll('script[src*="tosspayments"]');
          for (var script in existingScripts) {
            script.remove();
          }
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }

        debugPrint('📦 토스페이먼츠 SDK 로드 시도 ${attempt + 1}/$maxRetries');

        // SDK 스크립트 로드
        final script = html.ScriptElement()
          ..src = 'https://js.tosspayments.com/v2/standard'
          ..type = 'text/javascript'
          ..async = true;
        
        html.document.head!.append(script);
        
        // 로드 대기
        await script.onLoad.first.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('토스페이먼츠 SDK 로드 시간 초과');
          },
        );

        // SDK 초기화 확인
        int checkCount = 0;
        while (checkCount < 10) {
          await Future.delayed(Duration(milliseconds: 200));
          if (js.context.hasProperty('TossPayments')) {
            debugPrint('✅ 토스페이먼츠 SDK 로드 완료');
            return;
          }
          checkCount++;
        }

        throw Exception('토스페이먼츠 SDK가 로드되었지만 초기화되지 않았습니다.');
      } catch (e) {
        debugPrint('❌ 토스페이먼츠 SDK 로드 실패 (시도 ${attempt + 1}/$maxRetries): $e');
        if (attempt == maxRetries - 1) {
          throw Exception('토스페이먼츠 SDK 로드 실패: $e');
        }
      }
    }
  }

  Map<String, dynamic> _jsObjectToMap(js.JsObject jsObject) {
    final map = <String, dynamic>{};
    final objectKeys = js.context['Object'].callMethod('keys', [jsObject]);
    final keysList = objectKeys as js.JsArray;
    
    for (var i = 0; i < keysList.length; i++) {
      final key = keysList[i] as String;
      final value = jsObject[key];
      
      if (value is js.JsObject) {
        map[key] = _jsObjectToMap(value);
      } else {
        map[key] = value;
      }
    }
    return map;
  }

  // ============================================================
  // 모바일 환경 결제 처리 (WebView)
  // ============================================================

  String _getAppSuccessUrl() {
    return 'mygolfplanner.app://payment/toss/success?orderId=${widget.orderId}';
  }

  String _getAppFailUrl() {
    return 'mygolfplanner.app://payment/toss/fail?orderId=${widget.orderId}';
  }

  void _initializeWebView() {
    final htmlContent = TosspaymentsService.generatePaymentHtml(
      orderId: widget.orderId,
      orderName: widget.orderName,
      totalAmount: widget.totalAmount,
      customerName: widget.customerName,
      customerEmail: widget.customerEmail,
      customerPhone: widget.customerPhone,
      successUrl: _getAppSuccessUrl(),
      failUrl: _getAppFailUrl(),
    );

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(true)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            debugPrint('페이지 로드 완료: $url');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            debugPrint('네비게이션 요청: $url');

            // 결제 성공 리디렉션 감지
            if (url.startsWith('mygolfplanner.app://payment/toss/success')) {
              debugPrint('✅ 결제 성공 리디렉션 감지');
              _handleAppRedirectSuccess(url);
              return NavigationDecision.prevent;
            }

            // 결제 실패 리디렉션 감지
            if (url.startsWith('mygolfplanner.app://payment/toss/fail')) {
              debugPrint('❌ 결제 실패 리디렉션 감지');
              _handleAppRedirectFail(url);
              return NavigationDecision.prevent;
            }

            // intent:// URL 처리
            if (url.startsWith('intent://') || url.startsWith('intent:')) {
              _handleIntentUrl(url);
              return NavigationDecision.prevent;
            }

            // 외부 앱 스킴 처리
            if (!url.startsWith('http://') && !url.startsWith('https://') && !url.startsWith('data:')) {
              _launchExternalApp(url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView 오류: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handlePaymentMessage(message.message);
        },
      )
      ..loadRequest(
        Uri.dataFromString(
          htmlContent,
          mimeType: 'text/html',
          encoding: Encoding.getByName('utf-8'),
        ),
      );
  }

  // 앱 리디렉션 성공 처리
  void _handleAppRedirectSuccess(String url) async {
    try {
      final uri = Uri.parse(url);
      final paymentKey = uri.queryParameters['paymentKey'];
      final orderId = uri.queryParameters['orderId'];
      final amount = int.tryParse(uri.queryParameters['amount'] ?? '');

      debugPrint('📱 앱 리디렉션 성공');
      debugPrint('   - paymentKey: $paymentKey');
      debugPrint('   - orderId: $orderId');
      debugPrint('   - amount: $amount');

      if (paymentKey != null && orderId != null && amount != null) {
        // 금액 검증
        if (amount != widget.totalAmount) {
          _handlePaymentFailure({
            'code': 'AMOUNT_MISMATCH',
            'message': '결제 금액이 일치하지 않습니다.',
          });
          return;
        }

        // 결제 승인 API 호출
        await _confirmPayment(paymentKey, orderId, amount);
      } else {
        _handlePaymentFailure({
          'code': 'MISSING_PARAMS',
          'message': '결제 정보가 누락되었습니다.',
        });
      }
    } catch (e) {
      debugPrint('❌ 앱 리디렉션 처리 오류: $e');
      _handlePaymentFailure({
        'code': 'ERROR',
        'message': '결제 처리 중 오류가 발생했습니다.',
      });
    }
  }

  // 앱 리디렉션 실패 처리
  void _handleAppRedirectFail(String url) {
    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];
    final message = uri.queryParameters['message'];

    _handlePaymentFailure({
      'code': code ?? 'UNKNOWN',
      'message': message ?? '결제가 실패했습니다.',
    });
  }

  // intent:// URL 처리
  void _handleIntentUrl(String intentUrl) async {
    try {
      debugPrint('🔗 intent:// URL 처리: $intentUrl');
      
      final success = await _launchExternalApp(intentUrl);
      if (!success) {
        debugPrint('⚠️ 앱 실행 실패');
        Future.delayed(Duration(milliseconds: 300), () {
          _webViewController?.goBack();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('앱이 설치되지 않았습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ intent:// URL 처리 오류: $e');
    }
  }

  // 외부 앱 실행
  Future<bool> _launchExternalApp(String url) async {
    try {
      if (!kIsWeb) {
        try {
          final result = await _intentChannel.invokeMethod<bool>('launchIntent', {'url': url});
          if (result == true) {
            return true;
          }
        } catch (e) {
          debugPrint('⚠️ 네이티브 Intent 채널 오류: $e');
        }
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ 외부 앱 실행 오류: $e');
      return false;
    }
  }

  // JavaScript 채널 메시지 처리
  void _handlePaymentMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'payment_cancelled') {
        _handlePaymentFailure({
          'code': 'USER_CANCELLED',
          'message': data['message'] ?? '결제가 취소되었습니다.',
        });
      } else if (type == 'payment_error') {
        _handlePaymentFailure({
          'code': data['code'] ?? 'ERROR',
          'message': data['message'] ?? '결제 중 오류가 발생했습니다.',
        });
      }
    } catch (e) {
      debugPrint('결제 메시지 처리 오류: $e');
    }
  }

  // ============================================================
  // 공통 처리
  // ============================================================

  void _handlePaymentSuccess(Map<String, dynamic> data) {
    debugPrint('✅ 결제 성공 처리');
    _clearPaymentInfoFromStorage();
    
    if (widget.onPaymentSuccess != null) {
      final callbackResult = widget.onPaymentSuccess!(data);
      if (callbackResult is Future) {
        callbackResult.then((_) {
          if (mounted) Navigator.of(context).pop(true);
        }).catchError((e) {
          debugPrint('❌ 콜백 오류: $e');
          if (mounted) Navigator.of(context).pop(true);
        });
      } else {
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    } else {
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  void _handlePaymentFailure(Map<String, dynamic> data) {
    debugPrint('❌ 결제 실패 처리: ${data['code']} - ${data['message']}');
    _clearPaymentInfoFromStorage();
    
    if (widget.onPaymentFailed != null) {
      widget.onPaymentFailed!(data);
    }
    
    if (mounted) Navigator.of(context).pop(false);
  }

  // ============================================================
  // UI 빌드
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // 결제 승인 처리 중 UI
    if (_isProcessing) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Color(0xFF0064FF), // 토스 블루
          foregroundColor: Colors.white,
          title: Text('결제 승인 중', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF0064FF)),
              SizedBox(height: 24),
              Text(
                '결제를 승인하는 중입니다...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
              ),
              SizedBox(height: 8),
              Text(
                '잠시만 기다려주세요',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      );
    }

    // 웹 환경
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Color(0xFF0064FF),
          foregroundColor: Colors.white,
          title: Text('결제 진행', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        bottomNavigationBar: TabDesignService.buildBottomNavigationBar(
          context: context,
          selectedIndex: 3,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                CircularProgressIndicator(color: Color(0xFF0064FF)),
                SizedBox(height: 16),
                Text('결제창을 불러오는 중...', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              ] else ...[
                Icon(Icons.payment, size: 64, color: Color(0xFF0064FF)),
                SizedBox(height: 16),
                Text('결제 진행 중...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1F2937))),
                SizedBox(height: 8),
                Text('결제창이 열렸습니다', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              ],
            ],
          ),
        ),
      );
    }

    // 모바일 환경 (WebView)
    if (_webViewController == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Color(0xFF0064FF),
          foregroundColor: Colors.white,
          title: Text('결제 진행', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0064FF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF0064FF),
        foregroundColor: Colors.white,
        title: Text('결제 진행', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      bottomNavigationBar: TabDesignService.buildBottomNavigationBar(
        context: context,
        selectedIndex: 3,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController!),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF0064FF)),
                    SizedBox(height: 16),
                    Text('결제창을 불러오는 중...', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

