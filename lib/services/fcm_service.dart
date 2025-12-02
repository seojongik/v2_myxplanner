import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'chat_notification_service.dart';
import 'supabase_adapter.dart';
import 'api_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';

// 백그라운드 메시지 핸들러 (최상위 함수여야 함)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('═══════════════════════════════════════════════════════════');
  print('🔔 [FCM] 백그라운드 메시지 수신!');
  print('═══════════════════════════════════════════════════════════');
  print('🔔 [FCM] 메시지 ID: ${message.messageId}');
  print('🔔 [FCM] 발신자: ${message.senderId}');
  print('🔔 [FCM] 데이터: ${message.data}');
  print('🔔 [FCM] 알림 제목: ${message.notification?.title}');
  print('🔔 [FCM] 알림 내용: ${message.notification?.body}');
  print('🔔 [FCM] 알림 내용 (data): ${message.data['message']}');
  
  // Firebase 초기화 (백그라운드 핸들러에서는 필요)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ [FCM] Firebase 초기화 완료');
  } catch (e) {
    print('❌ [FCM] Firebase 초기화 실패: $e');
  }
  
  // iOS에서는 시스템이 자동으로 알림을 표시하므로 Flutter 로컬 알림 표시 안함
  // Android에서만 로컬 알림 표시
  if (defaultTargetPlatform == TargetPlatform.android) {
    await _showBackgroundNotification(message);
  } else {
    print('🍎 [FCM] iOS 백그라운드 - 시스템 알림 사용 (Flutter 로컬 알림 스킵)');
  }
  print('═══════════════════════════════════════════════════════════');
}

