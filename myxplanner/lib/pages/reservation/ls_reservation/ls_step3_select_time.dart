import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';

class LsStep3SelectTime extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  final DateTime? selectedDate;
  final String? selectedInstructor;
  final Function(String) onTimeSelected;
  final String? selectedTime;
  final Map<String, dynamic>? lessonCountingData;
  final Map<String, Map<String, dynamic>> proInfoMap;
  final Map<String, Map<String, Map<String, dynamic>>> proScheduleMap;

  const LsStep3SelectTime({
    Key? key,
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
    this.selectedDate,
    this.selectedInstructor,
    required this.onTimeSelected,
    this.selectedTime,
    this.lessonCountingData,
    required this.proInfoMap,
    required this.proScheduleMap,
  }) : super(key: key);

  @override
  _LsStep3SelectTimeState createState() => _LsStep3SelectTimeState();
}

class _LsStep3SelectTimeState extends State<LsStep3SelectTime> {
  String? _selectedTimeRange;
  List<Map<String, dynamic>> _availableTimeRanges = [];
  List<Map<String, dynamic>> _reservations = [];
  int _minServiceMin = 0;
  String _workStart = '09:00:00';
  String _workEnd = '18:00:00';
  bool _isLoadingReservations = false;
  int _serviceUnitMin = 5; // 기본값 5분

  @override
  void initState() {
    super.initState();
    _initializeTimeData();
  }

  @override
  void didUpdateWidget(LsStep3SelectTime oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 날짜나 강사가 변경된 경우 데이터 다시 로드
    if (widget.selectedDate != oldWidget.selectedDate ||
        widget.selectedInstructor != oldWidget.selectedInstructor) {
      _selectedTimeRange = null; // 선택된 시간 초기화
      _initializeTimeData();
    }
  }

  Future<void> _initializeTimeData() async {
    if (widget.selectedDate == null || widget.selectedInstructor == null) return;

    print('\n=== 시간선택 단계에서 호출된 정보 ===');
    print('날짜: ${DateFormat('yyyy-MM-dd').format(widget.selectedDate!)}');
    print('선택된 프로 ID: ${widget.selectedInstructor}');

    // 프로 정보 가져오기
    final proInfo = widget.proInfoMap[widget.selectedInstructor];
    if (proInfo == null) {
      print('❌ 프로 정보를 찾을 수 없습니다.');
      return;
    }

    print('프로 이름: ${proInfo['pro_name']}');

    // 최소 레슨시간 설정
    _minServiceMin = int.tryParse(proInfo['min_service_min']?.toString() ?? '0') ?? 0;
    // 레슨시간 단위 설정
    _serviceUnitMin = int.tryParse(proInfo['svc_time_unit']?.toString() ?? '5') ?? 5;
    print('최소 레슨시간: ${_minServiceMin}분');
    print('레슨시간 단위: ${_serviceUnitMin}분');

    // 근무시간 설정
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
    final proSchedule = widget.proScheduleMap[widget.selectedInstructor]?[dateStr];
    if (proSchedule != null) {
      _workStart = proSchedule['work_start'] ?? '09:00:00';
      _workEnd = proSchedule['work_end'] ?? '18:00:00';
      print('근무시간: ${_workStart} ~ ${_workEnd}');
    } else {
      print('프로 스케줄 정보를 찾을 수 없습니다. 기본 근무시간 사용: 09:00:00 ~ 18:00:00');
    }

    // 예약내역 직접 API 조회
    await _loadReservations();
  }

