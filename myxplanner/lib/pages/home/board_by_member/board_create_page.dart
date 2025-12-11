import 'package:flutter/material.dart';
import '../../../models/board_model.dart';
import '../../../services/board_service.dart';
import '../../../services/content_filter_service.dart';
import '../../../widgets/chat_eula_dialog.dart';

class BoardCreatePage extends StatefulWidget {
  final String? branchId;
  final Map<String, dynamic>? selectedMember;
  final String? initialBoardType;
  final BoardModel? editingBoard;

  const BoardCreatePage({
    Key? key,
    this.branchId,
    this.selectedMember,
    this.initialBoardType,
    this.editingBoard,
  }) : super(key: key);

  @override
  _BoardCreatePageState createState() => _BoardCreatePageState();
}

class _BoardCreatePageState extends State<BoardCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  String _selectedBoardType = '자유게시판';
  String _postStatus = '진행';
  DateTime? _postDueDate;
  bool _isSubmitting = false;
  bool _eulaAccepted = false;

  final List<Map<String, dynamic>> _boardTypes = [
    {'value': '공지사항', 'label': '공지사항'},
    {'value': '자유게시판', 'label': '자유게시판'},
    {'value': '라운딩 모집', 'label': '라운딩 모집'},
    {'value': '중고판매', 'label': '중고판매'},
  ];

  @override
  void initState() {
    super.initState();
    
    if (widget.editingBoard != null) {
      _titleController.text = widget.editingBoard!.title;
      _contentController.text = widget.editingBoard!.content;
      _selectedBoardType = widget.editingBoard!.boardType;
      _postStatus = widget.editingBoard!.postStatus ?? '진행';
      _postDueDate = widget.editingBoard!.postDueDate;
      _eulaAccepted = true; // 수정 시에는 이미 동의한 것으로 간주
    } else if (widget.initialBoardType != null && widget.initialBoardType!.isNotEmpty) {
      _selectedBoardType = widget.initialBoardType!;
    } else {
      _selectedBoardType = '공지사항'; // 기본값을 공지사항으로
    }
    
    // 새 글 작성 시 EULA 확인
    if (widget.editingBoard == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkEula());
    }
  }

  Future<void> _checkEula() async {
    final accepted = await ChatEulaDialog.show(context);
    if (!accepted) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _eulaAccepted = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Color getBoardTypeColor(String boardType) {
    switch (boardType) {
      case '공지사항':
        return Colors.red;
      case '자유게시판':
        return Colors.indigo;
      case '라운딩 모집':
        return Colors.teal;
      case '중고판매':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  bool _showPostStatus() {
    return _selectedBoardType == '라운딩 모집' || _selectedBoardType == '중고판매';
  }

  bool _showPostDueDate() {
    return _selectedBoardType == '라운딩 모집';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _postDueDate ?? DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    
    if (picked != null && picked != _postDueDate) {
      setState(() {
        _postDueDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    // 제목은 validator로, 내용은 수동으로 체크
    if (!_formKey.currentState!.validate()) return;
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '내용을 입력해주세요',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    if (widget.branchId == null || widget.selectedMember == null) {
      print('브랜치 ID 또는 선택된 회원이 null입니다');
      print('branchId: ${widget.branchId}');
      print('selectedMember: ${widget.selectedMember}');
      return;
    }

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // 콘텐츠 필터링 검사
    final (titleAllowed, titleReason) = ContentFilterService.validateMessage(title);
    if (!titleAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '제목에 $titleReason',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final (contentAllowed, contentReason) = ContentFilterService.validateMessage(content);
    if (!contentAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '내용에 $contentReason',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final memberId = widget.selectedMember!['member_id']?.toString() ?? '';

    print('=== 폼 제출 시작 ===');
    print('제목: "$title"');
    print('내용: "$content"');
    print('제목 길이: ${title.length}');
    print('내용 길이: ${content.length}');
    print('회원 ID: $memberId');
    print('브랜치 ID: ${widget.branchId}');

    final postStatus = _showPostStatus() ? _postStatus : null;
    final postDueDate = _showPostDueDate() ? _postDueDate : null;

    try {
      bool success;
      
      if (widget.editingBoard != null) {
        success = await BoardService.updateBoard(
          branchId: widget.branchId!,
          memberboardId: widget.editingBoard!.memberboardId,
          memberId: memberId,
          title: title,
          content: content,
          postStatus: postStatus,
          postDueDate: postDueDate,
        );
      } else {
        final memberName = widget.selectedMember!['member_name']?.toString();
        success = await BoardService.createBoard(
          branchId: widget.branchId!,
          memberId: memberId,
          title: title,
          content: content,
          boardType: _selectedBoardType,
          postStatus: postStatus,
          postDueDate: postDueDate,
          memberName: memberName,
        );
      }

      print('API 호출 결과: $success');

      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.editingBoard != null ? '게시글이 수정되었습니다' : '게시글이 등록되었습니다',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Color(0xFF06B6D4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.editingBoard != null ? '게시글 수정에 실패했습니다' : '게시글 등록에 실패했습니다',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error submitting form: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '오류가 발생했습니다. 다시 시도해주세요.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingBoard != null;

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1A1A),
        title: Text(
          isEditing ? '게시글 수정' : '새 게시글',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 게시판 유형 표시 (고정값)
              if (!isEditing) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedBoardType == '공지사항' ? Icons.campaign :
                        _selectedBoardType == '자유게시판' ? Icons.chat_bubble :
                        _selectedBoardType == '라운딩 모집' ? Icons.golf_course :
                        Icons.storefront,
                        size: 24,
                        color: getBoardTypeColor(_selectedBoardType),
                      ),
                      SizedBox(width: 12),
                      Text(
                        _boardTypes.firstWhere((type) => type['value'] == _selectedBoardType)['label'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

              // 제목 입력
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.title, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '제목',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' *',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: '제목을 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Color(0xFF00A86B)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '제목을 입력해주세요';
                        }
                        if (value.trim().length > 100) {
                          return '제목은 100자 이내로 입력해주세요';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // 상태 및 날짜 설정
              if (_showPostStatus() || _showPostDueDate()) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_showPostStatus()) ...[
                        Row(
                          children: [
                            Icon(Icons.flag, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '상태',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _postStatus = '진행'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _postStatus == '진행' ? Colors.green : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _postStatus == '진행' ? Colors.green : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Text(
                                    '진행',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _postStatus == '진행' ? Colors.white : Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _postStatus = '완료'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _postStatus == '완료' ? Colors.grey : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _postStatus == '완료' ? Colors.grey : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Text(
                                    '완료',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _postStatus == '완료' ? Colors.white : Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (_showPostDueDate()) ...[
                        if (_showPostStatus()) SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(Icons.event, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '이벤트일자',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                                SizedBox(width: 12),
                                Text(
                                  _postDueDate != null
                                      ? '${_postDueDate!.year}.${_postDueDate!.month.toString().padLeft(2, '0')}.${_postDueDate!.day.toString().padLeft(2, '0')}'
                                      : '날짜를 선택하세요',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _postDueDate != null ? Colors.black87 : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

              // 내용 입력
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '내용',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' *',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 200,
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: '내용을 입력하세요',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(14),
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00A86B),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    isEditing ? '수정하기' : '등록하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}