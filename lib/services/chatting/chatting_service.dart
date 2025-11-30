// Supabase로 전환: ChattingService를 ChattingServiceSupabase의 wrapper로 사용
import 'chatting_service_supabase.dart';
import 'chat_models.dart';
export 'chat_models.dart' show ChatRoom, ChatMessage;

/// ChattingService는 ChattingServiceSupabase의 wrapper입니다.
/// 기존 코드와의 호환성을 위해 유지됩니다.
class ChattingService {
  // 모든 정적 메서드를 ChattingServiceSupabase로 위임
  static Future<ChatRoom> getOrCreateChatRoom() =>
      ChattingServiceSupabase.getOrCreateChatRoom();
  
  static Stream<List<ChatMessage>> getMessagesStream() =>
      ChattingServiceSupabase.getMessagesStream();
  
  static Future<void> sendMessage(String message) =>
      ChattingServiceSupabase.sendMessage(message);
  
  static Future<void> markAdminMessagesAsRead() =>
      ChattingServiceSupabase.markAdminMessagesAsRead();
  
  static Stream<int> getUnreadMessageCountStream() =>
      ChattingServiceSupabase.getUnreadMessageCountStream();
  
  static void setChatPageActive(bool isActive) =>
      ChattingServiceSupabase.setChatPageActive(isActive);
  
  static bool get isChatPageActive => ChattingServiceSupabase.isChatPageActive;
  
  static void startGlobalNotificationListener() =>
      ChattingServiceSupabase.startGlobalNotificationListener();
  
  static void stopGlobalNotificationListener() =>
      ChattingServiceSupabase.stopGlobalNotificationListener();
  
  static bool isFirebaseAvailable() =>
      ChattingServiceSupabase.isFirebaseAvailable();
  
  static Future<void> playNotificationSound() =>
      ChattingServiceSupabase.playNotificationSound();
}
