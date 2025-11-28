import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'services/sms_auth_service.dart';
import 'pages/phone_auth/phone_input_page.dart';
import 'login_page.dart';
import 'main_page.dart';
import 'login_branch_select.dart';
import 'admin_branch_select.dart';
import 'admin_member_select.dart';
import 'services/api_service.dart';
import 'index.dart';
import 'crm_member_redirect_page.dart';
import 'utils/debug_logger.dart';
import 'stubs/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'services/fcm_service.dart';
import 'services/supabase_adapter.dart';

void main() async {
  // 강제로 로그 출력 (예외 발생 전에도 보이도록)
  print('🚀🚀🚀 main() 함수 시작 🚀🚀🚀');
  debugPrint('🚀🚀🚀 main() 함수 시작 🚀🚀🚀');
  DebugLogger.log('🚀🚀🚀 main() 함수 시작 🚀🚀🚀', tag: 'MAIN');
  
  try {
    // Flutter 바인딩 초기화
    print('🚀 [STEP 1] Flutter 바인딩 초기화 시작');
    debugPrint('🚀 [STEP 1] Flutter 바인딩 초기화 시작');
    WidgetsFlutterBinding.ensureInitialized();
    print('✅ [STEP 1] Flutter 바인딩 초기화 완료');
    debugPrint('✅ [STEP 1] Flutter 바인딩 초기화 완료');
    
    // 화면 방향을 세로 모드로 고정
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    print('✅ [STEP 1.5] 화면 방향 세로 모드로 고정 완료');
    debugPrint('✅ [STEP 1.5] 화면 방향 세로 모드로 고정 완료');
    
    // 웹 환경에서 localStorage에서 로그인 상태 복원
    if (kIsWeb) {
      print('💾 [STEP 1.5] localStorage에서 로그인 상태 복원 시작');
      debugPrint('💾 [STEP 1.5] localStorage에서 로그인 상태 복원 시작');
      ApiService.restoreLoginState();
      print('✅ [STEP 1.5] 로그인 상태 복원 완료');
      debugPrint('✅ [STEP 1.5] 로그인 상태 복원 완료');
    }
    
    // 플랫폼 확인
    print('🚀 [STEP 2] 플랫폼 확인');
    debugPrint('🚀 [STEP 2] 플랫폼 확인');
    print('🚀 [STEP 2] kIsWeb: $kIsWeb');
    debugPrint('🚀 [STEP 2] kIsWeb: $kIsWeb');
    print('🚀 [STEP 2] defaultTargetPlatform: $defaultTargetPlatform');
    debugPrint('🚀 [STEP 2] defaultTargetPlatform: $defaultTargetPlatform');
    
    // Firebase 초기화 (웹에서는 조건부)
    print('🔥 [STEP 3] Firebase 초기화 블록 진입');
    debugPrint('🔥 [STEP 3] Firebase 초기화 블록 진입');
    print('🔥 [STEP 3] 플랫폼: ${kIsWeb ? "웹" : "네이티브"}');
    debugPrint('🔥 [STEP 3] 플랫폼: ${kIsWeb ? "웹" : "네이티브"}');
    
    if (kIsWeb) {
      print('🔥 [STEP 3] 웹 환경 - Firebase 초기화 건너뛰기');
      debugPrint('🔥 [STEP 3] 웹 환경 - Firebase 초기화 건너뛰기');
      print('⚠️ [STEP 3] 웹에서는 JavaScript Firebase SDK 사용 예정');
      debugPrint('⚠️ [STEP 3] 웹에서는 JavaScript Firebase SDK 사용 예정');
    } else {
      print('🔥 [STEP 3] 네이티브 환경 - Flutter Firebase 초기화 시작');
      debugPrint('🔥 [STEP 3] 네이티브 환경 - Flutter Firebase 초기화 시작');
      try {
        print('🔥 [STEP 3] Firebase 옵션 생성 중...');
        debugPrint('🔥 [STEP 3] Firebase 옵션 생성 중...');
        final options = DefaultFirebaseOptions.currentPlatform;
        print('🔥 [STEP 3] 프로젝트 ID: ${options.projectId}');
        debugPrint('🔥 [STEP 3] 프로젝트 ID: ${options.projectId}');
        print('🔥 [STEP 3] API 키: ${options.apiKey.substring(0, 10)}...');
        debugPrint('🔥 [STEP 3] API 키: ${options.apiKey.substring(0, 10)}...');
        print('🔥 [STEP 3] 앱 ID: ${options.appId}');
        debugPrint('🔥 [STEP 3] 앱 ID: ${options.appId}');
        
        print('🔥 [STEP 3] Firebase.initializeApp 호출 중...');
        debugPrint('🔥 [STEP 3] Firebase.initializeApp 호출 중...');
        
        // 네이티브 플러그인이 준비될 때까지 충분히 대기 (네이티브 Firebase 초기화 완료 대기)
        await Future.delayed(Duration(milliseconds: 2000));
        
        // 재시도 로직 추가 (더 많은 시도와 더 긴 대기 시간)
        int retryCount = 0;
        const maxRetries = 5;
        bool initialized = false;
        
        while (retryCount < maxRetries && !initialized) {
          try {
            await Firebase.initializeApp(options: options);
            initialized = true;
            print('✅ [STEP 3] Firebase 초기화 성공! (시도 ${retryCount + 1})');
            debugPrint('✅ [STEP 3] Firebase 초기화 성공! (시도 ${retryCount + 1})');
          } catch (e, stackTrace) {
            retryCount++;
            print('❌ [STEP 3] Firebase 초기화 실패 (시도 ${retryCount}/${maxRetries})');
            debugPrint('❌ [STEP 3] Firebase 초기화 실패 (시도 ${retryCount}/${maxRetries})');
            print('❌ [STEP 3] 에러 타입: ${e.runtimeType}');
            debugPrint('❌ [STEP 3] 에러 타입: ${e.runtimeType}');
            print('❌ [STEP 3] 에러 메시지: $e');
            debugPrint('❌ [STEP 3] 에러 메시지: $e');
            print('❌ [STEP 3] 스택 트레이스:');
            debugPrint('❌ [STEP 3] 스택 트레이스:');
            print(stackTrace);
            debugPrint(stackTrace.toString());
            
            // PlatformException인 경우 상세 정보 출력
            if (e.toString().contains('PlatformException')) {
              print('❌ [STEP 3] PlatformException 감지 - 네이티브 플러그인 통신 문제');
              debugPrint('❌ [STEP 3] PlatformException 감지 - 네이티브 플러그인 통신 문제');
              print('❌ [STEP 3] 가능한 원인:');
              debugPrint('❌ [STEP 3] 가능한 원인:');
              print('   1. 네이티브 Firebase 플러그인이 아직 준비되지 않음');
              debugPrint('   1. 네이티브 Firebase 플러그인이 아직 준비되지 않음');
              print('   2. Flutter 엔진과 네이티브 코드 간 채널 연결 실패');
              debugPrint('   2. Flutter 엔진과 네이티브 코드 간 채널 연결 실패');
              print('   3. google-services.json 파일이 빌드에 포함되지 않음');
              debugPrint('   3. google-services.json 파일이 빌드에 포함되지 않음');
              print('   4. Firebase 플러그인 버전 불일치');
              debugPrint('   4. Firebase 플러그인 버전 불일치');
            }
            
            if (retryCount < maxRetries) {
              // 각 재시도마다 대기 시간 증가 (2초, 3초, 4초, 5초)
              final waitTime = 1000 * (retryCount + 1);
              print('⏳ [STEP 3] ${waitTime}ms 후 재시도...');
              debugPrint('⏳ [STEP 3] ${waitTime}ms 후 재시도...');
              await Future.delayed(Duration(milliseconds: waitTime));
            } else {
              print('❌ [STEP 3] 모든 재시도 실패 (총 ${maxRetries}회 시도)');
              debugPrint('❌ [STEP 3] 모든 재시도 실패 (총 ${maxRetries}회 시도)');
              print('❌ [STEP 3] 최종 에러: $e');
              debugPrint('❌ [STEP 3] 최종 에러: $e');
              print('❌ [STEP 3] Firebase 없이 앱 계속 실행 (채팅 기능 사용 불가)');
              debugPrint('❌ [STEP 3] Firebase 없이 앱 계속 실행 (채팅 기능 사용 불가)');
              rethrow; // 마지막 시도 실패 시 예외 다시 던지기
            }
          }
        }
        
        print('✅ [STEP 3] Firebase.apps.length: ${Firebase.apps.length}');
        debugPrint('✅ [STEP 3] Firebase.apps.length: ${Firebase.apps.length}');
        
        if (Firebase.apps.isNotEmpty) {
          final app = Firebase.app();
          print('✅ [STEP 3] Firebase 앱 이름: ${app.name}');
          debugPrint('✅ [STEP 3] Firebase 앱 이름: ${app.name}');
          print('✅ [STEP 3] Firebase 프로젝트 ID: ${app.options.projectId}');
          debugPrint('✅ [STEP 3] Firebase 프로젝트 ID: ${app.options.projectId}');
          
          // Firestore 테스트
          try {
            final firestore = FirebaseFirestore.instance;
            print('✅ [STEP 3] Firestore 인스턴스 생성 성공');
            debugPrint('✅ [STEP 3] Firestore 인스턴스 생성 성공');
          } catch (e) {
            print('⚠️ [STEP 3] Firestore 인스턴스 생성 실패: $e');
            debugPrint('⚠️ [STEP 3] Firestore 인스턴스 생성 실패: $e');
          }
        }
        
      } catch (e, stackTrace) {
        print('❌ [STEP 3] Firebase 초기화 실패');
        debugPrint('❌ [STEP 3] Firebase 초기화 실패');
        print('❌ [STEP 3] 에러: $e');
        debugPrint('❌ [STEP 3] 에러: $e');
        print('❌ [STEP 3] 에러 타입: ${e.runtimeType}');
        debugPrint('❌ [STEP 3] 에러 타입: ${e.runtimeType}');
        print('❌ [STEP 3] 스택 트레이스: $stackTrace');
        debugPrint('❌ [STEP 3] 스택 트레이스: $stackTrace');
        print('⚠️ [STEP 3] Firebase 없이 앱 계속 실행');
        debugPrint('⚠️ [STEP 3] Firebase 없이 앱 계속 실행');
        print('⚠️ [STEP 3] 채팅 기능은 사용할 수 없습니다');
        debugPrint('⚠️ [STEP 3] 채팅 기능은 사용할 수 없습니다');
        print('⚠️ [STEP 3] 가능한 원인:');
        debugPrint('⚠️ [STEP 3] 가능한 원인:');
        print('   1. 네트워크 연결 문제');
        debugPrint('   1. 네트워크 연결 문제');
        print('   2. google-services.json 파일 문제');
        debugPrint('   2. google-services.json 파일 문제');
        print('   3. Firebase 프로젝트 설정 문제');
        debugPrint('   3. Firebase 프로젝트 설정 문제');
        print('   4. 인터넷 권한 문제 (AndroidManifest.xml 확인)');
        debugPrint('   4. 인터넷 권한 문제 (AndroidManifest.xml 확인)');
      }
    }
    
    // 최종 Firebase 상태 확인
    print('🔍 [STEP 4] 최종 Firebase 상태 확인');
    debugPrint('🔍 [STEP 4] 최종 Firebase 상태 확인');
    print('🔍 [STEP 4] Firebase.apps.length: ${Firebase.apps.length}');
    debugPrint('🔍 [STEP 4] Firebase.apps.length: ${Firebase.apps.length}');
    if (Firebase.apps.isNotEmpty) {
      for (var i = 0; i < Firebase.apps.length; i++) {
        final app = Firebase.apps[i];
        print('🔍 [STEP 4] Firebase 앱 [$i]: ${app.name} (${app.options.projectId})');
        debugPrint('🔍 [STEP 4] Firebase 앱 [$i]: ${app.name} (${app.options.projectId})');
      }
    } else {
      print('⚠️ [STEP 4] Firebase 앱이 없습니다!');
      debugPrint('⚠️ [STEP 4] Firebase 앱이 없습니다!');
    }
    
    // Supabase 초기화 (useSupabase = true 인 경우)
    if (ApiService.useSupabase) {
      print('🚀 [STEP 4.5] Supabase 초기화 시작');
      debugPrint('🚀 [STEP 4.5] Supabase 초기화 시작');
      try {
        await SupabaseAdapter.initialize();
        print('✅ [STEP 4.5] Supabase 초기화 완료');
        debugPrint('✅ [STEP 4.5] Supabase 초기화 완료');
      } catch (e) {
        print('❌ [STEP 4.5] Supabase 초기화 실패: $e');
        debugPrint('❌ [STEP 4.5] Supabase 초기화 실패: $e');
        print('⚠️ [STEP 4.5] PHP API로 폴백합니다');
        debugPrint('⚠️ [STEP 4.5] PHP API로 폴백합니다');
      }
    }
    
    // API 서비스 초기화
    print('🚀 [STEP 5] API 서비스 초기화');
    debugPrint('🚀 [STEP 5] API 서비스 초기화');
    await ApiService.initializeReservationSystem(branchId: 'test');
    print('✅ [STEP 5] API 서비스 초기화 완료');
    debugPrint('✅ [STEP 5] API 서비스 초기화 완료');
    
    // FCM 초기화 (네이티브 환경에서만)
    if (!kIsWeb) {
      print('🚀 [STEP 5.5] FCM 서비스 초기화');
      debugPrint('🚀 [STEP 5.5] FCM 서비스 초기화');
      try {
        await FCMService.initialize();
        print('✅ [STEP 5.5] FCM 서비스 초기화 완료');
        debugPrint('✅ [STEP 5.5] FCM 서비스 초기화 완료');
      } catch (e) {
        print('⚠️ [STEP 5.5] FCM 서비스 초기화 실패: $e');
        debugPrint('⚠️ [STEP 5.5] FCM 서비스 초기화 실패: $e');
      }
    }
    
    print('🚀 [STEP 6] MyGolfPlannerApp 실행');
    debugPrint('🚀 [STEP 6] MyGolfPlannerApp 실행');
    runApp(MyGolfPlannerApp());
    print('✅ [STEP 6] MyGolfPlannerApp 실행 완료');
    debugPrint('✅ [STEP 6] MyGolfPlannerApp 실행 완료');
    
  } catch (e, stackTrace) {
    debugPrint('💥💥💥 main() 함수에서 예외 발생 💥💥💥');
    debugPrint('💥 에러: $e');
    debugPrint('💥 스택 트레이스: $stackTrace');
    rethrow;
  }
}


