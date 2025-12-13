import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service_supabase.dart';
import 'api_service.dart';

class ChatNotificationService extends ChangeNotifier {
  static final ChatNotificationService _instance = ChatNotificationService._internal();
  factory ChatNotificationService() => _instance;
  ChatNotificationService._internal();

  StreamSubscription? _unreadCountSubscription;
  StreamSubscription? _messageActivitySubscription;
  StreamSubscription? _latestMessageInfoSubscription;
  int _totalUnreadCount = 0;
  int _lastMessageTimestamp = 0;
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  BuildContext? _currentContext;
  
  // 중복 구독 방지
  String? _subscribedBranchId;
  bool _isSettingUpSubscriptions = false;
  
  // 최신 메시지 정보 캐시
  Map<String, dynamic>? _latestMessageInfo;

  // 채팅 페이지가 현재 열려있는지 추적
  bool _isChatPageOpen = false;
  
  // 현재 열려있는 채팅방 ID 추적 (null이면 채팅 페이지가 닫혀있거나 목록 화면)
  String? _currentChatRoomId;
  
  // 벨소리 설정
  String _selectedRingtone = 'dingdong'; // 기본값: 딩동
  bool _browserNotificationEnabled = false;
  bool _snackbarNotificationEnabled = true; // CRM 하단 알림표시 (기본: ON)
  
  // 사용 가능한 벨소리 목록
  static const Map<String, String> availableRingtones = {
    'dingdong': '기본 딩동',
    'hole_in': '홀인원 축하',
    'iron': '아이언샷',
  };
  
  String get selectedRingtone => _selectedRingtone;
  bool get browserNotificationEnabled => _browserNotificationEnabled;
  bool get snackbarNotificationEnabled => _snackbarNotificationEnabled;

  int get totalUnreadCount => _totalUnreadCount;
  
  // 벨소리 설정 변경
  void setRingtone(String ringtone) {
    if (availableRingtones.containsKey(ringtone)) {
      _selectedRingtone = ringtone;
      notifyListeners();
      print('🔔 벨소리 변경: $ringtone');
    }
  }
  
  // 브라우저 알림 설정 변경
  void setBrowserNotificationEnabled(bool enabled) {
    _browserNotificationEnabled = enabled;
    notifyListeners();
    print('🔔 브라우저 알림: ${enabled ? '활성화' : '비활성화'}');
  }
  
  // CRM 하단 알림(스낵바) 설정 변경
  void setSnackbarNotificationEnabled(bool enabled) {
    _snackbarNotificationEnabled = enabled;
    notifyListeners();
    print('🔔 CRM 하단 알림: ${enabled ? '활성화' : '비활성화'}');
  }
  
  // 브라우저 알림 권한 요청
  Future<bool> requestNotificationPermission() async {
    if (!kIsWeb) {
      print('❌ 웹이 아니므로 알림 권한 요청 불가');
      return false;
    }
    
    try {
      print('🔔 브라우저 알림 권한 요청 시작...');
      print('🔔 현재 권한 상태: ${html.Notification.permission}');
      
      // 이미 권한이 있으면 바로 반환
      if (html.Notification.permission == 'granted') {
        print('✅ 이미 알림 권한이 허용되어 있습니다');
        _browserNotificationEnabled = true;
        notifyListeners();
        return true;
      }
      
      // 권한이 거부된 상태면 브라우저 설정에서 변경해야 함
      if (html.Notification.permission == 'denied') {
        print('⚠️ 알림 권한이 거부되어 있습니다. 브라우저 설정에서 변경 필요');
        return false;
      }
      
      // 권한 요청 (default 상태일 때만 팝업이 뜸)
      print('🔔 브라우저에 권한 요청 팝업 표시 중...');
      final permission = await html.Notification.requestPermission();
      final granted = permission == 'granted';
      
      if (granted) {
        _browserNotificationEnabled = true;
      }
      notifyListeners();
      print('🔔 알림 권한 요청 결과: $permission (granted: $granted)');
      return granted;
    } catch (e) {
      print('❌ 알림 권한 요청 실패: $e');
      return false;
    }
  }
  
  // 브라우저 알림 권한 상태 확인
  bool checkNotificationPermission() {
    if (!kIsWeb) return false;
    try {
      final permission = html.Notification.permission;
      print('🔍 현재 브라우저 알림 권한 상태: $permission');
      return permission == 'granted';
    } catch (e) {
      print('❌ 권한 상태 확인 실패: $e');
      return false;
    }
  }
  
