import 'package:flutter/material.dart';
import '../../services/board_service.dart';
import '../../models/board_model.dart';
import '../../widgets/branch_header.dart';
import 'today_reservations/today_reservations_widget.dart';
import 'board_by_member/board_detail_page.dart';
import 'board_by_member/board_create_page.dart';

class HomePage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;

  const HomePage({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;
  List<BoardModel> _recentBoards = [];
  bool _isBoardLoading = false;
  String _currentBoardType = '';
  
  // 각 게시판 타입별 페이지 상태 관리
  final Map<String, int> _pageByBoardType = {};
  final Map<String, bool> _hasMorePagesByBoardType = {};
  
  static const int _itemsPerPage = 4;
  
  // 현재 페이지와 다음 페이지 여부 getter
  int get _currentPage => _pageByBoardType[_currentBoardType] ?? 1;
  bool get _hasMorePages => _hasMorePagesByBoardType[_currentBoardType] ?? true;

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
    // 첫 번째 탭의 페이지 상태 초기화
    _pageByBoardType[_currentBoardType] = 1;
    _hasMorePagesByBoardType[_currentBoardType] = true;
    _loadRecentBoards();
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
    final newBoardType = selectedTab['type'] ?? '';
    
    setState(() {
      _currentBoardType = newBoardType;
      // 해당 게시판 타입의 페이지가 없으면 1로 초기화
      if (!_pageByBoardType.containsKey(newBoardType)) {
        _pageByBoardType[newBoardType] = 1;
        _hasMorePagesByBoardType[newBoardType] = true;
      }
    });
    _loadRecentBoards();
  }

  Future<void> _loadRecentBoards() async {
    if (widget.branchId == null) return;

    setState(() {
      _isBoardLoading = true;
    });

    try {
      final boards = await BoardService.getBoardList(
        branchId: widget.branchId!,
        boardType: _currentBoardType,
        page: _currentPage,
        limit: _itemsPerPage,
      );

      setState(() {
        _recentBoards = boards;
        // 현재 게시판 타입의 다음 페이지 여부 업데이트
        // 가져온 게시글이 4개 미만이면 마지막 페이지
        _hasMorePagesByBoardType[_currentBoardType] = boards.length >= _itemsPerPage;
        _isBoardLoading = false;
      });
    } catch (e) {
      print('Error loading recent boards: $e');
      setState(() {
        _isBoardLoading = false;
      });
    }
  }

  void _goToPage(int page) {
    if (page < 1) return;
    setState(() {
      // 현재 게시판 타입의 페이지만 업데이트
      _pageByBoardType[_currentBoardType] = page;
    });
    _loadRecentBoards();
  }

  Widget _buildBoardListContent() {
    if (_isBoardLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_recentBoards.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            '게시글이 없습니다',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[400],
            ),
          ),
        ),
      );
    }

    // 게시글 리스트 (전체 페이지 스크롤에 포함)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 게시글 아이템들
        ...List.generate(_recentBoards.length, (index) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBoardItem(_recentBoards[index]),
              if (index < _recentBoards.length - 1)
                Divider(height: 1, color: Colors.grey[200]),
            ],
          );
        }),
        // 페이지네이션
        if (!_isBoardLoading && _recentBoards.isNotEmpty)
          _buildPagination(),
      ],
    );
  }

  // 안전한 문자열 변환 헬퍼 메서드
  String? _safeToString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  void _navigateToBoardDetail(BoardModel board) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoardDetailPage(
          board: board,
          branchId: widget.branchId,
          selectedMember: widget.selectedMember,
        ),
      ),
    ).then((_) => _loadRecentBoards());
  }

  void _navigateToCreateBoard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoardCreatePage(
          branchId: widget.branchId,
          selectedMember: widget.selectedMember,
          initialBoardType: _currentBoardType,
        ),
      ),
    ).then((_) => _loadRecentBoards());
  }


  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 오늘의 예약
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
              child: TodayReservationsWidget(
                isAdminMode: widget.isAdminMode,
                selectedMember: widget.selectedMember,
                branchId: widget.branchId,
              ),
            ),

            // 우리 매장 게시판 (스와이프 가능)
            Padding(
              padding: EdgeInsets.only(
                left: isSmallScreen ? 16.0 : 24.0,
                right: isSmallScreen ? 16.0 : 24.0,
                bottom: isSmallScreen ? 16.0 : 24.0,
              ),
              child: _buildStoreBoard(isSmallScreen, screenSize),
            ),

            // 하단 여유 공간 (회색 배경)
            Container(
              height: 100,
              color: Colors.grey[50],
            ),
          ],
        ),
      ),
    );
  }

  // 깔끔한 AppBar 생성
  PreferredSizeWidget _buildAppBar() {
    final memberName = _safeToString(widget.selectedMember?['member_name']) ?? '사용자';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      title: Row(
        children: [
          Icon(Icons.home, color: Colors.blue, size: 24),
          SizedBox(width: 8),
          Text(
            '$memberName님',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.isAdminMode) ...[
            SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '관리자',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 16.0),
          child: Center(child: BranchHeader()),
        ),
      ],
    );
  }


  Widget _buildStoreBoard(bool isSmallScreen, Size screenSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 헤더
        Row(
          children: [
            Icon(
              Icons.forum,
              size: 24,
              color: Color(0xFF06B6D4),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '우리 매장 게시판',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18.0 : 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            // 새 글 등록 버튼 (공지사항 제외)
            if (_currentBoardType != '공지사항')
              Container(
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 4.0,
                      color: Color(0x4006B6D4),
                      offset: Offset(0.0, 2.0),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _navigateToCreateBoard,
                  icon: Icon(Icons.edit, size: 14, color: Colors.white),
                  label: Text(
                    '새 글 등록',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // 탭바
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.zero,
            labelPadding: EdgeInsets.symmetric(horizontal: 16),
            onTap: (index) {
              // 탭 클릭 시 게시판 타입 변경
              final selectedTab = _tabs[index];
              final newBoardType = selectedTab['type'] ?? '';
              if (newBoardType != _currentBoardType) {
                setState(() {
                  _currentBoardType = newBoardType;
                  if (!_pageByBoardType.containsKey(newBoardType)) {
                    _pageByBoardType[newBoardType] = 1;
                    _hasMorePagesByBoardType[newBoardType] = true;
                  }
                });
                _loadRecentBoards();
              }
            },
            tabs: _tabs.map((tab) {
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab['icon'], size: 16),
                    SizedBox(width: 6),
                    Text(
                      tab['title'],
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            }).toList(),
            labelColor: Color(0xFF06B6D4),
            unselectedLabelColor: Color(0xFF64748B),
            indicatorColor: Color(0xFF06B6D4),
            indicatorWeight: 3.0,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),

        // 게시글 리스트 (현재 선택된 탭만 표시)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildBoardListContent(),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이전 버튼
          IconButton(
            onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
            icon: Icon(Icons.chevron_left),
            color: _currentPage > 1 ? Color(0xFF06B6D4) : Colors.grey[300],
          ),

          // 페이지 번호들
          ..._buildPageNumbers(),

          // 다음 버튼
          IconButton(
            onPressed: _hasMorePages ? () => _goToPage(_currentPage + 1) : null,
            icon: Icon(Icons.chevron_right),
            color: _hasMorePages ? Color(0xFF06B6D4) : Colors.grey[300],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pageButtons = [];

    // 현재 페이지 기준으로 앞뒤 1개씩만 표시
    int startPage = (_currentPage - 1).clamp(1, _currentPage);
    // 다음 페이지가 없으면 현재 페이지까지만, 있으면 현재 페이지 + 1까지만
    int endPage = _hasMorePages ? (_currentPage + 1) : _currentPage;

    // 첫 페이지가 1이 아니면 1과 ... 표시
    if (startPage > 1) {
      pageButtons.add(_buildPageButton(1));
      if (startPage > 2) {
        pageButtons.add(Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: Colors.grey[400])),
        ));
      }
    }

    // 현재 페이지 주변 페이지들 표시 (앞뒤 1개씩만)
    for (int i = startPage; i <= endPage; i++) {
      pageButtons.add(_buildPageButton(i));
    }

    return pageButtons;
  }

  Widget _buildPageButton(int page) {
    bool isCurrentPage = page == _currentPage;

    return GestureDetector(
      onTap: () => _goToPage(page),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: isCurrentPage
            ? Border(bottom: BorderSide(color: Color(0xFF06B6D4), width: 2))
            : null,
        ),
        child: Text(
          '$page',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
            color: isCurrentPage ? Color(0xFF06B6D4) : Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardItem(BoardModel board) {
    final boardTypeDisplay = BoardModel.getBoardTypeDisplayName(board.boardType);
    final isToday = DateTime.now().difference(board.createdAt).inDays == 0;
    
    Color getTagColor(String boardType) {
      switch (boardType) {
        case '공지사항':
          return Colors.red[600]!;
        case '자유게시판':
          return Colors.indigo[600]!;
        case '라운딩 모집':
          return Colors.teal[600]!;
        case '중고판매':
          return Colors.amber[600]!;
        default:
          return Colors.grey[600]!;
      }
    }

    IconData getBoardIcon(String boardType) {
      switch (boardType) {
        case '공지사항':
          return Icons.campaign;
        case '자유게시판':
          return Icons.chat_bubble;
        case '라운딩 모집':
          return Icons.golf_course;
        case '중고판매':
          return Icons.storefront;
        default:
          return Icons.article;
      }
    }

    return InkWell(
      onTap: () => _navigateToBoardDetail(board),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 왼쪽 아이콘과 태그 통합
            Container(
              width: 56,
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: getTagColor(board.boardType).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: getTagColor(board.boardType).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    getBoardIcon(board.boardType),
                    size: 24,
                    color: getTagColor(board.boardType),
                  ),
                  SizedBox(height: 4),
                  Text(
                    boardTypeDisplay.length > 4 
                        ? boardTypeDisplay.substring(0, 4) 
                        : boardTypeDisplay,
                    style: TextStyle(
                      fontSize: 11,
                      color: getTagColor(board.boardType),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          board.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        board.memberName ?? '익명',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${board.createdAt.year}.${board.createdAt.month.toString().padLeft(2, '0')}.${board.createdAt.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (board.commentCount != null && board.commentCount! > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.comment,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
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
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

} 