// 개발 모드 설정
const bool kForceLoginOnHotReload = true; // Hot reload 시 강제 로그인 페이지 이동

class MyGolfPlannerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SmsAuthService(),
      child: MaterialApp(
      title: 'MyGolfPlanner - 골프 예약 관리 시스템',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      locale: Locale('ko', 'KR'),
      home: AppInitializer(),
      routes: {
        '/login': (context) => LoginPage(),
        '/login-branch-select': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return LoginBranchSelectPage(
            memberData: args?['memberData'] ?? {},
            memberBranches: List<String>.from(args?['memberBranches'] ?? []),
          );
        },
        '/admin-login': (context) => AdminBranchSelectPage(),
        '/admin-member-select': (context) {
          print('📍 [Route] /admin-member-select 진입');
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          print('📍 [Route] arguments: $args');
          final branchData = args?['branchData'] as Map<String, dynamic>?;
          print('📍 [Route] branchData: $branchData');

          if (branchData == null) {
            print('📍 [Route] branchData 없음 - AdminBranchSelectPage로');
            // 브랜치 정보가 없으면 브랜치 선택 페이지로
            return AdminBranchSelectPage();
          }

          print('📍 [Route] AdminMemberSelectPage 생성');
          return AdminMemberSelectPage(branchData: branchData);
        },
        '/main': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return MainPage(
            isAdminMode: args?['isAdminMode'] ?? false,
            selectedMember: args?['selectedMember'],
            branchId: args?['branchId'],
          );
        },
        '/phone-auth': (context) => PhoneInputPage(),
        '/crm-member': (context) {
          return CrmMemberRedirectPage();
        },
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => LoginPage(),
        );
      },
      ),
    );
  }
}