  // 브라우저 푸시 알림 표시
  void showBrowserNotification(String title, String body) {
    if (!kIsWeb || !_browserNotificationEnabled) return;
    
    try {
      if (html.Notification.permission == 'granted') {
        html.Notification(title, body: body, icon: 'icons/Icon-192.png');
        print('🔔 브라우저 알림 표시: $title');
      }
    } catch (e) {
      print('❌ 브라우저 알림 표시 실패: $e');
    }
  }
  
  // CRM 하단 알림(스낵바) 표시
  void showSnackbarNotification(String title, String body) {
    if (!_snackbarNotificationEnabled || _currentContext == null) return;
    
    try {
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
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(
                          body,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
        ),
      );
      print('✅ CRM 하단 알림 표시: $title');
    } catch (e) {
      print('❌ CRM 하단 알림 표시 실패: $e');
    }
  }
  
  // FCM에서 호출할 수 있도록 public 메서드 추가
  Future<void> playNotificationSound() async {
    await _playNotificationSound();
  }
  
  /// FCM 푸시 알림 수신 시 카운트 증가 (즉시 UI 업데이트)
  void incrementUnreadCount() {
    final previousCount = _totalUnreadCount;
    _totalUnreadCount++;
    notifyListeners();
  }
  
  // 채팅 페이지 열림/닫힘 상태 설정
  void setChatPageOpen(bool isOpen) {
    _isChatPageOpen = isOpen;
    // 채팅 페이지가 닫히면 현재 채팅방 ID도 초기화
    if (!isOpen) {
      _currentChatRoomId = null;
    }
  }
  
  // 채팅 페이지가 열려있는지 확인
  bool get isChatPageOpen => _isChatPageOpen;
  
  // 현재 열려있는 채팅방 ID 설정
  void setCurrentChatRoomId(String? chatRoomId) {
    _currentChatRoomId = chatRoomId;
  }
  
  // 현재 열려있는 채팅방 ID 가져오기
  String? get currentChatRoomId => _currentChatRoomId;
  
  // 특정 채팅방이 현재 열려있는지 확인
  bool isCurrentChatRoom(String chatRoomId) {
    return _currentChatRoomId == chatRoomId;
  }
  
  // BuildContext 설정 (스낵바 표시용)
  void setContext(BuildContext context) {
    _currentContext = context;
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
  
  void setupSubscriptions() {
    final branchId = ApiService.getCurrentBranchId();
    
    if (branchId == null) {
      print('⚠️ [알림] branchId가 null - 구독 설정 건너뜀');
      return;
    }
    
    // 이미 같은 branchId로 구독 중이면 스킵
    if (_subscribedBranchId == branchId) {
      print('⚠️ [알림] 이미 구독 중 - 스킵 ($branchId)');
      return;
    }
    
    // 중복 호출 방지
    if (_isSettingUpSubscriptions) {
      print('⚠️ [알림] 구독 설정 진행 중 - 스킵');
      return;
    }
    
    _isSettingUpSubscriptions = true;
    print('🔔 [알림] 구독 설정 시작 - branchId: $branchId');
    
    // 기존 구독이 있다면 취소
    _unreadCountSubscription?.cancel();
    _messageActivitySubscription?.cancel();
    _latestMessageInfoSubscription?.cancel();
    
    // 읽지 않은 메시지 카운트 구독 (카운트만 업데이트, 알림은 FCM에서 처리)
    _unreadCountSubscription = ChatServiceSupabase.getUnreadMessageCountStream().listen((count) {
      int previousCount = _totalUnreadCount;
      _totalUnreadCount = count;
      
      print('🔍 [알림] 카운트 변화: $previousCount → $count');
      
      // 알림음/스낵바는 FCM에서 처리 (회원 메시지에만 서버에서 FCM 발송)
      // 여기서는 카운트만 업데이트
      
      notifyListeners();
    });
    
    // 메시지 활동 스트림 (타임스탬프 추적용, 알림은 FCM에서 처리)
    try {
      print('🔧 [알림] 메시지 활동 스트림 구독 시작...');
      _messageActivitySubscription = ChatServiceSupabase.getMessageActivityStream().listen(
        (timestamp) {
          // 알림음/스낵바는 FCM에서 처리 (회원 메시지에만 서버에서 FCM 발송)
          // 여기서는 타임스탬프만 추적
          _lastMessageTimestamp = timestamp;
        },
        onError: (error) {
          print('❌ [알림] 메시지 활동 스트림 에러: $error');
        },
      );
      print('✅ [알림] 메시지 활동 스트림 구독 완료');
    } catch (e) {
      print('❌ [알림] 메시지 활동 스트림 구독 실패: $e');
    }
    
    // 최신 메시지 정보 스트림 구독 (알림 표시용)
    try {
      print('🔧 [알림] 최신 메시지 정보 스트림 구독 시작...');
      _latestMessageInfoSubscription = ChatServiceSupabase.getLatestMessageInfoStream().listen(
        (messageInfo) {
          if (messageInfo != null) {
            _latestMessageInfo = messageInfo;
            print('📧 [알림] 최신 메시지 정보 캐시 업데이트: ${messageInfo['senderName']} - ${messageInfo['message']}');
          }
        },
        onError: (error) {
          print('❌ [알림] 최신 메시지 정보 스트림 에러: $error');
        },
        onDone: () {
          print('✅ [알림] 최신 메시지 정보 스트림 완료');
        }
      );
      print('✅ [알림] 최신 메시지 정보 스트림 구독 완료');
    } catch (e) {
      print('❌ [알림] 최신 메시지 정보 스트림 구독 실패: $e');
    }
    
    _subscribedBranchId = branchId;
    _isSettingUpSubscriptions = false;
    print('✅ [알림] 구독 설정 완료 - $branchId');
  }

  Future<void> _playNotificationSound() async {
    print('🔔 알림음 재생 시도... (초기화됨: $_isInitialized, 벨소리: $_selectedRingtone)');
    
    if (!_isInitialized || _audioPlayer == null) {
      print('⚠️ AudioPlayer가 초기화되지 않음');
      _playFallbackSound();
      return;
    }
    
    // 모바일에서는 AudioPlayer로 MP3 파일 재생 시도
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
        
        // 선택된 벨소리에 따라 파일 선택
        String soundFile = 'sounds/dingdong.mp3';
        if (_selectedRingtone == 'hole_in') {
          soundFile = 'sounds/hole_in.mp3';
        } else if (_selectedRingtone == 'iron') {
          soundFile = 'sounds/iron.mp3';
        }
        
        // MP3 파일 재생
        await _audioPlayer!.play(AssetSource(soundFile));
        print('🔔 AudioPlayer로 소리 재생 ($soundFile, 볼륨: 1.0)');
        return;
      } catch (e) {
        print('❌ MP3 재생 실패, 시스템 알림음으로 대체: $e');
      }
    }
    
    // 웹이거나 MP3 재생 실패 시 시스템 알림음 사용
    _playFallbackSound();
  }

  void _playFallbackSound() {
    try {
      if (kIsWeb) {
        // 웹에서는 간단한 알림 방식 사용
        _playWebNotification();
      } else {
        // 모바일에서는 시스템 알림음 사용
        SystemSound.play(SystemSoundType.click);
        print('📱 모바일: 시스템 알림음 재생');
      }
    } catch (e) {
      print('❌ 알림음 실패: $e');
      print('🔊 DING DONG! 새 메시지 도착!');
    }
  }

  void _playWebNotification() {
    try {
      print('🌐 웹: 알림 시작 (벨소리: $_selectedRingtone)');
      
      bool success = false;
      
      // 선택된 벨소리에 따라 MP3 파일 재생 또는 기본 딩동
      if (_selectedRingtone == 'hole_in' || _selectedRingtone == 'iron') {
        // MP3 파일 재생
        try {
          final audio = html.AudioElement();
          audio.src = '${_selectedRingtone}.mp3';
          audio.volume = 1.0;
          audio.play().then((_) {
            print('🔔 MP3 벨소리 재생: ${_selectedRingtone}.mp3');
            success = true;
          }).catchError((e) {
            print('⚠️ MP3 재생 실패: $e');
            // 실패 시 기본 딩동 재생
            _createInlineDingDongSound();
          });
          success = true;
        } catch (e) {
          print('⚠️ Audio Element 생성 실패: $e');
        }
      }
      
      if (!success) {
        // 기본 딩동 소리 (JavaScript 생성)
        success = _createInlineDingDongSound();
      }
      
      if (!success) {
        // 백업: 기존 beep 소리
        try {
          final audio = html.AudioElement();
          audio.src = 'data:audio/wav;base64,UklGRjIAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQ4AAACA/ACA/ACA/ACA/A==';
          audio.volume = 0.5;
          audio.play().then((_) {
            print('🔔 백업 beep 소리 재생');
          }).catchError((e) {
            print('⚠️ 백업 소리도 실패: $e');
          });
        } catch (e) {
          print('⚠️ 백업 Audio Element 실패: $e');
        }
      }
      
      // 콘솔 알림은 항상 실행
      html.window.console.log('🔔 새 메시지가 도착했습니다!');
      
    } catch (e) {
      print('❌ 웹 알림 전체 실패: $e');
    }
  }
  
  bool _createInlineDingDongSound() {
    try {
      // JavaScript 코드를 직접 실행
      js.context.callMethod('eval', ['''
        try {
          const audioContext = new (window.AudioContext || window.webkitAudioContext)();
          
          function playTone(frequency, duration, delay = 0, volume = 0.3) {
            setTimeout(() => {
              const oscillator = audioContext.createOscillator();
              const gainNode = audioContext.createGain();
              
              oscillator.connect(gainNode);
              gainNode.connect(audioContext.destination);
              
              oscillator.frequency.value = frequency;
              oscillator.type = 'sine';
              
              gainNode.gain.setValueAtTime(0, audioContext.currentTime);
              gainNode.gain.linearRampToValueAtTime(volume, audioContext.currentTime + 0.01);
              gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + duration);
              
              oscillator.start(audioContext.currentTime);
              oscillator.stop(audioContext.currentTime + duration);
            }, delay);
          }
          
          // 딩 (높은 톤)
          playTone(800, 0.4, 0, 0.4);
          
          // 동 (낮은 톤) - 0.3초 후
          playTone(600, 0.5, 300, 0.4);
          
          console.log('🔔 인라인 딩동 소리 재생!');
          
        } catch (error) {
          console.error('딩동 소리 생성 실패:', error);
        }
      ''']);
      
      print('🔔 인라인 딩동 소리 실행 성공');
      return true;
      
    } catch (e) {
      print('❌ 인라인 딩동 소리 실패: $e');
      return false;
    }
  }
  
  // 메시지 알림 스낵바 표시
  Future<void> _showMessageNotification() async {
    if (_currentContext == null) {
      print('⚠️ [알림] BuildContext가 없어서 스낵바 표시 불가');
      return;
    }
    
    try {
      // 캐시가 업데이트될 때까지 최대 1초 대기
      int waitCount = 0;
      while (_latestMessageInfo == null && waitCount < 10) {
        await Future.delayed(Duration(milliseconds: 100));
        waitCount++;
      }
      
      // 최신 메시지 정보 가져오기
      final latestMessageInfo = await _getLatestMessageInfo();
      
      if (latestMessageInfo == null) {
        print('⚠️ [알림] 최신 메시지 정보를 가져올 수 없음');
        return;
      }
      
      final memberName = latestMessageInfo['memberName'] ?? '알 수 없는 사용자';
      final messagePreview = latestMessageInfo['message'] ?? '새 메시지';
      final senderType = latestMessageInfo['senderType'] ?? 'unknown';
      
      // 회원이 보낸 메시지에만 알림 표시 (관리자가 보낸 메시지는 무시)
      if (senderType != 'member') {
        print('📤 [알림] 관리자/프로가 보낸 메시지 - 알림 생략');
        return;
      }
      
      // 회원 메시지일 때만 알림음 재생
      await _playNotificationSound();
      
      String notificationText = '$memberName님으로부터 1:1 메시지가 수신되었습니다!';
      IconData notificationIcon = Icons.message_rounded;
      Color backgroundColor = Color(0xFF4CAF50); // 초록색
      
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
                    notificationIcon,
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
                        notificationText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (messagePreview.isNotEmpty && messagePreview.length < 50)
                        SizedBox(height: 2),
                      if (messagePreview.isNotEmpty && messagePreview.length < 50)
                        Text(
                          '"$messagePreview"',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
          backgroundColor: backgroundColor,
          duration: Duration(seconds: 4), // 4초간 표시
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
      
      print('✅ [알림] 메시지 알림 스낵바 표시: $notificationText');
      
      // 브라우저 푸시 알림도 함께 표시
      if (_browserNotificationEnabled) {
        showBrowserNotification(
          senderType == 'member' ? '새 메시지' : '메시지 전송',
          notificationText,
        );
      }
      
    } catch (e) {
      print('❌ [알림] 스낵바 표시 실패: $e');
    }
  }
  
  // 최신 메시지 정보 가져오기 (캐시 사용)
  Future<Map<String, dynamic>?> _getLatestMessageInfo() async {
    try {
      // 캐시된 정보가 있으면 사용
      if (_latestMessageInfo != null) {
        print('📧 [알림] 캐시된 메시지 정보 사용: ${_latestMessageInfo!['senderName']} - ${_latestMessageInfo!['message']}');
        
        String memberName = _latestMessageInfo!['senderName'] ?? '알 수 없는 사용자';
        String messageText = _latestMessageInfo!['message'] ?? '새로운 메시지';
        String senderType = _latestMessageInfo!['senderType'] ?? 'member';
        
        // 회원이 보낸 메시지인 경우 채팅방에서 실제 회원 이름 확인
        if (senderType == 'member' && _latestMessageInfo!['chatRoomId'] != null) {
          try {
            final chatRoomSnapshot = await FirebaseFirestore.instance
                .collection('chatRooms')
                .doc(_latestMessageInfo!['chatRoomId'])
                .get();
            
            if (chatRoomSnapshot.exists) {
              final chatRoomData = chatRoomSnapshot.data()!;
              memberName = chatRoomData['memberName'] ?? memberName;
              print('👤 [알림] 채팅방에서 회원 이름 확인: $memberName');
            }
          } catch (e) {
            print('⚠️ [알림] 채팅방 정보 조회 실패: $e');
          }
        }
        
        return {
          'memberName': memberName,
          'message': messageText,
          'senderType': senderType,
        };
      }
      
      // 캐시된 정보가 없으면 기본값 반환
      print('⚠️ [알림] 캐시된 메시지 정보가 없음 - 기본값 사용');
      return {
        'memberName': '고객',
        'message': '새로운 메시지',
        'senderType': 'member',
      };
      
    } catch (e) {
      print('❌ [알림] 최신 메시지 정보 가져오기 실패: $e');
      return {
        'memberName': '고객',
        'message': '새로운 메시지',
        'senderType': 'member',
      };
    }
  }

  void dispose() {
    _unreadCountSubscription?.cancel();
    _messageActivitySubscription?.cancel();
    _latestMessageInfoSubscription?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  // 수동으로 알림음 테스트
  Future<void> testNotificationSound() async {
    print('🧪 알림음 테스트 시작 (현재 벨소리: $_selectedRingtone)');
    await _playNotificationSound();
  }
  
  // 특정 벨소리 미리듣기 (설정 변경 없이)
  Future<void> previewRingtone(String ringtone) async {
    print('🎵 벨소리 미리듣기: $ringtone');
    
    if (kIsWeb) {
      // 웹에서 MP3 파일 재생
      if (ringtone == 'hole_in' || ringtone == 'iron') {
        try {
          final audio = html.AudioElement();
          audio.src = '${ringtone}.mp3';
          audio.volume = 1.0;
          await audio.play();
          print('🔔 MP3 미리듣기: ${ringtone}.mp3');
        } catch (e) {
          print('❌ MP3 미리듣기 실패: $e');
        }
      } else {
        // 기본 딩동
        _createInlineDingDongSound();
      }
    } else {
      // 모바일
      if (_audioPlayer != null) {
        String soundFile = 'sounds/dingdong.mp3';
        if (ringtone == 'hole_in') {
          soundFile = 'sounds/hole_in.mp3';
        } else if (ringtone == 'iron') {
          soundFile = 'sounds/iron.mp3';
        }
        await _audioPlayer!.play(AssetSource(soundFile));
      }
    }
  }
  
  // 특정 딩동 소리 테스트
  void testSpecificSound(String soundType) {
    if (!kIsWeb) {
      print('📱 모바일에서는 지원되지 않음');
      return;
    }
    
    try {
      print('🧪 $soundType 소리 테스트');
      bool success = false;
      
      switch (soundType) {
        case 'doorbell':
          success = js.context.callMethod('createDoorbellSound') == true;
          break;
        case 'rich':
          success = js.context.callMethod('createRichDingDongSound') == true;
          break;
        case 'basic':
          success = js.context.callMethod('createDingDongSound') == true;
          break;
      }
      
      print(success ? '✅ $soundType 테스트 성공' : '❌ $soundType 테스트 실패');
    } catch (e) {
      print('❌ $soundType 테스트 에러: $e');
    }
  }
  
  // 새 메시지 시뮬레이션 (테스트 버튼용)
  Future<void> simulateNewMessage() async {
    print('🎭 새 메시지 시뮬레이션 시작');
    int currentCount = _totalUnreadCount;

    // 카운트를 1 증가시켜서 새 메시지 도착 시뮬레이션
    _totalUnreadCount = currentCount + 1;

    print('🚨 테스트 알림! 이전: $currentCount, 현재: $_totalUnreadCount');
    
    // 알림음 재생
    await _playNotificationSound();
    
    // 브라우저 푸시 알림 표시 (설정된 경우)
    if (kIsWeb && _browserNotificationEnabled) {
      showBrowserNotification(
        '테스트 알림',
        '🔔 알림 테스트가 정상적으로 작동합니다!',
      );
    }

    notifyListeners();

    // 3초 후 원복
    Timer(Duration(seconds: 3), () {
      _totalUnreadCount = currentCount;
      notifyListeners();
      print('🔄 메시지 카운트 원복: $_totalUnreadCount');
    });
  }
}