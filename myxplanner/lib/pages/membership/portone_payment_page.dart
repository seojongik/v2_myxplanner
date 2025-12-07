import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/portone_payment_service.dart';
import '../../services/tab_design_service.dart';
import '../../services/api_service.dart';

// 웹 환경에서 사용할 JavaScript 인터페이스
import '../../stubs/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import '../../stubs/js_stub.dart' if (dart.library.js) 'dart:js' as js;

/// 포트원 결제 페이지 (WebView 사용)
class PortonePaymentPage extends StatefulWidget {
  final String paymentId;
  final String channelKey;
  final String orderName;
  final int totalAmount;
  final String currency;
  final String payMethod; // 결제 수단 (CARD, EASY_PAY 등)
  final String? customerName; // 주문자명
  final Function(Map<String, dynamic>)? onPaymentSuccess;
  final Function(Map<String, dynamic>)? onPaymentFailed;

  const PortonePaymentPage({
    Key? key,
    required this.paymentId,
    required this.channelKey,
    required this.orderName,
    required this.totalAmount,
    this.currency = 'KRW',
    this.payMethod = 'CARD',
    this.customerName,
    this.onPaymentSuccess,
    this.onPaymentFailed,
  }) : super(key: key);

  @override
  _PortonePaymentPageState createState() => _PortonePaymentPageState();
}