  Future<void> _loadReservations() async {
    if (_isLoadingReservations) return;
    
    setState(() {
      _isLoadingReservations = true;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
      final orders = await ApiService.getLsOrders(
        proId: widget.selectedInstructor!,
        lsDate: dateStr,
      );

      print('\n[API로 조회한 예약내역]');
      if (orders.isEmpty) {
        print('예약된 레슨이 없습니다.');
      } else {
        for (final order in orders) {
          print('• ${order['LS_start_time']} ~ ${order['LS_end_time']}');
        }
      }

      // 예약내역 정렬
      _reservations = List<Map<String, dynamic>>.from(orders)
        ..sort((a, b) => a['LS_start_time'].compareTo(b['LS_start_time']));

      print('\n[정렬된 예약내역]');
      for (int i = 0; i < _reservations.length; i++) {
        final reservation = _reservations[i];
        print('• ${reservation['LS_start_time']} ~ ${reservation['LS_end_time']}');
      }
      print('================================\n');

      setState(() {
        _isLoadingReservations = false;
      });

      _calculateAvailableTimeRanges();
    } catch (e) {
      print('예약내역 조회 실패: $e');
      setState(() {
        _isLoadingReservations = false;
        _reservations = [];
      });
      _calculateAvailableTimeRanges();
    }
  }

  void _calculateAvailableTimeRanges() {
    _availableTimeRanges = [];
    
    try {
      print('\n=== 시간대 계산 시작 ===');
      print('근무시간: $_workStart ~ $_workEnd');
      print('최소 레슨시간: ${_minServiceMin}분');
      print('레슨시간 단위: ${_serviceUnitMin}분');
      print('예약내역 수: ${_reservations.length}');
      
      // 근무 시간을 분 단위로 변환
      final workStartMinutes = _timeToMinutes(_workStart);
      final workEndMinutes = _timeToMinutes(_workEnd);
      
      print('근무시간(분): $workStartMinutes ~ $workEndMinutes');
      
      // 예약 시간들을 분 단위로 변환
      List<Map<String, int>> reservationMinutes = [];
      for (var reservation in _reservations) {
        final startMinutes = _timeToMinutes(reservation['LS_start_time']);
        final endMinutes = _timeToMinutes(reservation['LS_end_time']);
        reservationMinutes.add({
          'start': startMinutes,
          'end': endMinutes,
        });
        print('예약: ${_minutesToTime(startMinutes)} ~ ${_minutesToTime(endMinutes)}');
      }
      
      // 예약 시간 정렬
      reservationMinutes.sort((a, b) => a['start']!.compareTo(b['start']!));
      
      // 가능한 시작시간들을 레슨시간 단위로 체크
      List<int> availableStartTimes = [];
      
      // 근무 시작부터 (근무 종료 - 최소 레슨시간)까지 레슨시간 단위로 체크
      final lastPossibleStartTime = workEndMinutes - _minServiceMin;
      
      // 가능한 시작시간 후보 생성 - 기본 단위시간 + 예약 종료시간들
      Set<int> candidateStartTimes = {};
      
      // 1. 기본 단위시간으로 생성
      for (int startTime = workStartMinutes; startTime <= lastPossibleStartTime; startTime += _serviceUnitMin) {
        candidateStartTimes.add(startTime);
      }
      
      // 2. 기존 예약의 종료시간을 시작시간 후보로 추가
      for (var reservation in reservationMinutes) {
        final reservationEndTime = reservation['end']! as int;
        if (reservationEndTime >= workStartMinutes && reservationEndTime <= lastPossibleStartTime) {
          candidateStartTimes.add(reservationEndTime);
        }
      }
      
      // 정렬된 후보 시간들 체크
      final sortedCandidates = candidateStartTimes.toList()..sort();
      
      for (int startTime in sortedCandidates) {
        final endTime = startTime + _minServiceMin;
        bool canStart = true;
        
        // 근무시간 내에 있는지 확인
        if (endTime > workEndMinutes) {
          canStart = false;
          print('시작시간 ${_minutesToTime(startTime)} 불가: 근무시간 초과');
        } else {
          // 이 시작시간으로 최소 레슨시간만큼 진행했을 때 기존 예약과 충돌하는지 확인
          for (var reservation in reservationMinutes) {
            // 새로운 레슨 시간(startTime ~ endTime)이 기존 예약과 겹치는지 확인
            if (startTime < reservation['end']! && endTime > reservation['start']!) {
              canStart = false;
              print('시작시간 ${_minutesToTime(startTime)} 불가: 예약 ${_minutesToTime(reservation['start']!)}~${_minutesToTime(reservation['end']!)}와 충돌');
              break;
            }
          }
        }
        
        if (canStart) {
          availableStartTimes.add(startTime);
          print('시작시간 ${_minutesToTime(startTime)} 가능 (${_minutesToTime(endTime)}까지 최소 레슨시간 확보)');
        }
      }
      
      // 연속된 시간들을 그룹화하여 시간대로 만들기
      if (availableStartTimes.isNotEmpty) {
        int rangeStart = availableStartTimes[0];
        int rangeEnd = rangeStart;
        
        for (int i = 1; i < availableStartTimes.length; i++) {
          // 연속성 체크: 이전 시간과 1분 이상 5분 이하 차이면 연속으로 간주
          final timeDiff = availableStartTimes[i] - rangeEnd;
          if (timeDiff >= 1 && timeDiff <= _serviceUnitMin) {
            // 연속된 시간
            rangeEnd = availableStartTimes[i];
          } else {
            // 연속이 끊어짐 - 이전 범위 추가
            _addTimeRange(rangeStart, rangeEnd);
            rangeStart = availableStartTimes[i];
            rangeEnd = rangeStart;
          }
        }
        // 마지막 범위 추가
        _addTimeRange(rangeStart, rangeEnd);
      }
      
      print('\n=== 계산된 예약 가능 시간대 ===');
      for (var timeRange in _availableTimeRanges) {
        print('• ${timeRange['formatted']}');
      }
      print('총 ${_availableTimeRanges.length}개 시간대');
      print('================================\n');
      
    } catch (e) {
      print('시간대 계산 오류: $e');
      _availableTimeRanges = [];
    }

    // UI 업데이트를 위한 setState 호출
    if (mounted) {
      setState(() {});
    }
  }

  // 시간 문자열을 분 단위로 변환 (HH:MM:SS 또는 HH:MM)
  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }

