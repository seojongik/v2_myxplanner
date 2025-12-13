import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'chat_notification_service.dart';
import 'supabase_adapter.dart';
import 'api_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../backend/firebase/firebase_config.dart';

// 백그라운드 메시지 핸들러 (최상위 함수여야 함)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  
  // Firebase 초기화 (백그라운드 핸들러에서는 필요)
  try {
    await Firebase.initializeApp();
  } catch (e) {
  }
  
  // iOS에서는 시스템이 자동으로 알림을 표시하므로 Flutter 로컬 알림 표시 안함
  // Android에서만 로컬 알림 표시
  if (defaultTargetPlatform == TargetPlatform.android) {
    await _showBackgroundNotification(message);
  } else {
  }
}

Future<void> _showBackgroundNotification(RemoteMessage message) async {
  try {
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
      },
    );
    
    
    // 알림 제목과 내용 준비
    final title = message.notification?.title ?? 
                  message.data['senderName'] ?? 
                  '새 메시지';
    final body = message.notification?.body ?? 
                 message.data['message'] ?? 
                 '새 메시지가 도착했습니다';
    
    
    // 알림 표시
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
    
  } catch (e, stackTrace) {
  }
}

class FCMService {
  static FirebaseMessaging? _messaging;
  static String? _currentToken;
  static FlutterLocalNotificationsPlugin? _localNotifications;
  
  // FCM 초기화
  // 주의: 이 시점에는 branchId가 설정되지 않았을 수 있음
  // 토큰 저장은 branchId가 설정된 후(로그인 완료 후) updateTokenAfterLogin() 호출 필요
  static Future<void> initialize() async {
    try {
      
      _messaging = FirebaseMessaging.instance;
      
      // 로컬 알림 플러그인 초기화 (웹이 아닌 경우만)
      if (!kIsWeb) {
        await _initializeLocalNotifications();
      }
      
      // 알림 권한 요청 (iOS, 웹)
      if (!kIsWeb) {
        final settings = await _messaging!.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      } else {
        // 웹에서는 알림 권한 요청
        try {
          await _messaging!.requestPermission();
        } catch (e) {
          // 웹에서 권한 요청 실패는 무시
        }
      }
      
      // 백그라운드 메시지 핸들러 등록 (웹이 아닌 경우만)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }
      
      // 포그라운드 메시지 핸들러
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // 백그라운드에서 알림 클릭 시 처리
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);
      
      // 앱이 종료된 상태에서 알림 클릭으로 실행된 경우
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationClick(initialMessage);
      }
      
      // 토큰 갱신 리스너 (토큰이 변경되면 자동으로 업데이트)
      _messaging!.onTokenRefresh.listen((newToken) {
        _updateTokenInSupabase(newToken);
      });
      