class _PortonePaymentPageState extends State<PortonePaymentPage> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _isRedirectHandled = false; // 리디렉션 결과 처리 여부
  static const MethodChannel _intentChannel = MethodChannel('com.enabletech.autogolfcrm/intent_launcher');

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // 웹 환경에서는 WebView 대신 직접 포트원 SDK 사용
      _initializeWebPayment();
    } else {
      // 모바일 환경에서는 WebView 사용
      _initializeWebView();
    }
  }
  
  // localStorage에 결제 콜백 정보 저장 (리디렉션 후 복원용)
  void _savePaymentCallbackToStorage() {
    if (!kIsWeb) return;
    try {
      final storage = html.window.localStorage;
      storage['mgp_payment_callback_paymentId'] = widget.paymentId;
      storage['mgp_payment_callback_channelKey'] = widget.channelKey;
      storage['mgp_payment_callback_orderName'] = widget.orderName;
      storage['mgp_payment_callback_totalAmount'] = widget.totalAmount.toString();
      print('💾 결제 콜백 정보를 localStorage에 저장했습니다.');
    } catch (e) {
      print('⚠️ localStorage 저장 오류: $e');
    }
  }
  
  // localStorage에서 결제 콜백 정보 로드
  Map<String, dynamic>? _loadPaymentCallbackFromStorage() {
    if (!kIsWeb) return null;
    try {
      final storage = html.window.localStorage;
      final paymentId = storage['mgp_payment_callback_paymentId'];
      if (paymentId != null && paymentId == widget.paymentId) {
        return {
          'paymentId': paymentId,
          'channelKey': storage['mgp_payment_callback_channelKey'],
          'orderName': storage['mgp_payment_callback_orderName'],
          'totalAmount': int.tryParse(storage['mgp_payment_callback_totalAmount'] ?? '0') ?? 0,
        };
      }
    } catch (e) {
      print('⚠️ localStorage 로드 오류: $e');
    }
    return null;
  }
  
  // localStorage에서 결제 콜백 정보 제거
  void _clearPaymentCallbackFromStorage() {
    if (!kIsWeb) return;
    try {
      final storage = html.window.localStorage;
      storage.remove('mgp_payment_callback_paymentId');
      storage.remove('mgp_payment_callback_channelKey');
      storage.remove('mgp_payment_callback_orderName');
      storage.remove('mgp_payment_callback_totalAmount');
    } catch (e) {
      print('⚠️ localStorage 제거 오류: $e');
    }
  }

  // 모바일 웹 환경 감지
  bool _isMobileWeb() {
    if (!kIsWeb) return false;
    try {
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      final isMobile = userAgent.contains('mobile') || 
                       userAgent.contains('android') || 
                       userAgent.contains('iphone') || 
                       userAgent.contains('ipad') ||
                       userAgent.contains('ipod');
      print('📱 User-Agent: ${html.window.navigator.userAgent}');
      print('📱 모바일 웹 감지: $isMobile');
      return isMobile;
    } catch (e) {
      print('⚠️ 모바일 웹 감지 오류: $e');
      return false;
    }
  }

  // 리디렉션 URL 생성 (현재 페이지로 리디렉션)
  String _getRedirectUrl() {
    try {
      // 현재 페이지의 전체 URL을 가져옴
      final currentUrl = html.window.location.href;
      final uri = Uri.parse(currentUrl);
      
      // 쿼리 파라미터에 리디렉션 정보 추가
      final redirectParams = {
        ...uri.queryParameters,
        'portone_payment_id': widget.paymentId,
        'portone_redirect': 'true',
      };
      
      // 같은 페이지로 리디렉션 (해시 유지)
      final redirectUrl = uri.replace(
        queryParameters: redirectParams,
        fragment: uri.fragment, // 기존 해시 유지
      ).toString();
      
      print('🔗 리디렉션 URL: $redirectUrl');
      return redirectUrl;
    } catch (e) {
      print('⚠️ 리디렉션 URL 생성 오류: $e');
      // 기본값으로 현재 URL 반환
      return html.window.location.href;
    }
  }

  // 웹 환경에서 포트원 결제 초기화
  void _initializeWebPayment() {
    // 결제 콜백 정보를 localStorage에 저장 (리디렉션 후 복원용)
    _savePaymentCallbackToStorage();
    
    // 채널 정보 확인 (테스트/실제 결제 구분)
    _checkChannelInfo();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 리디렉션 결과 확인 (리디렉션 후 페이지 로드 시)
      // 리디렉션 후에도 같은 결제 페이지가 열려있어야 함
      final redirectHandled = _checkRedirectResult();
      if (!redirectHandled) {
        // 리디렉션 결과가 없으면 결제 요청 진행
        _loadPortoneSDKAndRequestPayment();
      }
    });
  }
  
  // 채널 정보 확인 (테스트/실제 결제 구분)
  // 포트원 SDK가 로드된 후 JavaScript를 통해 채널 정보 확인
  void _checkChannelInfo() async {
    try {
      debugPrint('📋 사용 중인 채널 키: ${widget.channelKey}');
      
      if (!kIsWeb) {
        debugPrint('📋 모바일 환경에서는 결제 응답에서 채널 정보를 확인합니다.');
        return;
      }
      
      // 포트원 SDK가 로드될 때까지 대기
      await _ensurePortoneSDKLoaded();
      
      // JavaScript를 통해 포트원 SDK에서 채널 정보 확인 시도
      try {
        final portone = js.context['PortOne'];
        if (portone != null) {
          debugPrint('🔍 포트원 SDK에서 채널 정보 확인 시도...');
          
          // 포트원 SDK의 채널 정보 조회 메서드가 있는지 확인
          // SDK 내부적으로 채널 정보를 가지고 있을 수 있음
          // 또는 requestPayment 전에 채널 정보를 확인할 수 있는 방법이 있을 수 있음
          
          // 임시로 결제 요청 전에 채널 정보를 확인하는 방법 시도
          // 포트원 SDK가 내부적으로 채널 정보를 가지고 있는지 확인
          debugPrint('📋 포트원 SDK 로드 완료. 결제 요청 시 채널 정보를 확인합니다.');
        }
      } catch (e) {
        debugPrint('⚠️ 포트원 SDK 채널 정보 확인 오류: $e');
      }
    } catch (e) {
      debugPrint('⚠️ 채널 정보 확인 오류: $e');
    }
  }

  // URL 정리 (리디렉션 파라미터 제거) - 페이지 재로드 방지
  void _cleanRedirectUrl() {
    try {
      // 현재 상태를 저장하여 페이지 재로드 방지
      final currentState = html.window.history.state;
      
      final uri = Uri.parse(html.window.location.href);
      // 리디렉션 관련 파라미터 제거
      final cleanParams = Map<String, String>.from(uri.queryParameters);
      cleanParams.remove('portone_redirect');
      cleanParams.remove('portone_payment_id');
      cleanParams.remove('paymentId');
      cleanParams.remove('txId');
      cleanParams.remove('code');
      cleanParams.remove('message');
      cleanParams.remove('pgCode');
      cleanParams.remove('pgMessage');
      
      // 해시에서도 리디렉션 파라미터 제거
      String cleanHash = uri.fragment;
      if (cleanHash.contains('portone_redirect')) {
        // 해시에서 리디렉션 관련 부분 제거
        final hashParts = cleanHash.split('?');
        if (hashParts.length > 1) {
          final hashParams = Uri.splitQueryString(hashParts[1]);
          hashParams.remove('portone_redirect');
          hashParams.remove('portone_payment_id');
          hashParams.remove('paymentId');
          hashParams.remove('txId');
          hashParams.remove('code');
          hashParams.remove('message');
          
          if (hashParams.isEmpty) {
            cleanHash = hashParts[0];
          } else {
            cleanHash = '${hashParts[0]}?${Uri(queryParameters: hashParams).query}';
          }
        } else {
          cleanHash = hashParts[0];
        }
      }
      
      // 깨끗한 URL로 변경 (히스토리 교체, 페이지 재로드 방지)
      final cleanUri = uri.replace(
        queryParameters: cleanParams.isEmpty ? null : cleanParams,
        fragment: cleanHash.isEmpty ? null : cleanHash,
      );
      
      // replaceState를 사용하여 페이지 재로드 없이 URL만 변경
      html.window.history.replaceState(currentState, '', cleanUri.toString());
      print('🧹 URL 정리 완료 (페이지 재로드 없음): ${cleanUri.toString()}');
    } catch (e) {
      print('⚠️ URL 정리 오류: $e');
    }
  }

  // 리디렉션 후 결제 결과 확인
  // 반환값: 리디렉션 결과를 처리했는지 여부
  bool _checkRedirectResult() {
    try {
      final uri = Uri.parse(html.window.location.href);
      // 쿼리 파라미터와 해시 모두에서 리디렉션 플래그 확인
      final isRedirect = uri.queryParameters['portone_redirect'] == 'true' ||
                        uri.fragment.contains('portone_redirect=true');
      
      if (isRedirect && !_isRedirectHandled) {
        debugPrint('🔄🔄🔄 리디렉션 결과 확인 중...');
        debugPrint('🔄 현재 URL: ${html.window.location.href}');
        debugPrint('🔄 쿼리 파라미터: ${uri.queryParameters}');
        debugPrint('🔄 해시: ${uri.fragment}');
        _isRedirectHandled = true;
        
        // URL에서 결제 결과 파라미터 확인
        // 포트원이 리디렉션 시 전달하는 파라미터 확인 (쿼리 파라미터와 해시 모두 확인)
        Map<String, String> allParams = Map<String, String>.from(uri.queryParameters);
        
        // 해시에서도 파라미터 추출
        if (uri.fragment.contains('?')) {
          final hashParts = uri.fragment.split('?');
          if (hashParts.length > 1) {
            final hashParams = Uri.splitQueryString(hashParts[1]);
            allParams.addAll(hashParams);
          }
        }
        
        final paymentId = allParams['paymentId'];
        final txId = allParams['txId'];
        final code = allParams['code'];
        final message = allParams['message'];
        final pgCode = allParams['pgCode'];
        final pgMessage = allParams['pgMessage'];
        final expectedPaymentId = uri.queryParameters['portone_payment_id'] ?? 
                                 (uri.fragment.contains('portone_payment_id=') 
                                  ? uri.fragment.split('portone_payment_id=')[1].split('&')[0] 
                                  : null);
        
        debugPrint('🔄🔄🔄 리디렉션 파라미터 확인:');
        debugPrint('🔄 paymentId=$paymentId');
        debugPrint('🔄 expectedPaymentId=$expectedPaymentId');
        debugPrint('🔄 txId=$txId');
        debugPrint('🔄 code=$code');
        debugPrint('🔄 message=$message');
        debugPrint('🔄 allParams=$allParams');
        
        // 예상한 결제 ID와 실제 결제 ID가 일치하는지 확인
        if (expectedPaymentId != null && paymentId != null && paymentId != expectedPaymentId) {
          print('❌ 결제 ID 불일치: 예상=$expectedPaymentId, 실제=$paymentId');
          setState(() {
            _isLoading = false;
          });
          if (widget.onPaymentFailed != null) {
            widget.onPaymentFailed!({
              'code': 'PAYMENT_ID_MISMATCH',
              'message': '결제 정보가 일치하지 않습니다.',
            });
          }
          if (mounted) {
            Navigator.of(context).pop(false);
          }
          return true;
        }
        
        if (code != null) {
          // 결제 실패
          print('❌ 리디렉션 결과: 결제 실패 - $code: $message');
          setState(() {
            _isLoading = false;
          });
          
          // 결제 결과 처리 후 URL 정리
          if (widget.onPaymentFailed != null) {
            widget.onPaymentFailed!({
              'code': code,
              'message': message ?? '결제 실패',
              'pgCode': pgCode,
              'pgMessage': pgMessage,
            });
          }
          
          // 페이지 닫기
          if (mounted) {
            Navigator.of(context).pop(false);
            // 페이지가 닫힌 후 URL 정리 (페이지 재로드 방지)
            Future.delayed(Duration(milliseconds: 200), () {
              _cleanRedirectUrl();
            });
          }
          return true;
        } else if (paymentId != null && paymentId.isNotEmpty) {
          // 결제 성공 - paymentId와 txId가 모두 있어야 실제 결제 완료로 간주
          // 리디렉션 방식에서는 txId가 없을 수도 있으므로 paymentId만 확인
          print('✅ 리디렉션 결과: 결제 성공 - $paymentId');
          
          // 리디렉션 응답에서 테스트 결제 여부 확인
          // 리디렉션 방식에서는 응답 데이터가 제한적이므로 채널 키로 추정
          // 정확한 확인은 결제 조회 API를 통해 가능
          final redirectResponse = {
            'paymentId': paymentId,
            'txId': txId,
            'channel': {'key': widget.channelKey}, // 채널 정보는 채널 키만 있음
          };
          final isTest = PortonePaymentService.isTestPaymentFromResponse(redirectResponse);
          if (isTest == true) {
            debugPrint('⚠️ 리디렉션 결과: 테스트 결제 모드입니다. 실제 결제가 이루어지지 않습니다.');
          } else if (isTest == false) {
            debugPrint('✅ 리디렉션 결과: 실제 결제 모드입니다.');
          }
          
          // paymentId가 실제 결제 ID 형식인지 확인 (포트원 결제 ID는 특정 형식)
          // widget.paymentId와 비교하여 일치하는지 확인
          if (paymentId != widget.paymentId) {
            print('❌ 결제 ID 불일치: 예상=${widget.paymentId}, 실제=$paymentId');
            setState(() {
              _isLoading = false;
            });
            if (widget.onPaymentFailed != null) {
              widget.onPaymentFailed!({
                'code': 'PAYMENT_ID_MISMATCH',
                'message': '결제 정보가 일치하지 않습니다.',
              });
            }
            if (mounted) {
              Navigator.of(context).pop(false);
              Future.delayed(Duration(milliseconds: 200), () {
                _cleanRedirectUrl();
              });
            }
            return true;
          }
          
          // paymentId 형식 검증 (포트원 결제 ID는 'payment'로 시작하고 길이가 충분해야 함)
          if (!paymentId.startsWith('payment') || paymentId.length < 15) {
            print('❌ 잘못된 결제 ID 형식: $paymentId');
            setState(() {
              _isLoading = false;
            });
            if (widget.onPaymentFailed != null) {
              widget.onPaymentFailed!({
                'code': 'INVALID_PAYMENT_ID',
                'message': '결제 정보가 올바르지 않습니다.',
              });
            }
            if (mounted) {
              Navigator.of(context).pop(false);
              Future.delayed(Duration(milliseconds: 200), () {
                _cleanRedirectUrl();
              });
            }
            return true;
          }
          
          setState(() {
            _isLoading = false;
          });
          
          // 결제 성공 콜백 즉시 호출 (리디렉션 후)
          // 리디렉션 후 페이지가 재로드되었지만 같은 결제 페이지가 열려있어야 함
          debugPrint('✅✅✅ 결제 성공 확인 완료!');
          debugPrint('✅ paymentId: $paymentId');
          debugPrint('✅ txId: $txId');
          debugPrint('✅ 콜백 존재 여부: ${widget.onPaymentSuccess != null}');
          debugPrint('✅ 위젯 마운트 여부: $mounted');
          
          // localStorage에 결제 결과 저장 (리디렉션 후 복원용)
          if (kIsWeb) {
            try {
              final storage = html.window.localStorage;
              storage['mgp_payment_result_paymentId'] = paymentId;
              storage['mgp_payment_result_txId'] = txId ?? '';
              storage['mgp_payment_result_status'] = 'success';
              storage['mgp_payment_result_expectedId'] = widget.paymentId;
              storage['mgp_payment_result_channelKey'] = widget.channelKey;
              storage['mgp_payment_result_orderName'] = widget.orderName;
              storage['mgp_payment_result_totalAmount'] = widget.totalAmount.toString();
              print('💾 결제 결과를 localStorage에 저장했습니다.');
            } catch (e) {
              print('⚠️ localStorage 저장 오류: $e');
            }
          }
          
          if (widget.onPaymentSuccess != null) {
            debugPrint('📞📞📞 리디렉션 후 결제 성공 콜백 호출 시작');
            debugPrint('📞 결제 ID: $paymentId, TxId: $txId');
            
            // 채널 키로 테스트 여부 확인 (결제 응답에 채널 정보가 없어도 채널 키로 판단 가능)
            bool? finalIsTest = isTest;
            if (finalIsTest == null) {
              // 테스트 채널 키 목록
            const testChannelKeys = [
                'channel-key-4103c2a4-ab14-4707-bdb3-6c6254511ba0', // 토스페이먼츠 테스트 키
                'channel-key-bc51c093-a46c-45cc-934a-c805007abe3d',
                'channel-key-601c7153-6a75-45e0-b2df-09b67a45b452',
                'channel-key-77102617-6e37-4f2f-bf37-e6e54b8c6417',
              ];
              finalIsTest = testChannelKeys.contains(widget.channelKey);
              debugPrint('📋 채널 키로 테스트 여부 확인: ${widget.channelKey} -> ${finalIsTest ? "테스트" : "실제"}');
            }
            
            // 즉시 콜백 호출 (동기적으로)
            try {
              debugPrint('📞 콜백 즉시 호출 시도...');
              // 콜백을 Future로 감싸서 처리
              final callbackResult = widget.onPaymentSuccess!({
                'paymentId': paymentId,
                'txId': txId,
                'isTest': finalIsTest, // 채널 키로 확인한 테스트 여부
                'channelKey': widget.channelKey,
              });
              
              debugPrint('✅ 리디렉션 후 결제 성공 콜백 호출 완료');
              
              // 콜백이 Future를 반환하는 경우 처리
              if (callbackResult is Future) {
                callbackResult.then((_) {
                  debugPrint('✅ 콜백 처리 완료, 결제 페이지 닫기');
                  _clearPaymentCallbackFromStorage();
                  if (mounted) {
                    Navigator.of(context).pop(true);
                  }
                }).catchError((e) {
                  debugPrint('❌ 콜백 처리 오류: $e');
                  _clearPaymentCallbackFromStorage();
                  if (mounted) {
                    Navigator.of(context).pop(true);
                  }
                });
              } else {
                // 콜백이 동기적으로 완료된 경우
                debugPrint('✅ 콜백 동기 처리 완료, 결제 페이지 닫기');
                _clearPaymentCallbackFromStorage();
                Future.delayed(Duration(milliseconds: 100), () {
                  if (mounted) {
                    Navigator.of(context).pop(true);
                  }
                });
              }
            } catch (e, stackTrace) {
              debugPrint('❌ 리디렉션 후 결제 성공 콜백 오류: $e');
              debugPrint('❌ 스택 트레이스: $stackTrace');
              _clearPaymentCallbackFromStorage();
              // 콜백 실패 시에도 페이지는 닫기
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            }
          } else {
            // 콜백이 없으면 localStorage에서 결과를 확인하고 처리
            debugPrint('⚠️ 콜백이 없습니다. localStorage에서 결과 확인...');
            _clearPaymentCallbackFromStorage();
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          }
          
          // URL 정리는 나중에 (콜백 처리 후)
          Future.delayed(Duration(milliseconds: 500), () {
            _cleanRedirectUrl();
          });
          
          return true;
        } else {
          // 리디렉션은 되었지만 결과 파라미터가 없는 경우
          debugPrint('⚠️ 리디렉션되었지만 결과 파라미터가 없습니다.');
          // URL 정리 후 계속 진행 (결제 요청)
          return false;
        }
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ 리디렉션 결과 확인 오류: $e');
      return false;
    }
  }

  // 포트원 SDK 로드 보장 (재시도 로직 포함)
  Future<void> _ensurePortoneSDKLoaded({int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // 이미 로드되어 있는지 확인
        try {
          if (js.context.hasProperty('PortOne')) {
            final portone = js.context['PortOne'];
            if (portone != null) {
              // requestPayment 메서드가 있는지 확인
              try {
                final requestPayment = portone['requestPayment'];
                if (requestPayment != null) {
                  print('✅ 포트원 SDK가 이미 로드되어 있습니다.');
                  return;
                }
              } catch (e) {
                // hasProperty가 없으면 직접 접근 시도
                print('⚠️ SDK 확인 중: $e');
              }
            }
          }
        } catch (e) {
          print('⚠️ SDK 확인 중 오류 (무시): $e');
        }

        // 기존 스크립트 태그 제거 (재시도 시)
        if (attempt > 0) {
          final existingScripts = html.document.querySelectorAll('script[src*="portone.io"]');
          for (var script in existingScripts) {
            script.remove();
          }
          // 잠시 대기
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }

        debugPrint('📦 포트원 SDK 로드 시도 ${attempt + 1}/$maxRetries');

        // 포트원 SDK 스크립트 로드
        final script = html.ScriptElement()
          ..src = 'https://cdn.portone.io/v2/browser-sdk.js'
          ..type = 'text/javascript'
          ..async = true;
        
        html.document.head!.append(script);
        
        // SDK 로드 대기 (모바일 웹에서 더 긴 시간 필요)
        await script.onLoad.first.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('포트원 SDK 로드 시간 초과 (15초)');
          },
        );

        // SDK가 완전히 로드되었는지 확인
        int checkCount = 0;
        while (checkCount < 10) {
          await Future.delayed(Duration(milliseconds: 200));
          
          if (js.context.hasProperty('PortOne')) {
            final portone = js.context['PortOne'];
            if (portone != null) {
              // requestPayment 메서드가 있는지 확인
              try {
                final requestPayment = portone['requestPayment'];
                if (requestPayment != null) {
                  debugPrint('✅ 포트원 SDK 로드 완료');
                  return;
                }
              } catch (e) {
                debugPrint('⚠️ 포트원 SDK 확인 중 오류: $e');
              }
            }
          }
          checkCount++;
        }

        // 마지막 확인
        if (js.context.hasProperty('PortOne') && 
            js.context['PortOne'] != null) {
          debugPrint('✅ 포트원 SDK 로드 완료 (최종 확인)');
          return;
        }

        throw Exception('포트원 SDK가 로드되었지만 초기화되지 않았습니다.');
      } catch (e) {
        debugPrint('❌ 포트원 SDK 로드 실패 (시도 ${attempt + 1}/$maxRetries): $e');
        
        if (attempt == maxRetries - 1) {
          // 마지막 시도 실패
          throw Exception('포트원 SDK 로드 실패: $e');
        }
      }
    }
  }

  void _loadPortoneSDKAndRequestPayment() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 포트원 SDK 로드 및 확인 (재시도 로직 포함)
      await _ensurePortoneSDKLoaded();

      // 포트원 결제 요청
      final portone = js.context['PortOne'];
      if (portone == null) {
        throw Exception('포트원 SDK를 찾을 수 없습니다.');
      }
      
      // requestPayment 메서드 확인
      try {
        final requestPayment = portone['requestPayment'];
        if (requestPayment == null) {
          throw Exception('포트원 SDK의 requestPayment 메서드를 찾을 수 없습니다.');
        }
      } catch (e) {
        throw Exception('포트원 SDK 초기화 확인 실패: $e');
      }

      // 결제 요청 파라미터
      final isMobileWeb = _isMobileWeb();
      final redirectUrl = isMobileWeb ? _getRedirectUrl() : null;
      
      final paymentRequestMap = <String, dynamic>{
        'storeId': PortonePaymentService.storeId,
        'channelKey': widget.channelKey,
        'paymentId': widget.paymentId,
        'orderName': widget.orderName,
        'totalAmount': widget.totalAmount,
        'currency': widget.currency == 'KRW' ? 'CURRENCY_KRW' : widget.currency,
        'payMethod': widget.payMethod,
      };
      
      // 주문자 정보 추가 (customer 객체)
      if (widget.customerName != null && widget.customerName!.isNotEmpty) {
        paymentRequestMap['customer'] = {
          'fullName': widget.customerName,
        };
        debugPrint('👤 주문자 정보 추가: ${widget.customerName}');
      }
      
      // PC: 팝업 방식, 모바일: 리디렉션 방식
      if (isMobileWeb && redirectUrl != null) {
        paymentRequestMap['redirectUrl'] = redirectUrl;
        print('📱 모바일 웹 - 리디렉션 방식 사용');
      } else {
        print('💻 PC 웹 - 팝업 방식 사용');
      }
      
      final paymentRequest = js.JsObject.jsify(paymentRequestMap);

      // 포트원 결제 요청 전에 채널 정보 확인 시도
      // 포트원 SDK가 내부적으로 채널 정보를 가지고 있을 수 있음
      try {
        // 포트원 SDK의 채널 정보 확인 (가능한 경우)
        debugPrint('🔍 결제 요청 전 채널 정보 확인 시도...');
        // 포트원 SDK는 내부적으로 채널 정보를 가지고 있지만 직접 접근할 수 없을 수 있음
        // 결제 응답에서 확인하는 것이 가장 확실함
      } catch (e) {
        debugPrint('⚠️ 채널 정보 확인 오류 (무시): $e');
      }
      
      // 포트원 결제 요청 (Promise 반환)
      debugPrint('💳 포트원 결제 요청 시작');
      debugPrint('💳 결제 정보: ${widget.orderName}, ${widget.totalAmount}원');
      debugPrint('💳 채널 키: ${widget.channelKey}');
      
      final paymentPromise = portone.callMethod('requestPayment', [paymentRequest]);
      
      // Promise 처리
      paymentPromise.callMethod('then', [
        js.allowInterop((response) {
          debugPrint('💳 포트원 결제 응답 수신');
          
          // 결제 성공
          setState(() {
            _isLoading = false;
          });

          try {
            final responseMap = _jsObjectToMap(response);
            debugPrint('💳 결제 응답 데이터: $responseMap');
            
            // 포트원 SDK가 API와 통신할 때 채널 정보를 받아옴
            // 결제 응답에 채널 정보가 포함되어 있음
            final isTest = PortonePaymentService.isTestPaymentFromResponse(responseMap);
            
            if (isTest == true) {
              debugPrint('⚠️⚠️⚠️ 테스트 결제 모드입니다! 실제 결제가 이루어지지 않습니다.');
              debugPrint('   채널 타입: TEST');
              // 사용자에게 알림 표시
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('⚠️ 테스트 결제 모드입니다. 실제 결제가 이루어지지 않습니다.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            } else if (isTest == false) {
              debugPrint('✅ 실제 결제 모드입니다.');
              debugPrint('   채널 타입: LIVE');
            } else {
              // 응답에 채널 정보가 없으면 응답 전체를 로그로 출력하여 확인
              debugPrint('📋 결제 응답에 채널 정보가 없습니다. 응답 전체: $responseMap');
              debugPrint('📋 채널 정보 확인을 위해 응답 구조를 확인하세요.');
            }
            
            if (responseMap['code'] != null) {
              // 결제 실패
              debugPrint('❌ 결제 실패: ${responseMap['code']} - ${responseMap['message']}');
              if (widget.onPaymentFailed != null) {
                widget.onPaymentFailed!({
                  'code': responseMap['code'],
                  'message': responseMap['message'] ?? '결제 실패',
                  'pgCode': responseMap['pgCode'],
                  'pgMessage': responseMap['pgMessage'],
                  'isTest': isTest,
                });
              }
              Navigator.of(context).pop(false);
            } else {
              // 결제 성공 - paymentId와 txId 확인
              final paymentId = responseMap['paymentId'] ?? widget.paymentId;
              final txId = responseMap['txId'];
              
              if (paymentId == null || paymentId.toString().isEmpty) {
                print('❌ 결제 ID가 없습니다. 결제가 완료되지 않았습니다.');
                if (widget.onPaymentFailed != null) {
                  widget.onPaymentFailed!({
                    'code': 'MISSING_PAYMENT_ID',
                    'message': '결제 정보가 올바르지 않습니다.',
                    'isTest': isTest,
                  });
                }
                Navigator.of(context).pop(false);
                return;
              }
              
              debugPrint('✅ 결제 성공: $paymentId, txId: $txId');
              
              // 결제 응답에 채널 정보가 없으므로 결제 ID로 포트원 API 조회 시도
              // 하지만 브라우저에서 직접 호출하면 CORS 문제 발생
              // 서버에서 결제 정보를 조회하여 채널 정보를 확인해야 함
              // 현재는 결제 응답에서만 확인 가능하므로 채널 정보가 없으면 null
              
              if (isTest == true) {
                debugPrint('⚠️ 주의: 이 결제는 테스트 결제입니다. 실제 결제가 이루어지지 않았습니다.');
              } else if (isTest == null) {
                debugPrint('⚠️ 결제 응답에 채널 정보가 없어 테스트/실제 여부를 확인할 수 없습니다.');
                debugPrint('   서버에서 결제 정보를 조회하여 채널 정보를 확인해야 합니다.');
              }
              
              // 채널 키로 테스트 여부 확인 (결제 응답에 채널 정보가 없어도 채널 키로 판단 가능)
              bool? finalIsTest = isTest;
              if (finalIsTest == null) {
                // 테스트 채널 키 목록
              const testChannelKeys = [
                'channel-key-4103c2a4-ab14-4707-bdb3-6c6254511ba0', // 토스페이먼츠 테스트 키
                'channel-key-bc51c093-a46c-45cc-934a-c805007abe3d',
                'channel-key-601c7153-6a75-45e0-b2df-09b67a45b452',
                'channel-key-77102617-6e37-4f2f-bf37-e6e54b8c6417',
              ];
                finalIsTest = testChannelKeys.contains(widget.channelKey);
                debugPrint('📋 채널 키로 테스트 여부 확인: ${widget.channelKey} -> ${finalIsTest ? "테스트" : "실제"}');
              }
              
              // 결제 성공 콜백 호출 (비동기 처리)
              if (widget.onPaymentSuccess != null) {
                debugPrint('📞 결제 성공 콜백 호출 시작');
                // 콜백을 Future로 감싸서 처리
                final callbackResult = widget.onPaymentSuccess!({
                  'paymentId': paymentId.toString(),
                  'txId': txId?.toString(),
                  'isTest': finalIsTest, // 채널 키로 확인한 테스트 여부
                  'channelKey': widget.channelKey, // 채널 키는 전달
                });
                
                // 콜백이 Future를 반환하는 경우 처리
                if (callbackResult is Future) {
                  callbackResult.then((_) {
                    debugPrint('✅ 결제 성공 콜백 완료');
                  }).catchError((e) {
                    debugPrint('❌ 결제 성공 콜백 오류: $e');
                  });
                } else {
                  debugPrint('✅ 결제 성공 콜백 호출 완료');
                }
                // 결제 페이지는 콜백에서 처리 완료 후 닫도록 함
              } else {
                // 콜백이 없으면 바로 닫기
                Navigator.of(context).pop(true);
              }
            }
          } catch (e) {
            debugPrint('❌ 결제 응답 처리 오류: $e');
            if (widget.onPaymentFailed != null) {
              widget.onPaymentFailed!({
                'code': 'ERROR',
                'message': '결제 응답 처리 중 오류가 발생했습니다: $e',
              });
            }
            Navigator.of(context).pop(false);
          }
        }),
        js.allowInterop((error) {
          // 에러 발생
          debugPrint('❌ 포트원 결제 에러: $error');
          setState(() {
            _isLoading = false;
          });

          String errorMessage = '알 수 없는 오류가 발생했습니다.';
          try {
            if (error is js.JsObject) {
              final errorMap = _jsObjectToMap(error);
              errorMessage = errorMap['message']?.toString() ?? error.toString();
            } else {
              errorMessage = error.toString();
            }
          } catch (e) {
            errorMessage = error.toString();
          }

          if (widget.onPaymentFailed != null) {
            widget.onPaymentFailed!({
              'code': 'ERROR',
              'message': errorMessage,
            });
          }
          Navigator.of(context).pop(false);
        }),
      ]);
    } catch (e) {
      debugPrint('❌ 포트원 결제 초기화 오류: $e');
      debugPrint('❌ 오류 스택: ${StackTrace.current}');
      
      setState(() {
        _isLoading = false;
      });

      String errorMessage = '결제 초기화 중 오류가 발생했습니다.';
      if (e.toString().contains('시간 초과')) {
        errorMessage = '결제창을 불러오는 데 시간이 오래 걸립니다. 네트워크 연결을 확인하고 다시 시도해주세요.';
      } else if (e.toString().contains('SDK')) {
        errorMessage = '결제 시스템을 불러올 수 없습니다. 인터넷 연결을 확인하고 다시 시도해주세요.';
      } else {
        errorMessage = '결제 초기화 중 오류가 발생했습니다: ${e.toString()}';
      }

      if (widget.onPaymentFailed != null) {
        widget.onPaymentFailed!({
          'code': 'ERROR',
          'message': errorMessage,
        });
      }
      Navigator.of(context).pop(false);
    }
  }

  // JavaScript 객체를 Dart Map으로 변환
  Map<String, dynamic> _jsObjectToMap(js.JsObject jsObject) {
    final map = <String, dynamic>{};
    
    // JavaScript의 Object.keys()를 사용하여 키 목록 가져오기
    final objectKeys = js.context['Object'].callMethod('keys', [jsObject]);
    final keysList = objectKeys as js.JsArray;
    
    for (var i = 0; i < keysList.length; i++) {
      final key = keysList[i] as String;
      final value = jsObject[key];
      
      if (value is js.JsObject) {
        map[key] = _jsObjectToMap(value);
      } else if (value is js.JsArray) {
        // 배열인 경우 리스트로 변환
        map[key] = _jsArrayToList(value);
      } else {
        map[key] = value;
      }
    }
    return map;
  }
  
  // JavaScript 배열을 Dart List로 변환
  List<dynamic> _jsArrayToList(js.JsArray jsArray) {
    final list = <dynamic>[];
    for (var i = 0; i < jsArray.length; i++) {
      final value = jsArray[i];
      if (value is js.JsObject) {
        list.add(_jsObjectToMap(value));
      } else if (value is js.JsArray) {
        list.add(_jsArrayToList(value));
      } else {
        list.add(value);
      }
    }
    return list;
  }

  // APK 환경에서 리디렉션 URL 생성
  String _getAppRedirectUrl() {
    // 앱 내부 URL 스키마 사용 (포트원이 리디렉션할 URL)
    // 포트원이 결제 완료 후 이 URL로 리디렉션하고, 쿼리 파라미터로 결과 전달
    final redirectUrl = 'mygolfplanner.app://payment/result?paymentId=${widget.paymentId}';
    print('📱 APK 리디렉션 URL: $redirectUrl');
    return redirectUrl;
  }

  void _initializeWebView() {
    // APK 환경에서는 리디렉션 URL 필수
    final redirectUrl = _getAppRedirectUrl();
    
    final htmlContent = PortonePaymentService.generatePaymentHtml(
      paymentId: widget.paymentId,
      channelKey: widget.channelKey,
      orderName: widget.orderName,
      totalAmount: widget.totalAmount,
      currency: widget.currency,
      payMethod: widget.payMethod,
      redirectUrl: redirectUrl, // APK 환경에서 리디렉션 URL 필수
      customerName: widget.customerName, // 주문자명 추가
    );

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(true) // 줌 허용
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36') // 모바일 User-Agent 설정
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            
            // 포트원 결제 완료 페이지로 리다이렉트된 경우 감지
            // (포트원이 자동으로 처리하므로 대부분 JavaScript 채널로 처리됨)
            print('페이지 로드 완료: $url');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            print('네비게이션 요청: $url');
            
            // 포트원 결제 완료 후 리디렉션 URL 감지
            if (url.startsWith('mygolfplanner.app://payment/result')) {
              print('🔄 포트원 리디렉션 감지: $url');
              _handleRedirectUrl(url);
              // 리디렉션 URL은 WebView에서 처리하지 않고 앱에서 처리
              return NavigationDecision.prevent;
            }
            
            // intent:// 또는 intent: 스킴 처리 (카카오페이, 네이버페이, 현대카드 등)
            if (url.startsWith('intent://') || url.startsWith('intent:')) {
              print('🔗 intent URL 감지: $url');
              // intent: 로 시작하는 경우 올바르게 정규화
              // intent:SCHEME://... -> intent://SCHEME/... (://를 /로 변경)
              String normalizedUrl = url;
              if (url.startsWith('intent:') && !url.startsWith('intent://')) {
                // intent:hdcardappcardansimclick://... -> intent://hdcardappcardansimclick/...
                final match = RegExp(r'intent:([^:]+)://').firstMatch(url);
                if (match != null) {
                  final scheme = match.group(1);
                  normalizedUrl = url.replaceFirst(RegExp(r'intent:[^:]+://'), 'intent://$scheme/');
                  print('🔗 정규화된 URL: $normalizedUrl');
                } else {
                  // 정규식 매칭 실패 시 그대로 전달
                  normalizedUrl = url;
                }
              }
              _handleIntentUrl(normalizedUrl);
              return NavigationDecision.prevent;
            }
            
            // 외부 앱 스킴 처리 (카드사 앱, 간편결제 앱 등)
            // kftc-bankpay://, ispmobile://, supertoss://, kakaotalk://, payco:// 등
            if (!url.startsWith('http://') && !url.startsWith('https://') && !url.startsWith('data:')) {
              print('📱 외부 앱 스킴 감지: $url');
              // APK 환경에서는 직접 처리
              if (!kIsWeb) {
                // 비동기로 앱 실행 시도, 실패하면 WebView에서 이전 페이지로 돌아감
                _launchExternalApp(url).then((success) {
                  if (!success) {
                    print('⚠️ 앱 실행 실패, WebView에서 이전 페이지로 돌아감');
                    // 앱이 없으면 WebView에서 이전 페이지로 돌아가기
                    Future.delayed(Duration(milliseconds: 300), () {
                      _webViewController?.goBack();
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('앱이 설치되지 않았습니다. 웹페이지로 진행합니다.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                });
                // 앱 실행 시도 (성공하면 앱으로 이동, 실패하면 WebView에서 이전 페이지로 돌아감)
                return NavigationDecision.prevent;
              }
              // 웹 환경에서는 WebView가 자동 처리
              return NavigationDecision.navigate;
            }
            
            // HTTP/HTTPS URL은 WebView 내에서 계속 진행
            // 카드사 결제 페이지 등 모든 웹페이지는 WebView에서 로드
            print('🌐 웹페이지 로드: $url');
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView 오류: ${error.description}');
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

  // 외부 앱 실행 (네이티브 Intent 사용 또는 url_launcher 사용)
  // 반환값: 앱 실행 성공 여부 (false면 WebView에서 원래 페이지로 돌아감)
  Future<bool> _launchExternalApp(String url) async {
    try {
      print('📱 외부 앱 실행 시도: $url');
      
      // APK 환경에서는 네이티브 Intent 사용 (더 안정적)
      if (!kIsWeb) {
        try {
          final result = await _intentChannel.invokeMethod<bool>('launchIntent', {'url': url});
          if (result == true) {
            print('✅ 네이티브 Intent 실행 성공');
            return true;
          } else {
            print('⚠️ 네이티브 Intent 실행 실패 (앱 미설치 또는 오류)');
            // 앱이 없으면 WebView에서 원래 페이지로 돌아가도록 false 반환
            return false;
          }
        } catch (e) {
          print('⚠️ 네이티브 Intent 채널 오류: $e, url_launcher로 시도');
        }
      }
      
      // 웹 환경이거나 네이티브 Intent 실패 시 url_launcher 사용
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ url_launcher로 외부 앱 실행 성공');
        return true;
      } else {
        print('❌ 외부 앱을 실행할 수 없습니다: $url');
        // 앱이 없으면 false 반환하여 WebView에서 원래 페이지로 돌아가도록 함
        return false;
      }
    } catch (e) {
      print('❌ 외부 앱 실행 오류: $e');
      // 오류 발생 시에도 false 반환하여 WebView에서 처리하도록 함
      return false;
    }
  }

  // intent:// URL 처리 (카카오페이, 네이버페이 등)
  void _handleIntentUrl(String intentUrl) {
    try {
      print('🔗 intent:// URL 파싱 시작: $intentUrl');
      
      // intent:// URL 형식: intent://path?params#Intent;scheme=xxx;package=xxx;end
      // 예: intent://kakaopay/pg?...&url=...#Intent;scheme=kakaotalk;package=com.kakao.talk;end
      
      final hashIndex = intentUrl.indexOf('#Intent');
      if (hashIndex == -1) {
        print('⚠️ Intent 섹션을 찾을 수 없습니다.');
        return;
      }
      
      final intentPart = intentUrl.substring(hashIndex + 7); // '#Intent' 제거
      final endIndex = intentPart.indexOf(';end');
      if (endIndex == -1) {
        print('⚠️ Intent 종료 마커를 찾을 수 없습니다.');
        return;
      }
      
      final intentParams = intentPart.substring(0, endIndex);
      print('🔗 Intent 파라미터: $intentParams');
      
      // scheme과 package 추출
      String? scheme;
      String? package;
      String? actualUrl;
      
      final params = intentParams.split(';');
      for (final param in params) {
        if (param.startsWith('scheme=')) {
          scheme = param.substring(7);
        } else if (param.startsWith('package=')) {
          package = param.substring(8);
        }
      }
      
      // URL 파라미터에서 실제 URL 추출 (쿼리 파라미터에서)
      final queryStart = intentUrl.indexOf('?');
      final hashStart = intentUrl.indexOf('#Intent');
      if (queryStart != -1 && hashStart != -1) {
        final queryString = intentUrl.substring(queryStart + 1, hashStart);
        final queryParams = Uri.splitQueryString(queryString);
        actualUrl = queryParams['url'];
        if (actualUrl != null) {
          actualUrl = Uri.decodeComponent(actualUrl);
        }
      }
      
      print('🔗 파싱 결과:');
      print('   scheme: $scheme');
      print('   package: $package');
      print('   actualUrl: $actualUrl');
      
      // 실제 앱 스킴으로 변환하여 실행
      String? appUrl;
      
      // 카카오페이의 경우: kakaotalk:// 스킴으로 실제 URL을 열어야 함
      if (scheme == 'kakaotalk' && actualUrl != null) {
        // 카카오톡 앱에서 웹뷰로 열기
        // 실제로는 intent:// URL 자체를 Android Intent로 변환해야 하지만,
        // 간단하게 scheme://url 형식으로 시도
        appUrl = actualUrl; // 실제 URL을 직접 열기
        // 또는 kakaotalk://open?url= 형식으로 시도할 수도 있음
      } else if (scheme != null && actualUrl != null) {
        // 다른 앱의 경우 scheme과 URL 조합
        appUrl = '$scheme://$actualUrl';
      } else if (scheme != null) {
        // scheme만 있는 경우
        appUrl = '$scheme://';
      }
      
      // APK 환경에서는 원본 intent:// URL을 그대로 네이티브로 전달
      if (!kIsWeb) {
        print('📱 네이티브 Intent로 실행: $intentUrl');
        _launchExternalApp(intentUrl).then((success) {
          if (!success) {
            print('⚠️ intent:// 앱 실행 실패, WebView에서 이전 페이지로 돌아감');
            // 앱이 없으면 WebView에서 이전 페이지로 돌아가기
            Future.delayed(Duration(milliseconds: 300), () {
              _webViewController?.goBack();
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('앱이 설치되지 않았습니다. 웹페이지로 진행합니다.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        });
      } else if (appUrl != null) {
        print('📱 앱 실행 URL: $appUrl');
        _launchExternalApp(appUrl);
      } else {
        print('⚠️ 실행할 URL을 생성할 수 없습니다.');
      }
    } catch (e) {
      print('❌ intent:// URL 처리 오류: $e');
    }
  }

  // 리디렉션 URL에서 결제 결과 처리
  void _handleRedirectUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final queryParams = uri.queryParameters;
      
      print('🔄 리디렉션 URL 파싱: $queryParams');
      
      // 포트원이 리디렉션 시 전달하는 파라미터 확인
      final paymentId = queryParams['paymentId'];
      final txId = queryParams['txId'];
      final code = queryParams['code'];
      final message = queryParams['message'];
      final pgCode = queryParams['pgCode'];
      final pgMessage = queryParams['pgMessage'];
      
      // 결제 성공 (code가 없거나 SUCCESS인 경우)
      if (code == null || code == 'SUCCESS') {
        if (txId != null && paymentId == widget.paymentId) {
          print('✅ 결제 성공: paymentId=$paymentId, txId=$txId');
          if (widget.onPaymentSuccess != null) {
            widget.onPaymentSuccess!({
              'paymentId': paymentId,
              'txId': txId,
            });
          }
          Navigator.of(context).pop(true);
          return;
        }
      }
      
      // 결제 실패
      print('❌ 결제 실패: code=$code, message=$message');
      if (widget.onPaymentFailed != null) {
        widget.onPaymentFailed!({
          'code': code ?? 'UNKNOWN',
          'message': message ?? '알 수 없는 오류',
          'pgCode': pgCode,
          'pgMessage': pgMessage,
        });
      }
      Navigator.of(context).pop(false);
    } catch (e) {
      print('❌ 리디렉션 URL 처리 오류: $e');
      if (widget.onPaymentFailed != null) {
        widget.onPaymentFailed!({
          'code': 'ERROR',
          'message': '리디렉션 처리 중 오류 발생: $e',
        });
      }
      Navigator.of(context).pop(false);
    }
  }

  void _handlePaymentMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'payment_success') {
        final paymentId = data['paymentId'] as String?;
        final txId = data['txId'] as String?;
        
        if (widget.onPaymentSuccess != null) {
          // 콜백 호출 (결제 페이지는 아직 열려있음)
          widget.onPaymentSuccess!({
            'paymentId': paymentId,
            'txId': txId,
          });
          // 결제 페이지는 콜백에서 처리 완료 후 닫도록 함
        } else {
          // 콜백이 없으면 바로 닫기
          Navigator.of(context).pop(true);
        }
      } else if (type == 'payment_failed') {
        if (widget.onPaymentFailed != null) {
          widget.onPaymentFailed!({
            'code': data['code'],
            'message': data['message'],
            'pgCode': data['pgCode'],
            'pgMessage': data['pgMessage'],
          });
        }
        
        Navigator.of(context).pop(false);
      } else if (type == 'payment_error') {
        if (widget.onPaymentFailed != null) {
          widget.onPaymentFailed!({
            'code': 'ERROR',
            'message': data['error'] ?? '알 수 없는 오류',
          });
        }
        
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      print('결제 메시지 처리 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 웹 환경에서는 포트원 SDK를 직접 사용
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          title: Text(
            '결제 진행',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        bottomNavigationBar: TabDesignService.buildBottomNavigationBar(
          context: context,
          selectedIndex: 3, // 회원권 탭
        ),
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading) ...[
                    CircularProgressIndicator(color: Color(0xFF3B82F6)),
                    SizedBox(height: 16),
                    Text(
                      '결제창을 불러오는 중...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.payment,
                      size: 64,
                      color: Color(0xFF3B82F6),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '결제 진행 중...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '결제창이 열렸습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 모바일 환경에서는 WebView 사용
    if (_webViewController == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          title: Text(
            '결제 진행',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        bottomNavigationBar: TabDesignService.buildBottomNavigationBar(
          context: context,
          selectedIndex: 3, // 회원권 탭
        ),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        title: Text(
          '결제 진행',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      bottomNavigationBar: TabDesignService.buildBottomNavigationBar(
        context: context,
        selectedIndex: 3, // 회원권 탭
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
                    CircularProgressIndicator(color: Color(0xFF3B82F6)),
                    SizedBox(height: 16),
                    Text(
                      '결제창을 불러오는 중...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

