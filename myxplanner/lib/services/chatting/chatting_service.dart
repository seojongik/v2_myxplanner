import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_models.dart';
import '../api_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';
import 'firebase_web_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../notification_settings_service.dart';

// 웹에서만 dart:js import
import '../../stubs/js_stub.dart' if (dart.library.js) 'dart:js' as js;
import '../../stubs/js_stub.dart' if (dart.library.js_util) 'dart:js_util' as js_util;
import '../../stubs/html_stub.dart' if (dart.library.html) 'dart:html' as html;

class ChattingService {
  static FirebaseFirestore? _firestore;
  static int _lastMessageCount = 0;
  static StreamSubscription<List<ChatMessage>>? _globalMessageSubscription;
  static bool _isGlobalListenerActive = false;
  static bool _isChatPageActive = false; // 채팅 페이지가 활성화되어 있는지 여부
  
  static Future<void> playNotificationSound() async {
    print('🔔 [Chat] playNotificationSound 호출됨');
    if (kIsWeb) {
      // 웹 환경: 소리만 재생
      try {
        final audio = html.AudioElement();
        audio.src = 'data:audio/mpeg;base64,SUQzBAAAAAABEVRYWFgAAAAtAAADY29tbWVudABCaWdTb3VuZEJhbmsuY29tIC8gTGFTb25vdGhlcXVlLm9yZwBURU5DAAAAHQAAAU1wZWcgTGF5ZXIgMyBhdWRpbyBlbmNvZGVyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//OEAAAAAAAAAAAAAAAAAAAAASW5mbwAAAA8AAAAEAAABIADAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV6urq6urq6urq6urq6urq6urq6urq6urq6v////////////////////////////////8AAAAATGF2YzU4LjU0AAAAAAAAAAAAAAAAJAAAAAAAAAAAASDs90hvAAAAAAAAAAAAAAAAAAAA//MUZAAAAAGkAAAAAAAAA0gAAAAATEFN//MUZAMAAAGkAAAAAAAAA0gAAAAARTMu//MUZAYAAAGkAAAAAAAAA0gAAAAAOTku//MUZAkAAAGkAAAAAAAAA0gAAAAANVVV';
        audio.volume = 0.3;
        audio.play().catchError((e) {
          print('소리 재생 실패: $e');
        });
      } catch (e) {
        print('알림 소리 재생 중 오류: $e');
      }
    } else {
      // 네이티브 환경: 진동 + 소리
      try {
        await _playNativeNotification();
        HapticFeedback.mediumImpact();
      } catch (e) {
        print('❌ [Chat] 알림 재생 오류: $e');
      }
    }
  }
  
  static Future<void> _playNativeNotification() async {
    try {
      const platform = MethodChannel('com.example.reservation_system/notification');
      await platform.invokeMethod('playNotification', {
        'enableSound': true,
        'enableVibration': true,
      });
    } catch (e) {
      print('❌ [Chat] 알림 재생 실패: $e');
      // 실패 시 햅틱 피드백만 사용
      HapticFeedback.mediumImpact();
      Future.delayed(Duration(milliseconds: 200), () {
        HapticFeedback.lightImpact();
      });
    }
  }

