import '/flutter_flow/flutter_flow_util.dart';
import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/services/api_service.dart';
import 'crm1_board_widget.dart' show Crm1BoardWidget;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 게시글 데이터 모델 (v2_board 구조에 맞게 수정)
class BoardPost {
  final int boardId;
  final String title;
  final String content;
  final int? memberId;
  final String? memberName; // v3_members 테이블에서 가져올 회원명
  final DateTime createdAt;
  final DateTime updatedAt;
  final String boardType;
  final String branchId;
  final int? managerId;
  final String? managerName; // v2_board 테이블에 포함된 작성자명
  final int? proId;
  final String? proName; // v2_board 테이블에 포함된 작성자명
  final int commentCount; // v2_board_comment 테이블에서 가져올 댓글 수
  final List<Map<String, dynamic>> comments; // 댓글 목록

  BoardPost({
    required this.boardId,
    required this.title,
    required this.content,
    this.memberId,
    this.memberName,
    required this.createdAt,
    required this.updatedAt,
    required this.boardType,
    required this.branchId,
    this.managerId,
    this.managerName,
    this.proId,
    this.proName,
    this.commentCount = 0,
    this.comments = const [],
  });

  // DB 데이터에서 BoardPost 객체 생성
  factory BoardPost.fromJson(Map<String, dynamic> json) {
    return BoardPost(
      boardId: json['board_id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      memberId: json['member_id'],
      memberName: json['member_name'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      boardType: json['board_type'] ?? '일반',
      branchId: json['branch_id'] ?? '',
      managerId: json['manager_id'],
      managerName: json['manager_name'],
      proId: json['pro_id'],
      proName: json['pro_name'],
      commentCount: int.tryParse(json['comment_count']?.toString() ?? '0') ?? 0,
      comments: json['comments'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'board_id': boardId,
      'title': title,
      'content': content,
      'member_id': memberId,
      'member_name': memberName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'board_type': boardType,
      'branch_id': branchId,
      'manager_id': managerId,
      'manager_name': managerName,
      'pro_id': proId,
      'pro_name': proName,
      'comment_count': commentCount,
      'comments': comments,
    };
  }

  // NEW 표시 여부 (3일 이내)
  bool get isNew {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inDays <= 3; // 3일 이내를 NEW로 간주
  }

  // 최근글 여부 (7일 이내)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inDays <= 7; // 7일 이내를 최근글로 간주
  }

  // 날짜 포맷팅
  String get formattedDate {
    return DateFormat('yyyy.MM.dd   HH:mm').format(createdAt);
  }

  // 작성자 이름 가져오기 (manager_name 또는 pro_name 중 하나)
  String get authorName {
    if (managerName != null && managerName!.isNotEmpty) {
      return managerName!;
    } else if (proName != null && proName!.isNotEmpty) {
      return proName!;
    } else {
      return '관리자';
    }
  }
}

class Crm1BoardModel extends FlutterFlowModel<Crm1BoardWidget> with ChangeNotifier {
  ///  State fields for stateful widgets in this page.

  // Model for sideBarNav component.
  late SideBarNavModel sideBarNavModel;
  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // 게시글 관련 상태
  List<BoardPost> _allPosts = [];
  List<BoardPost> _filteredPosts = [];
  String _searchQuery = '';
  String _selectedTag = '최근글'; // 기본값을 최근글로 설정
  bool _isLoading = false;
  String? _errorMessage;
  
  // 태그별 캐시 추가 - 성능 최적화
  Map<String, List<BoardPost>> _tagCache = {};
  bool _cacheInitialized = false;
  
  // 페이지네이션 추가
  static const int _pageSize = 10000; // 한 번에 표시할 게시글 수 - 모든 게시글 표시
  Map<String, int> _currentPageByTag = {}; // 태그별 현재 페이지
  Map<String, List<BoardPost>> _displayedPostsByTag = {}; // 태그별 현재 표시 중인 게시글
  
  // 사용 가능한 태그 목록 (board_type 기반)
  final List<String> availableTags = [
    '최근글',
    '상담기록', 
    '회원요청', 
    '이벤트기획', 
    '기기문제', 
    '주차권', 
    '락커대기',
    '일반'
  ];

  // 게시글 타입 목록 (게시글 작성시 사용)
  final List<String> boardTypes = [
    '상담기록',
    '회원요청', 
    '이벤트기획', 
    '기기문제', 
    '주차권', 
    '락커대기'
  ];

  // Getters
  List<BoardPost> get filteredPosts => _filteredPosts;
  String get searchQuery => _searchQuery;
  String get selectedTag => _selectedTag;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // 페이지네이션 관련 getters
  bool get hasMorePosts {
    final taggedPosts = _tagCache[_selectedTag] ?? [];
    final currentPage = _currentPageByTag[_selectedTag] ?? 1;
    return taggedPosts.length > currentPage * _pageSize;
  }
  
  int get totalPostsForCurrentTag {
    return _tagCache[_selectedTag]?.length ?? 0;
  }
  
  int get displayedPostsCount {
    return _filteredPosts.length;
  }

  @override
  void initState(BuildContext context) {
    print('📋 [Board] initState() 호출');
    sideBarNavModel = createModel(context, () => SideBarNavModel());
    loadPosts();
  }

  @override
  void dispose() {
    sideBarNavModel.dispose();
    tabBarController?.dispose();
    super.dispose();
  }

  // 태그별 캐시 생성 - 한번만 실행
  void _buildTagCache() {
    if (_cacheInitialized) return;
    
    print('📋 [Board] _buildTagCache() 시작');
    
    _tagCache.clear();
    _currentPageByTag.clear();
    _displayedPostsByTag.clear();
    
    // 각 태그별로 미리 필터링
    for (String tag in availableTags) {
      List<BoardPost> taggedPosts;
      
      if (tag == '최근글') {
        taggedPosts = _allPosts.where((post) => post.isRecent).toList();
      } else {
        taggedPosts = _allPosts.where((post) => post.boardType == tag).toList();
      }
      
      _tagCache[tag] = taggedPosts;
      _currentPageByTag[tag] = 1;
      _displayedPostsByTag[tag] = [];
    }
    
    _cacheInitialized = true;
    print('📋 [Board] _buildTagCache() 완료 - 전체: ${_allPosts.length}개');
  }

  // 검색어 적용 (캐시된 태그 결과에서 검색) - 페이지네이션 적용
  void _applySearchToTaggedPosts() {
    List<BoardPost> taggedPosts = _tagCache[_selectedTag] ?? [];
    List<BoardPost> searchedPosts;
    
    if (_searchQuery.isEmpty) {
      searchedPosts = taggedPosts;
    } else {
      final searchLower = _searchQuery.toLowerCase();
      searchedPosts = taggedPosts.where((post) {
        return post.title.toLowerCase().contains(searchLower) ||
            post.content.toLowerCase().contains(searchLower) ||
            post.authorName.toLowerCase().contains(searchLower) ||
            (post.memberName?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }
    
    // 페이지네이션 적용
    final currentPage = _currentPageByTag[_selectedTag] ?? 1;
    final endIndex = currentPage * _pageSize;
    
    if (searchedPosts.length <= _pageSize) {
      _filteredPosts = searchedPosts;
    } else {
      _filteredPosts = searchedPosts.take(endIndex).toList();
    }
    
    _displayedPostsByTag[_selectedTag] = _filteredPosts;
  }

  // 실제 데이터 로드 (v2_board 구조에 맞게 수정)
  Future<void> loadPosts() async {
    // 중복 호출 방지
    if (_isLoading) {
      print('📋 [Board] loadPosts() 이미 로딩 중 - 스킵');
      return;
    }
    
    print('📋 [Board] loadPosts() 시작');
    _isLoading = true;
    _errorMessage = null;
    _cacheInitialized = false;
    notifyListeners();
    
    try {
      final currentUser = ApiService.getCurrentUser();
      final currentBranchId = ApiService.getCurrentBranchId();
      
      if (currentBranchId == null) {
        throw Exception('지점 정보가 없습니다.');
      }
      
      // 1. v2_board 데이터 가져오기
      final boardData = await ApiService.getBoardByMemberData(
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': currentBranchId}
        ],
        orderBy: [
          {'field': 'created_at', 'direction': 'DESC'}
        ],
      );
      
      print('📋 [Board] 게시글: ${boardData.length}개');
      
      if (boardData.isEmpty) {
        _allPosts = [];
        _tagCache.clear();
        _filteredPosts = [];
        return;
      }
      
      // 2. 필요한 ID들 추출
      final memberIds = <int>{};
      final boardIds = <int>{};
      
      for (var board in boardData) {
        if (board['member_id'] != null && board['member_id'] != 0) {
          memberIds.add(board['member_id']);
        }
        if (board['board_id'] != null) {
          boardIds.add(board['board_id']);
        }
      }
      
      // 3. Member 데이터 가져오기
      Map<int, Map<String, dynamic>> memberMap = {};
      if (memberIds.isNotEmpty) {
        try {
          final memberData = await ApiService.getMemberData(
            where: [
              {'field': 'member_id', 'operator': 'IN', 'value': memberIds.toList()}
            ],
          );
          print('📋 [Board] 회원: ${memberData.length}개');
          
          for (var member in memberData) {
            if (member['member_id'] != null) {
              memberMap[member['member_id']] = member;
            }
          }
        } catch (e) {
          print('❌ [Board] Member 로드 오류: $e');
        }
      }
      
      // 4. 댓글 데이터 가져오기
      Map<int, List<Map<String, dynamic>>> commentMap = {};
      Map<int, int> commentCountMap = {};
      if (boardIds.isNotEmpty) {
        try {
          final commentData = await ApiService.getBoardRepliesData(
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': currentBranchId}
            ],
            orderBy: [
              {'field': 'board_id', 'direction': 'ASC'},
              {'field': 'created_at', 'direction': 'ASC'}
            ],
          );
          
          print('📋 [Board] 댓글: ${commentData.length}개');
          
          for (var comment in commentData) {
            final boardId = comment['board_id'];
            if (boardId != null) {
              if (!commentMap.containsKey(boardId)) {
                commentMap[boardId] = [];
                commentCountMap[boardId] = 0;
              }
              commentMap[boardId]!.add(comment);
              commentCountMap[boardId] = commentCountMap[boardId]! + 1;
            }
          }
        } catch (e) {
          print('❌ [Board] Comment 로드 오류: $e');
        }
      }
      
      // 5. BoardPost 객체들 생성
      List<BoardPost> posts = [];
      for (var boardJson in boardData) {
        final memberId = boardJson['member_id'];
        final boardId = boardJson['board_id'];
        
        String? memberName;
        if (memberId != null && memberId != 0 && memberMap.containsKey(memberId)) {
          memberName = memberMap[memberId]!['member_name'];
        }
        
        final comments = commentMap[boardId] ?? [];
        final commentCount = commentCountMap[boardId] ?? 0;
        
        final post = BoardPost(
          boardId: boardJson['board_id'] ?? 0,
          title: boardJson['title'] ?? '',
          content: boardJson['content'] ?? '',
          memberId: memberId == 0 ? null : memberId,
          memberName: memberName,
          createdAt: DateTime.tryParse(boardJson['created_at'] ?? '') ?? DateTime.now(),
          updatedAt: DateTime.tryParse(boardJson['updated_at'] ?? '') ?? DateTime.now(),
          boardType: boardJson['board_type'] ?? '일반',
          branchId: boardJson['branch_id'] ?? '',
          managerId: boardJson['manager_id'],
          managerName: boardJson['manager_name'],
          proId: boardJson['pro_id'],
          proName: boardJson['pro_name'],
          commentCount: commentCount,
          comments: comments,
        );
        
        posts.add(post);
      }
      
      _allPosts = posts;
      _buildTagCache();
      _applySearchToTaggedPosts();
      
      print('✅ [Board] loadPosts() 완료 - ${_allPosts.length}개');
      
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ [Board] loadPosts() 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 확장된 검색 기능
  void onSearchChanged(String query) {
    _searchQuery = query;
    _applySearchToTaggedPosts(); // 캐시된 태그 결과에서 검색
    notifyListeners();
  }

  void onSearchSubmitted(String query) {
    _searchQuery = query;
    _applySearchToTaggedPosts();
    notifyListeners();
  }

  // 태그 선택 (한번에 하나만 선택 가능)
  void onTagSelected(List<String> selectedTags) {
    if (selectedTags.isNotEmpty) {
      _selectedTag = selectedTags.last;
    } else {
      _selectedTag = '최근글';
    }
    
    _currentPageByTag[_selectedTag] = 1;
    _applySearchToTaggedPosts();
    notifyListeners();
  }

  // 게시글 작성 버튼 클릭
  void onCreatePostPressed() {
    // TODO: 게시글 작성 다이얼로그 또는 페이지 열기
  }

  // 게시글 클릭
  void onPostTapped(BoardPost post) {
    // TODO: 게시글 상세 페이지로 네비게이션
  }

  // 게시글 생성 (v2_board 구조에 맞게 수정)
  Future<bool> createPost({
    required String title,
    required String content,
    required String boardType,
    int? memberId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final currentUser = ApiService.getCurrentUser();
      final currentBranchId = ApiService.getCurrentBranchId();
      
      if (currentUser == null || currentBranchId == null) {
        throw Exception('로그인 정보가 없습니다.');
      }
      
      print('📋 [Board] createPost() 시작');
      
      final data = {
        'title': title,
        'content': content,
        'board_type': boardType,
        'member_id': memberId ?? 0,
        'member_name': memberId != null ? '회원' : '개발자',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'branch_id': currentBranchId,
        'manager_id': currentUser['manager_id'],
        'manager_name': currentUser['manager_name'],
        'pro_id': currentUser['pro_id'],
        'pro_name': currentUser['pro_name'],
      };
      
      final result = await ApiService.addBoardByMemberData(data);
      
      int? newBoardId;
      if (result is Map<String, dynamic> && result['board_id'] != null) {
        newBoardId = result['board_id'];
      } else {
        final latestBoard = await ApiService.getBoardByMemberData(
          orderBy: [{'field': 'created_at', 'direction': 'DESC'}],
          limit: 1,
        );
        if (latestBoard.isNotEmpty) {
          newBoardId = latestBoard[0]['board_id'];
        }
      }
      
      if (newBoardId != null) {
        String? memberName;
        if (memberId != null && memberId != 0) {
          try {
            final memberData = await ApiService.getMemberData(
              where: [{'field': 'member_id', 'operator': '=', 'value': memberId}],
              limit: 1,
            );
            if (memberData.isNotEmpty) {
              memberName = memberData[0]['member_name'];
            }
          } catch (e) {
            print('❌ [Board] Member 정보 로드 오류: $e');
          }
        }
        
        final newPost = BoardPost(
          boardId: newBoardId,
          title: title,
          content: content,
          memberId: memberId == 0 ? null : memberId,
          memberName: memberName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          boardType: boardType,
          branchId: currentBranchId,
          managerId: currentUser['manager_id'],
          managerName: currentUser['manager_name'],
          proId: currentUser['pro_id'],
          proName: currentUser['pro_name'],
          commentCount: 0,
          comments: [],
        );
        
        _allPosts.insert(0, newPost);
        _cacheInitialized = false;
        _buildTagCache();
        _applySearchToTaggedPosts();
        
        print('✅ [Board] createPost() 완료');
      } else {
        await loadPosts();
      }
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ [Board] createPost() 오류: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 게시글 삭제 (v2_board 구조에 맞게 수정)
  Future<bool> deletePost(int boardId) async {
    try {
      _isLoading = true;
      notifyListeners();

      print('📋 [Board] deletePost() ID: $boardId');

      await ApiService.deleteBoardByMemberData([
        {'field': 'board_id', 'operator': '=', 'value': boardId}
      ]);

      _allPosts.removeWhere((post) => post.boardId == boardId);
      _cacheInitialized = false;
      _buildTagCache();
      _applySearchToTaggedPosts();
      
      _isLoading = false;
      notifyListeners();
      
      print('✅ [Board] deletePost() 완료');
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = '게시글 삭제 중 오류가 발생했습니다: $e';
      notifyListeners();
      print('❌ [Board] deletePost() 오류: $e');
      return false;
    }
  }

  // 새로고침
  Future<void> refresh() async {
    await loadPosts();
  }

  // 특정 게시글의 댓글 정보 업데이트 (v2_board 구조에 맞게 수정)
  void updatePostComments(int boardId, List<Map<String, dynamic>> updatedComments) {
    for (int i = 0; i < _allPosts.length; i++) {
      if (_allPosts[i].boardId == boardId) {
        _allPosts[i] = BoardPost(
          boardId: _allPosts[i].boardId,
          title: _allPosts[i].title,
          content: _allPosts[i].content,
          memberId: _allPosts[i].memberId,
          memberName: _allPosts[i].memberName,
          createdAt: _allPosts[i].createdAt,
          updatedAt: _allPosts[i].updatedAt,
          boardType: _allPosts[i].boardType,
          branchId: _allPosts[i].branchId,
          managerId: _allPosts[i].managerId,
          managerName: _allPosts[i].managerName,
          proId: _allPosts[i].proId,
          proName: _allPosts[i].proName,
          commentCount: updatedComments.length,
          comments: updatedComments,
        );
        break;
      }
    }
    
    // 캐시 재생성
    _cacheInitialized = false;
    _buildTagCache();
    
    // 현재 선택된 태그에 맞는 결과 적용
    _applySearchToTaggedPosts();
    notifyListeners();
  }

  // 더 많은 게시글 로드 (페이지네이션)
  void loadMorePosts() {
    if (!hasMorePosts) return;
    
    final currentPage = _currentPageByTag[_selectedTag] ?? 1;
    _currentPageByTag[_selectedTag] = currentPage + 1;
    
    _applySearchToTaggedPosts();
    notifyListeners();
  }
}
