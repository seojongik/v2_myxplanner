import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'chatting/chatting_service_supabase.dart';
import 'api_service.dart';
import 'notification_settings_service.dart';

/// 채팅 알림 서비스 (회원 앱용)
/// CRM Lite Pro의 ChatNotificationService를 회원용으로 수정
class ChatNotificationService extends ChangeNotifier {
  static final ChatNotificationService _instance = ChatNotificationService._internal();
  factory ChatNotificationService() => _instance;
  ChatNotificationService._internal();

  StreamSubscription? _unreadCountSubscription;
  StreamSubscription? _messageActivitySubscription;
  int _totalUnreadCount = 0;
  int _lastMessageTimestamp = 0;
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  BuildContext? _currentContext;

  // 채팅 페이지가 현재 열려있는지 추적
  bool _isChatPageOpen = false;
  
  // 현재 열려있는 채팅방 ID 추적 (null이면 채팅 페이지가 닫혀있거나 목록 화면)
  String? _currentChatRoomId;

  int get totalUnreadCount => _totalUnreadCount;
  
  // 합산값 직접 설정
  void setTotalUnreadCount(int count) {
    if (_totalUnreadCount != count) {
      final previousCount = _totalUnreadCount;
      _totalUnreadCount = count;
      print('🔄 [하단네비] 합산값 직접 업데이트: $previousCount → $count');
      notifyListeners();
    }
  }
  
  // BuildContext 설정 (스낵바 표시용)
  void setContext(BuildContext context) {
    _currentContext = context;
  }
  
  // 채팅 페이지 열림/닫힘 상태 설정
  void setChatPageOpen(bool isOpen) {
    _isChatPageOpen = isOpen;
    print('📱 [알림] 채팅 페이지 상태: ${isOpen ? "열림" : "닫힘"}');
    // 채팅 페이지가 닫히면 현재 채팅방 ID도 초기화
    if (!isOpen) {
      _currentChatRoomId = null;
      print('📱 [알림] 현재 채팅방 ID 초기화');
    }
  }
  
  // 채팅 페이지가 열려있는지 확인
  bool get isChatPageOpen => _isChatPageOpen;
  
  // 현재 열려있는 채팅방 ID 설정
  void setCurrentChatRoomId(String? chatRoomId) {
    _currentChatRoomId = chatRoomId;
    print('📱 [알림] 현재 채팅방 ID 설정: ${chatRoomId ?? "없음"}');
  }
  
  // 현재 열려있는 채팅방 ID 가져오기
  String? get currentChatRoomId => _currentChatRoomId;
  
  // 특정 채팅방이 현재 열려있는지 확인
  bool isCurrentChatRoom(String chatRoomId) {
    return _currentChatRoomId == chatRoomId;
  }

  Future<void> initialize() async {
    print('🔧 [알림] ChatNotificationService 초기화 시작...');
    
    // AudioPlayer 초기화
    _audioPlayer = AudioPlayer();
    
    try {
      // 오디오 파일 미리 로드 (웹과 모바일 모두 지원)
      if (kIsWeb) {
        // 웹에서는 사용자 상호작용 후 오디오가 활성화됨
        print('🌐 웹 환경: 사용자 상호작용 후 오디오 활성화됨');
      }
      
      _isInitialized = true;
      print('🎵 AudioPlayer 초기화 성공');
    } catch (e) {
      print('❌ AudioPlayer 초기화 실패: $e');
    }

    // 지연된 구독 설정 (branchId가 설정될 때까지 기다림)
    _setupDelayedSubscriptions();
    
    print('🎯 [알림] ChatNotificationService 초기화 완료!');
  }
  