  // 글로벌 메시지 알림 리스너 시작
  static void startGlobalNotificationListener() {
    if (_isGlobalListenerActive) {
      print('🔔 [ChattingService] 글로벌 알림 리스너가 이미 활성화됨');
      return;
    }

    final branchId = _getCurrentBranchId();
    final memberId = _getCurrentMemberId();
    
    if (branchId == null || memberId == null) {
      print('⚠️ [ChattingService] 로그인 정보 없음 - 글로벌 알림 리스너 시작 불가');
      return;
    }

    print('🔔 [ChattingService] 글로벌 메시지 알림 리스너 시작');
    _isGlobalListenerActive = true;
    
    _globalMessageSubscription = getMessagesStream().listen(
      (messages) {
        // 새로운 메시지가 있고, 이전 메시지가 있었던 경우만 알림 재생
        if (messages.length > _lastMessageCount && _lastMessageCount > 0) {
          final newMessages = messages.skip(_lastMessageCount).toList();
          
          // 현재 사용자 정보 가져오기
          final currentUser = ApiService.getCurrentUser();
          final currentMemberId = currentUser?['member_id']?.toString();
          final isAdmin = ApiService.isAdminLogin();
          
          // 알림을 재생할 메시지 필터링
          final messagesToNotify = <ChatMessage>[];
          
          for (final msg in newMessages) {
            // senderId 비교 (문자열로 정확히 비교)
            final msgSenderId = msg.senderId.toString().trim();
            final myId = (currentMemberId?.toString() ?? '').trim();
            final isMyMessage = msgSenderId == myId && myId.isNotEmpty;
            
            // 자신이 보낸 메시지면 알림 제외
            if (isMyMessage) {
              continue;
            }
            
            // 상대방 타입 확인
            final shouldNotify = isAdmin 
                ? msg.senderType == 'member'  // 관리자인 경우: 회원 메시지만
                : msg.senderType == 'admin';  // 회원인 경우: 관리자 메시지만
            
            if (shouldNotify) {
              messagesToNotify.add(msg);
            }
          }
          
          // 알림 재생 (채팅 페이지가 활성화되어 있지 않을 때만)
          if (messagesToNotify.isNotEmpty && !_isChatPageActive) {
            final msg = messagesToNotify.first;
            final msgPreview = msg.message.length > 30 
                ? '${msg.message.substring(0, 30)}...' 
                : msg.message;
            print('📨 [Global] ${msg.senderType}(${msg.senderId}): "$msgPreview" | 🔔 알림');
            playNotificationSound();
          }
        }
        
        _lastMessageCount = messages.length;
      },
      onError: (error) {
        print('❌ [ChattingService] 글로벌 알림 리스너 에러: $error');
        _isGlobalListenerActive = false;
      },
    );
  }

  // 글로벌 메시지 알림 리스너 중지
  static void stopGlobalNotificationListener() {
    print('🔔 [ChattingService] 글로벌 메시지 알림 리스너 중지');
    _globalMessageSubscription?.cancel();
    _globalMessageSubscription = null;
    _isGlobalListenerActive = false;
  }
  
  // 채팅 페이지 활성화 상태 설정
  static void setChatPageActive(bool isActive) {
    _isChatPageActive = isActive;
  }
  
