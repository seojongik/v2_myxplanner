import 'package:flutter/material.dart';
import 'chatting_service.dart';
import 'chat_models.dart';
import '../api_service.dart';
import 'dart:async';

class ChattingPage extends StatefulWidget {
  @override
  _ChattingPageState createState() => _ChattingPageState();
}

class _ChattingPageState extends State<ChattingPage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  ChatRoom? _chatRoom;
  List<ChatMessage> _messages = [];
  bool _isInitializing = true;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChattingService.setChatPageActive(true); // 채팅 페이지 활성화
    _initializeChat();
  }

  @override
  void dispose() {
    ChattingService.setChatPageActive(false); // 채팅 페이지 비활성화
    _messagesSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아왔을 때 관리자 메시지 읽음 처리
      print('🔄 [ChattingUI] 앱 포그라운드 복귀 - 관리자 메시지 읽음 처리');
      ChattingService.markAdminMessagesAsRead();
    }
  }

  Future<void> _initializeChat() async {
    try {
      final chatRoom = await ChattingService.getOrCreateChatRoom();
      
      setState(() {
        _chatRoom = chatRoom;
        _isInitializing = false;
      });

      _messagesSubscription?.cancel(); // 기존 구독이 있다면 취소
      
      int previousMessageCount = _messages.length;
      
      _messagesSubscription = ChattingService.getMessagesStream().listen((messages) {
        if (messages != null) {
          // 현재 사용자 ID 가져오기 (매번 최신 값으로 가져옴)
          final currentUser = ApiService.getCurrentUser();
          final currentMemberId = currentUser?['member_id']?.toString();
          final isAdmin = ApiService.isAdminLogin();
          
          // 타입 명시
          final List<ChatMessage> messageList = messages;
          
          // 새로운 메시지가 있고, 이전 메시지가 있었던 경우만 알림 재생
          if (messageList.length > previousMessageCount && previousMessageCount > 0) {
            final newMessages = messageList.skip(previousMessageCount).toList();
            
            // 회원인 경우: 관리자가 보낸 새 메시지만 알림 재생
            // 관리자인 경우: 회원이 보낸 새 메시지만 알림 재생
            // 자신이 보낸 메시지는 제외 (senderId 비교)
            final messagesToNotify = <ChatMessage>[];
            final messagesIgnored = <ChatMessage>[];
            
            for (final msg in newMessages) {
              // senderId 비교 (문자열로 정확히 비교)
              final msgSenderId = msg.senderId.toString().trim();
              final myId = (currentMemberId?.toString() ?? '').trim();
              final isMyMessage = msgSenderId == myId && myId.isNotEmpty;
              
              // 자신이 보낸 메시지면 알림 제외
              if (isMyMessage) {
                messagesIgnored.add(msg);
                continue;
              }
              
              // 상대방 타입 확인
              final shouldNotify = isAdmin 
                  ? msg.senderType == 'member'  // 관리자인 경우: 회원 메시지만
                  : msg.senderType == 'admin';  // 회원인 경우: 관리자 메시지만
              
              if (shouldNotify) {
                messagesToNotify.add(msg);
              } else {
                messagesIgnored.add(msg);
              }
            }
            
            // 로그 출력 (컴팩트하게)
            for (final msg in newMessages) {
              final msgSenderId = msg.senderId.toString().trim();
              final myId = (currentMemberId?.toString() ?? '').trim();
              final isMyMessage = msgSenderId == myId && myId.isNotEmpty;
              final willNotify = messagesToNotify.contains(msg);
              
              final senderInfo = isMyMessage 
                  ? '나($msgSenderId)' 
                  : '${msg.senderType}($msgSenderId)';
              final messagePreview = msg.message.length > 30 
                  ? '${msg.message.substring(0, 30)}...' 
                  : msg.message;
              final notifyStatus = willNotify ? '🔔 알림' : '🔕 무시';
              
              print('📨 [Chat] $senderInfo: "$messagePreview" | $notifyStatus');
            }
            
            if (messagesToNotify.isNotEmpty) {
              print('✅ [Chat] 알림 재생: ${messagesToNotify.length}개 메시지');
              ChattingService.playNotificationSound();
            } else {
              print('⏭️ [Chat] 알림 없음: 모두 자신이 보낸 메시지이거나 상대방 타입이 아님');
            }
          }
          
          previousMessageCount = messageList.length;
          
          // 새로운 관리자 메시지가 있으면 자동으로 읽음 처리
          final unreadAdminMessages = messageList.where((msg) => 
            msg.senderType == 'admin' && !msg.isRead
          ).toList();
          
          if (unreadAdminMessages.isNotEmpty) {
            // 잠시 후 읽음 처리 (사용자가 메시지를 볼 시간을 줌)
            Future.delayed(Duration(milliseconds: 1000), () {
              if (mounted && _messagesSubscription != null && !_messagesSubscription!.isPaused) {
                ChattingService.markAdminMessagesAsRead();
              }
            });
          }
        }
        
        if (mounted && _messagesSubscription != null && !_messagesSubscription!.isPaused) {
          setState(() {
            _messages = messages ?? [];
          });
          _scrollToBottom();
        } else {
          print('⚠️ [ChattingUI] 위젯이 mounted되지 않거나 구독이 취소됨');
        }
      }, onError: (error) {
        print('❌ [ChattingUI] 메시지 스트림 에러: $error');
        if (mounted && _messagesSubscription != null && !_messagesSubscription!.isPaused) {
          setState(() {
            _messages = [];
          });
        }
      });

      await ChattingService.markAdminMessagesAsRead();
      
    } catch (e) {
      print('❌ 채팅 초기화 실패: $e');
      print('❌ 스택 트레이스: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('채팅 초기화 실패: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_chatRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('채팅 서비스에 연결되지 않았습니다')),
      );
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    
    // 메시지 전송 후 이모티콘 창 닫기
    if (_showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
    }

    try {
      await ChattingService.sendMessage(message);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메시지 전송 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ApiService.getCurrentBranch();
    final branchName = currentBranch?['branch_name'] ?? '골프연습장';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${branchName}과의 1:1대화',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Color(0xFFB8C5D6),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.menu, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      backgroundColor: Color(0xFFB8C5D6),
      body: _isInitializing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '채팅방을 준비하고 있습니다...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _buildMessageList(),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageList() {
    // 브랜치 이름 가져오기
    final currentBranch = ApiService.getCurrentBranch();
    final branchName = currentBranch?['branch_name'] ?? '골프연습장';
    
    if (_chatRoom == null && !_isInitializing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              '채팅 서비스에 연결할 수 없습니다',
              style: TextStyle(fontSize: 18, color: Colors.red[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Firebase 연결을 확인해주세요',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeChat,
              child: Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.black38,
            ),
            SizedBox(height: 16),
            Text(
              '채팅을 시작하세요',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageItem(_messages[index], branchName);
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Color(0xFFB8C5D6),
      child: SafeArea(
        child: Column(
          children: [
            if (_showEmojiPicker)
              Container(
                height: 180,
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: GridView.builder(
                  padding: EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _commonEmojis.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _insertEmoji(_commonEmojis[index]),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _commonEmojis[index],
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: 48,
                      maxHeight: 120,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: '메시지를 입력하세요',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          isDense: true,
                        ),
                        maxLines: 5,
                        minLines: 1,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                        ),
                        textInputAction: TextInputAction.newline,
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _showEmojiPicker = !_showEmojiPicker;
                      });
                    },
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard : Icons.sentiment_satisfied,
                      color: Colors.black54,
                      size: 22,
                    ),
                    padding: EdgeInsets.all(10),
                    constraints: BoxConstraints(),
                  ),
                ),
                SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: Icon(Icons.send, color: Colors.black54, size: 22),
                    padding: EdgeInsets.all(10),
                    constraints: BoxConstraints(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 자주 사용하는 이모티콘 목록
  final List<String> _commonEmojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
    '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
    '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜',
    '🤪', '🤨', '🧐', '🤓', '😎', '🥸', '🤩', '🥳',
    '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️',
    '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤',
    '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱',
    '😨', '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫',
    '🤥', '😶', '😐', '😑', '😬', '🙄', '😯', '😦',
    '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵',
    '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕',
    '🤑', '🤠', '😈', '👿', '👹', '👺', '🤡', '💩',
    '👻', '💀', '☠️', '👽', '👾', '🤖', '🎃', '😺',
    '😸', '😹', '😻', '😼', '😽', '🙀', '😿', '😾',
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙',
    '👈', '👉', '👆', '🖕', '👇', '☝️', '👋', '🤚',
    '🖐️', '✋', '🖖', '👏', '🙌', '🤲', '🤝', '🙏',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
    '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
    '💘', '💝', '💟', '☮️', '✝️', '☪️', '🕉️', '☸️',
  ];

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    
    // selection 범위 검증
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    
    final newText = text.replaceRange(start, end, emoji);
    _messageController.value = _messageController.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (start + emoji.length).clamp(0, newText.length),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message, String branchName) {
    final isMyMessage = message.senderType == 'member';
    
    // 상대방 메시지일 때 발신자 라벨 생성
    String? senderLabel;
    if (!isMyMessage) {
      switch (message.senderType) {
        case 'admin':
          senderLabel = '관리자';
          break;
        case 'manager':
          senderLabel = '매니저';
          break;
        case 'pro':
          // 프로는 이름 + " 프로" 형식
          final proName = message.senderName.isNotEmpty 
              ? message.senderName 
              : '프로';
          senderLabel = '$proName 프로';
          break;
        default:
          // 기본값: 지점명 (기존 동작 유지)
          senderLabel = branchName;
          break;
      }
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMyMessage 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            // sender_type별 아이콘 및 색상
            CircleAvatar(
              radius: 16,
              backgroundColor: _getAvatarColor(message.senderType),
              child: Icon(
                _getAvatarIcon(message.senderType),
                size: 18,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMyMessage 
                  ? CrossAxisAlignment.end 
                  : CrossAxisAlignment.start,
              children: [
                if (!isMyMessage && senderLabel != null) ...[
                  Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 2),
                    child: Text(
                      senderLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMyMessage ? Color(0xFFFFEB3B) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    message.message,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ),
                SizedBox(height: 2),
                Padding(
                  padding: EdgeInsets.only(
                    left: isMyMessage ? 0 : 8,
                    right: isMyMessage ? 8 : 0,
                  ),
                  child: Text(
                    _formatTimeSimple(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      return '${weekdays[timestamp.weekday - 1]} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatTimeSimple(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  // sender_type별 아바타 아이콘 가져오기
  IconData _getAvatarIcon(String senderType) {
    switch (senderType) {
      case 'admin':
        return Icons.golf_course; // 골프 홀 아이콘
      case 'manager':
        return Icons.supervisor_account;
      case 'pro':
        return Icons.school; // 레슨 아이콘
      case 'member':
      default:
        return Icons.account_circle;
    }
  }

  // sender_type별 아바타 배경색 가져오기
  Color _getAvatarColor(String senderType) {
    switch (senderType) {
      case 'admin':
        return Color(0xFF3B82F6); // 파란색
      case 'manager':
        return Color(0xFF8B5CF6); // 보라색
      case 'pro':
        return Color(0xFF10B981); // 초록색
      case 'member':
      default:
        return Color(0xFF64748B); // 회색
    }
  }
}