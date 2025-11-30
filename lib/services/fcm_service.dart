import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'chatting/chatting_service.dart';
import 'supabase_adapter.dart';
import 'api_service.dart';
import 'notification_settings_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';

// 백그라운드 메시지 핸들러 (최상위 함수여야 함)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 [FCM] 백그라운드 메시지 수신: ${message.messageId}');
  print('🔔 [FCM] 데이터: ${message.data}');
  print('🔔 [FCM] 알림: ${message.notification?.title} - ${message.notification?.body}');
  
  // Firebase 초기화 (백그라운드 핸들러에서는 필요)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 백그라운드 알림 표시
  await _showBackgroundNotification(message);
}

Future<void> _showBackgroundNotification(RemoteMessage message) async {
  try {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Android 초기화 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print('🔔 [FCM] 알림 클릭: ${details.payload}');
      },
    );
    
    // 알림 표시
    const androidDetails = AndroidNotificationDetails(
      'chat_notifications',
      '채팅 알림',
      channelDescription: '1:1 채팅 메시지 알림',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? '새 메시지',
      message.notification?.body ?? message.data['message'] ?? '',
      notificationDetails,
      payload: message.data.toString(),
    );
    
    print('✅ [FCM] 백그라운드 알림 표시 완료');
  } catch (e) {
    print('❌ [FCM] 백그라운드 알림 표시 실패: $e');
  }
}

class FCMService {
  static FirebaseMessaging? _messaging;
  static String? _currentToken;
  static FlutterLocalNotificationsPlugin? _localNotifications;
  
  // FCM 초기화
  static Future<void> initialize() async {
    try {
      print('🔔 [FCM] FCM 서비스 초기화 시작');
      
      _messaging = FirebaseMessaging.instance;
      
      // 로컬 알림 플러그인 초기화
      await _initializeLocalNotifications();
      
      // 알림 권한 요청 (iOS)
      if (!kIsWeb) {
        final settings = await _messaging!.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        
        print('🔔 [FCM] 알림 권한 상태: ${settings.authorizationStatus}');
        
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          print('✅ [FCM] 알림 권한 허용됨');
        } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
          print('⚠️ [FCM] 알림 권한 임시 허용됨');
        } else {
          print('❌ [FCM] 알림 권한 거부됨');
        }
      }
      