  static FirebaseFirestore? get firestore {
    try {
      if (Firebase.apps.isEmpty) {
        print('❌ [Chat] Firebase 초기화 안됨');
        _tryInitializeFirebase();
        return null;
      }
      
      if (!kIsWeb) {
        try {
          _firestore ??= FirebaseFirestore.instance;
          return _firestore;
        } catch (e) {
          print('❌ [Chat] Firestore 오류: $e');
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      print('❌ [Chat] Firestore 오류: $e');
      return null;
    }
  }
  
  static void _tryInitializeFirebase() async {
    // Firebase 재초기화는 main()에서만 수행
  }

  // Firebase 사용 가능 여부 체크 (웹/네이티브 구분)
  static bool isFirebaseAvailable() {
    print('🔍 [FIREBASE-CHECK] Firebase 사용 가능 여부 체크 시작');
    print('🔍 [FIREBASE-CHECK] 플랫폼: ${kIsWeb ? "웹" : "네이티브"}');
    
    try {
      if (kIsWeb) {
        // 웹에서는 JavaScript Firebase 확인
        print('🔍 [FIREBASE-CHECK] 웹 환경 - JavaScript Firebase 확인');
        final isAvailable = FirebaseWebService.isFirebaseAvailable();
        print('🔍 [FIREBASE-CHECK] FirebaseWebService 사용 가능: $isAvailable');
        return isAvailable;
      } else {
        // 네이티브에서는 Flutter Firebase 확인
        print('🔍 [FIREBASE-CHECK] 네이티브 환경 - Flutter Firebase 확인');
        final appsCount = Firebase.apps.length;
        print('🔍 [FIREBASE-CHECK] Firebase.apps.length: $appsCount');
        
        if (appsCount == 0) {
          print('❌ [FIREBASE-CHECK] Firebase 앱이 없음 - 초기화되지 않았거나 실패함');
          print('❌ [FIREBASE-CHECK] main.dart에서 Firebase 초기화 로그를 확인하세요');
          return false;
        }
        
        // 각 Firebase 앱 정보 출력
        for (int i = 0; i < appsCount; i++) {
          final app = Firebase.apps[i];
          print('🔍 [FIREBASE-CHECK] Firebase 앱 [$i]: ${app.name}');
          print('🔍 [FIREBASE-CHECK] 프로젝트 ID: ${app.options.projectId}');
          print('🔍 [FIREBASE-CHECK] 앱 ID: ${app.options.appId}');
        }
        
        // Firestore 인스턴스는 실제 사용 시점에 생성되므로 여기서는 생성하지 않음
        // 단순히 Firebase 앱이 초기화되었는지만 확인
        print('✅ [FIREBASE-CHECK] Firebase 앱 초기화 확인됨');
        return true;
      }
      
    } catch (e, stackTrace) {
      print('❌ [FIREBASE-CHECK] Firebase 체크 중 예외 발생: $e');
      print('❌ [FIREBASE-CHECK] 스택 트레이스: $stackTrace');
      return false;
    }
  }

  static String? _getCurrentBranchId() {
    return ApiService.getCurrentBranchId();
  }

  static String? _getCurrentMemberId() {
    final currentUser = ApiService.getCurrentUser();
    return currentUser?['member_id']?.toString();
  }

  static Map<String, dynamic>? _getCurrentMember() {
    return ApiService.getCurrentUser();
  }

  static Future<ChatRoom> getOrCreateChatRoom() async {
    final branchId = _getCurrentBranchId();
    final member = _getCurrentMember();
    
    if (branchId == null || member == null) {
      throw Exception('로그인 정보를 찾을 수 없습니다.');
    }

    final memberId = member['member_id'].toString();
    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);
    
    if (kIsWeb) {
      try {
        final existingRoom = await FirebaseWebService.getDocument('chatRooms', chatRoomId);
        
        if (existingRoom != null) {
          return ChatRoom.fromMap(existingRoom);
        } else {
          final newChatRoom = ChatRoom(
            id: chatRoomId,
            branchId: branchId,
            memberId: memberId,
            memberName: member['member_name']?.toString() ?? '',
            memberPhone: member['member_phone']?.toString() ?? '',
            memberType: member['member_type']?.toString() ?? '',
            createdAt: DateTime.now(),
            lastMessage: '',
            lastMessageTime: DateTime.now(),
          );

          await FirebaseWebService.setDocument('chatRooms', chatRoomId, newChatRoom.toMap());
          return newChatRoom;
        }
      } catch (e) {
        print('❌ [ChattingService] 웹 Firebase 작업 실패: $e');
        rethrow;
      }
    } else {
      final fs = firestore;
      if (fs == null) {
        throw Exception('Firebase가 초기화되지 않았습니다.');
      }

      final chatRoomRef = fs.collection('chatRooms').doc(chatRoomId);

      try {
        final doc = await chatRoomRef.get();
        
        if (doc.exists) {
          return ChatRoom.fromFirestore(doc);
        } else {
          final newChatRoom = ChatRoom(
            id: chatRoomId,
            branchId: branchId,
            memberId: memberId,
            memberName: member['member_name']?.toString() ?? '',
            memberPhone: member['member_phone']?.toString() ?? '',
            memberType: member['member_type']?.toString() ?? '',
            createdAt: DateTime.now(),
            lastMessage: '',
            lastMessageTime: DateTime.now(),
          );

          await chatRoomRef.set(newChatRoom.toFirestore());
          return newChatRoom;
        }
      } catch (e) {
        print('❌ [ChattingService] Firestore 작업 실패: $e');
        rethrow;
      }
    }
  }

  static Stream<List<ChatMessage>> getMessagesStream() {
    final branchId = _getCurrentBranchId();
    final memberId = _getCurrentMemberId();
    
    if (branchId == null || memberId == null) {
      return Stream.value([]);
    }

    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);
    
    if (kIsWeb) {
      // 웹에서는 JavaScript Firebase 사용
      print('🔍 [ChattingService] 웹 환경 - JavaScript 메시지 스트림 시작');
      
      final controller = StreamController<List<ChatMessage>>();
      
      final onMessage = js.allowInterop((messagesJsonString) {
        try {
          print('📨 [ChattingService] JSON 문자열 수신');
          print('📨 [ChattingService] JSON 타입: ${messagesJsonString.runtimeType}');
          print('📨 [ChattingService] JSON 내용: $messagesJsonString');
          
          // JSON 문자열을 파싱
          final messagesData = jsonDecode(messagesJsonString.toString());
          print('📨 [ChattingService] JSON 파싱 결과 타입: ${messagesData.runtimeType}');
          print('📨 [ChattingService] JSON 파싱 결과: $messagesData');
          
          if (messagesData is List) {
            print('📨 [ChattingService] List 확인됨, 길이: ${messagesData.length}');
            
            final chatMessages = <ChatMessage>[];
            for (int i = 0; i < messagesData.length; i++) {
              final msg = messagesData[i];
              print('📨 [ChattingService] 메시지 [$i] 타입: ${msg.runtimeType}');
              print('📨 [ChattingService] 메시지 [$i] 내용: $msg');
              
              try {
                if (msg is Map<String, dynamic>) {
                  final chatMessage = _createChatMessageFromMap(msg);
                  chatMessages.add(chatMessage);
                  print('✅ [ChattingService] 메시지 [$i] 변환 성공: ${chatMessage.message}');
                } else if (msg is Map) {
                  final messageMap = Map<String, dynamic>.from(msg);
                  final chatMessage = _createChatMessageFromMap(messageMap);
                  chatMessages.add(chatMessage);
                  print('✅ [ChattingService] 메시지 [$i] 변환 성공: ${chatMessage.message}');
                } else {
                  print('❌ [ChattingService] 메시지 [$i] Map이 아님, 건너뜀');
                  continue;
                }
              } catch (e) {
                print('❌ [ChattingService] 메시지 [$i] 변환 실패: $e');
                continue;
              }
            }
            
            print('📨 [ChattingService] 최종 변환된 메시지 수: ${chatMessages.length}');
            controller.add(chatMessages);
          } else {
            print('⚠️ [ChattingService] 파싱 결과가 List가 아님');
            controller.add([]);
          }
        } catch (e) {
          print('❌ [ChattingService] JSON 파싱 에러: $e');
          print('❌ [ChattingService] 스택 트레이스: ${StackTrace.current}');
          controller.addError(e);
        }
      });
      
      final onError = js.allowInterop((error) {
        print('❌ [ChattingService] 메시지 스트림 에러: $error');
        controller.addError(Exception('Message stream error: $error'));
      });
      
      // JavaScript 메시지 스트림 시작
      js.context.callMethod('getMessagesStream', [chatRoomId, onMessage, onError]);
      
      return controller.stream;
    } else {
      // 네이티브에서는 Flutter Firebase 사용
      final fs = firestore;
      if (fs == null) {
        return Stream.value([]);
      }
      
      return fs
          .collection('messages')
          .where('chatRoomId', isEqualTo: chatRoomId)
          .snapshots()
          .map((snapshot) {
        final messages = snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList();
        
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return messages;
      });
    }
  }
  