  // 분을 시간 문자열로 변환 (HH:MM)
  String _minutesToTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  // 분을 TimeOfDay로 변환
  TimeOfDay _minutesToTimeOfDay(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _subtractMinutes(TimeOfDay time, int minutes) {
    final totalMinutes = time.hour * 60 + time.minute - minutes;
    if (totalMinutes < 0) return TimeOfDay(hour: 0, minute: 0);
    return TimeOfDay(
      hour: totalMinutes ~/ 60,
      minute: totalMinutes % 60
    );
  }

  int _compareTime(TimeOfDay a, TimeOfDay b) {
    final aMinutes = a.hour * 60 + a.minute;
    final bMinutes = b.hour * 60 + b.minute;
    return aMinutes.compareTo(bMinutes);
  }

  int _getMinutesDifference(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return endMinutes - startMinutes;
  }

  void _showTimePicker(Map<String, dynamic> timeRange) {
    final startMinutes = timeRange['startMinutes'] as int;
    final endMinutes = timeRange['endMinutes'] as int;
    
    // 이 시간대에서 선택 가능한 시작시간들을 레슨시간 단위로 생성
    List<int> validStartTimes = [];
    final lastPossibleStart = endMinutes - _minServiceMin;
    
    // 레슨시간 단위로 시간 생성 (5분이 아닌 _serviceUnitMin 사용)
    for (int time = startMinutes; time <= lastPossibleStart; time += _serviceUnitMin) {
      // 이 시작시간이 유효한지 다시 한번 확인
      final proposedEndTime = time + _minServiceMin;
      bool isValid = true;
      
      // 기존 예약과 충돌하는지 확인
      for (var reservation in _reservations) {
        final reservationStart = _timeToMinutes(reservation['LS_start_time']);
        final reservationEnd = _timeToMinutes(reservation['LS_end_time']);
        
        if (time < reservationEnd && proposedEndTime > reservationStart) {
          isValid = false;
          break;
        }
      }
      
      if (isValid) {
        validStartTimes.add(time);
      }
    }
    
    if (validStartTimes.isEmpty) {
      // 선택 가능한 시간이 없는 경우
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이 시간대에는 선택 가능한 시작시간이 없습니다.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    
    // 시간 선택 다이얼로그 표시
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, color: Color(0xFF10B981), size: 24),
                    SizedBox(width: 8),
                    Text(
                      '시작시간 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Color(0xFF666666)),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  '최소 레슨시간 : ${_minServiceMin}분',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                SizedBox(height: 20),
                // 시간 선택 그리드
                Container(
                  constraints: BoxConstraints(
                    maxHeight: 300,
                    maxWidth: double.infinity,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.0,
                    ),
                    itemCount: validStartTimes.length,
                    itemBuilder: (context, index) {
                      final startTime = validStartTimes[index];
                      final timeString = _minutesToTime(startTime);

                      return InkWell(
                        onTap: () {
                          final endTime = startTime + _minServiceMin;
                          final timeString = _minutesToTime(startTime);
                          widget.onTimeSelected(timeString);
                          setState(() {
                            _selectedTimeRange = timeRange['formatted'];
                          });
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color(0xFF3B82F6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF3B82F6).withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              timeString,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 시간 범위를 시간대 리스트에 추가
  void _addTimeRange(int startMinutes, int endMinutes) {
    // 최소 레슨시간만큼의 여유를 두고 종료시간 계산
    final maxEndTime = endMinutes + _minServiceMin;
    final workEndMinutes = _timeToMinutes(_workEnd);
    final actualEndTime = maxEndTime > workEndMinutes ? workEndMinutes : maxEndTime;
    
    _availableTimeRanges.add({
      'start': _minutesToTimeOfDay(startMinutes),
      'end': _minutesToTimeOfDay(actualEndTime),
      'formatted': '${_minutesToTime(startMinutes)}~${_minutesToTime(actualEndTime)}',
      'startMinutes': startMinutes,
      'endMinutes': actualEndTime,
    });
    
    print('시간대 추가: ${_minutesToTime(startMinutes)}~${_minutesToTime(actualEndTime)}');
  }

  @override
  Widget build(BuildContext context) {
    print('\n=== 시간 선택 상태 ===');
    print('selectedTime: ${widget.selectedTime}');
    print('_selectedTimeRange: $_selectedTimeRange');
    
    // 필수 정보가 없는 경우
    if (widget.selectedDate == null || widget.selectedInstructor == null) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            '날짜와 강사를 먼저 선택해주세요',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      constraints: BoxConstraints(minHeight: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          
          // 로딩 상태 표시
          if (_isLoadingReservations)
            Container(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '예약 현황을 확인하는 중...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_availableTimeRanges.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 48,
                      color: Color(0xFF9CA3AF),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '예약 가능한 시간이 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '다른 날짜나 강사를 선택해주세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 시간대 선택 그리드
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: _availableTimeRanges.length,
                  itemBuilder: (context, index) {
                    final timeRange = _availableTimeRanges[index];
                    final isSelected = _selectedTimeRange == timeRange['formatted'];

                    return InkWell(
                      onTap: () => _showTimePicker(timeRange),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Color(0xFF10B981) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Color(0xFF10B981) : Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            timeRange['formatted'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // 선택된 시간 표시
                Container(
                  margin: EdgeInsets.only(top: 24),
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 12),
                      Text(
                        widget.selectedTime != null 
                          ? '레슨 시작시간  ${widget.selectedTime}'
                          : '레슨시작 시간범위을 선택해주세요',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: widget.selectedTime != null ? Color(0xFF1F2937) : Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
} 