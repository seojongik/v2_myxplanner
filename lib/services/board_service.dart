import '../models/board_model.dart';
import 'api_service.dart';

class BoardService {
  static Future<List<BoardModel>> getBoardList({
    required String branchId,
    String? boardType,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final whereConditions = <Map<String, dynamic>>[
        {'field': 'branch_id', 'operator': '=', 'value': branchId}
      ];
      
      if (boardType != null && boardType.isNotEmpty) {
        whereConditions.add({
          'field': 'board_type', 
          'operator': '=', 
          'value': boardType
        });
      }

      final data = await ApiService.getData(
        table: 'v2_board_by_member',
        fields: ['*'],
        where: whereConditions,
        orderBy: [
          {'field': 'created_at', 'direction': 'DESC'}
        ],
        limit: limit,
        offset: (page - 1) * limit,
      );
      
      return data.map((item) => BoardModel.fromJson(item)).toList();
    } catch (e) {
      print('Error fetching board list: $e');
      return [];
    }
  }

  static Future<BoardModel?> getBoardDetail({
    required String branchId,
    required int memberboardId,
  }) async {
    try {
      final data = await ApiService.getData(
        table: 'v2_board_by_member',
        fields: ['*'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'memberboard_id', 'operator': '=', 'value': memberboardId}
        ],
      );
      
      if (data.isNotEmpty) {
        return BoardModel.fromJson(data[0]);
      }
      return null;
    } catch (e) {
      print('Error fetching board detail: $e');
      return null;
    }
  }

  static Future<List<BoardReplyModel>> getBoardReplies({
    required String branchId,
    required int memberboardId,
  }) async {
    try {
      print('=== 댓글 조회 시작 ===');
      print('branchId: $branchId');
      print('memberboardId: $memberboardId');

      final data = await ApiService.getData(
        table: 'v2_board_by_member_replies',
        fields: ['*'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'memberboard_id', 'operator': '=', 'value': memberboardId}
        ],
        orderBy: [
          {'field': 'created_at', 'direction': 'ASC'}
        ],
      );
      
      print('댓글 데이터: $data');
      return data.map((item) => BoardReplyModel.fromJson(item)).toList();
    } catch (e) {
      print('Error fetching board replies: $e');
      return [];
    }
  }

  static Future<bool> createBoard({
    required String branchId,
    required String memberId,
    required String title,
    required String content,
    required String boardType,
    String? postStatus,
    DateTime? postDueDate,
    String? memberName,
  }) async {
    try {
      print('=== 게시글 등록 시작 ===');
      print('branchId: $branchId');
      print('memberId: $memberId');
      print('title: $title');
      print('content: $content');
      print('boardType: $boardType');
      print('postStatus: $postStatus');
      print('postDueDate: $postDueDate');

      final data = <String, dynamic>{
        'branch_id': branchId,
        'member_id': memberId,
        'member_name': memberName,
        'title': title,
        'content': content,
        'board_type': boardType,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (postStatus != null && postStatus.isNotEmpty) {
        data['post_status'] = postStatus;
      }
      
      if (postDueDate != null) {
        data['post_due_date'] = postDueDate.toIso8601String();
      }

      print('Request data: $data');

      final result = await ApiService.addData(
        table: 'v2_board_by_member',
        data: data,
      );
      
      print('API 응답: $result');
      return result['success'] == true;
    } catch (e, stackTrace) {
      print('Error creating board: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<bool> updateBoard({
    required String branchId,
    required int memberboardId,
    required String memberId,
    required String title,
    required String content,
    String? postStatus,
    DateTime? postDueDate,
  }) async {
    try {
      final data = <String, dynamic>{
        'title': title,
        'content': content,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (postStatus != null && postStatus.isNotEmpty) {
        data['post_status'] = postStatus;
      }
      
      if (postDueDate != null) {
        data['post_due_date'] = postDueDate.toIso8601String();
      }

      final result = await ApiService.updateData(
        table: 'v2_board_by_member',
        data: data,
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'memberboard_id', 'operator': '=', 'value': memberboardId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
      );
      
      return result['success'] == true;
    } catch (e) {
      print('Error updating board: $e');
      return false;
    }
  }

  static Future<bool> deleteBoard({
    required String branchId,
    required int memberboardId,
    required String memberId,
  }) async {
    try {
      final result = await ApiService.deleteData(
        table: 'v2_board_by_member',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'memberboard_id', 'operator': '=', 'value': memberboardId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
      );
      
      return result['success'] == true;
    } catch (e) {
      print('Error deleting board: $e');
      return false;
    }
  }

  static Future<bool> createReply({
    required String branchId,
    required int memberboardId,
    required String memberId,
    required String content,
    String? memberName,
  }) async {
    try {
      print('=== 댓글 등록 시작 ===');
      print('branchId: $branchId');
      print('memberboardId: $memberboardId');
      print('memberId: $memberId');
      print('content: $content');

      final data = <String, dynamic>{
        'branch_id': branchId,
        'memberboard_id': memberboardId,
        'member_id': memberId,
        'member_name': memberName,
        'reply_by_member': content,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('Request data: $data');

      final result = await ApiService.addData(
        table: 'v2_board_by_member_replies',
        data: data,
      );
      
      print('API 응답: $result');
      return result['success'] == true;
    } catch (e, stackTrace) {
      print('Error creating reply: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<bool> deleteReply({
    required String branchId,
    required int memberboardId,
    required String memberId,
  }) async {
    try {
      final result = await ApiService.deleteData(
        table: 'v2_board_by_member_replies',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'memberboard_id', 'operator': '=', 'value': memberboardId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
      );
      
      return result['success'] == true;
    } catch (e) {
      print('Error deleting reply: $e');
      return false;
    }
  }
}