  // Map에서 ChatMessage 생성 헬퍼 함수
  static ChatMessage _createChatMessageFromMap(Map<String, dynamic> data) {
    DateTime timestamp;
    
    try {
      if (data['timestamp'] != null) {
        final timestampData = data['timestamp'];
        
        if (timestampData is String) {
          // ISO 문자열 형태 (JavaScript에서 변환된 것)
          timestamp = DateTime.parse(timestampData);
          print('✅ [ChattingService] ISO 문자열 타임스탬프 파싱 성공: $timestamp');
        } else if (timestampData is Map && timestampData.containsKey('seconds')) {
          // Firestore Timestamp 형태
          final seconds = timestampData['seconds'] ?? 0;
          final nanoseconds = timestampData['nanoseconds'] ?? 0;
          timestamp = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + nanoseconds ~/ 1000000
          );
          print('✅ [ChattingService] Firestore 타임스탬프 파싱 성공: $timestamp');
        } else if (timestampData is int) {
          // milliseconds 형태
          timestamp = DateTime.fromMillisecondsSinceEpoch(timestampData);
          print('✅ [ChattingService] milliseconds 타임스탬프 파싱 성공: $timestamp');
        } else {
          print('⚠️ [ChattingService] 알 수 없는 타임스탬프 형태, 현재 시간 사용: $timestampData');
          timestamp = DateTime.now();
        }
      } else {
        print('⚠️ [ChattingService] 타임스탬프 없음, 현재 시간 사용');
        timestamp = DateTime.now();
      }
    } catch (e) {
      print('❌ [ChattingService] 타임스탬프 파싱 에러: $e');
      timestamp = DateTime.now();
    }
    
