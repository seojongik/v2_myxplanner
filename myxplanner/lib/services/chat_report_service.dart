import '../services/supabase_adapter.dart';
import '../services/api_service.dart';

/// 콘텐츠 신고 및 차단 서비스
/// Apple App Store 가이드라인 1.2 준수
/// 채팅 및 게시판 모두에 적용
class ChatReportService {
  /// 메시지 신고
  /// - 신고 내용을 DB에 저장
  /// - 개발자에게 알림 (이메일 또는 푸시)
  static Future<bool> reportMessage({
    required String messageId,
    required String chatRoomId,
    required String reportedSenderId,
    required String reportedSenderType,
    required String messageContent,
    required String reportReason,
  }) async {
    try {
      final currentUser = ApiService.getCurrentUser();
      final branchId = ApiService.getCurrentBranchId();
      
      if (currentUser == null || branchId == null) {
        print('❌ [ChatReportService] 로그인 정보 없음');
        return false;
      }

      final reportData = {
        'id': 'report_${DateTime.now().millisecondsSinceEpoch}',
        'message_id': messageId,
        'chat_room_id': chatRoomId,
        'reporter_id': currentUser['member_id'].toString(),
        'reporter_name': currentUser['member_name'] ?? '',
        'reported_sender_id': reportedSenderId,
        'reported_sender_type': reportedSenderType,
        'message_content': messageContent,
        'report_reason': reportReason,
        'branch_id': branchId,
        'status': 'pending', // pending, reviewed, resolved, dismissed
        'created_at': DateTime.now().toIso8601String(),
      };

      await SupabaseAdapter.client
          .from('chat_reports')
          .insert(reportData);

      print('✅ [ChatReportService] 신고 접수 완료: $messageId');
      return true;
    } catch (e) {
      print('❌ [ChatReportService] 신고 실패: $e');
      return false;
    }
  }

  /// 사용자 차단
  /// - 차단 정보를 DB에 저장
  /// - 차단된 사용자의 메시지는 표시되지 않음
  static Future<bool> blockUser({
    required String blockedUserId,
    required String blockedUserType,
    String? reason,
  }) async {
    try {
      final currentUser = ApiService.getCurrentUser();
      final branchId = ApiService.getCurrentBranchId();
      
      if (currentUser == null || branchId == null) {
        print('❌ [ChatReportService] 로그인 정보 없음');
        return false;
      }

      final blockData = {
        'id': 'block_${DateTime.now().millisecondsSinceEpoch}',
        'blocker_id': currentUser['member_id'].toString(),
        'blocker_type': 'member',
        'blocked_id': blockedUserId,
        'blocked_type': blockedUserType,
        'branch_id': branchId,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      };

      await SupabaseAdapter.client
          .from('chat_blocks')
          .insert(blockData);

      print('✅ [ChatReportService] 사용자 차단 완료: $blockedUserId');
      return true;
    } catch (e) {
      print('❌ [ChatReportService] 차단 실패: $e');
      return false;
    }
  }

  /// 차단 해제
  static Future<bool> unblockUser({
    required String blockedUserId,
  }) async {
    try {
      final currentUser = ApiService.getCurrentUser();
      
      if (currentUser == null) {
        return false;
      }

      await SupabaseAdapter.client
          .from('chat_blocks')
          .delete()
          .eq('blocker_id', currentUser['member_id'].toString())
          .eq('blocked_id', blockedUserId);

      print('✅ [ChatReportService] 차단 해제 완료: $blockedUserId');
      return true;
    } catch (e) {
      print('❌ [ChatReportService] 차단 해제 실패: $e');
      return false;
    }
  }

  /// 차단된 사용자 목록 조회
  static Future<List<String>> getBlockedUserIds() async {
    try {
      final currentUser = ApiService.getCurrentUser();
      
      if (currentUser == null) {
        return [];
      }

      final response = await SupabaseAdapter.client
          .from('chat_blocks')
          .select('blocked_id')
          .eq('blocker_id', currentUser['member_id'].toString());

      return (response as List)
          .map((item) => item['blocked_id'].toString())
          .toList();
    } catch (e) {
      print('❌ [ChatReportService] 차단 목록 조회 실패: $e');
      return [];
    }
  }

