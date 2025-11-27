class BoardModel {
  final String branchId;
  final int memberboardId;
  final String title;
  final String content;
  final String boardType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String memberId;
  final String? postStatus;
  final DateTime? postDueDate;
  final String? memberName;
  final int? commentCount;

  BoardModel({
    required this.branchId,
    required this.memberboardId,
    required this.title,
    required this.content,
    required this.boardType,
    required this.createdAt,
    required this.updatedAt,
    required this.memberId,
    this.postStatus,
    this.postDueDate,
    this.memberName,
    this.commentCount,
  });

  factory BoardModel.fromJson(Map<String, dynamic> json) {
    return BoardModel(
      branchId: json['branch_id']?.toString() ?? '',
      memberboardId: json['memberboard_id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      boardType: json['board_type'] ?? '',
      createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at']) 
        : DateTime.now(),
      updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
        : DateTime.now(),
      memberId: json['member_id']?.toString() ?? '',
      postStatus: json['post_status'],
      postDueDate: json['post_due_date'] != null 
        ? DateTime.parse(json['post_due_date']) 
        : null,
      memberName: json['member_name'],
      commentCount: json['comment_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'branch_id': branchId,
      'memberboard_id': memberboardId,
      'title': title,
      'content': content,
      'board_type': boardType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'member_id': memberId,
      'post_status': postStatus,
      'post_due_date': postDueDate?.toIso8601String(),
      'member_name': memberName,
      'comment_count': commentCount,
    };
  }

  static String getBoardTypeDisplayName(String boardType) {
    // 이제 DB에 한글로 저장되므로 그대로 반환
    return boardType;
  }

  static String getBoardTypeCode(String displayName) {
    // 이제 DB에 한글로 저장되므로 그대로 반환
    return displayName;
  }
}

class BoardReplyModel {
  final String branchId;
  final int memberboardId;
  final int? replyId;
  final String memberId;
  final String? memberName;
  final String replyByMember; // 댓글 내용
  final DateTime createdAt;
  final DateTime updatedAt;

  BoardReplyModel({
    required this.branchId,
    required this.memberboardId,
    this.replyId,
    required this.memberId,
    this.memberName,
    required this.replyByMember,
    required this.createdAt,
    required this.updatedAt,
  });

  // 편의를 위해 댓글 내용을 반환하는 getter
  String get content => replyByMember;

  factory BoardReplyModel.fromJson(Map<String, dynamic> json) {
    return BoardReplyModel(
      branchId: json['branch_id']?.toString() ?? '',
      memberboardId: json['memberboard_id'] ?? 0,
      replyId: json['reply_id'],
      memberId: json['member_id']?.toString() ?? '',
      memberName: json['member_name'],
      replyByMember: json['reply_by_member'] ?? '',
      createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at']) 
        : DateTime.now(),
      updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
        : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'branch_id': branchId,
      'memberboard_id': memberboardId,
      'reply_id': replyId,
      'member_id': memberId,
      'member_name': memberName,
      'reply_by_member': replyByMember,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}