import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'chat_models.dart';
import '../api_service.dart';
import '../supabase_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;

/// Supabase 기반 채팅 서비스 (회원 앱용)
/// Firebase Firestore 대신 Supabase PostgreSQL + Realtime 사용
class ChattingServiceSupabase {
  static SupabaseClient get _supabase => SupabaseAdapter.client;

  // 현재 지점 ID 가져오기
  static String? _getCurrentBranchId() {
    return ApiService.getCurrentBranchId();
  }

  // 현재 회원 정보 가져오기
  static Map<String, dynamic>? _getCurrentMember() {
    return ApiService.getCurrentUser();
  }

  // 현재 회원 ID 가져오기
  static String? _getCurrentMemberId() {
    final currentUser = ApiService.getCurrentUser();
    return currentUser?['member_id']?.toString();
  }

  // 채팅방 생성 또는 가져오기
  static Future<ChatRoom> getOrCreateChatRoom() async {
    print('🏢 ChattingServiceSupabase.getOrCreateChatRoom 시작');

    final branchId = _getCurrentBranchId();
    final member = _getCurrentMember();

    if (branchId == null || member == null) {
      print('❌ 브랜치 ID 또는 회원 정보가 null입니다');
      throw Exception('로그인 정보를 찾을 수 없습니다.');
    }

    final memberId = member['member_id'].toString();
    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);
    print('🆔 생성된 채팅방 ID: $chatRoomId');

    try {
      // 기존 채팅방 조회
      final response = await _supabase
          .from('chat_rooms')
          .select()
          .eq('id', chatRoomId)
          .maybeSingle();

      if (response != null) {
        print('✅ 기존 채팅방 발견');
        return ChatRoom.fromMap(response);
      } else {
        print('🆕 새 채팅방 생성 중...');

        // 새 채팅방 생성
        final newChatRoom = ChatRoom(
          id: chatRoomId,
          branchId: branchId,
          memberId: memberId,
          memberName: member['member_name']?.toString() ?? '회원',
          memberPhone: member['member_phone']?.toString() ?? '',
          memberType: member['member_type']?.toString() ?? '',
          createdAt: DateTime.now(),
          lastMessage: '',
          lastMessageTime: DateTime.now(),
        );

        print('💾 Supabase에 채팅방 저장 중...');
        await _supabase.from('chat_rooms').insert(newChatRoom.toMap());
        print('✅ 새 채팅방 저장 완료');

        return newChatRoom;
      }
    } catch (e, stackTrace) {
      print('❌ ChattingServiceSupabase.getOrCreateChatRoom 에러!');
      print('에러: $e');
      print('타입: ${e.runtimeType}');
      print('스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  // 특정 채팅방의 메시지 목록 가져오기 (실시간 구독)
  static Stream<List<ChatMessage>> getMessagesStream() {
    final branchId = _getCurrentBranchId();
    final memberId = _getCurrentMemberId();

    if (branchId == null || memberId == null) {
      print('⚠️ [ChattingServiceSupabase] 로그인 정보 없음 - 메시지 스트림 중단');
      return Stream.value([]);
    }

    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);
    print('📡 메시지 스트림 시작: $chatRoomId');

    // 초기 데이터 로드
    final initialStream = Stream.fromFuture(
      _supabase
          .from('chat_messages')
          .select()
          .eq('chat_room_id', chatRoomId)
          .order('timestamp', ascending: true)
          .then((data) => (data as List)
              .map((item) => ChatMessage.fromMap(item as Map<String, dynamic>))
              .toList()),
    );

    // 초기 데이터 + 실시간 업데이트 스트림
    return initialStream.asyncExpand((initialMessages) {
      final changeStream = StreamController<List<ChatMessage>>();

      // 초기 데이터 전송
      changeStream.add(initialMessages);

      // Realtime 구독 (asyncExpand 내부에서 생성하여 스트림과 함께 관리)
      final channel = _supabase
          .channel('chat_messages_$chatRoomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'chat_room_id',
              value: chatRoomId,
            ),
            callback: (payload) async {
              // 변경사항 발생 시 전체 목록 다시 조회
              try {
                final updatedData = await _supabase
                    .from('chat_messages')
                    .select()
                    .eq('chat_room_id', chatRoomId)
                    .order('timestamp', ascending: true);

                final updatedMessages = (updatedData as List)
                    .map((item) => ChatMessage.fromMap(item as Map<String, dynamic>))
                    .toList();

                changeStream.add(updatedMessages);
              } catch (e) {
                print('❌ 메시지 목록 업데이트 실패: $e');
              }
            },
          )
          .subscribe();

      // 스트림이 취소될 때 채널 구독 해제
      changeStream.onCancel = () {
        channel.unsubscribe();
      };

      return changeStream.stream;
    });
  }

