import 'package:flutter/material.dart';
import '../../../models/board_model.dart';
import '../../../services/board_service.dart';
import 'board_create_page.dart';

class BoardDetailPage extends StatefulWidget {
  final BoardModel board;
  final String? branchId;
  final Map<String, dynamic>? selectedMember;

  const BoardDetailPage({
    Key? key,
    required this.board,
    this.branchId,
    this.selectedMember,
  }) : super(key: key);

  @override
  _BoardDetailPageState createState() => _BoardDetailPageState();
}

class _BoardDetailPageState extends State<BoardDetailPage> {
  List<BoardReplyModel> _replies = [];
  bool _isLoading = false;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    if (widget.branchId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final replies = await BoardService.getBoardReplies(
        branchId: widget.branchId!,
        memberboardId: widget.board.memberboardId,
      );

      setState(() {
        _replies = replies;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading replies: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitReply() async {
    if (_replyController.text.trim().isEmpty) return;
    if (widget.branchId == null || widget.selectedMember == null) return;

    final content = _replyController.text.trim();
    final memberId = widget.selectedMember!['member_id']?.toString() ?? '';

    try {
      final memberName = widget.selectedMember!['member_name']?.toString();
      final success = await BoardService.createReply(
        branchId: widget.branchId!,
        memberboardId: widget.board.memberboardId,
        memberId: memberId,
        content: content,
        memberName: memberName,
      );

      if (success) {
        _replyController.clear();
        _replyFocusNode.unfocus();
        _loadReplies();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글이 등록되었습니다')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 등록에 실패했습니다')),
        );
      }
    } catch (e) {
      print('Error submitting reply: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 등록 중 오류가 발생했습니다')),
      );
    }
  }

  Future<void> _deleteBoard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('게시글 삭제'),
        content: Text('정말로 이 게시글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.branchId != null && widget.selectedMember != null) {
      final memberId = widget.selectedMember!['member_id']?.toString() ?? '';
      
      try {
        final success = await BoardService.deleteBoard(
          branchId: widget.branchId!,
          memberboardId: widget.board.memberboardId,
          memberId: memberId,
        );

        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('게시글이 삭제되었습니다')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('게시글 삭제에 실패했습니다')),
          );
        }
      } catch (e) {
        print('Error deleting board: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게시글 삭제 중 오류가 발생했습니다')),
        );
      }
    }
  }

  void _editBoard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoardCreatePage(
          branchId: widget.branchId,
          selectedMember: widget.selectedMember,
          editingBoard: widget.board,
        ),
      ),
    ).then((result) {
      if (result == true) {
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final boardTypeDisplay = BoardModel.getBoardTypeDisplayName(widget.board.boardType);
    final isAuthor = widget.selectedMember != null && 
        widget.selectedMember!['member_id']?.toString() == widget.board.memberId;

    Color getTagColor(String boardType) {
      switch (boardType) {
        case 'free':
          return Colors.blue;
        case 'round':
          return Colors.green;
        case 'market':
          return Colors.orange;
        default:
          return Colors.grey;
      }
    }

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1A1A),
        title: Text(
          '게시글 상세',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (isAuthor) ...[
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('수정'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('삭제', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editBoard();
                } else if (value == 'delete') {
                  _deleteBoard();
                }
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 게시글 내용
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: getTagColor(widget.board.boardType).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: getTagColor(widget.board.boardType).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                boardTypeDisplay,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: getTagColor(widget.board.boardType),
                                ),
                              ),
                            ),
                            if (widget.board.postStatus != null && widget.board.postStatus!.isNotEmpty) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: widget.board.postStatus == '진행' 
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: widget.board.postStatus == '진행' 
                                        ? Colors.green.withOpacity(0.3)
                                        : Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  widget.board.postStatus!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: widget.board.postStatus == '진행' ? Colors.green : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          widget.board.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[300],
                              child: Icon(
                                Icons.person,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              widget.board.memberName ?? '익명',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            Spacer(),
                            Text(
                              '${widget.board.createdAt.year}.${widget.board.createdAt.month.toString().padLeft(2, '0')}.${widget.board.createdAt.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        if (widget.board.postDueDate != null) ...[
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.event,
                                  size: 20,
                                  color: Colors.purple[600],
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '이벤트일자: ${widget.board.postDueDate!.year}.${widget.board.postDueDate!.month.toString().padLeft(2, '0')}.${widget.board.postDueDate!.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.purple[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: 24),
                        Text(
                          widget.board.content,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 8),

                  // 댓글 섹션
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.comment, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '댓글 ${_replies.length}개',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        
                        if (_isLoading)
                          Center(child: CircularProgressIndicator())
                        else if (_replies.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.comment_outlined,
                                  size: 48,
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '첫 번째 댓글을 남겨보세요!',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...(_replies.map((reply) => _buildReplyItem(reply)).toList()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 댓글 입력창
          if (widget.selectedMember != null) _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildReplyItem(BoardReplyModel reply) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey[300],
                child: Icon(
                  Icons.person,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(width: 8),
              Text(
                reply.memberName ?? '익명',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              Spacer(),
              Text(
                '${reply.createdAt.month}/${reply.createdAt.day} ${reply.createdAt.hour.toString().padLeft(2, '0')}:${reply.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            reply.content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                focusNode: _replyFocusNode,
                decoration: InputDecoration(
                  hintText: '댓글을 입력하세요...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Color(0xFF00A86B)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitReply(),
              ),
            ),
            SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF00A86B),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _submitReply,
              ),
            ),
          ],
        ),
      ),
    );
  }
}