      // 백그라운드 메시지 핸들러 등록
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      
      // 포그라운드 메시지 핸들러
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // 백그라운드에서 알림 클릭 시 처리
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);
      
      // 앱이 종료된 상태에서 알림 클릭으로 실행된 경우
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationClick(initialMessage);
      }
      
      // 토큰 가져오기 및 저장
      await _updateToken();
      
      // 토큰 갱신 리스너
      _messaging!.onTokenRefresh.listen((newToken) {
        print('🔔 [FCM] 토큰 갱신: $newToken');
        _updateTokenInSupabase(newToken);
      });
      
      print('✅ [FCM] FCM 서비스 초기화 완료');
    } catch (e, stackTrace) {
      print('❌ [FCM] FCM 초기화 실패: $e');
      print('❌ [FCM] 스택 트레이스: $stackTrace');
    }
  }
  
  // 로컬 알림 초기화
  static Future<void> _initializeLocalNotifications() async {
    try {
      _localNotifications = FlutterLocalNotificationsPlugin();
      
      // Android 초기화 설정
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _localNotifications!.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          print('🔔 [FCM] 알림 클릭: ${details.payload}');
          // 채팅 페이지로 이동하는 로직은 필요시 추가
        },
      );
      
      // Android 알림 채널 생성 (이미 MainActivity에서 생성했지만, 로컬 알림용으로도 필요)
      const androidChannel = AndroidNotificationChannel(
        'chat_notifications',
        '채팅 알림',
        description: '1:1 채팅 메시지 알림',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      await _localNotifications!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
      
      print('✅ [FCM] 로컬 알림 초기화 완료');
    } catch (e) {
      print('❌ [FCM] 로컬 알림 초기화 실패: $e');
    }
  }
  
  // 포그라운드 메시지 처리
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // 자신이 보낸 메시지인지 확인
    final currentUser = ApiService.getCurrentUser();
    final currentMemberId = currentUser?['member_id']?.toString();
    
    // FCM 메시지의 data에서 senderId 확인
    final messageSenderId = message.data['senderId']?.toString() ?? 
                           message.data['memberId']?.toString();
    
    final title = message.notification?.title ?? '새 메시지';
    final body = message.notification?.body ?? message.data['message'] ?? '';
    final bodyPreview = body.length > 30 ? '${body.substring(0, 30)}...' : body;
    
    // 자신이 보낸 메시지면 알림 재생 안함
    if (messageSenderId != null && currentMemberId != null) {
      final msgSenderIdTrimmed = messageSenderId.trim();
      final myIdTrimmed = currentMemberId.trim();
      
      if (msgSenderIdTrimmed == myIdTrimmed) {
        print('📨 [FCM] 나($msgSenderIdTrimmed): "$bodyPreview" | 🔕 무시 (자신이 보낸 메시지)');
        return;
      }
    }
    
    final senderInfo = messageSenderId != null ? '상대방($messageSenderId)' : '알 수 없음';
    print('📨 [FCM] $senderInfo: "$bodyPreview" | 🔔 알림');
    
    // 포그라운드에서는 로컬 알림 표시
    await _showForegroundNotification(message);
    
    // 알림 소리/진동 재생
    await ChattingService.playNotificationSound();
  }
  
  // 포그라운드 알림 표시
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    try {
      if (_localNotifications == null) {
        print('⚠️ [FCM] 로컬 알림 플러그인이 초기화되지 않음');
        return;
      }
      
      const androidDetails = AndroidNotificationDetails(
        'chat_notifications',
        '채팅 알림',
        channelDescription: '1:1 채팅 메시지 알림',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications!.show(
        message.hashCode,
        message.notification?.title ?? '새 메시지',
        message.notification?.body ?? message.data['message'] ?? '',
        notificationDetails,
        payload: message.data.toString(),
      );
      
      print('✅ [FCM] 포그라운드 알림 표시 완료');
    } catch (e) {
      print('❌ [FCM] 포그라운드 알림 표시 실패: $e');
    }
  }
  
  // 알림 클릭 처리
  static void _handleNotificationClick(RemoteMessage message) {
    print('🔔 [FCM] 알림 클릭: ${message.data}');
    
    // 채팅 페이지로 이동하는 로직은 필요시 추가
    // 현재는 로그만 출력
  }
  
  // FCM 토큰 업데이트
  static Future<void> _updateToken() async {
    try {
      if (_messaging == null) return;
      
      final token = await _messaging!.getToken();
      if (token != null) {
        _currentToken = token;
        print('✅ [FCM] FCM 토큰 가져오기 성공: ${token.substring(0, 20)}...');
        await _updateTokenInSupabase(token);
      } else {
        print('⚠️ [FCM] FCM 토큰이 null입니다');
      }
    } catch (e) {
      print('❌ [FCM] FCM 토큰 가져오기 실패: $e');
    }
  }
  
  // Supabase에 토큰 저장
  static Future<void> _updateTokenInSupabase(String token) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final currentUser = ApiService.getCurrentUser();
      final isAdmin = ApiService.isAdminLogin();
      
      if (branchId == null) {
        print('⚠️ [FCM] 지점 정보 없음 - 토큰 저장 불가');
        return;
      }
      
      final supabase = SupabaseAdapter.client;
      
      if (isAdmin) {
        // 관리자 토큰 저장
        final adminId = currentUser?['member_id']?.toString() ?? 'admin';
        final tokenId = '${branchId}_admin_$adminId';
        
        await supabase.from('fcm_tokens').upsert({
          'id': tokenId,
          'branch_id': branchId,
          'member_id': adminId,
          'is_admin': true,
          'token': token,
          'platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios'),
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        print('✅ [FCM] 관리자 FCM 토큰 Supabase 저장 완료');
      } else {
        // 회원 토큰 저장
        final memberId = currentUser?['member_id']?.toString();
        if (memberId == null) {
          print('⚠️ [FCM] 회원 정보 없음 - 토큰 저장 불가');
          return;
        }
        
        final tokenId = '${branchId}_$memberId';
        
        await supabase.from('fcm_tokens').upsert({
          'id': tokenId,
          'branch_id': branchId,
          'member_id': memberId,
          'is_admin': false,
          'token': token,
          'platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios'),
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        print('✅ [FCM] 회원 FCM 토큰 Supabase 저장 완료');
      }
    } catch (e) {
      print('❌ [FCM] FCM 토큰 Supabase 저장 실패: $e');
    }
  }
  
  // 현재 토큰 가져오기
  static String? getCurrentToken() {
    return _currentToken;
  }
  
  // 토큰 삭제 (로그아웃 시)
  static Future<void> deleteToken() async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final currentUser = ApiService.getCurrentUser();
      final memberId = currentUser?['member_id']?.toString();
      
      if (branchId != null && memberId != null) {
        final supabase = SupabaseAdapter.client;
        final tokenId = '${branchId}_$memberId';
        
        await supabase.from('fcm_tokens').delete().eq('id', tokenId);
        print('✅ [FCM] FCM 토큰 Supabase 삭제 완료');
      }
      
      await _messaging?.deleteToken();
      _currentToken = null;
      print('✅ [FCM] FCM 토큰 삭제 완료');
    } catch (e) {
      print('❌ [FCM] FCM 토큰 삭제 실패: $e');
    }
  }
}

