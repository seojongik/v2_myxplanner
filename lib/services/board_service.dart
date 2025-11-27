import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/board_model.dart';

class BoardService {
  static const String baseUrl = 'https://autofms.mycafe24.com/dynamic_api.php';
  static Future<List<BoardModel>> getBoardList({
    required String branchId,
    String? boardType,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final whereConditions = [
        {'field': 'branch_id', 'operator': '=', 'value': branchId}
      ];
      
      if (boardType != null && boardType.isNotEmpty) {
        whereConditions.add({
          'field': 'board_type', 
          'operator': '=', 
          'value': boardType
        });
      }

      final requestData = {
        'operation': 'get',
        'table': 'v2_board_by_member',
        'fields': ['*'],
        'where': whereConditions,
        'orderBy': [
          {'field': 'created_at', 'direction': 'DESC'}
        ],
        'limit': limit,
        'offset': (page - 1) * limit,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          final List<dynamic> boardData = jsonData['data'] ?? [];
          return boardData.map((item) => BoardModel.fromJson(item)).toList();
        }
      }
      return [];
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
      final requestData = {
        'operation': 'get',
        'table': 'v2_board_by_member',
        'fields': ['*'],
        'where': [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'memberboard_id', 'operator': '=', 'value': memberboardId}
        ],
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null && jsonData['data'].isNotEmpty) {
          return BoardModel.fromJson(jsonData['data'][0]);
        }
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

      final requestData = {
        'operation': 'get',
        'table': 'v2_board_by_member_replies',
        'fields': ['*'],
        'where': [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'memberboard_id', 'operator': '=', 'value': memberboardId}
        ],
        'orderBy': [
          {'field': 'created_at', 'direction': 'ASC'}
        ],
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );
      
      print('댓글 조회 응답: ${response.statusCode}');
      print('댓글 조회 응답 body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          final List<dynamic> replyData = jsonData['data'] ?? [];
          print('댓글 데이터: $replyData');
          return replyData.map((item) => BoardReplyModel.fromJson(item)).toList();
        }
      }
      return [];
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

      final data = {
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

      final requestData = {
        'operation': 'add',
        'table': 'v2_board_by_member',
        'data': data,
      };

      print('Request data: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: json.encode(requestData),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('Parsed JSON: $jsonData');
        final success = jsonData['success'] == true;
        if (!success) {
          print('API 응답 실패: ${jsonData['error'] ?? '알 수 없는 오류'}');
        }
        return success;
      } else {
        print('HTTP 오류: ${response.statusCode} - ${response.body}');
        return false;
      }
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
      final data = {
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

      final requestData = {
        'operation': 'update',
        'table': 'v2_board_by_member',
        'data': data,
        'where': [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'memberboard_id', 'operator': '=', 'value': memberboardId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['success'] == true;
      }
      return false;
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
      final requestData = {
        'operation': 'delete',
        'table': 'v2_board_by_member',
        'where': [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'memberboard_id', 'operator': '=', 'value': memberboardId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['success'] == true;
      }
      return false;
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

      final data = {
        'branch_id': branchId,
        'memberboard_id': memberboardId,
        'member_id': memberId,
        'member_name': memberName,
        'reply_by_member': content, // 댓글 내용
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final requestData = {
        'operation': 'add',
        'table': 'v2_board_by_member_replies',
        'data': data,
      };

      print('Request data: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: json.encode(requestData),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('Parsed JSON: $jsonData');
        final success = jsonData['success'] == true;
        if (!success) {
          print('댓글 등록 실패: ${jsonData['error'] ?? '알 수 없는 오류'}');
        }
        return success;
      } else {
        print('HTTP 오류: ${response.statusCode} - ${response.body}');
        return false;
      }
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
      final requestData = {
        'operation': 'delete',
        'table': 'v2_board_by_member_replies',
        'where': [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'memberboard_id', 'operator': '=', 'value': memberboardId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error deleting reply: $e');
      return false;
    }
  }
}