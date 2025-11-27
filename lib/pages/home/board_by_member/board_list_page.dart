import 'package:flutter/material.dart';
import '../../../services/tab_design_service.dart';
import '../../../services/board_service.dart';
import '../../../models/board_model.dart';
import 'board_detail_page.dart';
import 'board_create_page.dart';

class BoardListPage extends StatefulWidget {
  final String? branchId;
  final Map<String, dynamic>? selectedMember;
  
  const BoardListPage({
    Key? key,
    this.branchId,
    this.selectedMember,
  }) : super(key: key);

  @override
  _BoardListPageState createState() => _BoardListPageState();
}

class _BoardListPageState extends State<BoardListPage> with TickerProviderStateMixin {
  late TabController _tabController;
  List<BoardModel> _boards = [];
  bool _isLoading = false;
  String _currentBoardType = '';

  final List<Map<String, dynamic>> _tabs = [
    {'title': '공지사항', 'icon': Icons.campaign, 'type': '공지사항'},
    {'title': '자유게시판', 'icon': Icons.chat_bubble, 'type': '자유게시판'},
    {'title': '라운딩 모집', 'icon': Icons.golf_course, 'type': '라운딩 모집'},
    {'title': '중고판매', 'icon': Icons.storefront, 'type': '중고판매'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _currentBoardType = _tabs[0]['type']; // 첫 번째 탭으로 초기화
    _loadBoards();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    
    final selectedTab = _tabs[_tabController.index];
    setState(() {
      _currentBoardType = selectedTab['type'] ?? '';
    });
    _loadBoards();
  }

  Future<void> _loadBoards() async {
    if (widget.branchId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final boards = await BoardService.getBoardList(
        branchId: widget.branchId!,
        boardType: _currentBoardType,
      );

      setState(() {
        _boards = boards;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading boards: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToDetail(BoardModel board) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoardDetailPage(
          board: board,
          branchId: widget.branchId,
          selectedMember: widget.selectedMember,
        ),
      ),
    ).then((_) => _loadBoards());
  }

  void _navigateToCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoardCreatePage(
          branchId: widget.branchId,
          selectedMember: widget.selectedMember,
          initialBoardType: _currentBoardType,
        ),
      ),
    ).then((_) => _loadBoards());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabDesignService.backgroundColor,
      appBar: TabDesignService.buildAppBar(
        title: '우리 매장 게시판',
        bottom: TabDesignService.buildUnderlineTabBar(
          controller: _tabController,
          tabs: _tabs,
        ),
      ),
      body: Column(
        children: [
          // 새글 등록 버튼 (공지사항이 아닌 경우에만 표시)
          if (_currentBoardType != '공지사항')
            Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: _navigateToCreate,
                icon: Icon(Icons.edit, size: 18),
                label: Text(
                  '새 글 등록',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Color(0xFF00A86B),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: Color(0xFF00A86B),
                    width: 2,
                  ),
                ),
              ),
            ),
          // 게시글 목록
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) => _buildBoardList()).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_boards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              '게시글이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              '첫 번째 게시글을 작성해보세요!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBoards,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _boards.length,
        itemBuilder: (context, index) => _buildBoardItem(_boards[index]),
      ),
    );
  }

  Widget _buildBoardItem(BoardModel board) {
    final boardTypeDisplay = BoardModel.getBoardTypeDisplayName(board.boardType);
    
    Color getTagColor(String boardType) {
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

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(board),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: getTagColor(board.boardType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: getTagColor(board.boardType).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      boardTypeDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: getTagColor(board.boardType),
                      ),
                    ),
                  ),
                  if (board.postStatus != null && board.postStatus!.isNotEmpty) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: board.postStatus == '진행' 
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: board.postStatus == '진행' 
                              ? Colors.green.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        board.postStatus!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: board.postStatus == '진행' ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                  Spacer(),
                  Text(
                    '${board.createdAt.month}/${board.createdAt.day}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                board.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Text(
                board.content.replaceAll('\n', ' '),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (board.postDueDate != null) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 16,
                      color: Colors.purple[400],
                    ),
                    SizedBox(width: 4),
                    Text(
                      '이벤트일자: ${board.postDueDate!.month}/${board.postDueDate!.day}/${board.postDueDate!.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.grey[300],
                    child: Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    board.memberName ?? '익명',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Spacer(),
                  if (board.commentCount != null && board.commentCount! > 0) ...[
                    Icon(
                      Icons.comment_outlined,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${board.commentCount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}