  void _setupDelayedSubscriptions() {
    // 3초 후에 구독 재시도 (로그인 완료 대기)
    Timer(Duration(seconds: 3), () {
      print('🔄 [알림] 지연된 구독 설정 시작...');
      setupSubscriptions();
    });
    
    // 브랜치 ID가 여전히 없으면 5초 후 한 번 더 시도
    Timer(Duration(seconds: 8), () {
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null) {
        print('🔄 [알림] 브랜치 ID 여전히 null - 추가 재시도...');
        setupSubscriptions();
      }
    });
  }
  
  void setupSubscriptions() async {
    final branchId = ApiService.getCurrentBranchId();
    print('🔍 [알림] 구독 설정 시작 - branchId: $branchId');

    if (branchId == null) {
      print('⚠️ [알림] branchId가 여전히 null - 구독 설정 건너뜀');
      return;
    }

    // 기존 구독이 있다면 확실히 취소
    print('🔄 [알림] 기존 구독 취소 중...');
    await _unreadCountSubscription?.cancel();
    await _messageActivitySubscription?.cancel();
    _unreadCountSubscription = null;
    _messageActivitySubscription = null;
    print('✅ [알림] 기존 구독 취소 완료');
    
    // 읽지 않은 메시지 카운트 구독 설정
    print('🔍 [알림] 읽지 않은 메시지 카운트 구독 설정 중...');
    _setupUnreadCountSubscription();
    print('✅ [알림] 읽지 않은 메시지 카운트 구독 설정 완료');
    
    print('✅ [알림] 구독 설정 완료');
  }
  
  /// 읽지 않은 메시지 카운트 구독 설정 (회원용)
  void _setupUnreadCountSubscription() {
    print('🔍 [하단네비] 구독 설정 시작 - 스트림 리스너 등록');
    
    _unreadCountSubscription = ChattingServiceSupabase.getUnreadMessageCountStream().listen(
      (count) {
        print('🔍 [하단네비] 스트림 이벤트 수신! 읽지 않은 메시지: $count개');
        
        int previousCount = _totalUnreadCount;
        _totalUnreadCount = count;
        
        print('🔍 [하단네비] 카운트 변화: $previousCount → $count');
        
        // UI 업데이트를 위해 notifyListeners 호출
        notifyListeners();
        print('✅ [하단네비] UI 업데이트 완료');
        
        // 새 메시지가 도착했을 때만 알림음 재생
        if (count > previousCount && previousCount >= 0) {
          print('🚨 [알림] 새 메시지 감지! (채팅창 열림: $_isChatPageOpen)');
          
          // 알림음 재생 조건:
          // 1. 채팅 페이지가 닫혀있을 때
          if (!_isChatPageOpen) {
            print('🔔 [알림] 알림음 재생 (채팅 페이지: 닫힘)');
            _handleNotification();
          } else {
            print('🔇 [알림] 알림음 재생 안함 (채팅 페이지가 열려있음)');
          }
        } else {
          print('📊 [알림] 카운트 증가 없음 - 알림 없음');
        }
      },
      onError: (error) {
        print('❌ [하단네비] 스트림 에러: $error');
      },
    );
  }

  /// 알림 처리 (회원용)
  Future<void> _handleNotification() async {
    // 알림음 재생
    await _playNotificationSound();
    
    // 스낵바 표시
    _showMessageNotification();
  }

  // FCM에서 호출할 수 있도록 public 메서드
  Future<void> playNotificationSound() async {
    await _playNotificationSound();
  }
  
  Future<void> _playNotificationSound() async {
    print('🔔 알림음 재생 시도... (초기화됨: $_isInitialized)');
    
    // 알림 설정 확인
    final isSoundEnabled = await NotificationSettingsService.isSoundEnabled();
    if (!isSoundEnabled) {
      print('🔇 [알림] 알림음이 비활성화되어 있습니다');
      return;
    }
    
    if (!_isInitialized || _audioPlayer == null) {
      print('⚠️ AudioPlayer가 초기화되지 않음');
      _playFallbackSound();
      return;
    }
    
    // 모바일에서는 AudioPlayer로 딩동 소리 재생 시도
    if (!kIsWeb) {
      try {
        // 이전 재생이 있으면 먼저 정지
        try {
          await _audioPlayer!.stop();
          await Future.delayed(Duration(milliseconds: 50)); // 정지 대기
        } catch (e) {
          // 정지 실패는 무시 (재생 중이 아닐 수도 있음)
        }
        
        // 볼륨 및 모드 설정
        await _audioPlayer!.setVolume(1.0); // 최대 볼륨
        await _audioPlayer!.setPlayerMode(PlayerMode.lowLatency); // 낮은 지연시간 모드
        
        // MP3 파일 재생
        await _audioPlayer!.play(AssetSource('sounds/hole_in.mp3'));
        print('🔔 AudioPlayer로 알림음 재생 (hole_in.mp3, 볼륨: 1.0)');
        return;
      } catch (e) {
        print('⚠️ 딩동 파일 재생 실패, 시스템 알림음으로 폴백: $e');
        _playFallbackSound();
      }
    } else {
      // 웹에서는 기존 방식 사용
      _playFallbackSound();
    }
  }

  void _playFallbackSound() {
    try {
      if (kIsWeb) {
        // 웹에서는 간단한 알림 방식 사용
        print('🌐 웹: 알림음 재생 (기본)');
      } else {
        // 모바일에서는 시스템 알림음 재생
        _playMobileDingDong();
      }
    } catch (e) {
      print('❌ 알림음 실패: $e');
      // 실패 시 기본 시스템 알림음으로 폴백
      try {
        SystemSound.play(SystemSoundType.alert);
        print('📱 모바일: 시스템 알림음 재생 (fallback)');
      } catch (e2) {
        print('❌ 알림음 전체 실패: $e2');
        print('🔊 DING DONG! 새 메시지 도착!');
      }
    }
  }

  /// 모바일에서 딩동 소리 재생
  void _playMobileDingDong() {
    try {
      // 여러 번 반복해서 확실하게 들리도록 함
      for (int i = 0; i < 2; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          try {
            SystemSound.play(SystemSoundType.alert);
            print('🔔 딩 - ${i + 1}번째');
          } catch (e) {
            // 무시
          }
        });
      }
      
      // 동 (낮은 톤) - 300ms 후 재생하여 딩동 효과
      Future.delayed(Duration(milliseconds: 300), () {
        try {
          for (int i = 0; i < 2; i++) {
            Future.delayed(Duration(milliseconds: i * 100), () {
              try {
                SystemSound.play(SystemSoundType.alert);
                print('🔔 동 - ${i + 1}번째');
              } catch (e) {
                try {
                  SystemSound.play(SystemSoundType.click);
                } catch (e2) {
                  // 무시
                }
              }
            });
          }
        } catch (e) {
          try {
            SystemSound.play(SystemSoundType.click);
            print('🔔 동 (click)');
          } catch (e2) {
            // 무시
          }
        }
      });
      
    } catch (e) {
      print('❌ 딩동 소리 재생 실패: $e');
      try {
        SystemSound.play(SystemSoundType.alert);
        Future.delayed(Duration(milliseconds: 200), () {
          SystemSound.play(SystemSoundType.alert);
        });
      } catch (e2) {
        SystemSound.play(SystemSoundType.click);
      }
    }
  }
  
  // 메시지 알림 스낵바 표시 (회원용 - 관리자로부터 메시지)
  Future<void> _showMessageNotification() async {
    if (_currentContext == null) {
      print('⚠️ [알림] BuildContext가 없어서 스낵바 표시 불가');
      return;
    }

    try {
      // 애니메이션이 있는 커스텀 스낵바 표시
      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        SnackBar(
          content: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.message_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '관리자로부터 새 메시지가 도착했습니다!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '채팅 탭에서 확인하세요',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.notifications_active,
                  color: Colors.white.withOpacity(0.8),
                  size: 18,
                ),
              ],
            ),
          ),
          backgroundColor: Color(0xFF4CAF50), // 초록색
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          action: SnackBarAction(
            label: '확인',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(_currentContext!).hideCurrentSnackBar();
            },
          ),
        ),
      );
      
      print('✅ [알림] 메시지 알림 스낵바 표시');
      
    } catch (e) {
      print('❌ [알림] 스낵바 표시 실패: $e');
    }
  }

  @override
  void dispose() {
    _unreadCountSubscription?.cancel();
    _messageActivitySubscription?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  // 수동으로 알림음 테스트
  Future<void> testNotificationSound() async {
    print('🧪 알림음 테스트 시작');
    await _playNotificationSound();
  }
  
  // 새 메시지 시뮬레이션 (카운트 증가로 알림 테스트)
  void simulateNewMessage() {
    print('🎭 새 메시지 시뮬레이션 시작');
    int currentCount = _totalUnreadCount;
    
    // 카운트를 1 증가시켜서 새 메시지 도착 시뮬레이션
    _totalUnreadCount = currentCount + 1;
    
    print('🚨 새 메시지 감지! 이전: $currentCount, 현재: $_totalUnreadCount');
    _playNotificationSound();
    
    notifyListeners();
    
    // 3초 후 원복
    Timer(Duration(seconds: 3), () {
      _totalUnreadCount = currentCount;
      notifyListeners();
      print('🔄 메시지 카운트 원복: $_totalUnreadCount');
    });
  }
}



