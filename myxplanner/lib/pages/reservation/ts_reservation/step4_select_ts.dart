import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';

class Step4SelectTs extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final DateTime? selectedDate;
  final String? selectedTime;
  final int? selectedDuration;
  final Function(String)? onTsSelected;
  final Function(String)? onTimeSelected;

  const Step4SelectTs({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.selectedDate,
    this.selectedTime,
    this.selectedDuration,
    this.onTsSelected,
    this.onTimeSelected,
  }) : super(key: key);

  @override
  _Step4SelectTsState createState() => _Step4SelectTsState();
}

class _Step4SelectTsState extends State<Step4SelectTs> {
  String? _selectedTsId;
  List<Map<String, dynamic>> _tsInfoList = [];
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _availabilityStatus = {}; // 타석별 예약 가능 여부 저장
  String _memberType = ''; // 회원 타입 저장

  @override
  void initState() {
    super.initState();
    _loadTsInfo();
    _loadMemberType(); // 회원 타입 조회 추가
  }

  @override
  void didUpdateWidget(Step4SelectTs oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 회원이 변경된 경우 회원 타입 다시 조회
    if (oldWidget.selectedMember?['member_id'] != widget.selectedMember?['member_id']) {
      print('🔄 Step4: 회원 변경됨 - 회원 타입 다시 조회');
      _loadMemberType();
    }
    
    // 연습시간이 변경되었을 때 예약 가능 여부 다시 체크
    if (oldWidget.selectedDuration != widget.selectedDuration ||
        oldWidget.selectedTime != widget.selectedTime ||
        oldWidget.selectedDate != widget.selectedDate) {
      print('🔄 Step4: 예약 조건 변경됨 - 예약 가능 여부 다시 체크');
      print('🔄 이전 연습시간: ${oldWidget.selectedDuration}분 → 현재: ${widget.selectedDuration}분');
      print('🔄 이전 시작시간: ${oldWidget.selectedTime} → 현재: ${widget.selectedTime}');
      _recheckAvailability();
    }
  }

  // 예약 가능 여부만 다시 체크하는 함수
  Future<void> _recheckAvailability() async {
    if (widget.selectedDate != null && widget.selectedTime != null && widget.selectedDuration != null && _tsInfoList.isNotEmpty) {
      await _checkTsAvailabilityForAll(_tsInfoList);
      setState(() {
        // UI 업데이트를 위한 setState
      });
    }
  }