  // 메시지 전송 (회원이 관리자에게 메시지 전송)
  static Future<void> sendMessage(String message) async {
    final branchId = _getCurrentBranchId();
    final member = _getCurrentMember();

    if (branchId == null || member == null) {
      throw Exception('로그인 정보를 찾을 수 없습니다.');
    }

    final memberId = member['member_id'].toString();
    final memberName = member['member_name']?.toString() ?? '회원';
    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);

    // 메시지 ID 생성
    final messageId = ChatMessage.generateMessageId(branchId, memberId);

    // 메시지 생성
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
      readBy: {
        'member': false,
        'pro': false,
        'manager': false,
        'admin': false,
      },
    );

    try {
      // 현재 채팅방 정보 가져오기
      final chatRoomData = await _supabase
          .from('chat_rooms')
          .select('admin_unread_count')
          .eq('id', chatRoomId)
          .single();

      final currentUnreadCount = (chatRoomData['admin_unread_count'] as int? ?? 0);

      // 메시지 삽입
      await _supabase.from('chat_messages').insert(chatMessage.toMap());

      // 채팅방 마지막 메시지 업데이트
      await _supabase.from('chat_rooms').update({
        'last_message': message,
        'last_message_time': DateTime.now().toIso8601String(),
        'admin_unread_count': currentUnreadCount + 1,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', chatRoomId);

      print('📨 메시지 전송 완료: $message');
      print('🔔 adminUnreadCount 증가 → 관리자에게 알림 발생 예상');
    } catch (e) {
      print('❌ 메시지 전송 실패: $e');
      rethrow;
    }
  }

  // 회원이 관리자 메시지를 읽었을 때 (관리자가 보낸 메시지)
  static Future<void> markAdminMessagesAsRead() async {
    final branchId = _getCurrentBranchId();
    final memberId = _getCurrentMemberId();

    if (branchId == null || memberId == null) return;

    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);

    try {
      // 읽지 않은 관리자/프로/매니저 메시지들을 회원이 읽음 처리
      final unreadMessages = await _supabase
          .from('chat_messages')
          .select('id, read_by')
          .eq('chat_room_id', chatRoomId)
          .inFilter('sender_type', ['admin', 'pro', 'manager']);

      if (unreadMessages.isNotEmpty) {
        for (final msg in unreadMessages) {
          // 현재 read_by 상태 확인
          final currentReadBy = msg['read_by'] as Map<String, dynamic>? ?? {
            'member': false,
            'pro': false,
            'manager': false,
            'admin': false,
          };
          
          // 이미 회원이 읽었으면 스킵
          if (currentReadBy['member'] == true) continue;
          
          // read_by 업데이트
          final updatedReadBy = Map<String, dynamic>.from(currentReadBy);
          updatedReadBy['member'] = true;
          
          // is_read도 업데이트 (하위 호환성) - 모든 타입이 읽었는지 확인
          final allRead = (updatedReadBy['member'] == true) &&
                          (updatedReadBy['pro'] == true) &&
                          (updatedReadBy['manager'] == true) &&
                          (updatedReadBy['admin'] == true);

          await _supabase
              .from('chat_messages')
              .update({
                'read_by': updatedReadBy,
                'is_read': allRead,
              })
              .eq('id', msg['id']);
        }
      }

      // 채팅방의 회원 읽지 않은 메시지 수 초기화
      await _supabase.from('chat_rooms').update({
        'member_unread_count': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', chatRoomId);
    } catch (e) {
      print('❌ 메시지 읽음 처리 실패: $e');
      rethrow;
    }
  }

  // 읽지 않은 메시지 개수 스트림 (회원 기준)
  static Stream<int> getUnreadMessageCountStream() {
    final branchId = _getCurrentBranchId();
    final memberId = _getCurrentMemberId();

    if (branchId == null || memberId == null) {
      return Stream.value(0);
    }

    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);

    // 초기 데이터 로드
    final initialStream = Stream.fromFuture(
      _supabase
          .from('chat_rooms')
          .select('member_unread_count')
          .eq('id', chatRoomId)
          .maybeSingle()
          .then((data) => data?['member_unread_count'] as int? ?? 0),
    );

    return initialStream.asyncExpand((initialCount) {
      final changeStream = StreamController<int>();

      changeStream.add(initialCount);

      // Realtime 구독 (asyncExpand 내부에서 생성하여 스트림과 함께 관리)
      final channel = _supabase
          .channel('chat_room_unread_$chatRoomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'chat_rooms',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: chatRoomId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord != null) {
                changeStream.add(newRecord['member_unread_count'] as int? ?? 0);
              }
            },
          )
          .subscribe();

      // 스트림이 취소될 때 채널 구독 해제
      changeStream.onCancel = () {
        channel.unsubscribe();
      };

      return changeStream.stream.distinct();
    });
  }

  // 채팅 페이지 활성화 상태 관리 (알림 제어용)
  static bool _isChatPageActive = false;
  
  static void setChatPageActive(bool isActive) {
    _isChatPageActive = isActive;
    print('📱 [ChattingServiceSupabase] 채팅 페이지 활성화 상태: $isActive');
  }
  
  static bool get isChatPageActive => _isChatPageActive;

  // 글로벌 메시지 알림 리스너 시작
  static StreamSubscription<List<ChatMessage>>? _globalMessageSubscription;
  static bool _isGlobalListenerActive = false;
  static int _lastMessageCount = 0;
  
  static void startGlobalNotificationListener() {
    if (_isGlobalListenerActive) {
      print('🔔 [ChattingServiceSupabase] 글로벌 알림 리스너가 이미 활성화됨');
      return;
    }

    final branchId = _getCurrentBranchId();
    final memberId = _getCurrentMemberId();
    
    if (branchId == null || memberId == null) {
      print('⚠️ [ChattingServiceSupabase] 로그인 정보 없음 - 글로벌 알림 리스너 시작 불가');
      return;
    }

    print('🔔 [ChattingServiceSupabase] 글로벌 메시지 알림 리스너 시작');
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
        print('❌ [ChattingServiceSupabase] 글로벌 알림 리스너 에러: $error');
        _isGlobalListenerActive = false;
      },
    );
  }

  // 글로벌 메시지 알림 리스너 중지
  static void stopGlobalNotificationListener() {
    print('🔔 [ChattingServiceSupabase] 글로벌 메시지 알림 리스너 중지');
    _globalMessageSubscription?.cancel();
    _globalMessageSubscription = null;
    _isGlobalListenerActive = false;
  }

  // Firebase 사용 가능 여부 (하위 호환성)
  // Supabase로 전환했으므로 Supabase 사용 가능 여부를 반환
  static bool isFirebaseAvailable() {
    try {
      // Supabase 클라이언트가 초기화되어 있는지 확인
      if (!SupabaseAdapter.isInitialized) {
        print('⚠️ [ChattingServiceSupabase] Supabase가 초기화되지 않았습니다');
        return false;
      }
      final supabase = SupabaseAdapter.client;
      print('✅ [ChattingServiceSupabase] Supabase 사용 가능: ${supabase != null}');
      return true; // Supabase가 초기화되어 있으면 항상 true 반환
    } catch (e) {
      print('⚠️ [ChattingServiceSupabase] Supabase 확인 중 오류: $e');
      return false;
    }
  }

  // 알림 소리 재생
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
        HapticFeedback.mediumImpact();
      } catch (e) {
        print('❌ [Chat] 알림 재생 오류: $e');
      }
    }
  }
}

