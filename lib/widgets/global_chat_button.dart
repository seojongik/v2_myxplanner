import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/chatting/chatting_ui.dart';
import '../services/chatting/chatting_service.dart';
import '../stubs/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'dart:convert';

class GlobalChatButton extends StatefulWidget {
  final Offset? initialPosition;
  final Function(Offset)? onPositionChanged;

  const GlobalChatButton({
    Key? key,
    this.initialPosition,
    this.onPositionChanged,
  }) : super(key: key);

  @override
  _GlobalChatButtonState createState() => _GlobalChatButtonState();
}

class _GlobalChatButtonState extends State<GlobalChatButton> {
  int _unreadMessageCount = 0;
  Offset? _position;
  Offset _dragStartPosition = Offset.zero;
  bool _isDragging = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initUnreadMessageStream();
    _loadSavedPosition();
  }

  void _loadSavedPosition() {
    if (widget.initialPosition != null) {
      _position = widget.initialPosition!;
      _isInitialized = true;
    } else {
      // 저장된 위치 불러오기
      if (kIsWeb) {
        try {
          final storage = html.window.localStorage;
          final savedX = storage['chat_button_x'];
          final savedY = storage['chat_button_y'];
          if (savedX != null && savedY != null) {
            _position = Offset(double.parse(savedX), double.parse(savedY));
            _isInitialized = true;
          }
        } catch (e) {
          print('⚠️ 위치 로드 오류: $e');
        }
      }
    }
  }

  void _savePosition(Offset position) {
    if (kIsWeb) {
      try {
        final storage = html.window.localStorage;
        storage['chat_button_x'] = position.dx.toString();
        storage['chat_button_y'] = position.dy.toString();
      } catch (e) {
        print('⚠️ 위치 저장 오류: $e');
      }
    }
    // 콜백으로 부모 위젯에 위치 변경 알림
    widget.onPositionChanged?.call(position);
  }

  void _initUnreadMessageStream() {
    // 안읽은 메시지 수 스트림 구독
    ChattingService.getUnreadMessageCountStream().listen((count) {
      if (mounted) {
        setState(() {
          _unreadMessageCount = count;
        });
      }
    }, onError: (error) {
      print('❌ [GlobalChatButton] 안읽은 메시지 수 스트림 에러: $error');
      if (mounted) {
        setState(() {
          _unreadMessageCount = 0;
        });
      }
    });
  }

  void _openChatPage() {
    print('🎯 [GLOBAL-CHAT] 채팅 페이지 열기 시도');
    
    try {
      print('🎯 [GLOBAL-CHAT] Firebase 연결 상태 체크 시작');
      final hasFirebase = ChattingService.isFirebaseAvailable();
      print('🎯 [GLOBAL-CHAT] Firebase 사용 가능: $hasFirebase');
      
      if (hasFirebase) {
        print('✅ [GLOBAL-CHAT] Firebase 사용 가능 - 채팅 페이지로 이동');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChattingPage(),
          ),
        );
      } else {
        print('❌ [GLOBAL-CHAT] Firebase 사용 불가 - 안내 다이얼로그 표시');
        // Firebase 연결 실패 시 안내 메시지
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('채팅 서비스 안내'),
            content: Text('현재 채팅 서비스에 연결할 수 없습니다.\n잠시 후 다시 시도해주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      print('💥 [GLOBAL-CHAT] 채팅 페이지 열기 중 예외 발생: $e');
      print('💥 [GLOBAL-CHAT] 스택 트레이스: $stackTrace');
      
      // 예외 발생 시 안내 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('채팅 서비스를 사용할 수 없습니다: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final buttonSize = 75.0;
    final mediaQuery = MediaQuery.of(context);
    
    // 하단 네비게이션 바 높이 계산 (SafeArea + 네비게이션 바 높이 + 여유 공간)
    // 네비게이션 바 높이 약 50-60px + SafeArea 하단 패딩
    final bottomNavBarHeight = mediaQuery.padding.bottom + 55.0; // SafeArea + 네비게이션 바 높이
    final minDistanceFromBottom = bottomNavBarHeight + 10.0; // 네비게이션 바 위 10px 여유
    
    // 화면 경계 내로 위치 제한 (하단 네비게이션 바 위로)
    final maxX = screenSize.width - buttonSize;
    final maxY = screenSize.height - minDistanceFromBottom - buttonSize;
    
    // 초기 위치 설정 (저장된 위치가 없으면 기본값 - 네비게이션 바 위)
    if (!_isInitialized || _position == null) {
      _position = Offset(
        maxX - 20, // 오른쪽에서 20px
        screenSize.height - minDistanceFromBottom - buttonSize, // 네비게이션 바 위
      );
      _isInitialized = true;
    }
    
    // 화면 경계 내로 위치 제한 (하단 네비게이션 바 위로)
    final currentX = _position!.dx.clamp(0.0, maxX);
    final currentY = _position!.dy.clamp(0.0, maxY);
    
    // 경계 제한이 적용된 경우 위치 업데이트
    if (_position!.dx != currentX || _position!.dy != currentY) {
      _position = Offset(currentX, currentY);
    }

    return Positioned(
      left: currentX,
      top: currentY,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
            _dragStartPosition = details.globalPosition;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            final delta = details.globalPosition - _dragStartPosition;
            _position = Offset(
              (currentX + delta.dx).clamp(0.0, maxX),
              (currentY + delta.dy).clamp(0.0, maxY),
            );
            _dragStartPosition = details.globalPosition;
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
          });
          if (_position != null) {
            _savePosition(_position!);
          }
        },
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0xFF4A90E2).withOpacity(_isDragging ? 0.6 : 0.4),
                blurRadius: _isDragging ? 20 : 15,
                offset: Offset(0, _isDragging ? 8 : 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(37.5),
              onTap: _isDragging ? null : _openChatPage,
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat,
                          color: Colors.white,
                          size: 26,
                        ),
                        SizedBox(height: 3),
                        Text(
                          '1:1문의',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 안읽은 메시지 배지
                  if (_unreadMessageCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        child: Text(
                          _unreadMessageCount > 99 ? '99+' : '$_unreadMessageCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}