  // 타석 정보 조회
  Future<void> _loadTsInfo() async {
    try {
      print('=== 타석 정보 조회 시작 (Step4) ===');
      
      // 1. ts_buffer 포함한 타석 정보 조회
      final tsInfoList = await ApiService.getTsInfoWithBuffer();
      
      print('조회된 타석 수: ${tsInfoList.length}');
      
      // 타석 정보 출력
      for (final tsInfo in tsInfoList) {
        print('타석 ${tsInfo['ts_id']}: 상태=${tsInfo['ts_status']}, 최소=${tsInfo['ts_min_minimum']}분, 최대=${tsInfo['ts_min_maximum']}분, 버퍼=${tsInfo['ts_buffer']}분, 제한회원=${tsInfo['member_type_prohibited']}');
      }
      
      // 2. 예약하려는 날짜와 시간이 있는 경우 시간 겹침 체크
      if (widget.selectedDate != null && widget.selectedTime != null && widget.selectedDuration != null) {
        await _checkTsAvailabilityForAll(tsInfoList);
      }
      
      setState(() {
        _tsInfoList = tsInfoList;
        _isLoading = false;
      });
      
    } catch (e) {
      print('타석 정보 조회 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 회원 타입 조회
  Future<void> _loadMemberType() async {
    if (widget.selectedMember == null) {
      print('회원 정보가 없어 회원 타입 조회 건너뛰기');
      setState(() {
        _memberType = '';
      });
      return;
    }

    try {
      final memberId = widget.selectedMember!['member_id']?.toString();
      if (memberId != null && memberId.isNotEmpty) {
        print('=== 회원 타입 조회 시작 ===');
        print('회원 ID: $memberId');
        
        final memberType = await ApiService.getMemberType(memberId: memberId);
        
        setState(() {
          _memberType = memberType;
        });
        
        print('조회된 회원 타입: $memberType');
      } else {
        setState(() {
          _memberType = '';
        });
      }
    } catch (e) {
      print('회원 타입 조회 실패: $e');
      setState(() {
        _memberType = '';
      });
    }
  }

  // 모든 타석의 예약 가능 여부 체크
  Future<void> _checkTsAvailabilityForAll(List<Map<String, dynamic>> tsInfoList) async {
    try {
      print('=== 모든 타석 예약 가능 여부 체크 시작 ===');
      
      final selectedDate = widget.selectedDate!;
      final selectedTime = widget.selectedTime!;
      final selectedDuration = widget.selectedDuration!;
      
      final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      
      print('체크할 날짜: $dateStr');
      print('체크할 시간: $selectedTime');
      print('체크할 연습시간: ${selectedDuration}분');
      
      Map<String, Map<String, dynamic>> availabilityStatus = {};
      
      for (final tsInfo in tsInfoList) {
        final tsId = tsInfo['ts_id']?.toString() ?? '';
        final tsBuffer = int.tryParse(tsInfo['ts_buffer']?.toString() ?? '0') ?? 0;
        
        if (tsId.isNotEmpty) {
          print('타석 $tsId 예약 가능 여부 체크 중... (버퍼: ${tsBuffer}분)');
          
          final availabilityResult = await ApiService.checkTsAvailability(
            date: dateStr,
            startTime: selectedTime,
            durationMinutes: selectedDuration,
            tsId: tsId,
            tsBuffer: tsBuffer,
          );
          
          availabilityStatus[tsId] = availabilityResult;
          
          print('타석 $tsId 결과: ${availabilityResult['available'] ? '예약가능' : '예약불가'} (${availabilityResult['reason']})');
        }
      }
      
      _availabilityStatus = availabilityStatus;
      print('=== 모든 타석 예약 가능 여부 체크 완료 ===');
      
    } catch (e) {
      print('타석 예약 가능 여부 체크 실패: $e');
    }
  }

  // 타석 사용 가능 여부 확인
  bool _isTsAvailable(Map<String, dynamic> tsInfo) {
    final tsId = tsInfo['ts_id']?.toString() ?? '';
    
    // 1. ts_status가 '예약중지'인 경우 비활성화
    if (tsInfo['ts_status'] == '예약중지') {
      return false;
    }
    
    // 2. 회원 타입 제한 체크
    final memberTypeProhibited = tsInfo['member_type_prohibited']?.toString() ?? '';
    if (memberTypeProhibited.isNotEmpty && _memberType.isNotEmpty) {
      // 콤마로 구분된 제한 회원 타입들을 분리
      final prohibitedTypes = memberTypeProhibited.split(',').map((type) => type.trim()).toList();
      
      // 현재 회원 타입이 제한 목록에 포함되어 있는지 확인
      if (prohibitedTypes.contains(_memberType)) {
        print('타석 $tsId: 회원 타입 $_memberType이 제한 목록 $prohibitedTypes에 포함됨');
        return false;
      }
    }
    
    // 3. 선택된 연습시간이 있는 경우 최소/최대 시간 체크
    if (widget.selectedDuration != null) {
      final selectedDuration = widget.selectedDuration!;
      final minMinimum = double.tryParse(tsInfo['ts_min_minimum']?.toString() ?? '0') ?? 0;
      final minMaximum = double.tryParse(tsInfo['ts_min_maximum']?.toString() ?? '999') ?? 999;
      
      // 선택된 시간이 최소시간보다 작거나 최대시간보다 큰 경우 비활성화
      if (selectedDuration < minMinimum || selectedDuration > minMaximum) {
        return false;
      }
    }
    
    // 4. 기존 예약과 시간 겹침 체크
    if (_availabilityStatus.containsKey(tsId)) {
      final availabilityResult = _availabilityStatus[tsId]!;
      if (!availabilityResult['available']) {
        return false;
      }
    }
    
    return true;
  }

  // 오직 시간 겹침 때문에 예약이 불가한지 확인
  bool _isOnlyTimeConflict(Map<String, dynamic> tsInfo) {
    final tsId = tsInfo['ts_id']?.toString() ?? '';
    
    // 1. ts_status가 '예약중지'인 경우 - 시간 문제가 아님
    if (tsInfo['ts_status'] == '예약중지') {
      return false;
    }
    
    // 2. 회원 타입 제한이 있는 경우 - 시간 문제가 아님
    final memberTypeProhibited = tsInfo['member_type_prohibited']?.toString() ?? '';
    if (memberTypeProhibited.isNotEmpty && _memberType.isNotEmpty) {
      final prohibitedTypes = memberTypeProhibited.split(',').map((type) => type.trim()).toList();
      if (prohibitedTypes.contains(_memberType)) {
        return false;
      }
    }
    
    // 3. 연습시간 제약이 있는 경우 - 시간 문제가 아님
    if (widget.selectedDuration != null) {
      final selectedDuration = widget.selectedDuration!;
      final minMinimum = double.tryParse(tsInfo['ts_min_minimum']?.toString() ?? '0') ?? 0;
      final minMaximum = double.tryParse(tsInfo['ts_min_maximum']?.toString() ?? '999') ?? 999;
      
      if (selectedDuration < minMinimum || selectedDuration > minMaximum) {
        return false;
      }
    }
    
    // 4. 기존 예약과 시간 겹침만 남은 경우 - 진짜 시간 문제
    if (_availabilityStatus.containsKey(tsId)) {
      final availabilityResult = _availabilityStatus[tsId]!;
      if (!availabilityResult['available']) {
        final reason = availabilityResult['reason']?.toString() ?? '';
        // 시간 겹침 관련 이유인 경우만 true 반환
        return reason.contains('기존 예약과 시간 겹침');
      }
    }
    
    return false;
  }

  // 비활성화 사유 반환
  String _getDisabledReason(Map<String, dynamic> tsInfo) {
    final tsId = tsInfo['ts_id']?.toString() ?? '';
    
    // 1. ts_status 체크
    if (tsInfo['ts_status'] == '예약중지') {
      return '예약중지';
    }
    
    // 2. 회원 타입 제한 체크
    final memberTypeProhibited = tsInfo['member_type_prohibited']?.toString() ?? '';
    if (memberTypeProhibited.isNotEmpty && _memberType.isNotEmpty) {
      final prohibitedTypes = memberTypeProhibited.split(',').map((type) => type.trim()).toList();
      if (prohibitedTypes.contains(_memberType)) {
        return '회원 타입 제한';
      }
    }
    
    // 3. 연습시간 체크
    if (widget.selectedDuration != null) {
      final selectedDuration = widget.selectedDuration!;
      final minMinimum = double.tryParse(tsInfo['ts_min_minimum']?.toString() ?? '0') ?? 0;
      final minMaximum = double.tryParse(tsInfo['ts_min_maximum']?.toString() ?? '999') ?? 999;
      
      if (selectedDuration < minMinimum) {
        return '최소시간 부족';
      } else if (selectedDuration > minMaximum) {
        return '최대시간 초과';
      }
    }
    
    // 4. 기존 예약과 시간 겹침 체크
    if (_availabilityStatus.containsKey(tsId)) {
      final availabilityResult = _availabilityStatus[tsId]!;
      if (!availabilityResult['available']) {
        final reason = availabilityResult['reason']?.toString() ?? '';
        if (reason.contains('기존 예약과 시간 겹침')) {
          return '예약 시간 겹침';
        } else if (reason.contains('시스템 오류')) {
          return '시스템 오류';
        } else {
          return '예약 불가';
        }
      }
    }
    
    return '';
  }

  // 타석 선택 처리
  void _selectTs(String tsId) {
    print('🎯 Step4에서 타석 선택됨: $tsId');
    setState(() {
      _selectedTsId = tsId;
    });
    print('🎯 Step4 _selectedTsId 업데이트됨: $_selectedTsId');
    
    // 콜백 호출
    if (widget.onTsSelected != null) {
      print('🎯 Step4에서 콜백 호출: ${widget.onTsSelected}');
      widget.onTsSelected!(tsId);
      print('🎯 Step4 콜백 호출 완료');
    } else {
      print('🎯 Step4 콜백이 null입니다');
    }
    
    // 선택 확인 메시지
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$tsId번 타석이 선택되었습니다.'),
        backgroundColor: Color(0xFF00A86B),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // 타석 시간표 팝업 다이얼로그
  void _showTsScheduleDialog(Map<String, dynamic> tsInfo) async {
    if (widget.selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('날짜를 먼저 선택해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final tsId = tsInfo['ts_id']?.toString() ?? '';
    final tsBuffer = int.tryParse(tsInfo['ts_buffer']?.toString() ?? '0') ?? 0;
    
    // 해당 날짜의 타석 예약 현황 조회
    final dateStr = '${widget.selectedDate!.year}-${widget.selectedDate!.month.toString().padLeft(2, '0')}-${widget.selectedDate!.day.toString().padLeft(2, '0')}';
    
    try {
      final reservationsByTs = await ApiService.getTsReservationsByDate(date: dateStr);
      final tsReservations = reservationsByTs[tsId] ?? [];
      
      showDialog(
        context: context,
      useRootNavigator: false,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '타석 현황 ($tsId번 타석)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                  
                  // 날짜 정보
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF666666),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // 시간표
                  Expanded(
                    child: _buildTsScheduleView(tsReservations, tsBuffer),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('타석 시간표 조회 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('시간표 조회에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 타석 시간표 뷰 생성
  Widget _buildTsScheduleView(List<Map<String, dynamic>> reservations, int tsBuffer) {
    // 현재 시간 가져오기
    final now = DateTime.now();
    final currentTimeMinutes = now.hour * 60 + now.minute;
    
    // 선택된 날짜가 오늘인지 확인
    final selectedDate = widget.selectedDate!;
    final today = DateTime.now();
    final isToday = selectedDate.year == today.year && 
                   selectedDate.month == today.month && 
                   selectedDate.day == today.day;
    
    // 예약 정보를 시간 순으로 정렬
    reservations.sort((a, b) {
      final aStart = _timeToMinutes(a['ts_start']?.toString() ?? '00:00');
      final bStart = _timeToMinutes(b['ts_start']?.toString() ?? '00:00');
      return aStart.compareTo(bStart);
    });
    
    // 연속된 시간대 생성 (전환시간 포함)
    List<Map<String, dynamic>> timeSegments = [];
    int currentTime = 9 * 60; // 09:00부터 시작
    final endTime = 22 * 60; // 22:00까지
    
    for (final reservation in reservations) {
      final resStart = _timeToMinutes(reservation['ts_start']?.toString() ?? '00:00');
      final resEnd = _timeToMinutes(reservation['ts_end']?.toString() ?? '00:00');
      
      // 예약 시작 전 시간이 있으면 추가 (버퍼 고려)
      final reservationStartWithBuffer = resStart - tsBuffer;
      if (currentTime < reservationStartWithBuffer) {
        // 현재시간 고려하여 상태 결정
        String status = 'available';
        String info = '예약 가능';
        
        if (isToday && reservationStartWithBuffer <= currentTimeMinutes) {
          status = 'passed';
          info = '시간 경과';
        } else if (isToday && currentTime < currentTimeMinutes && reservationStartWithBuffer > currentTimeMinutes) {
          // 시간대가 현재시간을 걸쳐있는 경우 분할
          if (currentTime < currentTimeMinutes) {
            // 경과된 부분
            timeSegments.add({
              'startTime': _minutesToTime(currentTime),
              'endTime': _minutesToTime(currentTimeMinutes),
              'status': 'passed',
              'info': '시간 경과',
            });
            currentTime = currentTimeMinutes;
          }
          if (currentTime < reservationStartWithBuffer) {
            // 예약 가능한 부분
            timeSegments.add({
              'startTime': _minutesToTime(currentTime),
              'endTime': _minutesToTime(reservationStartWithBuffer),
              'status': 'available',
              'info': '예약 가능',
            });
          }
          currentTime = reservationStartWithBuffer;
        }
        
        timeSegments.add({
          'startTime': _minutesToTime(currentTime),
          'endTime': _minutesToTime(reservationStartWithBuffer),
          'status': status,
          'info': info,
        });
        currentTime = reservationStartWithBuffer;
      }
      
      // 예약된 시간 (전환시간 포함)
      final reservationEndWithBuffer = resEnd + tsBuffer;
      if (currentTime < reservationEndWithBuffer) {
        String reservedStatus = 'reserved';
        String info = '예약된 타석';
        
        if (isToday && reservationEndWithBuffer <= currentTimeMinutes) {
          reservedStatus = 'passed';
          info = '시간 경과';
        }
        
        timeSegments.add({
          'startTime': _minutesToTime(currentTime),
          'endTime': _minutesToTime(reservationEndWithBuffer),
          'status': reservedStatus,
          'info': info,
        });
        currentTime = reservationEndWithBuffer;
      }
    }
    
    // 마지막 예약 후 남은 시간
    if (currentTime < endTime) {
      String status = 'available';
      String info = '예약가능';
      
      if (isToday && currentTime < currentTimeMinutes) {
        // 현재시간을 걸쳐있는 경우 분할
        if (currentTimeMinutes < endTime) {
          // 경과된 부분
          timeSegments.add({
            'startTime': _minutesToTime(currentTime),
            'endTime': _minutesToTime(currentTimeMinutes),
            'status': 'passed',
            'info': '시간 경과',
          });
          
          // 예약 가능한 부분
          timeSegments.add({
            'startTime': _minutesToTime(currentTimeMinutes),
            'endTime': _minutesToTime(endTime),
            'status': 'available',
            'info': '예약가능',
          });
        } else {
          // 전체가 경과된 경우
          timeSegments.add({
            'startTime': _minutesToTime(currentTime),
            'endTime': _minutesToTime(endTime),
            'status': 'passed',
            'info': '시간 경과',
          });
        }
      } else {
        timeSegments.add({
          'startTime': _minutesToTime(currentTime),
          'endTime': _minutesToTime(endTime),
          'status': status,
          'info': info,
        });
      }
    }
    
    return ListView.builder(
      itemCount: timeSegments.length,
      itemBuilder: (context, index) {
        final segment = timeSegments[index];
        final status = segment['status'];
        final isAvailable = status == 'available';
        
        Color backgroundColor;
        Color textColor;
        IconData? icon;
        
        switch (status) {
          case 'reserved':
            backgroundColor = Color(0xFFF5F5F5);
            textColor = Color(0xFF9E9E9E);
            icon = Icons.block;
            break;
          case 'passed':
            backgroundColor = Color(0xFFF5F5F5);
            textColor = Color(0xFF9E9E9E);
            icon = Icons.history;
            break;
          default:
            backgroundColor = Color(0xFFE8F5E8);
            textColor = Color(0xFF2E7D32);
            icon = Icons.check_circle_outline;
        }
        
        return GestureDetector(
          onTap: isAvailable ? () => _selectTimeFromSchedule(segment['startTime']) : null,
          child: Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAvailable 
                    ? Color(0xFF00A86B).withOpacity(0.3)
                    : Colors.transparent,
              ),
              boxShadow: isAvailable ? [
                BoxShadow(
                  color: Color(0xFF00A86B).withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ] : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: textColor,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${segment['startTime']} - ${segment['endTime']} ${segment['info']}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                if (isAvailable) ...[
                  Text(
                    '선택',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF00A86B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFF00A86B),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // 스케줄에서 시간 선택 처리
  void _selectTimeFromSchedule(String startTime) {
    try {
      // 팝업 닫기
      Navigator.of(context).pop();
      
      // Step2로 돌아가기 위해 부모 컴포넌트에 시간 변경 요청
      if (widget.onTimeSelected != null) {
        widget.onTimeSelected!(startTime);
        
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('시작시간이 $startTime 으로 변경되었습니다.'),
            backgroundColor: Color(0xFF00A86B),
            duration: Duration(seconds: 2),
          ),
        );
        
        print('=== 스케줄에서 시간 선택 완료 ===');
        print('선택된 시작시간: $startTime');
      }
      
    } catch (e) {
      print('스케줄 시간 선택 오류: $e');
      
      // 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('시간 변경 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 시간을 분으로 변환
  int _timeToMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }

  // 분을 시간으로 변환
  String _minutesToTime(int minutes) {
    try {
      if (minutes < 0) minutes = 0;
      if (minutes >= 1440) minutes = minutes % 1440;
      
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A86B)),
              ),
              SizedBox(height: 16),
              Text(
                '타석 정보를 조회 중...',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_tsInfoList.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xFFBBBBBB),
              ),
              SizedBox(height: 16),
              Text(
                '타석 정보를 찾을 수 없습니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타석 그리드 (타일 제거, 직접 배치)
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3열
              crossAxisSpacing: 12, // 16에서 12로 감소
              mainAxisSpacing: 12, // 16에서 12로 감소
              childAspectRatio: 1.28, // 1.3에서 1.29로 조정 (타일 높이 증가)
            ),
            itemCount: _tsInfoList.length,
            itemBuilder: (context, index) {
              final tsInfo = _tsInfoList[index];
              final tsId = tsInfo['ts_id']?.toString() ?? '';
              final isAvailable = _isTsAvailable(tsInfo);
              final disabledReason = _getDisabledReason(tsInfo);
              final isSelected = _selectedTsId == tsId;
              
              print('🏌️ 타석 $tsId: 선택가능=$isAvailable, 비활성화사유=$disabledReason, 선택됨=$isSelected');
              
              return GestureDetector(
                onTap: isAvailable ? () => _selectTs(tsId) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Color(0xFFF0F9F4) // 더 부드러운 연한 민트색 배경
                        : isAvailable 
                            ? Colors.white 
                            : Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12), // 14에서 12로 감소
                    border: Border.all(
                      color: isSelected 
                          ? Color(0xFF00A86B) 
                          : isAvailable 
                              ? Color(0xFFE0E0E0) 
                              : Color(0xFFCCCCCC),
                      width: isSelected ? 2 : 1, // 2.5에서 2, 1.5에서 1로 감소
                    ),
                    boxShadow: isAvailable ? [
                      BoxShadow(
                        color: isSelected 
                            ? Color(0xFF00A86B).withOpacity(0.2)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: isSelected ? 8 : 4, // 12에서 8, 6에서 4로 감소
                        offset: Offset(0, isSelected ? 3 : 2), // 4에서 3, 3에서 2로 감소
                      ),
                    ] : null,
                  ),
                  child: Stack(
                    children: [
                      // 기존 타석 내용 - 전체 컨테이너를 중앙 정렬
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 불가 사유 (타석 번호 위에 표시)
                            if (!isAvailable) ...[
                              Text(
                                disabledReason,
                                style: TextStyle(
                                  fontSize: 11, // 12에서 11로 감소
                                  color: Color(0xFFE53E3E),
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 4), // 6에서 4로 감소
                            ],
                            
                            // 타석 아이콘 (활성화된 타석만)
                            if (isAvailable) ...[
                              Container(
                                padding: EdgeInsets.all(8), // 10에서 8로 감소
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Color(0xFF00A86B).withOpacity(0.1)
                                      : Color(0xFF8E44AD).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.sports_golf,
                                  size: 22, // 26에서 22로 감소
                                  color: isSelected ? Color(0xFF00A86B) : Color(0xFF8E44AD),
                                ),
                              ),
                              SizedBox(height: 6), // 10에서 6으로 감소
                            ],
                            
                            // 타석 번호
                            Text(
                              '${tsId}번 타석',
                              style: TextStyle(
                                fontSize: 14, // 15에서 14로 감소
                                fontWeight: FontWeight.bold,
                                color: isAvailable 
                                    ? (isSelected ? Color(0xFF00A86B) : Color(0xFF333333))
                                    : Color(0xFF999999),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            // 가능시간 확인 버튼 (기존 예약과 시간 겹침으로 인해 불가한 경우에만 표시)
                            if (!isAvailable && _isOnlyTimeConflict(tsInfo)) ...[
                              SizedBox(height: 3), // 4에서 3으로 감소
                              GestureDetector(
                                onTap: () => _showTsScheduleDialog(tsInfo),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5), // 14, 7에서 12, 5로 감소
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8), // 10에서 8로 감소
                                    border: Border.all(
                                      color: Color(0xFF2196F3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF2196F3).withOpacity(0.1),
                                        blurRadius: 3, // 4에서 3으로 감소
                                        offset: Offset(0, 1), // 2에서 1로 감소
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '가능시간',
                                    style: TextStyle(
                                      fontSize: 11, // 12에서 11로 감소
                                      color: Color(0xFF424242),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
} 