      // 초기 토큰 가져오기 (branchId가 있으면 저장)
      // branchId가 없으면 저장하지 않음 (로그인 후 updateTokenAfterLogin() 호출 필요)
      await _updateToken();
      
    } catch (e, stackTrace) {
    }
  }
  
  // 로컬 알림 초기화 (웹이 아닌 경우만)
  static Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return;
    
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
      
    } catch (e) {
    }
  }
  
  // 포그라운드 메시지 처리
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // 자신이 보낸 메시지인지 확인
    final currentUser = ApiService.getCurrentUser();
    final currentUserId = currentUser?['member_id']?.toString() ?? 
                         currentUser?['admin_id']?.toString() ??
                         currentUser?['staff_access_id']?.toString();
    
    // FCM 메시지의 data에서 senderId 확인
    final messageSenderId = message.data['senderId']?.toString() ?? 
                           message.data['memberId']?.toString() ??
                           message.data['adminId']?.toString();
    
    final title = message.notification?.title ?? '새 메시지';
    final body = message.notification?.body ?? message.data['message'] ?? '';
    
    // 자신이 보낸 메시지면 알림 재생 안함
    if (messageSenderId != null && currentUserId != null) {
      final msgSenderIdTrimmed = messageSenderId.trim();
      final myIdTrimmed = currentUserId.trim();
      
      if (msgSenderIdTrimmed == myIdTrimmed) {
        return;
      }
    }
    
    final notificationService = ChatNotificationService();
    
    // 웹이 아닌 경우에만 로컬 알림 표시
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _showForegroundNotification(message);
    }
    
    // 알림음 재생 조건:
    // 1. 채팅 페이지가 닫혀있거나
    // 2. 채팅 페이지가 열려있지만 현재 열려있는 채팅방이 메시지의 채팅방과 다를 때
    final messageChatRoomId = message.data['chatRoomId']?.toString();
    final shouldPlaySound = !notificationService.isChatPageOpen || 
                            (messageChatRoomId != null && 
                             !notificationService.isCurrentChatRoom(messageChatRoomId));
    
    if (shouldPlaySound) {
      await notificationService.playNotificationSound();
      
      // 하단 네비 카운트 즉시 증가 (UI 업데이트)
      notificationService.incrementUnreadCount();
    }
  }
  
  // 포그라운드 알림 표시
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb || _localNotifications == null) {
      return;
    }
    
    try {
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
      
    } catch (e) {
    }
  }
  
  // 알림 클릭 처리
  static void _handleNotificationClick(RemoteMessage message) {
    // 채팅 페이지로 이동하는 로직은 필요시 추가
  }
  
  // FCM 토큰 업데이트
  static Future<void> _updateToken() async {
    try {
      if (_messaging == null) return;
      
      final token = await _messaging!.getToken();
      if (token != null) {
        _currentToken = token;
        await _updateTokenInSupabase(token);
      }
    } catch (e) {
    }
  }
  
  // Supabase에 토큰 저장 (branch_id 기준, 개인 계정 아님)
  // 중요: branch_id가 없으면 저장하지 않음 (다른 지점 알림 방지)
  static Future<void> _updateTokenInSupabase(String token) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final currentUser = ApiService.getCurrentUser();
      
      // branch_id가 없으면 저장하지 않음 (로그인 전이거나 branch_id 미설정)
      if (branchId == null) {
        return;
      }
      
      final supabase = SupabaseAdapter.client;
      
      // 현재 사용자의 역할 확인 (admin, manager)
      // crm은 관리자/매니저만 사용 (프로는 crm_lite_pro 사용)
      final role = ApiService.getCurrentStaffRole() ?? 'admin';
      final senderType = role; // 'admin', 'manager'
      
      // branch_id 기준으로 토큰 저장 (개인 계정이 아닌 branch_id별 계정)
      // 같은 branch_id의 같은 역할이면 하나의 토큰으로 관리
      // 여러 관리자/매니저가 같은 branch_id에서 사용할 수 있으므로
      // tokenId는 branch_id + sender_type 조합으로 생성
      final tokenId = '${branchId}_${senderType}';
      
      final data = {
        'id': tokenId,
        'branch_id': branchId, // 중요: 이 branch_id로만 알림이 발송됨
        'member_id': currentUser?['member_id']?.toString() ?? 
                     currentUser?['admin_id']?.toString() ?? 
                     currentUser?['staff_access_id']?.toString() ??
                     'admin',
        'is_admin': senderType == 'admin',
        'sender_type': senderType,
        'token': token,
        'platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios'),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await supabase.from('fcm_tokens').upsert(data);
      
    } catch (e, stackTrace) {
    }
  }
  
  // 현재 토큰 가져오기
  static String? getCurrentToken() {
    return _currentToken;
  }
  
  // 로그인 후 토큰 업데이트 (지점 정보가 설정된 후 호출)
  // 중요: 로그인 완료 후 branch_id가 설정된 후에 호출해야 함
  // 이 메서드를 호출하지 않으면 토큰이 저장되지 않아 푸시 알림을 받을 수 없음
  static Future<void> updateTokenAfterLogin() async {
    try {
      if (_messaging == null) {
        return;
      }
      
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null) {
        // branch_id가 없으면 토큰 저장하지 않음
        return;
      }
      
      final token = await _messaging!.getToken();
      if (token != null) {
        _currentToken = token;
        await _updateTokenInSupabase(token);
      }
    } catch (e) {
    }
  }
  
  // 토큰 삭제 (로그아웃 시)
  static Future<void> deleteToken() async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      
      if (branchId != null) {
        final supabase = SupabaseAdapter.client;
        final role = ApiService.getCurrentStaffRole() ?? 'admin';
        final senderType = role;
        final tokenId = '${branchId}_${senderType}';
        
        await supabase.from('fcm_tokens').delete().eq('id', tokenId);
      }
      
      await _messaging?.deleteToken();
      _currentToken = null;
    } catch (e) {
    }
  }
}