Future<void> _showBackgroundNotification(RemoteMessage message) async {
  try {
    print('🔔 [FCM] 백그라운드 알림 표시 시작...');
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
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
    
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print('🔔 [FCM] 알림 클릭: ${details.payload}');
      },
    );
    
    print('✅ [FCM] 로컬 알림 플러그인 초기화 완료');
    
    // 알림 제목과 내용 준비
    final title = message.notification?.title ?? 
                  message.data['senderName'] ?? 
                  '새 메시지';
    final body = message.notification?.body ?? 
                 message.data['message'] ?? 
                 '새 메시지가 도착했습니다';
    
    print('🔔 [FCM] 알림 제목: $title');
    print('🔔 [FCM] 알림 내용: $body');
    
    // 알림 표시 (커스텀 사운드 포함)
    const androidDetails = AndroidNotificationDetails(
      'chat_notifications',
      '채팅 알림',
      channelDescription: '1:1 채팅 메시지 알림',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('hole_in'), // 커스텀 사운드
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'hole_in.mp3', // 커스텀 사운드
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
      notificationDetails,
      payload: message.data.toString(),
    );
    
    print('✅ [FCM] 백그라운드 알림 표시 완료 (ID: ${message.hashCode})');
  } catch (e, stackTrace) {
    print('❌ [FCM] 백그라운드 알림 표시 실패: $e');
    print('❌ [FCM] 스택 트레이스: $stackTrace');
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
      
      // Android 알림 채널 생성 (커스텀 사운드 포함)
      const androidChannel = AndroidNotificationChannel(
        'chat_notifications',
        '채팅 알림',
        description: '1:1 채팅 메시지 알림',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('hole_in'), // 커스텀 사운드
      );
      
      await _localNotifications!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
      
      print('✅ [FCM] 로컬 알림 초기화 완료');
    } catch (e) {
      print('❌ [FCM] 로컬 알림 초기화 실패: $e');
    }
  }
  
  // 포그라운드 메시지 처리 (회원 앱용)
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
    
    // FCM 메시지의 chatRoomId 확인
    final messageChatRoomId = message.data['chatRoomId']?.toString();
    final notificationService = ChatNotificationService();
    
    // iOS에서는 시스템이 자동으로 알림을 표시하므로 Flutter 로컬 알림 표시 안함
    // Android에서만 로컬 알림 표시
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _showForegroundNotification(message);
    } else {
      print('🍎 [FCM] iOS - 시스템 알림 사용 (Flutter 로컬 알림 스킵)');
    }
    
    // 알림음 재생 조건:
    // 1. 채팅 페이지가 닫혀있거나
    // 2. 채팅 페이지가 열려있지만 현재 열려있는 채팅방이 메시지의 채팅방과 다를 때
    final shouldPlaySound = !notificationService.isChatPageOpen || 
                            (messageChatRoomId != null && 
                             !notificationService.isCurrentChatRoom(messageChatRoomId));
    
    if (shouldPlaySound) {
      print('🔔 [FCM] 알림음 재생 (채팅 페이지: ${notificationService.isChatPageOpen ? "열림" : "닫힘"}, 현재 채팅방: ${notificationService.currentChatRoomId ?? "없음"}, 메시지 채팅방: $messageChatRoomId)');
      await notificationService.playNotificationSound();
    } else {
      print('🔇 [FCM] 알림음 재생 안함 (현재 열려있는 채팅방과 동일: $messageChatRoomId)');
    }
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
        sound: RawResourceAndroidNotificationSound('hole_in'), // 커스텀 사운드
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'hole_in.mp3', // 커스텀 사운드
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
  
  // Supabase에 토큰 저장 (회원 앱용)
  static Future<void> _updateTokenInSupabase(String token) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final currentUser = ApiService.getCurrentUser();
      
      print('🔍 [FCM] 토큰 저장 시도 - branchId: $branchId, currentUser: $currentUser');
      
      if (branchId == null) {
        print('⚠️ [FCM] 지점 정보 없음 - 토큰 저장 불가');
        return;
      }
      
      // 회원 정보 확인
      final memberId = currentUser?['member_id']?.toString();
      if (memberId == null) {
        print('⚠️ [FCM] 회원 정보 없음 - 토큰 저장 불가');
        return;
      }
      
      final supabase = SupabaseAdapter.client;
      
      // 회원 토큰 저장 (myxplanner는 회원 전용)
      final tokenId = '${branchId}_member_$memberId';
      
      final data = {
        'id': tokenId,
        'branch_id': branchId,
        'member_id': memberId,
        'is_admin': false,
        'sender_type': 'member', // 회원용
        'token': token,
        'platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios'),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      print('🔍 [FCM] 저장할 데이터: $data');
      
      await supabase.from('fcm_tokens').upsert(data);
      
      print('✅ [FCM] 회원 FCM 토큰 Supabase 저장 완료 - tokenId: $tokenId');
    } catch (e, stackTrace) {
      print('❌ [FCM] FCM 토큰 Supabase 저장 실패: $e');
      print('❌ [FCM] 스택 트레이스: $stackTrace');
    }
  }
  
  // 현재 토큰 가져오기
  static String? getCurrentToken() {
    return _currentToken;
  }
  
  // 로그인 후 토큰 업데이트 (지점 정보가 설정된 후 호출)
  static Future<void> updateTokenAfterLogin() async {
    try {
      print('🔔 [FCM] 로그인 후 토큰 업데이트 시작...');
      
      if (_messaging == null) {
        print('⚠️ [FCM] FCM 메시징이 초기화되지 않음');
        return;
      }
      
      // iOS에서는 APNS 토큰이 먼저 설정되어야 함
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        print('🍎 [FCM] iOS - APNS 토큰 대기 중...');
        String? apnsToken;
        int retryCount = 0;
        const maxRetries = 10;
        
        while (apnsToken == null && retryCount < maxRetries) {
          try {
            apnsToken = await _messaging!.getAPNSToken();
            if (apnsToken != null) {
              print('✅ [FCM] APNS 토큰 획득 성공');
              break;
            }
          } catch (e) {
            print('⏳ [FCM] APNS 토큰 대기 중... (${retryCount + 1}/$maxRetries)');
          }
          retryCount++;
          await Future.delayed(const Duration(seconds: 1));
        }
        
        if (apnsToken == null) {
          print('⚠️ [FCM] APNS 토큰을 가져올 수 없습니다. 푸시 알림이 작동하지 않을 수 있습니다.');
          print('   → 설정 > 알림에서 앱 알림이 허용되어 있는지 확인하세요.');
          return;
        }
      }
      
      final token = await _messaging!.getToken();
      if (token != null) {
        _currentToken = token;
        print('✅ [FCM] FCM 토큰 가져오기 성공: ${token.substring(0, 20)}...');
        await _updateTokenInSupabase(token);
      } else {
        print('⚠️ [FCM] FCM 토큰이 null입니다');
      }
    } catch (e) {
      print('❌ [FCM] 로그인 후 토큰 업데이트 실패: $e');
    }
  }
  
  // 토큰 삭제 (로그아웃 시)
  static Future<void> deleteToken() async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final currentUser = ApiService.getCurrentUser();
      final memberId = currentUser?['member_id']?.toString();
      
      if (branchId != null && memberId != null) {
        final supabase = SupabaseAdapter.client;
        final tokenId = '${branchId}_member_$memberId';
        
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