  /// 메시지 삭제 (자신의 메시지만)
  static Future<bool> deleteMessage({
    required String messageId,
  }) async {
    try {
      final currentUser = ApiService.getCurrentUser();
      
      if (currentUser == null) {
        return false;
      }

      // 자신의 메시지인지 확인 후 삭제
      await SupabaseAdapter.client
          .from('chat_messages')
          .update({
            'message': '[삭제된 메시지입니다]',
            'is_deleted': true,
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId)
          .eq('sender_id', currentUser['member_id'].toString());

      print('✅ [ChatReportService] 메시지 삭제 완료: $messageId');
      return true;
    } catch (e) {
      print('❌ [ChatReportService] 메시지 삭제 실패: $e');
      return false;
    }
  }

  /// 신고 사유 목록
  static List<String> getReportReasons() {
    return [
      '욕설/비속어',
      '음란/성적 내용',
      '스팸/광고',
      '사기/사칭',
      '개인정보 노출',
      '기타 부적절한 내용',
    ];
  }

  // ========== 게시판 관련 메서드 ==========

  /// 게시글 신고
  static Future<bool> reportBoard({
    required String boardId,
    required String reportedMemberId,
    required String reportedMemberName,
    required String boardTitle,
    required String boardContent,
    required String reportReason,
  }) async {
    try {
      final currentUser = ApiService.getCurrentUser();
      final branchId = ApiService.getCurrentBranchId();
      
      if (currentUser == null || branchId == null) {
        print('❌ [ChatReportService] 로그인 정보 없음');
        return false;
      }

      final reportData = {
        'id': 'board_report_${DateTime.now().millisecondsSinceEpoch}',
        'content_type': 'board',
        'content_id': boardId,
        'reporter_id': currentUser['member_id'].toString(),
        'reporter_name': currentUser['member_name'] ?? '',
        'reported_user_id': reportedMemberId,
        'reported_user_name': reportedMemberName,
        'content_title': boardTitle,
        'content_text': boardContent,
        'report_reason': reportReason,
        'branch_id': branchId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      await SupabaseAdapter.client
          .from('content_reports')
          .insert(reportData);

      print('✅ [ChatReportService] 게시글 신고 접수 완료: $boardId');
      return true;
    } catch (e) {
      print('❌ [ChatReportService] 게시글 신고 실패: $e');
      return false;
    }
  }

  /// 댓글 신고
  static Future<bool> reportReply({
    required String replyId,
    required String boardId,
    required String reportedMemberId,
    required String reportedMemberName,
    required String replyContent,
    required String reportReason,
  }) async {
    try {
      final currentUser = ApiService.getCurrentUser();
      final branchId = ApiService.getCurrentBranchId();
      
      if (currentUser == null || branchId == null) {
        print('❌ [ChatReportService] 로그인 정보 없음');
        return false;
      }

      final reportData = {
        'id': 'reply_report_${DateTime.now().millisecondsSinceEpoch}',
        'content_type': 'reply',
        'content_id': replyId,
        'parent_id': boardId,
        'reporter_id': currentUser['member_id'].toString(),
        'reporter_name': currentUser['member_name'] ?? '',
        'reported_user_id': reportedMemberId,
        'reported_user_name': reportedMemberName,
        'content_text': replyContent,
        'report_reason': reportReason,
        'branch_id': branchId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      await SupabaseAdapter.client
          .from('content_reports')
          .insert(reportData);

      print('✅ [ChatReportService] 댓글 신고 접수 완료: $replyId');
      return true;
    } catch (e) {
      print('❌ [ChatReportService] 댓글 신고 실패: $e');
      return false;
    }
  }
}

