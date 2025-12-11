import 'package:flutter/material.dart';
import 'chatting_service.dart';
import 'chat_models.dart';
import '../api_service.dart';
import '../content_filter_service.dart';
import '../chat_report_service.dart';
import '../../widgets/chat_eula_dialog.dart';
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
  bool _eulaAccepted = false;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  bool _showEmojiPicker = false;
  List<String> _blockedUserIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChattingService.setChatPageActive(true);
    _checkEulaAndInitialize();
  }

  @override
  void dispose() {
    ChattingService.setChatPageActive(false);
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
      print('🔄 [ChattingUI] 앱 포그라운드 복귀 - 관리자 메시지 읽음 처리');
      ChattingService.markAdminMessagesAsRead();
    }
  }

  /// EULA 동의 확인 후 채팅 초기화
  Future<void> _checkEulaAndInitialize() async {
    // EULA 동의 확인
    final accepted = await ChatEulaDialog.show(context);
    
    if (!accepted) {
      // 동의하지 않으면 이전 화면으로
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    
    setState(() {
      _eulaAccepted = true;
    });
    
    // 차단된 사용자 목록 로드
    _blockedUserIds = await ChatReportService.getBlockedUserIds();
    
    // 채팅 초기화
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final chatRoom = await ChattingService.getOrCreateChatRoom();
      
      setState(() {
        _chatRoom = chatRoom;
        _isInitializing = false;
      });

      _messagesSubscription?.cancel();
      
      int previousMessageCount = _messages.length;
      
      _messagesSubscription = ChattingService.getMessagesStream().listen((messages) {
        if (messages != null) {
          final currentUser = ApiService.getCurrentUser();
          final currentMemberId = currentUser?['member_id']?.toString();
          final isAdmin = ApiService.isAdminLogin();
          
          final List<ChatMessage> messageList = messages;
          
          if (messageList.length > previousMessageCount && previousMessageCount > 0) {
            final newMessages = messageList.skip(previousMessageCount).toList();
            
            final messagesToNotify = <ChatMessage>[];
            
            for (final msg in newMessages) {
              final msgSenderId = msg.senderId.toString().trim();
              final myId = (currentMemberId?.toString() ?? '').trim();
              final isMyMessage = msgSenderId == myId && myId.isNotEmpty;
              
              if (isMyMessage) continue;
              
              // 차단된 사용자 메시지는 알림 제외
              if (_blockedUserIds.contains(msg.senderId)) continue;
              
              final shouldNotify = isAdmin 
                  ? msg.senderType == 'member'
                  : msg.senderType == 'admin';
              
              if (shouldNotify) {
                messagesToNotify.add(msg);
              }
            }
            
            if (messagesToNotify.isNotEmpty) {
              print('✅ [Chat] 알림 재생: ${messagesToNotify.length}개 메시지');
              ChattingService.playNotificationSound();
            }
          }
          
          previousMessageCount = messageList.length;
          
          final unreadAdminMessages = messageList.where((msg) => 
            msg.senderType == 'admin' && !msg.isRead
          ).toList();
          
          if (unreadAdminMessages.isNotEmpty) {
            Future.delayed(Duration(milliseconds: 1000), () {
              if (mounted && _messagesSubscription != null && !_messagesSubscription!.isPaused) {
                ChattingService.markAdminMessagesAsRead();
              }
            });
          }
        }
        
        if (mounted && _messagesSubscription != null && !_messagesSubscription!.isPaused) {
          setState(() {
            // 차단된 사용자 메시지 필터링
            _messages = (messages ?? []).where((msg) => 
              !_blockedUserIds.contains(msg.senderId)
            ).toList();
          });
          _scrollToBottom();
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

    // 콘텐츠 필터링
    final (isAllowed, reason) = ContentFilterService.validateMessage(message);
    if (!isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason ?? '메시지를 전송할 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _messageController.clear();
    
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

  /// 메시지 옵션 다이얼로그 (신고/삭제)
  void _showMessageOptions(ChatMessage message) {
    final currentUser = ApiService.getCurrentUser();
    final isMyMessage = message.senderId == currentUser?['member_id']?.toString();
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isMyMessage) ...[
              // 내 메시지: 삭제만 가능
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('메시지 삭제'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMessage(message);
                },
              ),
            ] else ...[
              // 상대방 메시지: 신고/차단
              ListTile(
                leading: Icon(Icons.flag_outlined, color: Colors.orange),
                title: Text('신고하기'),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(message);
                },
              ),
              ListTile(
                leading: Icon(Icons.block, color: Colors.red),
                title: Text('차단하기'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlockUser(message);
                },
              ),
            ],
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 메시지 삭제 확인
  void _confirmDeleteMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('메시지 삭제'),
        content: Text('이 메시지를 삭제하시겠습니까?\n삭제된 메시지는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ChatReportService.deleteMessage(
                messageId: message.id,
              );
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('메시지가 삭제되었습니다.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// 신고 다이얼로그
  void _showReportDialog(ChatMessage message) {
    final reasons = ChatReportService.getReportReasons();
    String? selectedReason;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.flag, color: Colors.orange),
              SizedBox(width: 8),
              Text('신고하기'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '신고 사유를 선택해주세요.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 12),
              ...reasons.map((reason) => RadioListTile<String>(
                title: Text(reason, style: TextStyle(fontSize: 14)),
                value: reason,
                groupValue: selectedReason,
                onChanged: (value) {
                  setState(() {
                    selectedReason = value;
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              )),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '신고된 내용은 24시간 이내에 검토됩니다.',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null ? null : () async {
                Navigator.pop(context);
                final success = await ChatReportService.reportMessage(
                  messageId: message.id,
                  chatRoomId: message.chatRoomId,
                  reportedSenderId: message.senderId,
                  reportedSenderType: message.senderType,
                  messageContent: message.message,
                  reportReason: selectedReason!,
                );
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('신고가 접수되었습니다. 24시간 이내에 검토됩니다.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('신고', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// 차단 확인
  void _confirmBlockUser(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('사용자 차단'),
        content: Text(
          '이 사용자를 차단하시겠습니까?\n'
          '차단된 사용자의 메시지는 더 이상 표시되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ChatReportService.blockUser(
                blockedUserId: message.senderId,
                blockedUserType: message.senderType,
              );
              if (success) {
                // 차단 목록 업데이트
                _blockedUserIds = await ChatReportService.getBlockedUserIds();
                // 메시지 목록에서 차단된 사용자 메시지 제거
                setState(() {
                  _messages = _messages.where((msg) => 
                    !_blockedUserIds.contains(msg.senderId)
                  ).toList();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('사용자가 차단되었습니다.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('차단', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ApiService.getCurrentBranch();
    final branchName = currentBranch?['branch_name'] ?? '골프연습장';
    
    // EULA 동의 전에는 로딩 표시
    if (!_eulaAccepted) {
      return Scaffold(
        backgroundColor: Color(0xFFB8C5D6),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
          ),
        ),
      );
    }
    
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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) {
              if (value == 'blocked') {
                _showBlockedUsers();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'blocked',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20, color: Colors.grey[700]),
                    SizedBox(width: 8),
                    Text('차단 목록 관리'),
                  ],
                ),
              ),
            ],
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

  /// 차단 목록 관리
  void _showBlockedUsers() async {
    if (_blockedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('차단된 사용자가 없습니다.')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('차단 목록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _blockedUserIds.map((userId) => ListTile(
            title: Text('사용자 $userId'),
            trailing: TextButton(
              onPressed: () async {
                await ChatReportService.unblockUser(blockedUserId: userId);
                _blockedUserIds = await ChatReportService.getBlockedUserIds();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('차단이 해제되었습니다.')),
                );
              },
              child: Text('해제', style: TextStyle(color: Colors.blue)),
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
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
              '네트워크 연결을 확인해주세요',
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

  final List<String> _commonEmojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
    '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
    '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜',
    '🤪', '🤨', '🧐', '🤓', '😎', '🥸', '🤩', '🥳',
    '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️',
    '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤',
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
  ];

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    
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
          final proName = message.senderName.isNotEmpty 
              ? message.senderName 
              : '프로';
          senderLabel = '$proName 프로';
          break;
        default:
          senderLabel = branchName;
          break;
      }
    }
    
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: isMyMessage 
              ? MainAxisAlignment.end 
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMyMessage) ...[
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
      ),
    );
  }

  String _formatTimeSimple(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  IconData _getAvatarIcon(String senderType) {
    switch (senderType) {
      case 'admin':
        return Icons.golf_course;
      case 'manager':
        return Icons.supervisor_account;
      case 'pro':
        return Icons.school;
      case 'member':
      default:
        return Icons.account_circle;
    }
  }

  Color _getAvatarColor(String senderType) {
    switch (senderType) {
      case 'admin':
        return Color(0xFF3B82F6);
      case 'manager':
        return Color(0xFF8B5CF6);
      case 'pro':
        return Color(0xFF10B981);
      case 'member':
      default:
        return Color(0xFF64748B);
    }
  }
}