// 앱 초기화 위젯 - 로그인 상태를 확인하고 적절한 페이지로 라우팅
class AppInitializer extends StatefulWidget {
  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() {
    // Hot reload 시에도 로그인 상태를 확인
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 웹 환경에서 결제 완료 후 리디렉션 결과 확인
      bool hasPendingPayment = false;
      if (kIsWeb) {
        hasPendingPayment = await _checkPaymentRedirectResult();
      }
      
      // 개발 모드에서 강제 로그인 페이지 이동 설정이 켜져 있으면
      if (kForceLoginOnHotReload && !hasPendingPayment) {
        debugPrint('🚧 개발 모드: 강제 로그인 페이지 이동');
        await ApiService.logout(); // 로그인 상태 초기화
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      
      // 결제 결과가 있으면 로그인 상태를 먼저 복원
      if (hasPendingPayment && kIsWeb) {
        debugPrint('💳 결제 결과가 있음 - 로그인 상태 복원 시도');
        ApiService.restoreLoginState();
      }
      
      final currentUser = ApiService.getCurrentUser();
      final currentBranchId = ApiService.getCurrentBranchId();
      
      debugPrint('🔍 앱 초기화 - 현재 사용자: $currentUser');
      debugPrint('🔍 앱 초기화 - 현재 브랜치: $currentBranchId');
      
      if (currentUser != null && currentBranchId != null) {
        // 이미 로그인된 상태면 메인 페이지로 이동
        debugPrint('✅ 로그인 상태 확인됨 - 메인 페이지로 이동');
        Navigator.pushReplacementNamed(
          context,
          '/main',
          arguments: {
            'isAdminMode': false, // 기본값으로 설정
            'selectedMember': currentUser,
            'branchId': currentBranchId,
            'hasPendingPayment': hasPendingPayment, // 결제 결과 플래그 전달
          },
        );
      } else {
        // 로그인되지 않은 상태면 로그인 페이지로 이동
        debugPrint('❌ 로그인 상태 없음 - 로그인 페이지로 이동');
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  // 결제 완료 후 리디렉션 결과 확인 및 처리
  // 반환값: 결제 결과가 있는지 여부
  Future<bool> _checkPaymentRedirectResult() async {
    try {
      // URL 파라미터에서 결제 결과 확인
      final uri = Uri.parse(html.window.location.href);
      final isRedirect = uri.queryParameters['portone_redirect'] == 'true' ||
                         uri.fragment.contains('portone_redirect=true');
      
      if (!isRedirect) {
        // 리디렉션 플래그가 없으면 localStorage에서 확인
        final storage = html.window.localStorage;
        final paymentId = storage['mgp_payment_result_paymentId'];
        final txId = storage['mgp_payment_result_txId'];
        final status = storage['mgp_payment_result_status'];
        
        if (paymentId != null && status == 'success') {
          debugPrint('💳 localStorage에서 결제 결과 확인: $paymentId');
          // 결제 결과를 URL 파라미터로 변환하여 처리
          final redirectParams = {
            ...uri.queryParameters,
            'portone_redirect': 'true',
            'portone_payment_id': paymentId,
            'paymentId': paymentId,
            if (txId != null && txId.isNotEmpty) 'txId': txId,
          };
          
          final redirectUri = uri.replace(queryParameters: redirectParams);
          html.window.history.replaceState(null, '', redirectUri.toString());
          
          // localStorage에서 결제 결과 제거 (나중에 다시 저장)
          storage.remove('mgp_payment_result_paymentId');
          storage.remove('mgp_payment_result_txId');
          storage.remove('mgp_payment_result_status');
          
          // 결제 결과를 pending으로 이동
          storage['mgp_pending_payment_paymentId'] = paymentId;
          if (txId != null && txId.isNotEmpty) {
            storage['mgp_pending_payment_txId'] = txId;
          }
          storage['mgp_pending_payment_status'] = 'success';
          
          return true; // 결제 결과가 있음
        }
        return false;
      }
      
      // URL 파라미터에서 결제 결과 확인
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
      final expectedPaymentId = allParams['portone_payment_id'];
      
      if (isRedirect && paymentId != null && paymentId.isNotEmpty && code == null) {
        // 결제 성공
        debugPrint('✅ 리디렉션 후 결제 성공 확인: $paymentId');
        
        // 결제 결과를 localStorage에 저장 (메인 페이지에서 처리)
        final storage = html.window.localStorage;
        storage['mgp_pending_payment_paymentId'] = paymentId;
        if (txId != null && txId.isNotEmpty) {
          storage['mgp_pending_payment_txId'] = txId;
        }
        storage['mgp_pending_payment_status'] = 'success';
        if (expectedPaymentId != null) {
          storage['mgp_pending_payment_expectedId'] = expectedPaymentId;
        }
        
        // URL 정리 (리디렉션 파라미터 제거)
        final cleanParams = Map<String, String>.from(uri.queryParameters);
        cleanParams.remove('portone_redirect');
        cleanParams.remove('portone_payment_id');
        cleanParams.remove('paymentId');
        cleanParams.remove('txId');
        
        final cleanUri = uri.replace(queryParameters: cleanParams.isEmpty ? null : cleanParams);
        html.window.history.replaceState(null, '', cleanUri.toString());
        
        debugPrint('💾 결제 결과를 localStorage에 저장했습니다. 메인 페이지에서 처리됩니다.');
        return true; // 결제 결과가 있음
      } else if (isRedirect && code != null) {
        // 결제 실패
        debugPrint('❌ 리디렉션 후 결제 실패: $code');
        
        // URL 정리
        final cleanParams = Map<String, String>.from(uri.queryParameters);
        cleanParams.remove('portone_redirect');
        cleanParams.remove('portone_payment_id');
        cleanParams.remove('paymentId');
        cleanParams.remove('txId');
        cleanParams.remove('code');
        cleanParams.remove('message');
        
        final cleanUri = uri.replace(queryParameters: cleanParams.isEmpty ? null : cleanParams);
        html.window.history.replaceState(null, '', cleanUri.toString());
        return false; // 결제 실패는 처리할 필요 없음
      }
      
      return false;
    } catch (e) {
      debugPrint('⚠️ 결제 리디렉션 결과 확인 오류: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 화면 표시
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 20),
            Text(
              'MyGolfPlanner',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '앱을 초기화하고 있습니다...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 