    return ChatMessage(
      id: data['id']?.toString() ?? '',
      chatRoomId: data['chatRoomId']?.toString() ?? '',
      branchId: data['branchId']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      senderType: data['senderType']?.toString() ?? 'member',
      senderName: data['senderName']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      timestamp: timestamp,
      isRead: data['isRead'] as bool? ?? false,
    );
  }

  static Future<void> sendMessage(String message) async {
    final branchId = _getCurrentBranchId();
    final member = _getCurrentMember();
    
    if (branchId == null || member == null) {
      throw Exception('로그인 정보를 찾을 수 없습니다.');
    }

    final memberId = member['member_id'].toString();
    final memberName = member['member_name']?.toString() ?? '회원';
    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);
    
    if (kIsWeb) {
      // 웹에서는 JavaScript Firebase 사용 (콜백 방식)
      print('📤 [ChattingService] 웹 환경 - JavaScript 메시지 전송');
      
      try {
        final completer = Completer<void>();
        
        final onSuccess = js.allowInterop((result) {
          print('✅ [ChattingService] 메시지 전송 성공');
          completer.complete();
        });
        
        final onError = js.allowInterop((error) {
          print('❌ [ChattingService] 메시지 전송 실패: $error');
          completer.completeError(Exception('Failed to send message: $error'));
        });
        
        // JavaScript 콜백 함수 호출
        js.context.callMethod('sendMessageCallback', [
          chatRoomId,
          branchId, 
          memberId,
          memberName,
          'member',
          message,
          onSuccess,
          onError
        ]);
        
        await completer.future;
      } catch (e) {
        print('❌ [ChattingService] 웹 메시지 전송 실패: $e');
        throw Exception('Failed to send message: $e');
      }
    } else {
      // 네이티브에서는 Flutter Firebase 사용
      final fs = firestore;
      if (fs == null) {
        throw Exception('Firebase가 초기화되지 않았습니다.');
      }

      final messageId = ChatMessage.generateMessageId(branchId, memberId);
      
      final chatMessage = ChatMessage(
        id: messageId,
        chatRoomId: chatRoomId,
        branchId: branchId,
        senderId: memberId,
        senderType: 'member',
        senderName: memberName,
        message: message,
        timestamp: DateTime.now(),
        isRead: false,
      );

      final batch = fs.batch();

      final messageRef = fs.collection('messages').doc(messageId);
      batch.set(messageRef, chatMessage.toFirestore());

      final chatRoomRef = fs.collection('chatRooms').doc(chatRoomId);
      batch.update(chatRoomRef, {
        'lastMessage': message,
        'lastMessageTime': Timestamp.fromDate(DateTime.now()),
        'adminUnreadCount': FieldValue.increment(1),
      });

      await batch.commit();
      
      // FCM 푸시 알림은 Firebase Cloud Functions에서 자동으로 처리됨
      // Firestore에 메시지가 추가되면 Cloud Functions가 트리거되어
      // 관리자에게 FCM 푸시 알림을 자동으로 발송함
    }
  }

  static Future<void> markMessagesAsRead({String? targetSenderType}) async {
    final branchId = _getCurrentBranchId();
    final memberId = _getCurrentMemberId();
    
    if (branchId == null || memberId == null) return;

    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);
    
    // 기본값: 관리자 메시지를 읽음 처리 (회원이 읽는 경우)
    final senderTypeToMark = targetSenderType ?? 'admin';
    
    if (kIsWeb) {
      // 웹에서는 JavaScript Firebase 사용
      print('📖 [ChattingService] 웹 환경 - JavaScript 읽음 처리');
      
      try {
        final completer = Completer<void>();
        
        final onSuccess = js.allowInterop((result) {
          print('✅ [ChattingService] 읽음 처리 성공');
          completer.complete();
        });
        
        final onError = js.allowInterop((error) {
          print('❌ [ChattingService] 읽음 처리 실패: $error');
          completer.completeError(Exception('Failed to mark messages as read: $error'));
        });
        
        // JavaScript 콜백 함수 호출
        js.context.callMethod('markMessagesAsReadCallback', [
          chatRoomId,
          senderTypeToMark,
          onSuccess,
          onError
        ]);
        
        await completer.future;
        print('✅ [ChattingService] 메시지 읽음 처리 완료');
      } catch (e) {
        print('❌ [ChattingService] 웹 읽음 처리 실패: $e');
        throw Exception('Failed to mark messages as read: $e');
      }
    } else {
      // 네이티브에서는 Flutter Firebase 사용
      final fs = firestore;
      if (fs == null) return;

      final unreadMessages = await fs
          .collection('messages')
          .where('chatRoomId', isEqualTo: chatRoomId)
          .where('senderType', isEqualTo: senderTypeToMark)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = fs.batch();

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      final chatRoomRef = fs.collection('chatRooms').doc(chatRoomId);
      final updateField = senderTypeToMark == 'admin' ? 'memberUnreadCount' : 'adminUnreadCount';
      batch.update(chatRoomRef, {updateField: 0});

      await batch.commit();
    }
  }
  
  // 관리자 메시지 읽음 처리 (회원이 읽을 때)
  static Future<void> markAdminMessagesAsRead() async {
    await markMessagesAsRead(targetSenderType: 'admin');
  }
  
  // 회원 메시지 읽음 처리 (관리자가 읽을 때)
  static Future<void> markMemberMessagesAsRead() async {
    await markMessagesAsRead(targetSenderType: 'member');
  }

  static Stream<int> getUnreadMessageCountStream() {
    final branchId = _getCurrentBranchId();
    final memberId = _getCurrentMemberId();
    
    if (branchId == null || memberId == null) {
      return Stream.value(0);
    }

    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);
    
    if (kIsWeb) {
      // 웹에서는 JavaScript Firebase 사용
      print('🔔 [ChattingService] 웹 환경 - JavaScript 안읽은 메시지 수 스트림');
      
      final controller = StreamController<int>();
      
      final onUpdate = js.allowInterop((count) {
        try {
          final dartCount = js_util.dartify(count);
          print('🔔 [ChattingService] 안읽은 메시지 수 업데이트: $dartCount');
          final intCount = dartCount is int ? dartCount : (dartCount is double ? dartCount.toInt() : 0);
          controller.add(intCount);
        } catch (e) {
          print('❌ [ChattingService] 안읽은 메시지 수 처리 에러: $e');
          controller.add(0);
        }
      });
      
      final onError = js.allowInterop((error) {
        print('❌ [ChattingService] 안읽은 메시지 수 스트림 에러: $error');
        controller.addError(Exception('Unread count stream error: $error'));
      });
      
      // JavaScript 안읽은 메시지 수 스트림 시작
      js.context.callMethod('getUnreadCountStream', [chatRoomId, onUpdate, onError]);
      
      return controller.stream;
    } else {
      // 네이티브에서는 Flutter Firebase 사용
      final fs = firestore;
      if (fs == null) {
        return Stream.value(0);
      }

      return fs
          .collection('chatRooms')
          .doc(chatRoomId)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) return 0;
        final data = snapshot.data() as Map<String, dynamic>;
        return data['memberUnreadCount'] as int? ?? 0;
      });
    }
  }
}